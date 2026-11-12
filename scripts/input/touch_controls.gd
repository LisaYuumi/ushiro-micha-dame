class_name TouchControls
extends CanvasLayer
## スマホ用の画面ボタン。押すとキーボードと同じ操作(アクション)を送るだけ。
## スマホでは指ごとに扱うので、2本指で同時に押せる。PC ではマウスでクリックして使える。

## ボタンと操作の組 [{"button": Button, "action": String}]
var _buttons := []
## 座っているときだけ出すボタン / 鬼のときだけ出すボタン
var _seated_buttons: Array[Button] = []
var _oni_buttons: Array[Button] = []
## 座っていて、追いかけっこ中だけ出すボタン(バナナの皮)
var _chase_buttons: Array[Button] = []
var _look_button: Button
## ⚙ボタンで開くメニューと、その中の「あそびかた」
var _menu: PanelContainer
var _help_panel: PanelContainer
var _personality_button: Button
var _stick: VirtualStick
## 「振り向く」ボタンの目のアイコン(残りの回数ぶん見える)
var _eyes: Array[Control] = []
var _looks_shown := -2
var _mode := []
## 押している指の番号 -> 操作
var _touch_action := {}


func _ready() -> void:
	layer = 2
	# 右下: 振り向く(押している間)
	_look_button = _add_button("", "look_back", Vector2(1, 1), Rect2(-250, -250, 220, 220), 36)
	_seated_buttons.append(_look_button)
	_build_look_face(_look_button)
	# 鬼のとき: 同じ場所に「止まる」(押している間)「落とす」、その左に「ふり」
	_oni_buttons.append(_add_button("止まる", "oni_stop", Vector2(1, 1), Rect2(-250, -250, 220, 220), 40))
	_oni_buttons.append(_add_button("落とす", "oni_drop", Vector2(1, 1), Rect2(-430, -170, 160, 140), 36))
	_oni_buttons.append(_add_button("落とす音", "oni_feint", Vector2(1, 1), Rect2(-430, -330, 160, 140), 30))
	# 鬼の声(下のまん中。座っているときのスタンプと同じ場所)
	for i in Voices.ALL.size():
		var v: String = Voices.ALL[i]
		_oni_buttons.append(_add_button(Voices.LABELS[v], "voice_%d" % i, Vector2(0.5, 1), Rect2(-385 + i * 150, -100, 140, 80), 26))
	# 鬼のスタンプ(声の上の列。先に相手をタップして選ぶ)
	for i in Stamps.ALL.size():
		var kind: String = Stamps.ALL[i]
		_oni_buttons.append(_add_button(Stamps.LABELS[kind], "oni_stamp_%d" % i, Vector2(0.5, 1), Rect2(-370 + i * 140, -190, 130, 80), 22))
	# 追いかけっこ中のバナナの皮(下のまん中)
	_chase_buttons.append(_add_button("鬼にバナナ", "banana_oni", Vector2(0.5, 1), Rect2(-300, -110, 280, 90), 28))
	_chase_buttons.append(_add_button("追う人にバナナ", "banana_chaser", Vector2(0.5, 1), Rect2(20, -110, 280, 90), 28))
	# 下のまん中: スタンプ(先に相手をタップして選ぶ)
	for i in Stamps.ALL.size():
		var kind: String = Stamps.ALL[i]
		_seated_buttons.append(_add_button(Stamps.LABELS[kind], "stamp_%d" % i, Vector2(0.5, 1), Rect2(-385 + i * 150, -100, 140, 80), 24))
	# 左下: 走るためのスティック
	var stick := VirtualStick.new()
	add_child(stick)
	stick.anchor_left = 0
	stick.anchor_right = 0
	stick.anchor_top = 1
	stick.anchor_bottom = 1
	stick.offset_left = UiStyle.SAFE
	stick.offset_top = -250
	stick.offset_right = UiStyle.SAFE + 220
	stick.offset_bottom = -30
	_stick = stick
	# 右上: ⚙ボタン(開発用の操作や「あそびかた」はメニューの中)
	var gear := _add_button("", "", Vector2(1, 0), Rect2(-UiStyle.SAFE - 64, 14, 64, 58), 28, toggle_menu)
	_add_gear_icon(gear)
	_build_menu()
	set_oni_mode(false)


## 「振り向く」ボタンの中身: 文字と、残りの回数ぶんの目のアイコン、「長押し」
func _build_look_face(b: Button) -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	b.add_child(col)
	var title := UiStyle.label("振り向く", 36, GameConfig.COLOR_PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for i in GameConfig.LOOKS_PER_ROUND:
		var eye := Control.new()
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye.custom_minimum_size = Vector2(58, 36)
		eye.draw.connect(_draw_eye.bind(eye))
		row.add_child(eye)
		_eyes.append(eye)
	# 押している間だけ振り向く、とわかるように
	var hint := UiStyle.label("長押し", 20, GameConfig.COLOR_PAPER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


## 目のアイコン: 白目と黒目。押している間は黒目が上(後ろ)を見る
func _draw_eye(eye: Control) -> void:
	var c := eye.size / 2.0
	var r := Vector2(eye.size.x * 0.45, eye.size.y * 0.42)
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	eye.draw_colored_polygon(pts, GameConfig.COLOR_PAPER)
	pts.append(pts[0])
	eye.draw_polyline(pts, GameConfig.COLOR_INK, 3.0, true)
	var looking := Input.is_action_pressed("look_back")
	var pupil := c + (Vector2(0, -r.y * 0.35) if looking else Vector2.ZERO)
	eye.draw_circle(pupil, r.y * 0.55, GameConfig.COLOR_INK)


## 「振り向く」ボタンの残りの回数(-1 = 数えない場面: 追いかけっこ中・勝敗のあと)。
## 目が1つずつ消え、0 になったらボタンを薄くして押せなくする
func set_looks_left(n: int) -> void:
	for e in _eyes:
		e.queue_redraw()
	if n == _looks_shown:
		return
	_looks_shown = n
	for i in _eyes.size():
		_eyes[i].modulate.a = 1.0 if n < 0 or i < n else 0.0
	var empty := n == 0
	_look_button.disabled = empty
	_look_button.modulate.a = 0.45 if empty else 1.0
	if empty:
		_release_action("look_back")


## 鬼のとき/座っているとき/座っていて追いかけっこ中で、出すボタンを切りかえる
func set_oni_mode(is_oni: bool, seated_in_chase: bool = false) -> void:
	if _mode == [is_oni, seated_in_chase]:
		return
	_mode = [is_oni, seated_in_chase]
	for b in _seated_buttons:
		b.visible = not is_oni and not seated_in_chase
	for b in _oni_buttons:
		b.visible = is_oni
	for b in _chase_buttons:
		b.visible = seated_in_chase
	# 切りかえで押しっぱなしになった指を離しておく
	for index in _touch_action.keys():
		var entry: Dictionary = _touch_action[index]
		_send(entry["action"], false)
		UiStyle.show_pressed(entry["button"], false)
	_touch_action.clear()


## A案の見た目でオレンジ地にするボタン(いちばん大事な操作)
const ACCENT_ACTIONS := ["look_back", "oni_stop", "oni_drop"]


## ⚙の絵(歯車)
func _add_gear_icon(b: Button) -> void:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.draw.connect(func() -> void:
		var c := g.size / 2.0 + Vector2(-1, -2)
		for k in 8:
			var t := TAU * k / 8.0
			var d := Vector2(cos(t), sin(t))
			var side := Vector2(-d.y, d.x) * 5.0
			g.draw_colored_polygon(PackedVector2Array([c + d * 9 - side, c + d * 9 + side, c + d * 17 + side * 0.7, c + d * 17 - side * 0.7]), GameConfig.COLOR_INK)
		g.draw_circle(c, 12.0, GameConfig.COLOR_INK)
		g.draw_circle(c, 5.0, GameConfig.COLOR_PAPER))
	b.add_child(g)


## ⚙メニュー: やり直し・役を変えて新試合・上から見る・ボットの性格の表示・あそびかた・とじる
func _build_menu() -> void:
	_menu = _panel(Vector2(420, 0))
	var col: VBoxContainer = _menu.get_child(0)
	var title := UiStyle.label("メニュー", 30, GameConfig.COLOR_INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_menu_button(col, "やり直し", _menu_action.bind("restart"))
	_menu_button(col, "役を変えて新しい試合", _menu_action.bind("toggle_role"))
	_menu_button(col, "上から見る(確認用)", _menu_action.bind("debug_top_camera"))
	_personality_button = _menu_button(col, "", _toggle_personality)
	_menu_button(col, "あそびかた", _show_help)
	_menu_button(col, "とじる", close_menu, true)
	_update_menu_texts()

	_help_panel = _panel(Vector2(760, 0))
	var hcol: VBoxContainer = _help_panel.get_child(0)
	var htitle := UiStyle.label("あそびかた", 30, GameConfig.COLOR_INK)
	htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hcol.add_child(htitle)
	var body := UiStyle.label(HOW_TO_PLAY, 20, GameConfig.COLOR_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(700, 0)
	hcol.add_child(body)
	_menu_button(hcol, "とじる", close_menu, true)


const HOW_TO_PLAY := """・振り向く(長押し): 押している間だけ後ろを見る。落ちていたら、そのまま拾って走る。1ラウンド2回まで(外れても減点なし)
・人をタップ: その人の頭の上にスタンプが出るので、選んで送る(同じ人には1ラウンド1回)
・鬼: スティックで歩く速さ。止まる・落とす・落とす音・声(咳/口笛/手拍子/叫ぶ)
・追いかけっこ: 自動で走る。スティックの上で内側(近道)、下で外側。座っている人はバナナを投げられる
キーボード: スペース=振り向く/止まる 1〜4=スタンプ/声 Z X C V=鬼のスタンプ W/S=内側/外側 A/D=鬼の速さ
 E=落とす F=落とす音 B/N=バナナ R=やり直し O=役を変える F1=上から見る K=転ぶ(確認用) Tab=メニュー"""


func _menu_action(action: String) -> void:
	_tap_action(action)
	close_menu()


func _toggle_personality() -> void:
	_tap_action("toggle_personality")
	_update_menu_texts()


func _show_help() -> void:
	_menu.visible = false
	_help_panel.visible = true


func _update_menu_texts() -> void:
	_personality_button.text = "ボットの性格を表示: %s" % ("オン" if Profile.show_personality else "オフ")


## 画面のまん中に出す白いパネル(中に縦に並べる)
func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 26, 5)
	st.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = min_size
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	p.visible = false
	return p


func _menu_button(parent: Container, text: String, on_press: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	UiStyle.button(b, accent, 24)
	parent.add_child(b)
	b.pressed.connect(on_press)
	_buttons.append({"button": b, "action": "", "call": on_press})
	return b


func toggle_menu() -> void:
	if _menu.visible or _help_panel.visible:
		close_menu()
	else:
		_update_menu_texts()
		_menu.visible = true


func close_menu() -> void:
	_menu.visible = false
	_help_panel.visible = false


func is_menu_open() -> bool:
	return _menu.visible or _help_panel.visible


## 操作を1回押して離す(メニューから)
func _tap_action(action: String) -> void:
	_send(action, true)
	_send(action, false)


func _add_button(text: String, action: String, anchor: Vector2, rect: Rect2, font_size: int, on_press: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	# A案: 白地かオレンジ地、黒い太い枠、右下の影。スタンプはスタンプの色の文字
	var text_color := Color(0, 0, 0, 0)
	if action.begins_with("stamp_") or action.begins_with("oni_stamp_"):
		var kind: String = Stamps.ALL[int(action.get_slice("_", action.get_slice_count("_") - 1))]
		text_color = WorldView.STAMP_COLORS[kind].darkened(0.25)
	# キーボードのスペースでボタンが反応しないように、フォーカスを受けない(UiStyle.button の中で)
	UiStyle.button(b, action in ACCENT_ACTIONS, font_size, text_color)
	add_child(b)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = rect.position.x
	b.offset_top = rect.position.y
	b.offset_right = rect.position.x + rect.size.x
	b.offset_bottom = rect.position.y + rect.size.y
	# PC のマウス用
	if on_press.is_valid():
		b.pressed.connect(on_press)
	else:
		b.button_down.connect(_send.bind(action, true))
		b.button_up.connect(_send.bind(action, false))
	_buttons.append({"button": b, "action": action, "call": on_press})
	return b


## スマホの指: ボタンの上に触れたら押す、その指を離したら離す
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle_menu()
		return
	if not event is InputEventScreenTouch:
		return
	var t := event as InputEventScreenTouch
	if t.pressed:
		# あとから足した(上に重なっている)ボタンから調べる。メニューが開いているときはメニューの中だけ
		for k in range(_buttons.size() - 1, -1, -1):
			var entry: Dictionary = _buttons[k]
			var b: Button = entry["button"]
			if not b.is_visible_in_tree() or b.disabled or not b.get_global_rect().has_point(t.position):
				continue
			if is_menu_open() and not (_menu.is_ancestor_of(b) or _help_panel.is_ancestor_of(b)):
				continue
			var call: Callable = entry.get("call", Callable())
			if call.is_valid():
				call.call()
				get_viewport().set_input_as_handled()
				return
			_touch_action[t.index] = entry
			UiStyle.show_pressed(b, true)
			_send(entry["action"], true)
			get_viewport().set_input_as_handled()
			return
		if is_menu_open():
			# メニューの外や背景をタップしても、うしろの画面には届かない
			get_viewport().set_input_as_handled()
	elif _touch_action.has(t.index):
		var entry: Dictionary = _touch_action[t.index]
		_touch_action.erase(t.index)
		UiStyle.show_pressed(entry["button"], false)
		_send(entry["action"], false)


## その操作を押している指を離したことにする(ボタンが押せなくなったときなど)
func _release_action(action: String) -> void:
	for index in _touch_action.keys():
		var entry: Dictionary = _touch_action[index]
		if entry["action"] == action:
			_touch_action.erase(index)
			UiStyle.show_pressed(entry["button"], false)
			_send(action, false)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
