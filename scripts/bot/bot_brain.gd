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


func reset(seed_value: int = -1) -> void:
	_notice_left.clear()
	_stamp_left.clear()
	_look_left.clear()
	_banana_left.clear()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func update(state: GameState, delta: float) -> void:
	for a in state.actors:
		if not a.is_bot:
			continue
		match a.role:
			GameState.Role.SEATED:
				_update_seated(state, a, delta)
				_update_look(state, a, delta)
				_update_stamp(state, a, delta)
				_update_banana(state, a, delta)
			GameState.Role.CHASER:
				_update_chaser(state, a)


## GameState からのお知らせを見て反応する(届いたスタンプ・鬼の「ふり」の物音)
func on_event(state: GameState, e: Dictionary) -> void:
	if e.get("type") == "voice":
		# 鬼の声: いちばん近い席のボットがときどき「落とされた?」と振り向く
		var near := state.get_actor_at_seat(e["seat"])
		if near and near.is_bot and near.role == GameState.Role.SEATED \
				and rng.randf() < GameConfig.BOT_VOICE_FOOL_CHANCE:
			state.pick_up(near.id)
			_look_left[near.id] = GameConfig.BOT_LOOK_TIME
		return
	if e.get("type") == "rustle" and e.get("feint", false):
		# 人の鬼が「ふり」をした: その席のボットがときどきだまされて振り向く
		var fooled := state.get_actor_at_seat(e["seat"])
		if fooled and fooled.is_bot and fooled.role == GameState.Role.SEATED \
				and rng.randf() < GameConfig.BOT_FEINT_FOOL_CHANCE:
			state.pick_up(fooled.id)
			_look_left[fooled.id] = GameConfig.BOT_LOOK_TIME
		return
	if e.get("type") != "stamp":
		return
	var me := state.get_actor(e["target"])
	if me == null or not me.is_bot or me.role != GameState.Role.SEATED:
		return
	if not Stamps.says_look(e["kind"]):
		return
	if rng.randf() < GameConfig.BOT_TRUST_CHANCE:
		# 信じて振り向く。後ろにあれば拾い、なければお手つき
		state.pick_up(me.id)
		_look_left[me.id] = GameConfig.BOT_LOOK_TIME


## 座っているボット: 後ろに落とされたら、しばらくして気づいて拾う
func _update_seated(state: GameState, a: GameState.Actor, delta: float) -> void:
	if not state.has_handkerchief_behind(a):
		return
	if not _notice_left.has(a.id):
		# 重い落とし物ほど置く音が大きいので、早く気づく
		var k := lerpf(1.0, GameConfig.BOT_NOTICE_HEAVY, state.item_weight())
		if state.drop_masked:
			# 声で置く音がかき消されていたら、気づくのが遅れる
			k *= GameConfig.BOT_NOTICE_MASKED
		_notice_left[a.id] = rng.randf_range(GameConfig.BOT_NOTICE_TIME_MIN, GameConfig.BOT_NOTICE_TIME_MAX) * k
	_notice_left[a.id] -= delta
	if _notice_left[a.id] <= 0.0:
		state.pick_up(a.id)


## 振り向いたボットは、しばらくしたら前を向く
func _update_look(state: GameState, a: GameState.Actor, delta: float) -> void:
	if not _look_left.has(a.id):
		return
	_look_left[a.id] -= delta
	if _look_left[a.id] <= 0.0:
		_look_left.erase(a.id)
		state.set_looking_back(a.id, false)


## ときどき、鬼がついさっき後ろを通った人にスタンプを送る。半分は本当、半分は嘘
func _update_stamp(state: GameState, a: GameState.Actor, delta: float) -> void:
	if a.stamps_left == 0:
		return
	if not _stamp_left.has(a.id):
		_stamp_left[a.id] = rng.randf_range(GameConfig.BOT_STAMP_INTERVAL_MIN, GameConfig.BOT_STAMP_INTERVAL_MAX)
	_stamp_left[a.id] -= delta
	if _stamp_left[a.id] > 0.0:
		return
	_stamp_left.erase(a.id)

	var targets := []
	for t in state.actors:
		if t.id == a.id or t.role != GameState.Role.SEATED or state.active_stamps.has(t.id):
			continue
		if not GameState.can_see_behind(a.seat_index, t.seat_index):
			continue # 両どなりには送れない
		if state.seat_pass_age[t.seat_index] <= GameConfig.BOT_STAMP_RECENT_PASS:
			targets.append(t)
	if targets.is_empty():
		return
	var target: GameState.Actor = targets[rng.randi_range(0, targets.size() - 1)]
	var honest := rng.randf() < GameConfig.BOT_STAMP_HONEST_CHANCE
	var behind := state.has_handkerchief_behind(target)
	var say_look := behind if honest else not behind
	var kind := Stamps.SAFE
	if say_look:
		var r := rng.randf()
		kind = Stamps.DROPPED if r < 0.5 else (Stamps.NOW if r < 0.8 else Stamps.TRUST)
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
