class_name TitleReveal
extends CanvasLayer
## 試合の最後の称号発表と記念写真(点数の発表のあと)。みんなの画面で同じ流れ(称号はホストが決めて match_over で届く)。
## 1. 「称号発表!」の大きな文字(称号がだれにもなければ、とばして 3 へ)
## 2. 称号を1つずつ(最大3つ。最後がオチ): カメラがその人に寄り(まわりは暗く、その人にスポットライト)、
##    その人が立って喜ぶ(いい称号)/ガーン(笑える称号)。画面の右半分に、くるっと回って大きな称号のカードが出て、
##    下に理由が1行(数字入り)。いい称号は金色とファンファーレ、笑える称号は紫とガーンの音。1つ STEP 秒
## 3. 記念写真: 全員が黒板の前に横に並び(1位がまん中)、称号のある人だけ頭の上にバッジ、足もとに名前と点数。
##    ルーム主には「新しい試合へ」、ほかの人には待っている案内。この画面のまま止まる(スクショ・撮影用)
## (タップで飛ばすことはしない。スマホで次へ進もうとしてタップすると、発表が見られなくなるので)。見た目だけ(状態は変えない)

signal next_pressed

const BANNER_TIME := 1.3
const STEP := 3.0
const CARD_AT := 0.45
const REASON_AT := 0.8
const COLOR_GOLD := Color("F6C945")
const COLOR_GOLD_DARK := Color("B07A10")
const COLOR_FUNNY := Color("6E56A8")
const COLOR_TITLE := Color("7A3FB8")
## 称号に合ったポーズ(CharacterModel.set_gesture)。書いていない称号(黒板消しなど)は shrug
const GESTURES := {
	"名探偵": "magnifier", "ウソつき大賞": "chin", "道連れ名人": "chin", "バナナの被害者": "banana",
	"気づかな賞": "shrug", "だまされ王": "head", "暗やみパニック賞": "head", "お手つき王": "head",
	"振り向き名人": "cheer", "逃げ足No.1": "peace", "タッチの達人": "cheer", "カミナリの目撃者": "cheer",
	"手下ハンター": "magnifier", "信じられる人": "peace", "おしゃべりさん": "wave", "鬼の常連": "chin",
}
## 称号のない人のポーズ(順番に。全員が同じ棒立ちにならないように)
const OTHER_GESTURES := ["peace", "wave", "", "cheer", "wave", "peace", "", "wave", "cheer", "peace"]

const DIM_SHADER := """
shader_type canvas_item;
uniform float dim = 0.0;
uniform vec2 size = vec2(1.0);
uniform vec3 hole = vec3(-1000.0, -1000.0, 1.0);
void fragment() {
	vec2 px = UV * size;
	float d = distance(px, hole.xy);
	float lit = 1.0 - smoothstep(hole.z * 0.55, hole.z, d);
	COLOR = vec4(0.02, 0.02, 0.06, dim * (1.0 - lit));
}
"""

var _view: WorldView
var _state: GameState
var _rows: Array = []
var _awards: Array = []
var _next_label := ""
var _footer_text := ""
var _t := 0.0
var _shown := -1
var _photo := false

var _dim: ColorRect
var _mat: ShaderMaterial
var _fx: Control
var _banner: Label
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _card_name: Label
var _card_title: Label
var _reason: Label
var _photo_ui: Control
var _badges := {}
var _names := {}
var _next_button: Button
## バッジの下の三角(頭を指す) [バッジの下のまん中, 頭の上の y, 色]
var _badge_tips: Array = []
## 3D の画面(カメラ・キャラの並び)を動かすか(撮影モードの4K保存用の写しは false)
var controls_view := true


## rows: 順位の高い順に {"title_id", "name", "color", "score", "mark", "me"}。awards: Titles.decide の配列(発表する順)。
## next_label が "" ならボタンを出さず footer の案内だけ。instant = true なら演出なしで記念写真から
func setup(view: WorldView, state: GameState, rows: Array, awards: Array, next_label: String, footer: String,
		instant: bool = false) -> void:
	layer = 3
	_view = view
	_state = state
	_rows = rows
	_awards = awards
	_next_label = next_label
	_footer_text = footer
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DIM_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_dim.material = _mat
	add_child(_dim)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	_banner = _big_label(tr("称号発表!"), 96, COLOR_GOLD)
	_banner.visible = false
	add_child(_banner)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_style = UiStyle.box(COLOR_GOLD, true, 30, 6)
	_card_style.shadow_offset = Vector2(8, 10)
	_card_style.set_content_margin_all(26)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.visible = false
	add_child(_card)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_card.add_child(col)
	_card_name = UiStyle.label("", 30, GameConfig.COLOR_INK)
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_name)
	_card_title = _big_label("", 72, Color.WHITE)
	col.add_child(_card_title)
	_reason = _big_label("", 34, Color.WHITE)
	_reason.visible = false
	add_child(_reason)

	if instant or _awards.is_empty():
		_start_photo(not instant)
	else:
		_banner.visible = true
		_place_center(_banner, 0.42)
		_pop(_banner, 0.4)
		AudioDirector.sfx("vote_don", -3.0)


func _big_label(text: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 8))
	return l


func is_done() -> bool:
	return _photo


func _process(delta: float) -> void:
	_t += delta
	if not _photo:
		var k := int(floor((_t - BANNER_TIME) / STEP))
		if _t >= BANNER_TIME and _banner.visible:
			_banner.visible = false
		if _t >= BANNER_TIME and k >= _awards.size():
			_start_photo(true)
		elif _t >= BANNER_TIME and k != _shown:
			_shown = k
			_focus(k)
		elif _shown >= 0:
			var into := _t - BANNER_TIME - float(_shown) * STEP
			if into >= CARD_AT and not _card.visible:
				_show_card(_awards[_shown])
			if into >= REASON_AT and not _reason.visible:
				_reason.visible = true
				_reason.modulate.a = 0.0
				_reason.create_tween().tween_property(_reason, "modulate:a", 1.0, 0.2)
	_update_dim()
	if _photo:
		_update_photo_ui()
	_fx.queue_redraw()


## その人にカメラを寄せる(まわりを暗く)
func _focus(i: int) -> void:
	var a: Dictionary = _awards[i]
	_card.visible = false
	_reason.visible = false
	var good := str(a.get("tone", "good")) == "good"
	var face := _face_of(a)
	if controls_view:
		# (ガーンでも、顔が見えるように立ったまま)
		_view.ceremony_focus(int(a["id"]), face, false, _gesture_of(a))
	AudioDirector.sfx("drumroll", -9.0)


func _gesture_of(a: Dictionary) -> String:
	return str(GESTURES.get(str(a.get("title", "")), "shrug"))


func _face_of(a: Dictionary) -> String:
	var f := str(a.get("face", ""))
	match f:
		"shock":
			return CharacterModel.SHOCK
		"awkward":
			return CharacterModel.AWKWARD
		"smirk":
			return CharacterModel.SMIRK
	return CharacterModel.WIN


## 大きな称号のカード(くるっと回って表が出る)と、下に理由
func _show_card(a: Dictionary) -> void:
	var good := str(a.get("tone", "good")) == "good"
	var actor := _state.get_actor(int(a["id"]))
	_card_name.text = _name_of(int(a["id"]))
	UiStyle.set_font_color(_card_name, GameConfig.COLOR_INK if good else Color.WHITE)
	_card_title.text = Titles.title_text(a)
	_card_style.bg_color = COLOR_GOLD if good else COLOR_FUNNY
	_card_style.border_color = COLOR_GOLD_DARK if good else GameConfig.COLOR_INK
	if actor:
		_card_style.border_color = actor.color.darkened(0.25) if good else _card_style.border_color
	_reason.text = Titles.reason_text(a)
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * 0.44
	_card.custom_minimum_size = Vector2(w, vp.y * 0.36)
	UiStyle.fit(_card_title, 72, w - 60.0, 30)
	UiStyle.fit(_reason, 34, vp.x * 0.46, 18)
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2(vp.x * 0.53, vp.y * 0.18)
	_card.pivot_offset = _card.size / 2.0
	_card.visible = true
	_card.scale = Vector2(0.0, 1.0)
	_card.rotation = 0.0 if good else deg_to_rad(-3.0)
	var tw := _card.create_tween()
	tw.tween_property(_card, "scale", Vector2(1.08, 1.08), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.1)
	_reason.reset_size()
	_reason.size = _reason.get_combined_minimum_size()
	_reason.position = Vector2(clampf(_card.position.x + (_card.size.x - _reason.size.x) / 2.0, 8.0, vp.x - _reason.size.x - 12.0),
			_card.position.y + _card.size.y + 14.0)
	_reason.visible = false
	if good:
		AudioDirector.sfx("jajaan", -3.0)
	else:
		AudioDirector.sfx("gaan", -3.0)
	AudioDirector.sfx("title_pon", -6.0)


## 記念写真
func _start_photo(flash: bool) -> void:
	if _photo:
		return
	_photo = true
	_banner.visible = false
	_card.visible = false
	_reason.visible = false
	var by := Titles.by_actor(_awards)
	# 順位の高い順(1位はまん中の台の上、そのあと左右に交互。並べるのは WorldView)
	var ranked := []
	var faces := {}
	var gestures := {}
	var other := 0
	for i in _rows.size():
		var id := int(_rows[i]["title_id"])
		ranked.append(id)
		if by.has(id):
			faces[id] = _face_of(by[id])
			gestures[id] = _gesture_of(by[id])
		else:
			faces[id] = CharacterModel.WIN
			gestures[id] = "cheer" if i == 0 else str(OTHER_GESTURES[other % OTHER_GESTURES.size()])
			if i > 0:
				other += 1
	if controls_view:
		_view.ceremony_photo(ranked, faces, gestures)
	_photo_ui = Control.new()
	_photo_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_photo_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_photo_ui)
	# 上: 「記念写真」とゲームの名前・舞台
	var head := PanelContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hst := UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4)
	hst.content_margin_left = 28
	hst.content_margin_right = 28
	hst.content_margin_top = 8
	hst.content_margin_bottom = 8
	head.add_theme_stylebox_override("panel", hst)
	var hl := UiStyle.label("%s ・ %s" % [tr("うしろ見ちゃダメ!"), tr(Items.STAGE_NAMES.get(_state.stage, "教室"))], 22, GameConfig.COLOR_INK)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", -6)
	hcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ht := UiStyle.label(tr("記念写真"), 40, COLOR_TITLE)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hcol.add_child(ht)
	hcol.add_child(hl)
	head.add_child(hcol)
	_photo_ui.add_child(head)
	head.reset_size()
	head.size = head.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	head.position = Vector2((vp.x - head.size.x) / 2.0, 14.0)
	# 頭の上の称号バッジ(称号のある人だけ)と、足もとの名前と点数
	for r in _rows:
		var id := int(r["title_id"])
		if by.has(id):
			var a: Dictionary = by[id]
			var good := str(a.get("tone", "good")) == "good"
			var b := PanelContainer.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bst := UiStyle.box(COLOR_GOLD if good else COLOR_FUNNY, true, 16, 3)
			bst.content_margin_left = 12
			bst.content_margin_right = 12
			bst.content_margin_top = 2
			bst.content_margin_bottom = 2
			b.add_theme_stylebox_override("panel", bst)
			var bl := UiStyle.label(Titles.title_text(a), 30, GameConfig.COLOR_INK if good else Color.WHITE)
			b.add_child(bl)
			_photo_ui.add_child(b)
			_badges[id] = b
		var np := PanelContainer.new()
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nst := UiStyle.box(Color("FFF6D8") if r.get("me", false) else Color.WHITE, false, 12, 3)
		nst.border_color = r["color"]
		nst.content_margin_left = 8
		nst.content_margin_right = 8
		nst.content_margin_top = 0
		nst.content_margin_bottom = 0
		np.add_theme_stylebox_override("panel", nst)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -6)
		nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := str(r.get("mark", ""))
		var nl := UiStyle.label(str(r["name"]), 20, GameConfig.COLOR_INK)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(76, 0)
		var sl := UiStyle.label(("%s %s" % [mark, tr("%d点") % int(r["score"])]).strip_edges(), 18,
				GameConfig.COLOR_ACCENT.darkened(0.2) if mark == "★" else GameConfig.COLOR_INK.lightened(0.3))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nv.add_child(nl)
		nv.add_child(sl)
		np.add_child(nv)
		_photo_ui.add_child(np)
		_names[id] = np
	# 下: 「新しい試合へ」/待っている案内
	var foot := VBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_ui.add_child(foot)
	if _footer_text != "":
		var f := _big_label(_footer_text, 22, Color.WHITE)
		foot.add_child(f)
	if _next_label != "":
		var nb := Button.new()
		nb.text = _next_label
		nb.custom_minimum_size = Vector2(380, 62)
		nb.focus_mode = Control.FOCUS_NONE
		UiStyle.button(nb, true, 26)
		nb.pressed.connect(func() -> void:
			AudioDirector.click()
			next_pressed.emit())
		foot.add_child(nb)
		_next_button = nb
	foot.reset_size()
	foot.size = foot.get_combined_minimum_size()
	foot.position = Vector2((vp.x - foot.size.x) / 2.0, vp.y - foot.size.y - 16.0)
	if flash:
		# パシャッ(白く光って消える)
		AudioDirector.sfx("flash_pasha", -4.0)
		var w := ColorRect.new()
		w.color = Color.WHITE
		w.set_anchors_preset(Control.PRESET_FULL_RECT)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(w)
		var tw := w.create_tween()
		tw.tween_property(w, "color:a", 0.0, 0.45)
		tw.tween_callback(w.queue_free)


## 称号のバッジは頭のすぐ上(下向きの三角で頭を指す。称号は最大3つなので、となり同士のときだけ上下にずらす)。
## 名前と順位・点数は、まとめて足もと
func _update_photo_ui() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	for id in _names:
		var np: Control = _names[id]
		# (床の高さ。1位は台の上なので、台の「1」を隠さないように台の下に)
		var feet := _view.actor_point(id, 0.0)
		feet.y = -0.02
		if cam.is_position_behind(feet):
			continue
		var p := cam.unproject_position(feet)
		np.reset_size()
		np.size = np.get_combined_minimum_size()
		np.position = Vector2(clampf(p.x - np.size.x / 2.0, 4.0, vp.x - np.size.x - 4.0), minf(p.y + 2.0, vp.y - np.size.y - 86.0))
	var placed: Array[Rect2] = []
	var list := _badges.keys()
	list.sort_custom(func(x, y): return _view.actor_point(x, 0.0).x < _view.actor_point(y, 0.0).x)
	_badge_tips.clear()
	for id in list:
		var b: Control = _badges[id]
		var top := _view.actor_point(id, 1.82)
		if cam.is_position_behind(top):
			continue
		var p := cam.unproject_position(top)
		b.reset_size()
		b.size = b.get_combined_minimum_size()
		var r := Rect2(Vector2(clampf(p.x - b.size.x / 2.0, 4.0, vp.x - b.size.x - 4.0), p.y - b.size.y - 22.0), b.size)
		for q in placed:
			if q.grow(2.0).intersects(r):
				r.position.y = q.position.y - r.size.y - 6.0
		r.position.y = maxf(r.position.y, 96.0)
		placed.append(r)
		b.position = r.position
		_badge_tips.append([Vector2(p.x, r.end.y), p.y - 2.0, (b.get_theme_stylebox("panel") as StyleBoxFlat).bg_color])


## まわりを暗く: 称号の人にスポットライト
func _update_dim() -> void:
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("size", vp)
	var dim := 0.0
	var hole := Vector3(-1000, -1000, 1)
	if not _photo and _shown >= 0 and _shown < _awards.size():
		dim = 0.6 * clampf((_t - BANNER_TIME - float(_shown) * STEP) / 0.3, 0.0, 1.0)
		var cam := get_viewport().get_camera_3d()
		var p3 := _view.actor_point(int(_awards[_shown]["id"]), 1.0)
		if cam and not cam.is_position_behind(p3):
			var p := cam.unproject_position(p3)
			hole = Vector3(p.x, p.y, vp.y * 0.42)
	elif not _photo:
		dim = 0.35
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("hole", hole)


## カードのまわりの飾り: いい称号は金色の星がきらきら、笑える称号は青い縦線(ガーン)
func _draw_fx() -> void:
	if _photo:
		for tip in _badge_tips:
			var at: Vector2 = tip[0]
			var head_y: float = tip[1]
			var y2 := maxf(at.y + 16.0, head_y)
			var tri := PackedVector2Array([at + Vector2(-14, -3), at + Vector2(14, -3), Vector2(at.x, y2)])
			_fx.draw_colored_polygon(tri, tip[2])
			_fx.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), GameConfig.COLOR_INK, 3.0, true)
		return
	if not _card.visible or _shown < 0 or _shown >= _awards.size():
		return
	var good := str(_awards[_shown].get("tone", "good")) == "good"
	var r := Rect2(_card.position, _card.size * _card.scale)
	var tt := Time.get_ticks_msec() / 1000.0
	if good:
		for i in 10:
			var a := TAU * float(i) / 10.0 + tt * 0.6
			# (下の理由の文字にかからないように、カードの上と横だけ)
			if sin(a) > 0.3:
				continue
			var c := r.get_center() + Vector2(cos(a) * r.size.x * 0.6, sin(a) * r.size.y * 0.75)
			var s := 9.0 + 6.0 * sin(tt * 5.0 + float(i))
			var pts := PackedVector2Array([c + Vector2(0, -s * 2), c + Vector2(s * 0.5, -s * 0.5), c + Vector2(s * 2, 0),
					c + Vector2(s * 0.5, s * 0.5), c + Vector2(0, s * 2), c + Vector2(-s * 0.5, s * 0.5),
					c + Vector2(-s * 2, 0), c + Vector2(-s * 0.5, -s * 0.5)])
			_fx.draw_colored_polygon(pts, Color(1.0, 0.92, 0.45))
	else:
		for i in 6:
			var x := r.position.x + 30.0 + float(i) * 22.0
			var len := 70.0 - float(i) * 9.0
			_fx.draw_line(Vector2(x, r.position.y - 12.0), Vector2(x, r.position.y - 12.0 - len), Color("6EA8F0"), 5.0, true)


func _name_of(id: int) -> String:
	for r in _rows:
		if int(r["title_id"]) == id:
			return str(r["name"])
	return ""


func _place_center(c: Control, y_ratio: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	c.reset_size()
	c.size = c.get_combined_minimum_size()
	c.position = Vector2((vp.x - c.size.x) / 2.0, vp.y * y_ratio - c.size.y / 2.0)
	c.pivot_offset = c.size / 2.0


func _pop(c: Control, from: float) -> void:
	c.scale = Vector2(from, from)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.1)


func _exit_tree() -> void:
	if controls_view and _view and is_instance_valid(_view):
		_view.ceremony_end()


## スマホの指: 「新しい試合へ」を押す(記念写真のとき)
func _input(event: InputEvent) -> void:
	if _photo and visible:
		UiStyle.tap_buttons(event, [_next_button])
