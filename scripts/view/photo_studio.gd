class_name PhotoStudio
extends Node3D
## 撮影モード(開発用): SNS 画像や宣伝素材の見本を撮るための画面。ゲームの状態にはさわらない。
## - 無地の背景に、プレイヤーと同じ人型キャラを1体
## - 向き(正面・横・後ろ・斜め前)、表情(ふつう・困り眉・汗だく・放心)、ポーズ(座る・立つ・走る・転ぶ)、体の色
## - UI を消して、キャラだけを大きく映せる(画面をタップすると UI が戻る)
## - 6人が輪になって座る場面を、斜め上から見下ろして撮れる

signal closed

## ほかの 3D(ゲームの教室・物理の床)と重ならないように、離れた場所に作る
const ORIGIN := Vector3(200, 0, 0)
const DIRECTIONS := {"正面": PI, "横": PI / 2.0, "後ろ": 0.0, "斜め前": PI * 0.83}
const EXPRESSIONS := ["ふつう", "困り眉", "汗だく", "放心"]
const POSES := ["座る", "立つ", "走る", "転ぶ"]
const BACKGROUNDS := [Color("8FD3E8"), Color("FFF4DC"), Color("FFFFFF"), Color("F7C4CF"), Color("F6C945"), Color("00B140")]
## カメラの近さ(1体のとき。メートル)
const ZOOMS := [1.9, 2.8, 4.0]
## 輪の場面の人数と半径
const RING_PEOPLE := 6
const RING_RADIUS := 2.3

var _cam: Camera3D
var _env: Environment
var _stage: Node3D
var _ui: CanvasLayer
var _panel: PanelContainer
var _buttons: Array[Button] = []
var _models: Array[CharacterModel] = []

var _direction := "斜め前"
var _expression := 0
var _pose := "立つ"
var _color: Color = Profile.COLORS[4]
var _bg := 0
var _zoom := 1
var _ring := false
var _ui_hidden := false


func _ready() -> void:
	position = ORIGIN
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color.WHITE
	_env.ambient_light_energy = 0.5
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.environment = _env
	_cam.fov = 40
	add_child(_cam)
	_cam.make_current()
	# 転んだ体が乗る床(見えない)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << (CharacterModel.FLOOR_LAYER - 1)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(cs)
	add_child(floor_body)
	_build_ui()
	_rebuild()


func _process(delta: float) -> void:
	for m in _models:
		m.animate(delta, _pose == "走る" and not _ring)


# --- 場面づくり ---

func _rebuild() -> void:
	if _stage:
		_stage.queue_free()
	_models.clear()
	_stage = Node3D.new()
	add_child(_stage)
	_env.background_color = BACKGROUNDS[_bg]
	if _ring:
		_build_ring()
	else:
		_build_single()
	_update_camera()
	_update_ui()


## 1体だけ。座るときは椅子も出す
func _build_single() -> void:
	var m := _make_model(_color)
	m.rotation.y = DIRECTIONS[_direction]
	if _pose == "座る":
		var chair := _chair()
		chair.rotation.y = m.rotation.y
		_stage.add_child(chair)
	_apply_pose(m, _pose)


## 6人が椅子に座って輪になる(黄色い丸い床)
func _build_ring() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = RING_RADIUS + 1.6
	disc.bottom_radius = RING_RADIUS + 1.6
	disc.height = 0.04
	disc.radial_segments = 48
	var floor_mi := Toon.mesh(disc, GameConfig.COLOR_FLOOR, 0.05)
	floor_mi.position.y = -0.02
	_stage.add_child(floor_mi)
	for i in RING_PEOPLE:
		var a := TAU * i / RING_PEOPLE
		var pos := Vector3(sin(a), 0, cos(a)) * RING_RADIUS
		# 輪の内側を向く(キャラの正面は -Z)
		var yaw := a
		var chair := _chair()
		chair.position = pos
		chair.rotation.y = yaw
		_stage.add_child(chair)
		var c: Color = _color if i == 0 else Profile.COLORS[(i * 3 + 1) % Profile.COLORS.size()]
		var m := _make_model(c)
		m.position = pos
		m.rotation.y = yaw
		_apply_pose(m, "座る")


func _make_model(color: Color) -> CharacterModel:
	var m := CharacterModel.new()
	m.build(color, "", HudFont.get_font())
	_stage.add_child(m)
	m.set_expression(CharacterModel.NORMAL)
	m.set_fluster(_expression)
	_models.append(m)
	return m


func _apply_pose(m: CharacterModel, pose: String) -> void:
	match pose:
		"座る":
			m.set_pose("sit")
		"走る":
			m.set_pose("run")
		"転ぶ":
			m.set_pose("run")
			# 少し走らせてから、倒れたまま止める
			get_tree().create_timer(0.25).timeout.connect(func() -> void:
				if is_instance_valid(m) and m.is_inside_tree():
					m.slip(true))
		_:
			m.set_pose("idle")


func _chair() -> Node3D:
	var chair := Node3D.new()
	var wood := Color(0.55, 0.35, 0.2)
	var parts := [
		[Vector3(0.5, 0.05, 0.5), Vector3(0, 0.45, 0), wood],
		[Vector3(0.5, 0.5, 0.05), Vector3(0, 0.72, 0.28), wood],
	]
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			parts.append([Vector3(0.04, 0.45, 0.04), Vector3(x, 0.225, z), Color(0.4, 0.4, 0.42)])
	for p in parts:
		var box := BoxMesh.new()
		box.size = p[0]
		var mi := Toon.mesh(box, p[2])
		mi.position = p[1]
		chair.add_child(mi)
	return chair


## カメラ: 1体のときは正面から(UI があるときはキャラを左に寄せる)。輪の場面は斜め上から見下ろす
func _update_camera() -> void:
	if _ring:
		_cam.fov = 45
		_cam.h_offset = 0.0 if _ui_hidden else 2.6
		_cam.look_at_from_position(ORIGIN + Vector3(0, 6.2, 7.2), ORIGIN + Vector3(0, 0.5, 0))
		return
	_cam.fov = 40
	var d: float = ZOOMS[_zoom]
	var target_y := 0.75 if _pose == "座る" else (0.45 if _pose == "転ぶ" else 0.95)
	_cam.h_offset = 0.0 if _ui_hidden else d * 0.28
	_cam.look_at_from_position(ORIGIN + Vector3(0, target_y + 0.25, d * 2.0), ORIGIN + Vector3(0, target_y, 0))


# --- 操作パネル ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	_panel = PanelContainer.new()
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4)
	st.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", st)
	_ui.add_child(_panel)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -UiStyle.SAFE - 560
	_panel.offset_right = -UiStyle.SAFE
	_panel.offset_top = 14
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	var title := UiStyle.label("撮影モード(開発用)", 24, GameConfig.COLOR_INK)
	col.add_child(title)
	_row(col, "向き", DIRECTIONS.keys(), func(v: String) -> void: _direction = v)
	_row(col, "表情", EXPRESSIONS, func(v: String) -> void: _expression = EXPRESSIONS.find(v))
	_row(col, "ポーズ", POSES, func(v: String) -> void: _pose = v)
	# 体の色(ロビーと同じ10色)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 6)
	col.add_child(colors)
	colors.add_child(_row_label("色"))
	for c in Profile.COLORS:
		var cc: Color = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.focus_mode = Control.FOCUS_NONE
		var bs := UiStyle.box(cc, false, 19, 3)
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, bs)
		b.pressed.connect(_pick_color.bind(cc))
		colors.add_child(b)
		_buttons.append(b)
	_row(col, "カメラ", ["近く", "ふつう", "遠く"], func(v: String) -> void: _zoom = ["近く", "ふつう", "遠く"].find(v))
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 8)
	col.add_child(extra)
	extra.add_child(_button("背景の色", _next_background))
	extra.add_child(_button("輪の場面", _toggle_ring, "ring"))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	col.add_child(bottom)
	bottom.add_child(_button("UIを消す", _set_ui_hidden.bind(true)))
	bottom.add_child(_button("もどる", _close, "", true))


func _row(parent: VBoxContainer, label: String, values: Array, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(_row_label(label))
	for v in values:
		var value: String = v
		row.add_child(_button(value, _pick.bind(on_pick, value), label + ":" + value))


func _pick(on_pick: Callable, value: String) -> void:
	on_pick.call(value)
	_rebuild()


func _pick_color(c: Color) -> void:
	_color = c
	_rebuild()


func _next_background() -> void:
	_bg = (_bg + 1) % BACKGROUNDS.size()
	_rebuild()


func _toggle_ring() -> void:
	_ring = not _ring
	_rebuild()


func _close() -> void:
	closed.emit()


func _row_label(text: String) -> Label:
	var l := UiStyle.label(text, 20, GameConfig.COLOR_INK)
	l.custom_minimum_size = Vector2(64, 0)
	return l


## 選んでいるものはオレンジにする(key: "向き:正面" など)
func _button(text: String, on_press: Callable, key: String = "", accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	UiStyle.button(b, accent, 20)
	b.pressed.connect(on_press)
	b.set_meta("key", key)
	_buttons.append(b)
	return b


func _update_ui() -> void:
	var chosen := {
		"向き:" + _direction: true,
		"表情:" + EXPRESSIONS[_expression]: true,
		"ポーズ:" + _pose: true,
		"カメラ:" + ["近く", "ふつう", "遠く"][_zoom]: true,
		"ring": _ring,
	}
	for b in _buttons:
		var key: String = b.get_meta("key", "")
		if key == "":
			continue
		UiStyle.button(b, chosen.get(key, false), 20)


func _set_ui_hidden(v: bool) -> void:
	_ui_hidden = v
	_panel.visible = not v
	_update_camera()


## スマホの指: パネルのボタンを押す/UI を消しているときは、どこかをタップすると戻る
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	if _ui_hidden:
		_set_ui_hidden(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		for b in _buttons:
			if b.is_visible_in_tree() and b.get_global_rect().has_point(event.position):
				b.pressed.emit()
				get_viewport().set_input_as_handled()
				return
