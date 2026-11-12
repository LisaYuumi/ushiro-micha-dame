class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

## 自分に届いたスタンプのまわりに出す枠の太さ
const FRAME_WIDTH := 18.0

var _help: Label
var _message: Label
var _message_left := 0.0
## 自分に届いたスタンプ(画面の下に、送り主つきで横に3つまで並べる)
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_senders: Array[Label] = []
var _slot_texts: Array[Label] = []
## 前のフレームに出ていたスタンプ(新しく届いたものだけポンと飛び出させる)
var _shown_keys: Array = []
## 自分に届いたスタンプの間、画面のふちを光らせる枠
var _frame: Array[ColorRect] = []
var _frame_tween: Tween
## 役の表示(手下のとき)
var _badge: Label


func _ready() -> void:
	_help = _make_label(22, Color.BLACK)
	_help.position = Vector2(16, 12)
	add_child(_help)

	# 画面中央の大きな文字(「お手つき!」など)
	_message = _make_label(72, Color.WHITE)
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_constant_override("outline_size", 16)
	_message.visible = false

	_build_stamp_display()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false


func set_help(text: String) -> void:
	_help.text = text


## 画面中央に大きく表示する。seconds 秒で消える(0 なら消さない)。
func show_message(text: String, outline: Color, seconds: float) -> void:
	_message.text = text
	_message.add_theme_color_override("font_outline_color", outline)
	_message.visible = true
	_message_left = seconds if seconds > 0.0 else INF


func hide_message() -> void:
	_message.visible = false
	_message_left = 0.0


## 自分に届いているスタンプを並べる。list: [{"text", "color", "sender", "sender_color"}](届いた順)
func show_my_stamps(list: Array) -> void:
	var keys := []
	for i in _slots.size():
		var box := _slots[i]
		if i >= list.size():
			box.visible = false
			continue
		var st: Dictionary = list[i]
		var key := "%s|%s" % [st["sender"], st["text"]]
		keys.append(key)
		_slot_texts[i].text = st["text"]
		_slot_senders[i].text = st["sender"]
		_slot_styles[i].bg_color = st["color"]
		# ふちの色と名前の色 = 送った人の体の色
		var sender_color: Color = st["sender_color"]
		_slot_styles[i].border_color = sender_color
		_slot_senders[i].add_theme_color_override("font_outline_color", sender_color.darkened(0.5))
		box.visible = true
		if not (key in _shown_keys):
			# 新しく届いた: ポンと大きくなってから元の大きさへ
			box.pivot_offset = box.size / 2.0
			box.scale = Vector2(0.3, 0.3)
			var tw := create_tween()
			tw.tween_property(box, "scale", Vector2(1.12, 1.12), 0.12)
			tw.tween_property(box, "scale", Vector2.ONE, 0.1)
	# 出ていたスタンプが全部消えたら、ふちの光も消す
	# (参加者の画面では、届いたお知らせが状態より先に来ることがあるので「全部消えたとき」だけ)
	if list.is_empty() and not _shown_keys.is_empty():
		for r in _frame:
			r.visible = false
	_shown_keys = keys


## 自分あてにスタンプが届いたとき、画面のふちを光らせる
func flash_stamp(color: Color) -> void:
	if _frame_tween:
		_frame_tween.kill()
	for r in _frame:
		r.color = color
		r.visible = true
	_frame_tween = create_tween()
	for i in 3:
		_frame_tween.tween_callback(_set_frame_alpha.bind(0.25))
		_frame_tween.tween_interval(0.15)
		_frame_tween.tween_callback(_set_frame_alpha.bind(0.9))
		_frame_tween.tween_interval(0.15)
	_frame_tween.tween_callback(_set_frame_alpha.bind(0.5))


## 画面の上のまん中に、役を出す(空文字で消す)
func set_role_badge(text: String, color: Color) -> void:
	_badge.text = text
	_badge.visible = text != ""
	_badge.add_theme_color_override("font_outline_color", color)


func _set_frame_alpha(a: float) -> void:
	for r in _frame:
		r.modulate.a = a


func _build_stamp_display() -> void:
	# 画面のふちの枠(上下左右の4本)
	for side in 4:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		add_child(r)
		match side:
			0: # 上
				r.set_anchors_preset(Control.PRESET_TOP_WIDE)
				r.offset_bottom = FRAME_WIDTH
			1: # 下
				r.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				r.offset_top = -FRAME_WIDTH
			2: # 左
				r.set_anchors_preset(Control.PRESET_LEFT_WIDE)
				r.offset_right = FRAME_WIDTH
			3: # 右
				r.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
				r.offset_left = -FRAME_WIDTH
		_frame.append(r)

	# 画面の下(スタンプボタンの上)に、横に並ぶ3つの吹き出し。
	# ほかの人あてのスタンプは 3D の頭の上に出るので、場所で区別できる
	var width := 240.0
	var gap := 12.0
	var total := width * GameConfig.STAMP_SLOTS + gap * (GameConfig.STAMP_SLOTS - 1)
	for i in GameConfig.STAMP_SLOTS:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(24)
		style.set_border_width_all(8)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 8
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", style)
		add_child(box)
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.anchor_top = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = -total / 2.0 + i * (width + gap)
		box.offset_right = box.offset_left + width
		box.offset_top = -300
		box.offset_bottom = -130
		box.visible = false

		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(col)
		# 送った人の名前(体の色のふち)
		var sender := _make_label(24, Color.WHITE)
		sender.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sender.add_theme_constant_override("outline_size", 8)
		sender.clip_text = true
		col.add_child(sender)
		var text := _make_label(50, Color.WHITE)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		text.add_theme_constant_override("outline_size", 10)
		col.add_child(text)
		_slots.append(box)
		_slot_styles.append(style)
		_slot_senders.append(sender)
		_slot_texts.append(text)

	_badge = _make_label(30, Color.WHITE)
	_badge.add_theme_constant_override("outline_size", 12)
	add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.offset_left = -400
	_badge.offset_right = 400
	_badge.offset_top = 96
	_badge.offset_bottom = 140
	_badge.visible = false


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
