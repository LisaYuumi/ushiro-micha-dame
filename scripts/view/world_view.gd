class_name WorldView
extends Node3D
## GameState を読んで 3D の見た目を作る・更新するだけ。
## 状態は書きかえない。

## 自分の体を自分のカメラに映さないためのレイヤー
const SELF_LAYER := 2

var _actor_nodes := {} # id -> Node3D
var _seat_cam: Camera3D
var _top_cam: Camera3D
var _handkerchief: Node3D
var _drop_player: AudioStreamPlayer3D
var _step_player: AudioStreamPlayer3D
var _beep_player: AudioStreamPlayer
var _stamp_player: AudioStreamPlayer
## 頭の上のスタンプ表示(id -> Label3D)
var _stamp_labels := {}
## スタンプを送る相手の目印
var _target_marker: MeshInstance3D

## スタンプの色(仮)
const STAMP_COLORS := {
	Stamps.DROPPED: Color(0.95, 0.35, 0.2),
	Stamps.SAFE: Color(0.2, 0.7, 0.35),
	Stamps.NOW: Color(0.95, 0.7, 0.1),
	Stamps.TRUST: Color(0.6, 0.4, 0.9),
}
## 足音用: 鬼の前回の位置と、前の足音から歩いた距離
var _oni_last_pos := Vector3.ZERO
var _oni_walked := 0.0
## 振り向きの度合い(0=前、1=後ろ)。見た目をなめらかにするためだけの値
var _turn := {} # id -> float


func build(state: GameState) -> void:
	for c in get_children():
		c.queue_free()
	_actor_nodes.clear()
	_turn.clear()
	_stamp_labels.clear()

	_build_environment()
	_build_floor()
	for i in state.seat_positions.size():
		_build_chair(state.seat_positions[i], state.seat_yaws[i])
	for a in state.actors:
		var node := _build_character(a, a.id == state.local_player_id)
		add_child(node)
		_actor_nodes[a.id] = node
	_build_handkerchief()
	_build_stamp_labels(state)
	_build_sounds(state)
	_build_cameras(state)
	sync(state, 0.0)


## 毎フレーム、状態に合わせて位置と向きを反映する。
func sync(state: GameState, delta: float) -> void:
	var turn_step := delta / GameConfig.LOOK_BACK_TIME
	for a in state.actors:
		var t: float = move_toward(_turn.get(a.id, 0.0), 1.0 if a.looking_back else 0.0, turn_step)
		_turn[a.id] = t
		var node: Node3D = _actor_nodes.get(a.id)
		if node:
			node.position = a.position
			# 振り向いた姿は全員に見える(体ごと大げさに後ろを向く)
			node.rotation.y = a.yaw + PI * t
	_update_seat_camera(state, delta)
	_update_stamp_labels(state)

	var holder := state.get_actor(state.chaser_id)
	if holder:
		# 追いかける人が手に持っている
		_handkerchief.visible = true
		_handkerchief.position = holder.position + Vector3(0, 1.0, 0)
	else:
		_handkerchief.visible = state.handkerchief_on_floor
		_handkerchief.position = state.handkerchief_position
	_update_footsteps(state)


## GameState からのお知らせに合わせて音などを出す。
func on_event(e: Dictionary) -> void:
	match e.get("type"):
		"dropped", "rustle":
			# 本物もニセの物音も、まったく同じ音
			_drop_player.position = e["pos"]
			_drop_player.pitch_scale = randf_range(0.9, 1.1)
			_drop_player.play()



func _update_footsteps(state: GameState) -> void:
	var oni := state.get_actor(state.oni_id)
	if oni == null:
		return
	_oni_walked += oni.position.distance_to(_oni_last_pos)
	_oni_last_pos = oni.position
	if _oni_walked >= GameConfig.FOOTSTEP_STRIDE:
		_oni_walked = 0.0
		_step_player.pitch_scale = randf_range(0.85, 1.15)
		_step_player.play()


## 席のカメラ ⇔ 上から見るカメラ(確認用)を切りかえる。
func toggle_top_camera() -> void:
	if _top_cam.current:
		_seat_cam.make_current()
	else:
		_top_cam.make_current()


func is_top_camera() -> bool:
	return _top_cam.current


# --- ここから下は見た目を作る処理 ---

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.9, 0.82) # 教室の壁っぽいクリーム色
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	add_child(_mesh(plane, Color(0.72, 0.55, 0.38))) # 木の床
	# 床板の継ぎ目っぽい線
	for i in range(-7, 8):
		var line := BoxMesh.new()
		line.size = Vector3(16, 0.002, 0.03)
		var mi := _mesh(line, Color(0.6, 0.44, 0.3))
		mi.position = Vector3(0, 0.001, i)
		add_child(mi)


func _build_chair(pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	var wood := Color(0.55, 0.35, 0.2)

	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.5, 0.05, 0.5)
	var seat := _mesh(seat_mesh, wood)
	seat.position = Vector3(0, 0.45, 0)
	chair.add_child(seat)

	# 背もたれは後ろ側(+Z)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.5, 0.5, 0.05)
	var back := _mesh(back_mesh, wood)
	back.position = Vector3(0, 0.72, 0.28)
	chair.add_child(back)

	var metal := Color(0.4, 0.4, 0.42)
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.04, 0.45, 0.04)
			var leg := _mesh(leg_mesh, metal)
			leg.position = Vector3(x, 0.225, z)
			chair.add_child(leg)
	add_child(chair)


## 仮のキャラクター: カプセルの体+球の頭+点の目。正面は -Z。
func _build_character(a: GameState.Actor, is_self: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Actor%d" % a.id

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.15
	var body := _mesh(body_mesh, a.color)
	body.position = Vector3(0, 0.6, 0)
	root.add_child(body)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var head := _mesh(head_mesh, a.color.lightened(0.25))
	head.position = Vector3(0, 1.42, 0)
	root.add_child(head)

	for x in [-0.08, 0.08]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		var eye := _mesh(eye_mesh, Color.BLACK)
		eye.position = Vector3(x, 1.46, -0.2)
		root.add_child(eye)

	var label := Label3D.new()
	label.text = a.display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 8
	label.position = Vector3(0, 1.85, 0)
	label.font = HudFont.get_font()
	root.add_child(label)

	if is_self:
		# 自分の体は自分の席カメラには映さない
		for c in root.get_children():
			if c is VisualInstance3D:
				c.layers = 1 << (SELF_LAYER - 1)
	return root


## 頭の上のスタンプ表示と、送る相手の目印
func _build_stamp_labels(state: GameState) -> void:
	for a in state.actors:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font = HudFont.get_font()
		# ほかの人あてのスタンプは小さめに(自分あては画面の下の吹き出しに出る)
		l.font_size = 44
		l.pixel_size = 0.004
		l.outline_size = 8
		l.no_depth_test = true
		l.position = Vector3(0, 2.25, 0)
		l.visible = false
		(_actor_nodes[a.id] as Node3D).add_child(l)
		_stamp_labels[a.id] = l

	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.0
	cone.height = 0.3
	_target_marker = _mesh(cone, Color(1.0, 0.85, 0.1))
	_target_marker.visible = false
	add_child(_target_marker)


func _update_stamp_labels(state: GameState) -> void:
	for id in _stamp_labels:
		var l: Label3D = _stamp_labels[id]
		var s: Dictionary = state.active_stamps.get(id, {})
		l.visible = not s.is_empty()
		if s.is_empty():
			continue
		var text: String = Stamps.LABELS[s["kind"]]
		if GameConfig.SHOW_STAMP_SENDER:
			var sender := state.get_actor(s["sender"])
			text += "\n(%s)" % sender.display_name
		l.text = text
		l.modulate = STAMP_COLORS[s["kind"]]


## 仮のハンカチ: 白くて薄い四角
func _build_handkerchief() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.02, 0.35)
	_handkerchief = _mesh(box, Color(0.97, 0.97, 1.0))
	_handkerchief.visible = false
	add_child(_handkerchief)


func _build_sounds(state: GameState) -> void:
	# 足音は鬼の体についていく(左右・遠近で鬼の位置がわかる)
	_step_player = AudioStreamPlayer3D.new()
	_step_player.stream = Sfx.footstep()
	_step_player.volume_db = GameConfig.FOOTSTEP_VOLUME_DB
	_step_player.max_polyphony = 2
	# スマホのブラウザでも鳴るように、PC と同じ方式で再生する
	_step_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	(_actor_nodes[state.oni_id] as Node3D).add_child(_step_player)
	_oni_last_pos = state.get_actor(state.oni_id).position
	_oni_walked = 0.0

	_drop_player = AudioStreamPlayer3D.new()
	_drop_player.stream = Sfx.drop()
	_drop_player.volume_db = GameConfig.DROP_VOLUME_DB
	_drop_player.unit_size = GameConfig.DROP_SOUND_RANGE
	_drop_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_drop_player)

	_stamp_player = AudioStreamPlayer.new()
	_stamp_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_stamp_player.volume_db = -6.0
	add_child(_stamp_player)

	_beep_player = AudioStreamPlayer.new()
	_beep_player.stream = Sfx.beep()
	_beep_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_beep_player)


## 自分に届いたスタンプの音(ほかの人あてのスタンプでは鳴らさない)
func play_stamp_sound(kind: String) -> void:
	_stamp_player.stream = Sfx.stamp(kind)
	_stamp_player.play()


## スタンプを送る相手の目印を出す(-1 で消す)
func set_stamp_target(state: GameState, id: int) -> void:
	var a := state.get_actor(id)
	_target_marker.visible = a != null
	if a:
		_target_marker.position = a.position + Vector3(0, 2.25, 0)


## 画面のこの位置(タップした場所)にいる、座っている人の id(いなければ -1)
func pick_actor_at(state: GameState, screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var best := -1
	var best_dist := 110.0
	for a in state.actors:
		if a.id == state.local_player_id or a.role != GameState.Role.SEATED:
			continue
		for h in [0.9, 1.45]:
			var p: Vector3 = a.position + Vector3(0, h, 0)
			if cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen_pos)
			if d < best_dist:
				best_dist = d
				best = a.id
	return best


## 音テスト: 方向や距離に関係なく「ピー」と鳴らす
func play_test_beep() -> void:
	_beep_player.play()


func _build_cameras(state: GameState) -> void:
	var me := state.get_local_player()

	_seat_cam = Camera3D.new()
	_seat_cam.fov = 75
	_seat_cam.near = 0.05
	# 自分の体のレイヤーを映さない
	_seat_cam.cull_mask = 0xFFFFF & ~(1 << (SELF_LAYER - 1))
	add_child(_seat_cam)
	_seat_cam.make_current()
	_update_seat_camera(state, 0.0)

	_top_cam = Camera3D.new()
	_top_cam.fov = 60
	add_child(_top_cam)
	_top_cam.look_at_from_position(Vector3(0, 13, 6), Vector3.ZERO)


## 今のカメラの向き(走る向きを画面に合わせるため、入力側が使う)
func get_camera_basis() -> Basis:
	var cam := get_viewport().get_camera_3d()
	return cam.global_basis if cam else Basis.IDENTITY


## 自分のカメラ:
## - 座っているとき: 前は輪の内側、振り向くと足元の後ろを見る
## - 追いかけているとき: 輪の外側・斜め上から自分を見る(画面の右が鬼の走る向き)
func _update_seat_camera(state: GameState, delta: float) -> void:
	var me := state.get_local_player()
	if me == null or _seat_cam == null:
		return
	# 座っているときは自分の体を映さない。立ち上がって追いかけるときは映す
	var self_bit := 1 << (SELF_LAYER - 1)
	if me.role == GameState.Role.CHASER:
		_seat_cam.cull_mask = 0xFFFFF
	else:
		_seat_cam.cull_mask = 0xFFFFF & ~self_bit
	if me.role == GameState.Role.CHASER:
		var out := Vector3(me.position.x, 0.0, me.position.z).normalized()
		var want := me.position + out * GameConfig.CHASE_CAM_DISTANCE + Vector3(0, GameConfig.CHASE_CAM_HEIGHT, 0)
		# 立ち上がった直後は一気に、そのあとはなめらかに追う
		var w := 1.0 if delta == 0.0 else clampf(delta * 8.0, 0.0, 1.0)
		var from := _seat_cam.position
		if from.distance_to(want) > 6.0:
			w = 1.0
		_seat_cam.look_at_from_position(from.lerp(want, w), me.position + Vector3(0, 0.8, 0))
		return
	var t: float = _turn.get(me.id, 0.0)
	var back_dir := Vector3(sin(me.yaw), 0.0, cos(me.yaw))
	_seat_cam.position = me.position + Vector3(0, 1.45, 0) + back_dir * GameConfig.LOOK_BACK_LEAN * t
	var pitch := lerpf(GameConfig.SEAT_CAM_PITCH_FRONT, GameConfig.SEAT_CAM_PITCH_BACK, t)
	_seat_cam.rotation = Vector3(deg_to_rad(pitch), me.yaw + PI * t, 0.0)


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
