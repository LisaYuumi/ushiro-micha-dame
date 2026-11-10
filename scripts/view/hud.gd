class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

var _help: Label


func _ready() -> void:
	_help = Label.new()
	_help.position = Vector2(16, 12)
	_help.add_theme_font_override("font", HudFont.get_font())
	_help.add_theme_font_size_override("font_size", 22)
	_help.add_theme_color_override("font_color", Color.BLACK)
	_help.add_theme_color_override("font_outline_color", Color.WHITE)
	_help.add_theme_constant_override("outline_size", 6)
	add_child(_help)


func set_help(text: String) -> void:
	_help.text = text
