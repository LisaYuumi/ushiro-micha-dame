class_name HudFont
extends RefCounted
## 日本語が表示できるフォントを返す。
## - assets/fonts/ の M PLUS Rounded 1c(太字)を使う(SIL Open Font License。assets/fonts/OFL.txt)
## - 読めなかったときだけ OS のフォントを使う

const BUNDLED := "res://assets/fonts/MPLUSRounded1c-Bold.ttf"

static var _font: Font


static func get_font() -> Font:
	if _font == null:
		if ResourceLoader.exists(BUNDLED):
			_font = load(BUNDLED)
		else:
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray([
				"Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "sans-serif",
			])
			_font = sf
	return _font
