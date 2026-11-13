class_name Lobby
extends CanvasLayer
## 最初の画面: 名前と体の色を決めて、「ひとりで遊ぶ」「部屋を作る」「部屋に入る」。
## 部屋に入るときは、4桁の合言葉を数字ボタンで入れる(スマホでもキーボードいらず)。
## 画面の表示とボタンだけ。つなぐ処理は NetSession、試合を始めるのは main がやる。

signal solo_pressed
signal host_pressed
signal join_pressed(code: String)
signal start_pressed

var _panel: PanelContainer
var _title: Label
var _status: Label
var _code_label: Label
var _players_label: Label
var _menu: VBoxContainer
var _join_box: VBoxContainer
var _host_box: VBoxContainer
var _code := ""
## 遊ぶ人数(鬼をふくむ全員の数)。ひとりで遊ぶとき・部屋を作るときに使う
var players: int = GameConfig.PLAYER_COUNT_OPTIONS[0]
var _players_button: Button
## スマホの指で押せるように、ボタンは自分で当たり判定をする
var _buttons: Array[Button] = []
## 名前と色(Profile に保存する)
var _name_button: Button
var _name_edit: LineEdit
var _code_edit: LineEdit
var _color_buttons: Array[Button] = []
var _preview: Panel


func _ready() -> void:
	layer = 10
	Profile.load_saved()
	var bg := ColorRect.new()
	var sky := GameConfig.COLOR_SKY
	sky.a = 0.93
	bg.color = sky
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.offset_left = -430
	root.offset_right = 430
	root.offset_top = -350
	root.offset_bottom = 350

	_title = _label("うしろ見ちゃダメ!", 56)
	root.add_child(_title)
	_status = _label("", 22)
	root.add_child(_status)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	root.add_child(_menu)
	_build_profile_rows(_menu)
	# 大きいボタンを2列に(押しやすいように)
	var menu_grid := GridContainer.new()
	menu_grid.columns = 2
	menu_grid.add_theme_constant_override("h_separation", 16)
	menu_grid.add_theme_constant_override("v_separation", 16)
	_menu.add_child(menu_grid)
	var big := Vector2(0, 110)
	var solo := _button("ひとりで遊ぶ", func() -> void: solo_pressed.emit(), big, true)
	solo.add_theme_font_size_override("font_size", 36)
	menu_grid.add_child(solo)
	_players_button = _button("", func() -> void: _toggle_players(), big)
	menu_grid.add_child(_players_button)
	_update_players_button()
	menu_grid.add_child(_button("部屋を作る\n(ホスト)", func() -> void: host_pressed.emit(), big))
	menu_grid.add_child(_button("部屋に入る\n(合言葉)", func() -> void: _show_join(), big))
	for b in menu_grid.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 10)
	root.add_child(_join_box)
	_code_label = _label("合言葉: ____", 44)
	_join_box.add_child(_code_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_join_box.add_child(grid)
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "けす", "0", "入る"]:
		var digit: String = d
		grid.add_child(_button(digit, func() -> void: _on_key(digit), Vector2(270, 76)))
	_join_box.add_child(_button("もどる", func() -> void: show_menu(), Vector2(0, 70)))

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 12)
	root.add_child(_host_box)
	_players_label = _label("", 26)
	_host_box.add_child(_players_label)
	_host_box.add_child(_button("スタート", func() -> void: start_pressed.emit(), Vector2(0, 100), true))

	show_menu()


## 名前(タップで入力)と、体の色(10色+カラーコード)
func _build_profile_rows(parent: VBoxContainer) -> void:
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	parent.add_child(name_row)
	_preview = UiStyle.dot(Profile.color, 56)
	name_row.add_child(_preview)
	if OS.has_feature("web"):
		# スマホのブラウザ: 入力欄より確実なので、ブラウザの入力ダイアログで聞く
		_name_button = _button("", func() -> void: _ask_name(), Vector2(0, 64))
		_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(_name_button)
	else:
		_name_edit = LineEdit.new()
		_name_edit.text = Profile.player_name
		_name_edit.max_length = Profile.NAME_MAX
		_name_edit.placeholder_text = "なまえ"
		_name_edit.custom_minimum_size = Vector2(0, 64)
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.add_theme_font_override("font", HudFont.get_font())
		_name_edit.add_theme_font_size_override("font_size", 30)
		_name_edit.add_theme_stylebox_override("normal", UiStyle.box(GameConfig.COLOR_PAPER))
		_name_edit.add_theme_stylebox_override("focus", UiStyle.box(GameConfig.COLOR_PAPER))
		_name_edit.add_theme_color_override("font_color", GameConfig.COLOR_INK)
		_name_edit.text_changed.connect(func(t: String) -> void: _set_name(t))
		name_row.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(color_row)
	for c in Profile.COLORS:
		var col: Color = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(48, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _set_color(col))
		color_row.add_child(b)
		_buttons.append(b)
		_color_buttons.append(b)
	if OS.has_feature("web"):
		color_row.add_child(_button("#", func() -> void: _ask_color(), Vector2(64, 48)))
	else:
		_code_edit = LineEdit.new()
		_code_edit.placeholder_text = "#4D96FF"
		_code_edit.custom_minimum_size = Vector2(130, 48)
		_code_edit.add_theme_font_override("font", HudFont.get_font())
		_code_edit.add_theme_font_size_override("font_size", 22)
		_code_edit.text_submitted.connect(func(t: String) -> void: _set_color(Profile.parse_color(t, Profile.color)))
		color_row.add_child(_code_edit)
	_update_profile()


func _ask_name() -> void:
	var t := _prompt("名前(%d文字まで)" % Profile.NAME_MAX, Profile.player_name)
	if t != "":
		_set_name(t)


func _ask_color() -> void:
	var t := _prompt("カラーコード(例: #4D96FF)", "#" + Profile.color.to_html(false))
	if t == "":
		return
	var c := Profile.parse_color(t, Color(0, 0, 0, 0))
	if c.a == 0.0:
		set_status("カラーコードが読めませんでした(例: #4D96FF)")
		return
	_set_color(c)


## ブラウザの入力ダイアログ(キャンセルなら "")
func _prompt(question: String, current: String) -> String:
	var r = JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(question), JSON.stringify(current)], true)
	return "" if r == null else str(r)


func _set_name(text: String) -> void:
	Profile.player_name = Profile.clean_name(text)
	Profile.save()
	_update_profile()


func _set_color(c: Color) -> void:
	Profile.color = c
	Profile.save()
	_update_profile()


func _update_profile() -> void:
	(_preview.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Profile.color
	if _name_button:
		_name_button.text = "%s(タップで名前を変える)" % Profile.player_name
	for i in _color_buttons.size():
		var c: Color = Profile.COLORS[i]
		var chosen := c.is_equal_approx(Profile.color)
		var st := UiStyle.box(c, false, 24, 6 if chosen else 3)
		st.border_color = GameConfig.COLOR_ACCENT if chosen else GameConfig.COLOR_INK
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			_color_buttons[i].add_theme_stylebox_override(k, st)


func _toggle_players() -> void:
	var opts: Array = GameConfig.PLAYER_COUNT_OPTIONS
	players = opts[(opts.find(players) + 1) % opts.size()]
	_update_players_button()


func _update_players_button() -> void:
	_players_button.text = "人数: %d人\n(タップで変える)" % players


func show_menu() -> void:
	_menu.visible = true
	_join_box.visible = false
	_host_box.visible = false
	set_status("")


## ホスト: 合言葉と、入っている人数を出す
func show_host(code: String, joined: int) -> void:
	_menu.visible = false
	_join_box.visible = false
	_host_box.visible = true
	_players_label.text = "合言葉: %s\n入っている人: %d人(あなたをふくむ) / %d人で遊ぶ\n足りない席はボットが座ります" % [code, joined, players]


## 参加者: ホストがスタートするのを待つ
func show_waiting(text: String) -> void:
	_menu.visible = false
	_join_box.visible = false
	_host_box.visible = false
	set_status(text)


func set_status(text: String) -> void:
	_status.text = text


func _show_join() -> void:
	_menu.visible = false
	_join_box.visible = true
	_host_box.visible = false
	_code = ""
	_update_code()
	set_status("ホストの画面に出ている4桁の数字を入れてください")


func _on_key(key: String) -> void:
	match key:
		"けす":
			_code = _code.substr(0, maxi(_code.length() - 1, 0))
		"入る":
			if _code.length() == 4:
				join_pressed.emit(_code)
			else:
				set_status("4桁入れてください")
		_:
			if _code.length() < 4:
				_code += key
	_update_code()


func _update_code() -> void:
	_code_label.text = "合言葉: %s" % (_code + "____".substr(0, 4 - _code.length()))


# --- 部品 ---

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GameConfig.COLOR_INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, on_press: Callable, min_size := Vector2(0, 66), accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	UiStyle.button(b, accent, 28)
	b.pressed.connect(on_press)
	_buttons.append(b)
	return b


## スマホの指: 見えているボタンの上をタップしたら押す
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventScreenTouch or not event.pressed:
		return
	for b in _buttons:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(event.position):
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return
