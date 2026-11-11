class_name CharacterModel
extends Node3D
## 仮のキャラクター: カプセルの体+球の頭+点の目と線の口。正面は -Z。
## 表情(set_expression)と、大げさな動き(跳ねる・前のめり・しょんぼり)を見た目だけで出す。
## 状態(GameState)は持たない。WorldView が毎フレーム表情を決めて渡す。

const NORMAL := "normal"       # ふだん: 点の目・まっすぐな口
const SURPRISED := "surprised" # 振り向いた/スタンプが届いた: 丸い大きな目・「o」の口
const OOPS := "oops"           # お手つき: 汗・「へ」の口
const PANIC := "panic"         # 追いかける/逃げる: 細い目・汗・「o」の口・前のめり
const WIN := "win"             # 勝ち: にっこり(「^」の目・U の口)
const LOSE := "lose"           # 負け: しょんぼり(下がった目・への字の口・うなだれる)

## お手つきでだんだん崩れる顔(set_fluster)
## 0: ふだん / 1: 困り眉・汗 / 2: 汗2つ・目がちぐはぐ・への字口・ふるえる / 3: 放心(×の目・ぽかん口・ふらふら)
const FLUSTER_MAX := 3

const HEAD_Y := 1.42
const FACE_Z := -0.205

var _pivot: Node3D
var _eyes: Array[MeshInstance3D] = []
var _happy_eyes: Array[Node3D] = []
var _mouth_flat: MeshInstance3D
var _mouth_o: MeshInstance3D
var _mouth_smile: Node3D
var _mouth_frown: Node3D
var _sweat: MeshInstance3D
var _sweat2: MeshInstance3D
var _brows: Array[MeshInstance3D] = []
var _x_eyes: Array[Node3D] = []
var _expression := ""
var _fluster := -1
var _hop := 0.0
var _lean := 0.0
var _slump := 0.0
var _time := 0.0
var _slip := 0.0


func build(color: Color, display_name: String, font: Font) -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.15
	var body := _mesh(body_mesh, color)
	body.position = Vector3(0, 0.6, 0)
	_pivot.add_child(body)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var head := _mesh(head_mesh, color.lightened(0.25))
	head.position = Vector3(0, HEAD_Y, 0)
	_pivot.add_child(head)

	# 点の目
	for x in [-0.08, 0.08]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		var eye := _mesh(eye_mesh, Color.BLACK)
		eye.position = Vector3(x, HEAD_Y + 0.04, FACE_Z + 0.005)
		_pivot.add_child(eye)
		_eyes.append(eye)
		# にっこりの「^」の目
		var happy := _bent_line(Vector3(x, HEAD_Y + 0.045, FACE_Z), 0.05, 0.4)
		_pivot.add_child(happy)
		_happy_eyes.append(happy)

	# 口のいろいろ
	_mouth_flat = _box(Vector3(0.1, 0.016, 0.01), Vector3(0, HEAD_Y - 0.08, FACE_Z))
	_pivot.add_child(_mouth_flat)
	var o_mesh := SphereMesh.new()
	o_mesh.radius = 0.035
	o_mesh.height = 0.07
	_mouth_o = _mesh(o_mesh, Color(0.25, 0.05, 0.05))
	_mouth_o.position = Vector3(0, HEAD_Y - 0.09, FACE_Z + 0.01)
	_pivot.add_child(_mouth_o)
	_mouth_smile = _bent_line(Vector3(0, HEAD_Y - 0.09, FACE_Z), 0.06, -0.5)
	_pivot.add_child(_mouth_smile)
	_mouth_frown = _bent_line(Vector3(0, HEAD_Y - 0.1, FACE_Z), 0.06, 0.5)
	_pivot.add_child(_mouth_frown)

	# 汗(水色のしずく)
	var sweat_mesh := SphereMesh.new()
	sweat_mesh.radius = 0.04
	sweat_mesh.height = 0.11
	_sweat = _mesh(sweat_mesh, Color(0.45, 0.75, 1.0))
	_sweat.position = Vector3(0.2, HEAD_Y + 0.1, -0.08)
	_pivot.add_child(_sweat)
	_sweat2 = _mesh(sweat_mesh, Color(0.45, 0.75, 1.0))
	_sweat2.position = Vector3(-0.19, HEAD_Y + 0.02, -0.1)
	_pivot.add_child(_sweat2)

	# 困り眉(ハの字)と、放心の「×」の目
	for x in [-0.08, 0.08]:
		var brow := _box(Vector3(0.075, 0.015, 0.01), Vector3(x, HEAD_Y + 0.115, FACE_Z + 0.01))
		brow.rotation.z = 0.4 if x < 0.0 else -0.4
		_pivot.add_child(brow)
		_brows.append(brow)
		var xe := Node3D.new()
		xe.position = Vector3(x, HEAD_Y + 0.04, FACE_Z)
		for r in [0.785, -0.785]:
			var bar := _box(Vector3(0.07, 0.014, 0.01), Vector3.ZERO)
			bar.rotation.z = r
			xe.add_child(bar)
		_pivot.add_child(xe)
		_x_eyes.append(xe)

	var label := Label3D.new()
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 8
	label.position = Vector3(0, 1.85, 0)
	label.font = font
	add_child(label)

	set_expression(NORMAL)


## 自分のカメラから隠すときなどに、すべての見た目のレイヤーをまとめて変える
func set_layers(layer_bits: int) -> void:
	_set_layers_rec(self, layer_bits)


func set_expression(expr: String) -> void:
	if expr == _expression:
		return
	_expression = expr
	_apply_face()


## お手つきの回数に合わせて、顔をだんだん崩す(0〜FLUSTER_MAX)
func set_fluster(level: int) -> void:
	level = clampi(level, 0, FLUSTER_MAX)
	if level == _fluster:
		return
	_fluster = level
	_apply_face()


func _apply_face() -> void:
	var expr := _expression
	var happy := expr == WIN
	for e in _eyes:
		e.visible = not happy
	for h in _happy_eyes:
		h.visible = happy
	_mouth_flat.visible = expr == NORMAL
	_mouth_o.visible = expr == SURPRISED or expr == PANIC
	_mouth_smile.visible = expr == WIN
	_mouth_frown.visible = expr == OOPS or expr == LOSE
	_sweat.visible = expr == OOPS or expr == PANIC
	var eye_scale := Vector3.ONE
	match expr:
		SURPRISED:
			eye_scale = Vector3(1.7, 1.7, 1.7)
		PANIC:
			eye_scale = Vector3(1.3, 0.45, 1.0)
		LOSE:
			eye_scale = Vector3(1.2, 0.5, 1.0)
	for e in _eyes:
		e.scale = eye_scale

	# --- お手つきで崩れた顔を上からかぶせる(勝ち・負け・走っているときは、その顔を優先) ---
	var f := maxi(_fluster, 0)
	var calm := expr == NORMAL or expr == SURPRISED or expr == OOPS
	for b in _brows:
		b.visible = f >= 1 and expr != WIN
	_sweat.visible = _sweat.visible or f >= 1
	_sweat2.visible = f >= 2
	for xe in _x_eyes:
		xe.visible = false
	if not calm:
		return
	if f >= 3:
		# 放心: ×の目・ぽかん口
		for e in _eyes:
			e.visible = false
		for xe in _x_eyes:
			xe.visible = true
		_mouth_flat.visible = false
		_mouth_frown.visible = false
		_mouth_o.visible = true
	elif f >= 2 and expr == NORMAL:
		# 目がちぐはぐ・への字口
		_eyes[0].scale = Vector3(1.5, 1.5, 1.0)
		_eyes[1].scale = Vector3(0.75, 0.75, 1.0)
		_mouth_flat.visible = false
		_mouth_frown.visible = true


## 振り向いたときなどに、ピョンと跳ねる
func hop() -> void:
	_hop = 1.0


## バナナの皮で、つるっと転ぶ
func slip() -> void:
	_slip = 1.0


## 毎フレームの動き。running: 走っている(前のめり)
func animate(delta: float, running: bool) -> void:
	_time += delta
	_hop = maxf(_hop - delta * 4.0, 0.0)
	_lean = move_toward(_lean, 1.0 if running else 0.0, delta * 5.0)
	_slump = move_toward(_slump, 1.0 if _expression == LOSE else 0.0, delta * 3.0)
	var hop_y := sin(_hop * PI) * 0.18
	# 走るときは前(-Z)に傾けて小刻みに揺らす。負けたらうなだれる
	var bob := sin(_time * 18.0) * 0.04 * _lean
	_pivot.position = Vector3(0, hop_y + bob, 0)
	_slip = maxf(_slip - delta / GameConfig.SLIP_TIME, 0.0)
	# 転ぶ: 横にばったり倒れて、だんだん起き上がる
	_pivot.rotation.z = sin(minf(_slip * 3.0, 1.0) * PI / 2.0) * 1.3 * minf(_slip * 1.5, 1.0)
	# お手つきが重なるほど落ち着きがなくなる: 2回でふるえ、放心でふらふら
	if _fluster == 2:
		_pivot.position.x = sin(_time * 45.0) * 0.012
	elif _fluster >= 3:
		_pivot.rotation.z += sin(_time * 2.5) * 0.15
		_pivot.position.x = 0.0
	else:
		_pivot.position.x = 0.0
	_pivot.rotation.x = -0.35 * _lean * (1.0 - _slip) - 0.25 * _slump
	_pivot.scale = Vector3(1.0, 1.0 - 0.08 * _slump, 1.0)
	# 汗はぷるぷる揺れる
	if _sweat.visible:
		_sweat.position.y = HEAD_Y + 0.1 + sin(_time * 10.0) * 0.015
	if _sweat2.visible:
		_sweat2.position.y = HEAD_Y + 0.02 + sin(_time * 12.0 + 1.0) * 0.015


# --- 部品づくり ---

## 「^」や「U」のような折れ線(2本の棒)。bend > 0 で山形、< 0 で谷形
func _bent_line(center: Vector3, width: float, bend: float) -> Node3D:
	var n := Node3D.new()
	n.position = center
	for side in [-1.0, 1.0]:
		var bar := _box(Vector3(width * 0.6, 0.016, 0.01), Vector3(side * width * 0.27, 0, 0))
		bar.rotation.z = -side * bend
		n.add_child(bar)
	return n


func _box(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := _mesh(m, Color.BLACK)
	mi.position = pos
	return mi


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi


func _set_layers_rec(node: Node, bits: int) -> void:
	for c in node.get_children():
		if c is VisualInstance3D:
			c.layers = bits
		_set_layers_rec(c, bits)
