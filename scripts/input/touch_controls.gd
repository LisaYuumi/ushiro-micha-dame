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
var _role_button: Button
var _look_button: Button
var _mode := []
## 押している指の番号 -> 操作
var _touch_action := {}


func _ready() -> void:
	layer = 2
	# 右下: 振り向く(押している間)
	_look_button = _add_button("振り向く", "look_back", Vector2(1, 1), Rect2(-250, -250, 220, 220), 36)
	_seated_buttons.append(_look_button)
	_seated_buttons.append(_add_button("拾う", "pick_up", Vector2(1, 1), Rect2(-430, -170, 160, 140), 36))
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
	stick.offset_left = 30
	stick.offset_top = -250
	stick.offset_right = 250
	stick.offset_bottom = -30
	# 右上: 確認用の操作
	_add_button("上から見る", "debug_top_camera", Vector2(1, 0), Rect2(-410, 16, 190, 64), 24)
	_add_button("次へ・やり直し", "restart", Vector2(1, 0), Rect2(-206, 16, 190, 64), 24)
	_add_button("音テスト", "sound_test", Vector2(1, 0), Rect2(-614, 16, 190, 64), 24)
	_role_button = _add_button("役を変える", "toggle_role", Vector2(1, 0), Rect2(-858, 16, 230, 64), 22)
	set_oni_mode(false)


## 「振り向く」ボタンに、残りの回数を出す(-1 で回数を出さない)
func set_looks_left(n: int) -> void:
	_look_button.text = "振り向く" if n < 0 else "振り向く\n(残り%d)" % n


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
	_role_button.text = "役を変えて新しい試合"
	# 切りかえで押しっぱなしになった指を離しておく
	for index in _touch_action.keys():
		var entry: Dictionary = _touch_action[index]
		_send(entry["action"], false)
		(entry["button"] as Button).modulate = Color(1, 1, 1, 0.85)
	_touch_action.clear()


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
