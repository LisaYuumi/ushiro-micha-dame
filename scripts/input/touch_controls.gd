class_name TouchControls
extends CanvasLayer
## スマホ用の画面ボタン。押すとキーボードと同じ操作(アクション)を送るだけ。
## スマホでは指ごとに扱うので、2本指で同時に押せる。PC ではマウスでクリックして使える。

## ボタンと操作の組 [{"button": Button, "action": String}]
var _buttons := []
## 押している指の番号 -> 操作
var _touch_action := {}


func _ready() -> void:
	layer = 2
	# 右下: 振り向く(押している間)
	_add_button("振り向く", "look_back", Vector2(1, 1), Rect2(-250, -250, 220, 220), 40)
	_add_button("拾う", "pick_up", Vector2(1, 1), Rect2(-430, -170, 160, 140), 36)
	# 左下: 走るためのスティック
	var stick := VirtualStick.new()
	add_child(stick)
	stick.anchor_left = 0
	stick.anchor_right = 0
	stick.anchor_top = 1
	stick.anchor_bottom = 1
	stick.offset_left = 30
	stick.offset_top = -250
	stick.offset_right = 250
	stick.offset_bottom = -30
	# 右上: 確認用の操作
	_add_button("上から見る", "debug_top_camera", Vector2(1, 0), Rect2(-410, 16, 190, 64), 24)
	_add_button("やり直し", "restart", Vector2(1, 0), Rect2(-206, 16, 190, 64), 24)
	_add_button("音テスト", "sound_test", Vector2(1, 0), Rect2(-614, 16, 190, 64), 24)


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
	# PC のマウス用
	b.button_down.connect(_send.bind(action, true))
	b.button_up.connect(_send.bind(action, false))
	_buttons.append({"button": b, "action": action})
	return b


## スマホの指: ボタンの上に触れたら押す、その指を離したら離す
func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var t := event as InputEventScreenTouch
	if t.pressed:
		for entry in _buttons:
			var b: Button = entry["button"]
			if b.visible and b.get_global_rect().has_point(t.position):
				_touch_action[t.index] = entry
				b.modulate = Color(0.7, 0.85, 1.0, 1.0)
				_send(entry["action"], true)
				get_viewport().set_input_as_handled()
				return
	elif _touch_action.has(t.index):
		var entry: Dictionary = _touch_action[t.index]
		_touch_action.erase(t.index)
		(entry["button"] as Button).modulate = Color(1, 1, 1, 0.85)
		_send(entry["action"], false)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
