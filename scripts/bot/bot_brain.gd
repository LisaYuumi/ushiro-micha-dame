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


func reset(seed_value: int = -1) -> void:
	_notice_left.clear()
	_stamp_left.clear()
	_look_left.clear()
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
			GameState.Role.CHASER:
				_update_chaser(state, a)


## GameState からのお知らせを見て反応する(届いたスタンプを信じるかどうか)
func on_event(state: GameState, e: Dictionary) -> void:
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
		_notice_left[a.id] = rng.randf_range(GameConfig.BOT_NOTICE_TIME_MIN, GameConfig.BOT_NOTICE_TIME_MAX)
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


## ときどき誰かにスタンプを送る。半分は本当、半分は嘘
func _update_stamp(state: GameState, a: GameState.Actor, delta: float) -> void:
	if a.stamps_left <= 0:
		return
	if not _stamp_left.has(a.id):
		_stamp_left[a.id] = rng.randf_range(GameConfig.BOT_STAMP_INTERVAL_MIN, GameConfig.BOT_STAMP_INTERVAL_MAX)
	_stamp_left[a.id] -= delta
	if _stamp_left[a.id] > 0.0:
		return
	_stamp_left.erase(a.id)

	var targets := []
	for t in state.actors:
		if t.id != a.id and t.role == GameState.Role.SEATED and not state.active_stamps.has(t.id):
			targets.append(t)
	if targets.is_empty():
		return
	var target: GameState.Actor = targets[rng.randi_range(0, targets.size() - 1)]
	var behind := state.has_handkerchief_behind(target)
	var honest := rng.randf() < GameConfig.BOT_STAMP_HONEST_CHANCE
	var say_look := behind if honest else not behind
	var kind := Stamps.SAFE
	if say_look:
		var r := rng.randf()
		kind = Stamps.DROPPED if r < 0.5 else (Stamps.NOW if r < 0.8 else Stamps.TRUST)
	state.send_stamp(a.id, target.id, kind)


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
