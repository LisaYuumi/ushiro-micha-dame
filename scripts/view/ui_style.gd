class_name UiStyle
extends RefCounted
## A案「放課後ポップ」の画面の部品: 白地か #FF6B4A の地、黒い太い枠、角丸、右下にずらした黒い影。
## 押すと影が消えて、影のあった所へ沈む。

## 画面の端からの余白(iPhone の角の丸みやカメラ部分にかからないように)
const SAFE := 40
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


## パネルを画面のまん中に置く(中身の大きさが決まってから呼ぶ)
static func center(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.reset_size()
	var vp := c.get_viewport_rect().size
	c.size = c.get_combined_minimum_size()
	c.position = ((vp - c.size) / 2.0).floor()


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


## 文字がはみ出さないように、文字の大きさを決める(英語などで文字が長くなっても、ボタンや札の中に収める)。
## ctrl: Button か Label。base: ふつうの大きさ。max_w: 文字を入れてよい横幅(ピクセル)。
## 言語を切りかえたら refit_all() で、登録したものを全部やり直す
static var _fits: Array = []


static func fit(ctrl: Control, base: int, max_w: float, min_size: int = 12) -> void:
	_fits.append([weakref(ctrl), base, max_w, min_size])
	_apply_fit(ctrl, base, max_w, min_size)


static func refit_all() -> void:
	var keep: Array = []
	for f in _fits:
		var c: Control = (f[0] as WeakRef).get_ref()
		if c == null:
			continue
		keep.append(f)
		_apply_fit(c, f[1], f[2], f[3])
	_fits = keep


static func _apply_fit(ctrl: Control, base: int, max_w: float, min_size: int) -> void:
	var text := ""
	if ctrl is Button:
		text = (ctrl as Button).text
	elif ctrl is Label:
		text = (ctrl as Label).text
	text = String(TranslationServer.translate(text))
	var size := fit_size(text, base, max_w, min_size)
	# 大きさが変わらなければ何もしない(並べ直しを起こさない。ボタンを押すたびに重くならないように)
	if ctrl.has_theme_font_size_override("font_size") and ctrl.get_theme_font_size("font_size") == size:
		return
	ctrl.add_theme_font_size_override("font_size", size)


## はみ出さない文字の大きさ。一度測った文字と幅は覚えておく。測るときは半分ずつしぼりこむ
static var _size_cache := {}


static func fit_size(text: String, base: int, max_w: float, min_size: int) -> int:
	var key := "%s|%d|%d|%d" % [text, base, int(max_w), min_size]
	if _size_cache.has(key):
		return _size_cache[key]
	var font := HudFont.get_font()
	var lines := text.split("\n")
	var fits := func(sz: int) -> bool:
		for line in lines:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
				return false
		return true
	var size := base
	if not fits.call(base):
		# min_size〜base の間で、入るいちばん大きい大きさ
		var lo := min_size
		var hi := base - 1
		size = min_size
		while lo <= hi:
			var mid := (lo + hi) / 2
			if fits.call(mid):
				size = mid
				lo = mid + 1
			else:
				hi = mid - 1
	if _size_cache.size() > 2000:
		_size_cache.clear()
	_size_cache[key] = size
	return size


## 文字の色を変える(同じ色なら何もしない。毎フレーム呼んでも、並べ直しが起きないように)
static func set_font_color(l: Label, c: Color) -> void:
	if l.has_theme_color_override("font_color") and l.get_theme_color("font_color") == c:
		return
	l.add_theme_color_override("font_color", c)


## 地の色を変える(同じ色なら何もしない)
static func set_bg(st: StyleBoxFlat, c: Color) -> void:
	if st.bg_color != c:
		st.bg_color = c
