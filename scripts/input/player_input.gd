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
	if state.is_runner(state.get_actor(id)):
		# 追いかけっこで走っている(鬼も追いかける人も): 走るのは自動。ジャンプと、列を変える(内側/外側)だけ
		if Input.is_action_just_pressed("chase_jump"):
			cmds.chase_jump(id)
		if Input.is_action_just_pressed("lane_in"):
			cmds.chase_lane(id, -1)
		if Input.is_action_just_pressed("lane_out"):
			cmds.chase_lane(id, 1)
		return
	if state.oni_id == id:
		# 鬼のとき: 落とす・フェイク(歩く速さと止まる・戻るはスティック。牛乳は main が送る)
		if Input.is_action_just_pressed("oni_drop"):
			cmds.oni_drop(id)
		if Input.is_action_just_pressed("oni_feint"):
			cmds.oni_feint(id)
	else:
		# 振り向く = 後ろに落ちていたら、そのまま拾って立ち上がる(「拾う」ボタンはない)
		var me := state.get_actor(id)
		# お手つきで抜けた人は振り向けない(バナナとスタンプだけ)
		if me.role == GameState.Role.OUT:
			_bananas(state, cmds, id)
			return
		var holding := Input.is_action_pressed("look_back")
		if Input.is_action_just_pressed("look_back") or Input.is_action_just_pressed("pick_up"):
			cmds.pick_up(id)
		elif holding and me.looking_back and state.phase == GameState.Phase.DROPPED and state.has_handkerchief_behind(me):
			# 振り向いたまま待っていたら、後ろに落とされた: そのまま拾う
			cmds.pick_up(id)
		cmds.set_looking_back(id, holding)
		_bananas(state, cmds, id)

	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := cam_basis.x
	right.y = 0.0
	var forward := -cam_basis.z
	forward.y = 0.0
	var dir := right.normalized() * v.x + forward.normalized() * -v.y
	cmds.set_move(id, dir)


## 追いかけっこ中: 鬼か追いかける人にバナナの皮
static func _bananas(state: GameState, cmds: Object, id: int) -> void:
	if Input.is_action_just_pressed("banana_oni"):
		cmds.throw_banana(id, state.oni_id)
	if Input.is_action_just_pressed("banana_chaser"):
		cmds.throw_banana(id, state.chaser_id)
