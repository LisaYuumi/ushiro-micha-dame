class_name HudFont
extends RefCounted
## 日本語が表示できるフォントを返す。
## - assets/fonts/ の M PLUS Rounded 1c(太字)を使う(SIL Open Font License。assets/fonts/OFL.txt)
## - 読めなかったときだけ OS のフォントを使う

const BUNDLED := "res://assets/fonts/MPLUSRounded1c-Bold.ttf"

static var _font: Font
## 黒板の手書き文字(Yusei Magic。SIL Open Font License。assets/fonts/OFL-YuseiMagic.txt)
const CHALK := "res://assets/fonts/YuseiMagic-Regular.ttf"
static var _chalk: Font


static func get_chalk_font() -> Font:
	if _chalk == null:
		_chalk = load(CHALK) if ResourceLoader.exists(CHALK) else get_font()
	return _chalk


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
