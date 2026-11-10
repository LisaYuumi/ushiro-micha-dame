class_name HudFont
extends RefCounted
## 日本語が表示できるフォントを返す。
## - assets/fonts/ にフォントがあればそれを使う(Web版はこちら。自動変換のときに入る)
## - なければ OS のフォントを使う(Windows / Mac で開発するとき)

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
