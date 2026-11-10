class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

## 自分に届いたスタンプのまわりに出す枠の太さ
const FRAME_WIDTH := 18.0

var _help: Label
var _message: Label
var _message_left := 0.0
## 自分に届いたスタンプ(画面の下に色付きの吹き出しで)
var _stamp_box: PanelContainer
var _stamp_style: StyleBoxFlat
var _stamp_header: Label
var _stamp: Label
## 自分に届いたスタンプの間、画面のふちを光らせる枠
var _frame: Array[ColorRect] = []
var _stamp_tween: Tween


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


## 自分に届いたスタンプを出す(空文字で消す)。
## 「あなたへ」の見出し+ポンと飛び出す動き+画面のふちが光る、で他人宛てと区別する
func show_stamp(text: String, color: Color) -> void:
	if _stamp_tween:
		_stamp_tween.kill()
		_stamp_tween = null
	if text == "":
		_stamp_box.visible = false
		for r in _frame:
			r.visible = false
		return

	_stamp.text = text
	_stamp_style.bg_color = color
	_stamp_box.visible = true
	for r in _frame:
		r.color = color
		r.visible = true

	# ポンと大きくなってから元の大きさへ。枠は点滅させる
	_stamp_box.pivot_offset = _stamp_box.size / 2.0
	_stamp_box.scale = Vector2(0.3, 0.3)
	_stamp_tween = create_tween()
	_stamp_tween.tween_property(_stamp_box, "scale", Vector2(1.15, 1.15), 0.12)
	_stamp_tween.tween_property(_stamp_box, "scale", Vector2.ONE, 0.1)
	for i in 3:
		_stamp_tween.tween_callback(_set_frame_alpha.bind(0.25))
		_stamp_tween.tween_interval(0.15)
		_stamp_tween.tween_callback(_set_frame_alpha.bind(0.9))
		_stamp_tween.tween_interval(0.15)


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

	# 画面の下(スタンプボタンの上)に出す、色付きの吹き出し。
	# ほかの人あてのスタンプは 3D の頭の上(画面の上のほう)に出るので、場所で区別できる
	_stamp_style = StyleBoxFlat.new()
	_stamp_style.set_corner_radius_all(28)
	_stamp_style.set_border_width_all(6)
	_stamp_style.border_color = Color.WHITE
	_stamp_style.content_margin_left = 24
	_stamp_style.content_margin_right = 24
	_stamp_style.content_margin_top = 8
	_stamp_style.content_margin_bottom = 12
	_stamp_box = PanelContainer.new()
	_stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_box.add_theme_stylebox_override("panel", _stamp_style)
	add_child(_stamp_box)
	_stamp_box.anchor_left = 0.5
	_stamp_box.anchor_right = 0.5
	_stamp_box.anchor_top = 1.0
	_stamp_box.anchor_bottom = 1.0
	_stamp_box.offset_left = -210
	_stamp_box.offset_right = 210
	_stamp_box.offset_top = -330
	_stamp_box.offset_bottom = -130
	_stamp_box.visible = false

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_stamp_box.add_child(col)

	_stamp_header = _make_label(28, Color.WHITE)
	_stamp_header.text = "あなたへ"
	_stamp_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	col.add_child(_stamp_header)

	_stamp = _make_label(72, Color.WHITE)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_stamp.add_theme_constant_override("outline_size", 10)
	col.add_child(_stamp)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
