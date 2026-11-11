class_name PlayerInput
extends RefCounted
## この画面のプレイヤーのキー入力を、命令に変える。
## cmds は命令の送り先: ひとり/ホストなら GameState そのもの、ホスト以外なら RemoteCommands
## (同じ名前の関数を持っていて、ホストに送る)。state は今の状態を読むためだけに使う。


## cam_basis: 今のカメラの向き。走る向きを「画面の上下左右」に合わせるために使う
static func apply(state: GameState, cmds: Object, cam_basis: Basis) -> void:
	var id := state.local_player_id
	if state.get_actor(id) == null:
		return
	if state.oni_id == id:
		# 鬼のとき: 止まる・落とす・声(咳/口笛/手拍子/叫ぶ)・落とす音
		cmds.set_oni_stop(id, Input.is_action_pressed("oni_stop"))
		for i in Voices.ALL.size():
			if Input.is_action_just_pressed("voice_%d" % i):
				cmds.oni_voice(id, Voices.ALL[i])
		if Input.is_action_just_pressed("oni_drop"):
			cmds.oni_drop(id)
		if Input.is_action_just_pressed("oni_feint"):
			cmds.oni_feint(id)
	else:
		cmds.set_looking_back(id, Input.is_action_pressed("look_back"))
		if Input.is_action_just_pressed("pick_up"):
			cmds.pick_up(id)
		# 追いかけっこ中: 鬼か追いかける人にバナナの皮
		if Input.is_action_just_pressed("banana_oni"):
			cmds.throw_banana(id, state.oni_id)
		if Input.is_action_just_pressed("banana_chaser"):
			cmds.throw_banana(id, state.chaser_id)

	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := cam_basis.x
	right.y = 0.0
	var forward := -cam_basis.z
	forward.y = 0.0
	var dir := right.normalized() * v.x + forward.normalized() * -v.y
	cmds.set_move(id, dir)
