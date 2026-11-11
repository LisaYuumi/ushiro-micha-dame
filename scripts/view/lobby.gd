class_name Lobby
extends CanvasLayer
## 最初の画面: 「ひとりで遊ぶ」「部屋を作る」「部屋に入る」。
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


func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	root.offset_left = -330
	root.offset_right = 330
	root.offset_top = -330
	root.offset_bottom = 330

	_title = _label("うしろ見ちゃダメ!", 56)
	root.add_child(_title)
	_status = _label("", 24)
	root.add_child(_status)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	root.add_child(_menu)
	_players_button = _button("", func() -> void: _toggle_players())
	_menu.add_child(_players_button)
	_update_players_button()
	_menu.add_child(_button("ひとりで遊ぶ(ボット相手)", func() -> void: solo_pressed.emit()))
	_menu.add_child(_button("部屋を作る(ホスト)", func() -> void: host_pressed.emit()))
	_menu.add_child(_button("部屋に入る(合言葉)", func() -> void: _show_join()))

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
		grid.add_child(_button(digit, func() -> void: _on_key(digit), Vector2(200, 70)))
	_join_box.add_child(_button("もどる", func() -> void: show_menu(), Vector2(0, 60)))

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 12)
	root.add_child(_host_box)
	_players_label = _label("", 26)
	_host_box.add_child(_players_label)
	_host_box.add_child(_button("スタート", func() -> void: start_pressed.emit()))

	show_menu()


func _toggle_players() -> void:
	var opts: Array = GameConfig.PLAYER_COUNT_OPTIONS
	players = opts[(opts.find(players) + 1) % opts.size()]
	_update_players_button()


func _update_players_button() -> void:
	_players_button.text = "人数: %d人(タップで変える)" % players


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
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, on_press: Callable, min_size := Vector2(0, 80)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", HudFont.get_font())
	b.add_theme_font_size_override("font_size", 30)
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
