class_name BotBrain
extends RefCounted
## ボットの判断。プレイヤーと同じ命令(振り向く・拾う・走る・スタンプ)を GameState に出すだけ。
## (オンライン対戦では、ホストだけがボットを動かす)

var rng := RandomNumberGenerator.new()
## 後ろに落とされたボットが気づくまでの残り時間(id -> 秒)
var _notice_left := {}
## 次にスタンプを送るまでの時間(id -> 秒)
var _stamp_left := {}
## 振り向いている残り時間(id -> 秒)
var _look_left := {}
## バナナを投げるまでの時間(id -> 秒。-1 は今回の追いかけっこでは投げない)
var _banana_left := {}
## 振り向いてよくなる前に届いたスタンプを、あとで考え直す人(id -> true)
var _stamp_pending := {}


func reset(seed_value: int = -1) -> void:
	_notice_left.clear()
	_stamp_left.clear()
	_look_left.clear()
	_banana_left.clear()
	_stamp_pending.clear()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func update(state: GameState, delta: float) -> void:
	for a in state.actors:
		if not a.is_bot:
			continue
		match a.role:
			GameState.Role.ONI:
				# 鬼のボットも、ときどきスタンプを送る(だいたい嘘)
				_update_stamp(state, a, delta)
			GameState.Role.SEATED:
				_update_seated(state, a, delta)
				_update_look(state, a, delta)
				_update_stamp(state, a, delta)
				_update_banana(state, a, delta)
			GameState.Role.CHASER:
				_update_chaser(state, a)
			GameState.Role.OUT:
				# お手つきで抜けたボット: 全員の後ろが見えるので、スタンプとバナナだけ
				_update_stamp(state, a, delta)
				_update_banana(state, a, delta)


## GameState からのお知らせを見て反応する(届いたスタンプ・鬼の「ふり」の物音)
func on_event(state: GameState, e: Dictionary) -> void:
	if e.get("type") == "rustle" and e.get("feint", false):
		# 人の鬼が「ふり」をした: その席のボットがときどきだまされて振り向く
		var fooled := state.get_actor_at_seat(e["seat"])
		if fooled and fooled.is_bot and fooled.role == GameState.Role.SEATED and may_turn(state, fooled) \
				and rng.randf() < GameConfig.BOT_FEINT_FOOL_CHANCE:
			state.pick_up(fooled.id)
			_look_left[fooled.id] = GameConfig.BOT_LOOK_TIME
		return
	if e.get("type") != "stamp":
		return
	var me := state.get_actor(e["target"])
	if me == null or not me.is_bot or me.role != GameState.Role.SEATED:
		return
	if not may_turn(state, me):
		# まだ振り向いてよくない: 振り向いてよくなったら考え直す
		_stamp_pending[me.id] = true
		return
	_consider_stamps(state, me)


## 鬼が自分の後ろを通ってから BOT_TURN_MIN_AFTER_PASS 秒たっているか(一度も通っていなければ false)。
## ボットはこれが true のときだけ振り向く
static func may_turn(state: GameState, a: GameState.Actor) -> bool:
	if a.seat_index < 0 or a.seat_index >= state.seat_pass_age.size():
		return false
	var age: float = state.seat_pass_age[a.seat_index]
	return age != INF and age >= GameConfig.BOT_TURN_MIN_AFTER_PASS


## 届いているスタンプを見て、振り向くか決める
func _consider_stamps(state: GameState, me: GameState.Actor) -> void:
	# 届いているスタンプの多数決: 「見ろ」は +1、「まだ平気」は -1。
	# 前のラウンドで手下だった人のスタンプは、あまり信用しない
	var vote := 0.0
	for st in state.active_stamps.get(me.id, []):
		var w := 1.0
		if st["sender"] == state.last_minion_id:
			w = GameConfig.BOT_PREV_MINION_WEIGHT
		vote += w if Stamps.says_look(st["kind"]) else -w
	var p := Personalities.params(me.personality)
	var need: float = p["threshold"]
	if me.looks_left <= 1:
		# 最後の1回は拾うために取っておきたいので、よほどそろわないと振り向かない
		need += 1.0
	if vote < need - 0.001:
		return
	if rng.randf() < GameConfig.BOT_TRUST_CHANCE * p["trust"]:
		# 信じて振り向く。後ろにあれば拾い、なければお手つき
		state.pick_up(me.id)
		_look_left[me.id] = GameConfig.BOT_LOOK_TIME


## 座っているボット: 後ろに落とされたら、しばらくして気づいて拾う
func _update_seated(state: GameState, a: GameState.Actor, delta: float) -> void:
	if _stamp_pending.has(a.id) and may_turn(state, a):
		_stamp_pending.erase(a.id)
		if not state.active_stamps.get(a.id, []).is_empty():
			_consider_stamps(state, a)
	if not state.has_handkerchief_behind(a):
		return
	if not _notice_left.has(a.id):
		# 重い落とし物ほど置く音が大きいので、早く気づく
		var k := lerpf(1.0, GameConfig.BOT_NOTICE_HEAVY, state.item_weight())
		if state.is_milked(a):
			# 牛乳がかかって前が白いと、気づくのが遅れる
			k *= GameConfig.BOT_MILK_NOTICE_MULT
		# せっかちな性格ほど早く気づく
		k *= Personalities.params(a.personality)["notice"]
		_notice_left[a.id] = rng.randf_range(GameConfig.BOT_NOTICE_TIME_MIN, GameConfig.BOT_NOTICE_TIME_MAX) * k
	_notice_left[a.id] -= delta
	# 気づいても、鬼がまだすぐ後ろ(通って BOT_TURN_MIN_AFTER_PASS 秒以内)なら待つ
	if _notice_left[a.id] <= 0.0 and may_turn(state, a):
		state.pick_up(a.id)


## 振り向いたボットは、しばらくしたら前を向く
func _update_look(state: GameState, a: GameState.Actor, delta: float) -> void:
	if not _look_left.has(a.id):
		return
	_look_left[a.id] -= delta
	if _look_left[a.id] <= 0.0:
		_look_left.erase(a.id)
		state.set_looking_back(a.id, false)


## ときどき、鬼がついさっき後ろを通った人にスタンプを送る。
## 落とされた人だけでなく、鬼が通った人にまんべんなく送る(スタンプの数で答えがわからないように)。
## 本当か嘘かは役で決まる: 普通の人はだいたい本当、手下と鬼はだいたい嘘
func _update_stamp(state: GameState, a: GameState.Actor, delta: float) -> void:
	if a.stamps_left == 0:
		return
	var is_oni := a.role == GameState.Role.ONI
	if not _stamp_left.has(a.id):
		if is_oni:
			_stamp_left[a.id] = rng.randf_range(GameConfig.BOT_ONI_STAMP_INTERVAL_MIN, GameConfig.BOT_ONI_STAMP_INTERVAL_MAX)
		else:
			_stamp_left[a.id] = rng.randf_range(GameConfig.BOT_STAMP_INTERVAL_MIN, GameConfig.BOT_STAMP_INTERVAL_MAX) \
					* Personalities.params(a.personality)["interval"]
	_stamp_left[a.id] -= delta
	if _stamp_left[a.id] > 0.0:
		return
	_stamp_left.erase(a.id)

	# 送れる相手のうち、表示中のスタンプがいちばん少ない人を選ぶ
	var targets := []
	var fewest := INF
	for t in state.actors:
		if t.role != GameState.Role.SEATED or state.stamp_block_reason(a.id, t.id) != "":
			continue
		if state.seat_pass_age[t.seat_index] > GameConfig.BOT_STAMP_RECENT_PASS:
			continue
		var n: int = state.active_stamps.get(t.id, []).size()
		if n < fewest:
			fewest = n
			targets = [t]
		elif n == fewest:
			targets.append(t)
	if targets.is_empty():
		return
	var target: GameState.Actor = targets[rng.randi_range(0, targets.size() - 1)]
	var say_look := false
	if state.sees_behind(a.id, target.seat_index):
		var honest_chance := GameConfig.BOT_NORMAL_HONEST_CHANCE
		match state.stamp_role_of(a.id):
			"minion":
				honest_chance = GameConfig.BOT_MINION_HONEST_CHANCE
			"oni":
				honest_chance = GameConfig.BOT_ONI_HONEST_CHANCE
		var behind := state.has_handkerchief_behind(target)
		say_look = behind if rng.randf() < honest_chance else not behind
	else:
		# 後ろが見えない相手(5人のときの両どなり)には当てずっぽう。間違えることがある
		say_look = rng.randf() < GameConfig.BOT_GUESS_LOOK_CHANCE
	var kind := Stamps.SAFE if rng.randf() < 0.7 else Stamps.FAKE
	if say_look:
		kind = Stamps.DROPPED if rng.randf() < 0.65 else Stamps.TRUST
	state.send_stamp(a.id, target.id, kind)


## 追いかけっこ中、ときどき鬼か追いかける人にバナナの皮を投げる
func _update_banana(state: GameState, a: GameState.Actor, delta: float) -> void:
	if state.phase != GameState.Phase.CHASE or a.bananas_left <= 0:
		return
	if not _banana_left.has(a.id):
		var go := rng.randf() < GameConfig.BOT_BANANA_CHANCE
		_banana_left[a.id] = rng.randf_range(GameConfig.BOT_BANANA_DELAY_MIN, GameConfig.BOT_BANANA_DELAY_MAX) if go else -1.0
	if _banana_left[a.id] < 0.0:
		return
	_banana_left[a.id] -= delta
	if _banana_left[a.id] <= 0.0:
		_banana_left[a.id] = -1.0
		var target := state.oni_id if rng.randf() < 0.5 else state.chaser_id
		state.throw_banana(a.id, target)


## 追いかけるボット: ふだんは内側(近道)を走り、鬼に近づいたら鬼のほうへ曲がる
## (前へは自動で走る)
func _update_chaser(state: GameState, a: GameState.Actor) -> void:
	state.set_move(a.id, chase_steer(state, a))


## 追いかけ方のお手本(テストでも使う)
static func chase_steer(state: GameState, a: GameState.Actor) -> Vector3:
	var oni := state.get_actor(state.oni_id)
	var to_oni := oni.position - a.position
	to_oni.y = 0.0
	if to_oni.length() < 2.5:
		return to_oni.normalized()
	return -Vector3(a.position.x, 0.0, a.position.z).normalized()
