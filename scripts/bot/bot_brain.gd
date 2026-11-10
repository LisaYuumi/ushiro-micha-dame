class_name BotBrain
extends RefCounted
## ボットの判断。プレイヤーと同じ命令(振り向く・拾う・走る)を GameState に出すだけ。
## (オンライン対戦では、ホストだけがボットを動かす)

var rng := RandomNumberGenerator.new()
## 後ろに落とされたボットが気づくまでの残り時間(id -> 秒)
var _notice_left := {}


func reset(seed_value: int = -1) -> void:
	_notice_left.clear()
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
			GameState.Role.CHASER:
				_update_chaser(state, a)


## 座っているボット: 後ろに落とされたら、しばらくして気づいて拾う
func _update_seated(state: GameState, a: GameState.Actor, delta: float) -> void:
	if not state.has_handkerchief_behind(a):
		return
	if not _notice_left.has(a.id):
		_notice_left[a.id] = rng.randf_range(GameConfig.BOT_NOTICE_TIME_MIN, GameConfig.BOT_NOTICE_TIME_MAX)
	_notice_left[a.id] -= delta
	if _notice_left[a.id] <= 0.0:
		state.set_looking_back(a.id, true)
		state.pick_up(a.id)


## 追いかけるボット: 鬼にまっすぐ向かう(走れない向きは GameState が止める)
func _update_chaser(state: GameState, a: GameState.Actor) -> void:
	var oni := state.get_actor(state.oni_id)
	var to_oni := oni.position - a.position
	to_oni.y = 0.0
	state.set_move(a.id, to_oni.normalized())
