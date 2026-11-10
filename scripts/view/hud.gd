class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

var _help: Label
var _message: Label
var _message_left := 0.0
## 自分に届いたスタンプ(画面の上に大きく)
var _stamp: Label


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

	_stamp = _make_label(64, Color.WHITE)
	add_child(_stamp)
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stamp.offset_top = 90
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.add_theme_constant_override("outline_size", 14)
	_stamp.visible = false


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false

	_stamp = _make_label(64, Color.WHITE)
	add_child(_stamp)
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stamp.offset_top = 90
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.add_theme_constant_override("outline_size", 14)
	_stamp.visible = false


func set_help(text: String) -> void:
	_help.text = text


## 画面中央に大きく表示する。seconds 秒で消える(0 なら消さない)。
func show_message(text: String, outline: Color, seconds: float) -> void:
	_message.text = text
	_message.add_theme_color_override("font_outline_color", outline)
	_message.visible = true
	_message_left = seconds if seconds > 0.0 else INF


## 自分に届いたスタンプを出す(空文字で消す)
func show_stamp(text: String, outline: Color) -> void:
	_stamp.visible = text != ""
	_stamp.text = text
	_stamp.add_theme_color_override("font_outline_color", outline)


func hide_message() -> void:
	_message.visible = false

	_stamp = _make_label(64, Color.WHITE)
	add_child(_stamp)
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stamp.offset_top = 90
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.add_theme_constant_override("outline_size", 14)
	_stamp.visible = false
	_message_left = 0.0


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
