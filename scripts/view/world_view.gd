class_name WorldView
extends Node3D
## GameState を読んで 3D の見た目を作る・更新するだけ。
## 状態は書きかえない。

## 自分の体を自分のカメラに映さないためのレイヤー
const SELF_LAYER := 2

var _actor_nodes := {} # id -> Node3D
var _seat_cam: Camera3D
var _top_cam: Camera3D


func build(state: GameState) -> void:
	for c in get_children():
		c.queue_free()
	_actor_nodes.clear()

	_build_environment()
	_build_floor()
	for i in state.seat_positions.size():
		_build_chair(state.seat_positions[i], state.seat_yaws[i])
	for a in state.actors:
		var node := _build_character(a, a.id == state.local_player_id)
		add_child(node)
		_actor_nodes[a.id] = node
	_build_cameras(state)
	sync(state)


## 毎フレーム、状態に合わせて位置と向きを反映する。
func sync(state: GameState) -> void:
	for a in state.actors:
		var node: Node3D = _actor_nodes.get(a.id)
		if node:
			node.position = a.position
			node.rotation.y = a.yaw


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


func _build_cameras(state: GameState) -> void:
	var me := state.get_local_player()

	_seat_cam = Camera3D.new()
	_seat_cam.fov = 75
	_seat_cam.near = 0.05
	# 自分の体のレイヤーを映さない
	_seat_cam.cull_mask = 0xFFFFF & ~(1 << (SELF_LAYER - 1))
	add_child(_seat_cam)
	var eye_pos := me.position + Vector3(0, 1.45, 0)
	_seat_cam.look_at_from_position(eye_pos, Vector3(0, 0.8, 0))
	_seat_cam.make_current()

	_top_cam = Camera3D.new()
	_top_cam.fov = 60
	add_child(_top_cam)
	_top_cam.look_at_from_position(Vector3(0, 13, 6), Vector3.ZERO)


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
