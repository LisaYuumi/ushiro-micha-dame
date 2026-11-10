class_name PlayerInput
extends RefCounted
## この画面のプレイヤーのキー入力を、GameState への命令に変える。
## (オンライン対戦では、この命令をホストに送る形に置きかえる)


## cam_basis: 今のカメラの向き。走る向きを「画面の上下左右」に合わせるために使う
static func apply(state: GameState, cam_basis: Basis) -> void:
	var id := state.local_player_id
	if state.oni_is_player:
		# 鬼のとき: 止まる・落とす・声(咳/口笛/手拍子/叫ぶ)
		state.set_oni_stop(id, Input.is_action_pressed("oni_stop"))
		for i in Voices.ALL.size():
			if Input.is_action_just_pressed("voice_%d" % i):
				state.oni_voice(id, Voices.ALL[i])
		if Input.is_action_just_pressed("oni_drop"):
			state.oni_drop(id)
		if Input.is_action_just_pressed("oni_feint"):
			state.oni_feint(id)
	else:
		state.set_looking_back(id, Input.is_action_pressed("look_back"))
		if Input.is_action_just_pressed("pick_up"):
			state.pick_up(id)
		# 追いかけっこ中: 鬼か追いかける人にバナナの皮
		if Input.is_action_just_pressed("banana_oni"):
			state.throw_banana(id, state.oni_id)
		if Input.is_action_just_pressed("banana_chaser"):
			state.throw_banana(id, state.chaser_id)

	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := cam_basis.x
	right.y = 0.0
	var forward := -cam_basis.z
	forward.y = 0.0
	var dir := right.normalized() * v.x + forward.normalized() * -v.y
	state.set_move(id, dir)
