class_name TitleReveal
extends CanvasLayer
## 試合の最後の称号発表(点数の発表のあと)。みんなの画面で同じ流れ(称号はホストが決めて match_over で届く)。
## 順位の低い人から1人ずつ: 名前が光る → ドラムロール → 称号がポンと出る。全部で10〜15秒くらい(人数で1人の長さを変える)。
## 最後は全員の順位・点数・称号が並んだ画面のまま止まる(スクショ・撮影用)。画面をタップすると、最後まで飛ばす。
## ルーム主は「新しい試合へ」、ほかの人には待っている案内。見た目だけ(状態は変えない)

signal next_pressed

## 1人の長さ(秒)= 全体の長さ / 人数 を、この範囲に収める
const STEP_TOTAL := 11.5
const STEP_MIN := 1.1
const STEP_MAX := 1.8
## 見出しが出てから、1人目までの間(秒)
const INTRO := 0.9
## 名前が光ってから称号が出るまで(ドラムロールの長さ)
const ROLL := 0.6
const COLOR_TITLE := Color("7A3FB8")

var _rows: Array = []   # [{"panel", "pill", "title", "reason", "id"}](出す順)
var _t := 0.0
var _step := 0.0
var _shown := 0
var _lit := -1
var _done := false
var _footer: Control
var _panel: PanelContainer


## rows: 順位の高い順に {"id", "name", "color", "score", "mark", "me"}。titles: id -> Titles.decide の値。
## next_label が "" ならボタンを出さず footer の案内だけ。instant = true なら演出なしで最後の画面
func setup(rows: Array, titles: Dictionary, next_label: String, footer: String, instant: bool = false) -> void:
	layer = 3
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# (⚙メニューなど下のボタンは押せるように、タップは止めない。飛ばすのは _unhandled_input)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 28, 5)
	st.shadow_offset = Vector2(6, 8)
	st.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var head := UiStyle.label(tr("称号発表!"), 46, COLOR_TITLE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	head.add_theme_constant_override("outline_size", 8)
	col.add_child(head)

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 1 if rows.size() <= 5 else 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	# 表は順位の順(2列なら左の列が上位)。発表は順位の低い人から
	var per_col := ceili(rows.size() / float(grid.columns))
	var order := []
	for r in per_col:
		for c in grid.columns:
			var i := c * per_col + r
			order.append(i if i < rows.size() else -1)
	var built := {}
	for i in order:
		if i < 0:
			grid.add_child(Control.new())
			continue
		var row: Dictionary = rows[i]
		var b := _build_row(row, titles.get(row["title_id"], titles.get(int(row["title_id"]), {})))
		grid.add_child(b["panel"])
		built[i] = b
	for i in range(rows.size() - 1, -1, -1):
		_rows.append(built[i])

	var foot := VBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot)
	if footer != "":
		var f := UiStyle.label(footer, 20, GameConfig.COLOR_INK.lightened(0.35))
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.add_child(f)
	if next_label != "":
		var nb := Button.new()
		nb.text = next_label
		nb.custom_minimum_size = Vector2(0, 58)
		UiStyle.button(nb, true, 26)
		nb.pressed.connect(func() -> void:
			AudioDirector.click()
			next_pressed.emit())
		foot.add_child(nb)
	_footer = foot
	_footer.modulate.a = 0.0

	_step = clampf(STEP_TOTAL / maxf(rows.size(), 1), STEP_MIN, STEP_MAX)
	_panel.reset_size()
	UiStyle.center(_panel)
	if instant:
		_finish()
	else:
		AudioDirector.sfx("jajaan", -6.0)
		_panel.pivot_offset = _panel.size / 2.0
		_panel.scale = Vector2(0.7, 0.7)
		var tw := create_tween()
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 発表が全部終わったか
func is_done() -> bool:
	return _done


func _build_row(r: Dictionary, t: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color("FFF6D8") if r.get("me", false) else Color.WHITE, false, 14, 3)
	st.border_color = GameConfig.COLOR_ACCENT if r.get("me", false) else GameConfig.COLOR_INK
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(540, 64)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	var mk := UiStyle.label(str(r.get("mark", "")), 20, GameConfig.COLOR_ACCENT.darkened(0.2))
	mk.custom_minimum_size = Vector2(44, 0)
	mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mk)
	var dot := UiStyle.dot(r["color"], 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var name_col := VBoxContainer.new()
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	name_col.add_theme_constant_override("separation", -4)
	h.add_child(name_col)
	var n := UiStyle.label(str(r["name"]), 20, GameConfig.COLOR_INK)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(150, 0)
	name_col.add_child(n)
	name_col.add_child(UiStyle.label(tr("%d点") % int(r["score"]), 18, GameConfig.COLOR_INK.lightened(0.3)))
	# 称号(はじめは「?」の札。発表で中身がポンと出る)
	var tcol := VBoxContainer.new()
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", 0)
	h.add_child(tcol)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pst := UiStyle.box(Color("D9D3E6"), false, 14, 3)
	pst.content_margin_left = 14
	pst.content_margin_right = 14
	pst.content_margin_top = 2
	pst.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", pst)
	tcol.add_child(pill)
	var title_text := Titles.title_text(t) if not t.is_empty() else ""
	var tl := UiStyle.label("?", 24, Color.WHITE)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	tl.add_theme_constant_override("outline_size", 6)
	pill.add_child(tl)
	UiStyle.fit(tl, 24, 280.0, 14)
	var reason := UiStyle.label(Titles.reason_text(t) if not t.is_empty() else "", 15, GameConfig.COLOR_INK.lightened(0.25))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.modulate.a = 0.0
	UiStyle.fit(reason, 15, 300.0, 11)
	tcol.add_child(reason)
	return {"panel": panel, "style": st, "pill": pill, "pill_style": pst, "label": tl,
			"title": title_text, "reason": reason}


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k := int(floor((_t - INTRO) / _step))
	var into := _t - INTRO - float(k) * _step
	if _t >= INTRO and k < _rows.size() and k != _lit:
		_lit = k
		_light(k)
	if _shown < _rows.size() and _t >= INTRO + float(_shown) * _step + ROLL:
		_reveal(_shown, true)
		_shown += 1
		if _shown >= _rows.size():
			_finish()
	elif _lit >= 0 and into < ROLL and _lit == _shown:
		# ドラムロールの間、名前の札を少しゆらす
		var p: Control = _rows[_lit]["panel"]
		p.rotation = sin(_t * 40.0) * 0.012


## この人の番: 札を明るくして、ドラムロール
func _light(i: int) -> void:
	var b: Dictionary = _rows[i]
	var st: StyleBoxFlat = b["style"]
	st.border_color = COLOR_TITLE
	st.set_border_width_all(5)
	AudioDirector.sfx("drumroll", -8.0)


func _reveal(i: int, sound: bool) -> void:
	var b: Dictionary = _rows[i]
	var p: Control = b["panel"]
	p.rotation = 0.0
	var st: StyleBoxFlat = b["style"]
	st.set_border_width_all(3)
	st.border_color = GameConfig.COLOR_INK
	var lbl: Label = b["label"]
	lbl.text = b["title"]
	UiStyle.fit(lbl, 24, 280.0, 14)
	var pst: StyleBoxFlat = b["pill_style"]
	pst.bg_color = COLOR_TITLE
	(b["reason"] as Control).modulate.a = 1.0
	if sound:
		AudioDirector.sfx("title_pon", -4.0)
		var pill: Control = b["pill"]
		pill.pivot_offset = pill.size / 2.0
		pill.scale = Vector2(0.3, 0.3)
		var tw := pill.create_tween()
		tw.tween_property(pill, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pill, "scale", Vector2.ONE, 0.08)


## 全部出した(または飛ばした): 案内とボタンを出す
func _finish() -> void:
	for i in range(_shown, _rows.size()):
		_reveal(i, false)
	_shown = _rows.size()
	_done = true
	if _footer:
		_footer.modulate.a = 1.0


func _unhandled_input(ev: InputEvent) -> void:
	if visible:
		_on_tap(ev)


func _on_tap(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if tap and not _done:
		_finish()
