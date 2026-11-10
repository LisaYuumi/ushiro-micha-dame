class_name TouchControls
extends CanvasLayer
## スマホ用の画面ボタン。押すとキーボードと同じ操作(アクション)を送るだけ。
## PC でもマウスでクリックして使える。


func _ready() -> void:
	layer = 2
	# 右下: 振り向く(押している間)
	_add_button("振り向く", "look_back", Vector2(1, 1), Rect2(-250, -250, 220, 220), 40)
	# 右上: 確認用の操作
	_add_button("上から見る", "debug_top_camera", Vector2(1, 0), Rect2(-410, 16, 190, 64), 24)
	_add_button("やり直し", "restart", Vector2(1, 0), Rect2(-206, 16, 190, 64), 24)


func _add_button(text: String, action: String, anchor: Vector2, rect: Rect2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	# キーボードのスペースでボタンが反応しないように、フォーカスを受けない
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.85)
	b.add_theme_font_override("font", HudFont.get_font())
	b.add_theme_font_size_override("font_size", font_size)
	add_child(b)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = rect.position.x
	b.offset_top = rect.position.y
	b.offset_right = rect.position.x + rect.size.x
	b.offset_bottom = rect.position.y + rect.size.y
	b.button_down.connect(_send.bind(action, true))
	b.button_up.connect(_send.bind(action, false))
	return b


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
