class_name UiStyle
extends RefCounted
## A案「放課後ポップ」の画面の部品: 白地か #FF6B4A の地、黒い太い枠、角丸、右下にずらした黒い影。
## 押すと影が消えて、影のあった所へ沈む。

const BORDER := 4
const RADIUS := 18
## 影のずれ(右下)
const SHADOW := Vector2(4, 5)


## 札・ボタンの地。shadow = false なら影なし
static func box(bg: Color, shadow: bool = true, radius: int = RADIUS, border: int = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = GameConfig.COLOR_INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	if shadow:
		s.shadow_color = GameConfig.COLOR_INK
		s.shadow_size = 1
		s.shadow_offset = SHADOW
	return s


## 押したときの地: 影を消して、影のあった所(右下)へずらす
static func pressed_box(bg: Color, radius: int = RADIUS) -> StyleBoxFlat:
	var s := box(bg, false, radius)
	s.expand_margin_left = -SHADOW.x
	s.expand_margin_right = SHADOW.x
	s.expand_margin_top = -SHADOW.y
	s.expand_margin_bottom = SHADOW.y
	return s


## ボタンを A案の見た目にする。accent = true ならオレンジ地に白い文字
static func button(b: Button, accent: bool = false, font_size: int = 28, text_color: Color = Color(0, 0, 0, 0)) -> void:
	var bg := GameConfig.COLOR_ACCENT if accent else GameConfig.COLOR_PAPER
	var fg := GameConfig.COLOR_PAPER if accent else GameConfig.COLOR_INK
	if text_color.a > 0.0:
		fg = text_color
	b.add_theme_stylebox_override("normal", box(bg))
	b.add_theme_stylebox_override("hover", box(bg))
	b.add_theme_stylebox_override("pressed", pressed_box(bg))
	b.add_theme_stylebox_override("hover_pressed", pressed_box(bg))
	b.add_theme_stylebox_override("disabled", box(bg.darkened(0.2)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_font_override("font", HudFont.get_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE


## スマホの指で押している間、押したときの見た目にする(指の操作はボタンの「押された」状態にならないため)
static func show_pressed(b: Button, pressed: bool) -> void:
	var key := "_ui_normal"
	if pressed:
		if not b.has_meta(key):
			b.set_meta(key, b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed"))
	elif b.has_meta(key):
		b.add_theme_stylebox_override("normal", b.get_meta(key))
		b.remove_meta(key)


## 札(ラウンド・落とし物・点数など)。dark = true なら黒地に白い文字
static func pill(text: String, font_size: int = 22, dark: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(GameConfig.COLOR_INK if dark else GameConfig.COLOR_PAPER, true, 14, 3))
	var l := label(text, font_size, GameConfig.COLOR_PAPER if dark else GameConfig.COLOR_INK)
	p.add_child(l)
	return p


static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 色の丸(送った人・点数の表など)
static func dot(color: Color, size: float = 26.0) -> Panel:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = GameConfig.COLOR_INK
	s.set_border_width_all(3)
	s.set_corner_radius_all(int(size))
	var d := Panel.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.custom_minimum_size = Vector2(size, size)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.add_theme_stylebox_override("panel", s)
	return d
