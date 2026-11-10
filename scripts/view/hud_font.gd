class_name HudFont
extends RefCounted
## 日本語が表示できる OS のフォントを使う(Windows / Mac / Linux)。

static var _font: SystemFont


static func get_font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray([
			"Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "sans-serif",
		])
	return _font
