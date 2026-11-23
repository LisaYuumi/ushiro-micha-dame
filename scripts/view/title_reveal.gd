class_name TitleReveal
extends CanvasLayer
## 試合の終わりの演出(手下の発表のあと)。同じ教室の中でカメラが動いて、場面をつなぐ(黒や白の画面は挟まない。
## 白いフラッシュは記念写真の1回だけ)。みんなの画面で同じ流れ(順位と称号はホストが決めて match_over で届く)。
##   1. 試合終了: 照明が少し落ちて「試合終了!」。みんなが立ち上がって表彰台のまわりへ歩いて集まる
##   2. 表彰台: 3位 → 2位 → 1位の順に台に上がり、点数が0から数え上がる。1位で紙ふぶきとファンファーレ、1位は喜ぶ。
##      4位からは、下に名前と点数を並べる。自分は色と枠で分かる
##   3. 「そして…称号発表!」(カメラが少し引く。称号がなければ、とばして記念写真へ)
##   4. 称号を1人ずつ(最大3人。最後がオチ): カメラがその人へすーっと動いて寄る(スポットライトも移る)。
##      名前を大きく → ドラムロール(最後だけ長め)→ カードがくるっと回って称号(いい称号は金色とファンファーレ、
##      笑える称号は紫とガーン)→ 理由を大きく1行
##   5. 記念写真: みんなが横に並ぶ →「はい、チーズ!」→ パシャッ(白いフラッシュ)。称号のバッジは頭のすぐ上、
##      名前と順位・点数は足もと。ルーム主には「新しい試合へ」。この画面のまま止まる(スクショ・撮影用)
## 場面の文字は、前の文字が消えてから次を出す。画面をタップ(またはスペースキー)すると次の場面へ早送り。
## ルーム主の「スキップ」は、全員が記念写真へ(main がお知らせで送る)。見た目だけ(状態は変えない)

signal next_pressed
## ルーム主が「スキップ」を押した(main が全員に送る)
signal skip_pressed

## 場面の長さ(秒)。全体で30秒くらい
const END_TIME := 2.4
const PODIUM_STEP_AT := [0.3, 1.5, 2.7]    # 3位・2位・1位が台に上がる
const PODIUM_TIME := 6.0                   # (1位のあと、紙ふぶきが落ちきるまで)
const COUNT_TIME := 0.8                    # 点数が数え上がる時間
const INTRO_TIME := 1.7
const AWARD_NAME_AT := 0.35
const AWARD_ROLL := 1.0                    # ドラムロール
const AWARD_ROLL_LAST := 2.0               # 最後の称号だけ長め
const AWARD_AFTER := 2.0                   # カードが出てから次まで
const CHEESE_AT := 1.3
const FLASH_AT := 2.3

const COLOR_GOLD := Color("F6C945")
const COLOR_GOLD_DARK := Color("B07A10")
const COLOR_FUNNY := Color("6E56A8")
const COLOR_TITLE := Color("7A3FB8")
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
var _is_host := false
## 場面: "end" / "podium" / "intro" / "award" / "photo"
var _scene := ""
var _award_i := -1
var _st := 0.0
var _steps_done := 0
var _photo := false
var _flashed := false

var _dim: ColorRect
var _mat: ShaderMaterial
var _fx: Control
var _banner: Label
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _card_title: Label
var _award_name: Label
var _reason: Label
var _podium_ui: Control
var _podium_tags := {}
var _photo_ui: Control
var _badges := {}
var _names := {}
var _next_button: Button
var _skip_button: Button
## バッジの下の三角(頭を指す) [バッジの下のまん中, 頭の上の y, 色]
var _badge_tips: Array = []
## 3D の画面(カメラ・キャラの並び)を動かすか(撮影モードの4K保存用の写しは false)
var controls_view := true


## rows: 順位の高い順に {"title_id", "name", "color", "score", "mark", "me"}。awards: Titles.decide の配列(発表する順)。
## next_label が "" ならボタンを出さず footer の案内だけ(ルーム主でない人)。instant = true なら演出なしで記念写真
func setup(view: WorldView, state: GameState, rows: Array, awards: Array, next_label: String, footer: String,
		instant: bool = false) -> void:
	layer = 3
	_view = view
	_state = state
	_rows = rows
	_awards = awards
	_next_label = next_label
	_footer_text = footer
	_is_host = next_label != ""
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
	_banner = _big_label("", 92, COLOR_GOLD)
	_banner.visible = false
	add_child(_banner)
	_award_name = _big_label("", 56, Color.WHITE)
	_award_name.visible = false
	add_child(_award_name)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_style = UiStyle.box(COLOR_GOLD, true, 30, 6)
	_card_style.shadow_offset = Vector2(8, 10)
	_card_style.set_content_margin_all(26)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.visible = false
	add_child(_card)
	_card_title = _big_label("", 76, Color.WHITE)
	_card.add_child(_card_title)
	_reason = _big_label("", 42, Color.WHITE)
	_reason.visible = false
	add_child(_reason)
	# ルーム主だけ: 「スキップ」(全員が記念写真へ)
	if _is_host and not instant:
		_skip_button = Button.new()
		_skip_button.text = tr("スキップ ▶▶")
		_skip_button.focus_mode = Control.FOCUS_NONE
		UiStyle.button(_skip_button, false, 20)
		_skip_button.anchor_left = 1.0
		_skip_button.anchor_right = 1.0
		_skip_button.offset_left = -UiStyle.SAFE - 170
		_skip_button.offset_right = -UiStyle.SAFE
		_skip_button.offset_top = 14
		_skip_button.offset_bottom = 62
		_skip_button.pressed.connect(func() -> void:
			AudioDirector.click()
			skip_pressed.emit())
		add_child(_skip_button)
	if instant:
		_enter("photo", true)
	else:
		_enter("end")


func _big_label(text: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 8))
	return l


## 記念写真まで来たか
func is_done() -> bool:
	return _photo


## 今の場面(テスト用)
func scene() -> String:
	return _scene


## 次の場面へ早送り(タップ・スペースキー)
func advance() -> void:
	match _scene:
		"end":
			_enter("podium")
		"podium":
			_finish_podium()
			_enter("intro" if not _awards.is_empty() else "photo")
		"intro":
			_award_i = 0
			_enter("award")
		"award":
			if _award_i + 1 < _awards.size():
				_award_i += 1
				_enter("award")
			else:
				_enter("photo")
		"photo":
			if not _flashed:
				_take_photo()


## 記念写真まで飛ばす(ルーム主の「スキップ」)
func jump_to_photo() -> void:
	if _scene == "photo":
		if not _flashed:
			_take_photo()
		return
	if _scene == "podium" or _scene == "end":
		_finish_podium()
	_enter("photo")


func _enter(scene: String, instant := false) -> void:
	_scene = scene
	_st = 0.0
	_hide_texts()
	match scene:
		"end":
			# 照明を少し落として「試合終了!」。みんなが立ち上がって表彰台のまわりへ
			_show_banner(tr("試合終了!"), Color.WHITE)
			AudioDirector.sfx("match_end", -4.0)
			if controls_view:
				_view.ceremony_gather(_ranked())
		"podium":
			_build_podium_ui()
		"intro":
			if controls_view:
				_view.ceremony_view("wide")
			_show_banner(tr("そして…称号発表!"), COLOR_GOLD)
			AudioDirector.sfx("vote_don", -3.0)
		"award":
			_focus(_award_i)
		"photo":
			_start_photo(instant)


func _hide_texts() -> void:
	_banner.visible = false
	_card.visible = false
	_reason.visible = false
	_award_name.visible = false
	if _podium_ui and is_instance_valid(_podium_ui):
		_podium_ui.queue_free()
	_podium_ui = null
	_podium_tags.clear()


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	UiStyle.set_font_color(_banner, color)
	_banner.visible = true
	_place_center(_banner, 0.32)
	_pop(_banner, 0.4)


func _process(delta: float) -> void:
	_st += delta
	match _scene:
		"end":
			if _st >= END_TIME:
				_enter("podium")
		"podium":
			while _steps_done < 3 and _steps_done < _rows.size() and _st >= PODIUM_STEP_AT[_steps_done]:
				_step_up(_steps_done)
			if _st >= PODIUM_TIME:
				_enter("intro" if not _awards.is_empty() else "photo")
		"intro":
			if _st >= INTRO_TIME:
				_award_i = 0
				_enter("award")
		"award":
			_update_award()
		"photo":
			if not _flashed and _st >= CHEESE_AT and not _banner.visible:
				_show_banner(tr("はい、チーズ!"), Color.WHITE)
			if not _flashed and _st >= FLASH_AT:
				_take_photo()
	_update_podium_ui()
	_update_dim()
	if _photo:
		_update_photo_ui()
	_fx.queue_redraw()


# --- 表彰台 ---

func _ranked() -> Array:
	return _rows.map(func(r): return int(r["title_id"]))


## 3位 → 2位 → 1位(i: 0 なら3位。人数が3人より少ないときは、いる人だけ)
func _step_up(i: int) -> void:
	_steps_done = i + 1
	var top := mini(3, _rows.size())
	var rank := top - 1 - i
	if rank < 0:
		return
	var id := int(_rows[rank]["title_id"])
	if controls_view:
		_view.ceremony_step_up(id, rank)
	if _podium_tags.has(id):
		var tag: Dictionary = _podium_tags[id]
		tag["start"] = _st
		(tag["panel"] as Control).visible = true
	if rank == 0:
		# 1位: 紙ふぶきとファンファーレ。喜ぶ
		AudioDirector.sfx("jajaan", -2.0)
		_confetti()
		if controls_view:
			_view.ceremony_set_face(id, CharacterModel.WIN, "cheer")
	else:
		AudioDirector.sfx("title_pon", -4.0)


## 表彰台をとばしたとき: まだ上がっていない人も台に上げる
func _finish_podium() -> void:
	while _steps_done < mini(3, _rows.size()):
		_step_up(_steps_done)


## 表彰台の文字: 1〜3位は頭の上に名前と点数(0から数え上がる)。4位からは下に並べる。自分は色と枠で分かる
func _build_podium_ui() -> void:
	_podium_ui = Control.new()
	_podium_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_podium_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_podium_ui)
	var vp := get_viewport().get_visible_rect().size
	for i in mini(3, _rows.size()):
		var r: Dictionary = _rows[i]
		var p := _pill(r, 24, 30)
		p.visible = false
		_podium_ui.add_child(p)
		_podium_tags[int(r["title_id"])] = {"panel": p, "score": int(r["score"]), "start": -1.0,
				"label": p.get_meta("score_label"), "rank": i}
	if _rows.size() > 3:
		# 4位からは、下に1列に並べる(人数が多いときは文字を少し小さく)
		var flow := HBoxContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("separation", 10)
		var fs := 22 if _rows.size() <= 7 else 18
		for i in range(3, _rows.size()):
			var r: Dictionary = _rows[i]
			var p := _pill(r, fs, fs)
			(p.get_meta("score_label") as Label).text = "%s  %s" % [str(r.get("mark", "")), tr("%d点") % int(r["score"])]
			flow.add_child(p)
		_podium_ui.add_child(flow)
		flow.reset_size()
		flow.size = flow.get_combined_minimum_size()
		flow.position = Vector2((vp.x - flow.size.x) / 2.0, vp.y - flow.size.y - 18.0)


## 名前と点数の札(自分はオレンジの枠と黄色)
func _pill(r: Dictionary, name_size: int, score_size: int) -> PanelContainer:
	var me: bool = r.get("me", false)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color("FFF1B8") if me else Color.WHITE, true, 14, 4 if me else 3)
	st.border_color = GameConfig.COLOR_ACCENT if me else r["color"]
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var dot := UiStyle.dot(r["color"], 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var nl := UiStyle.label(str(r["name"]), name_size, GameConfig.COLOR_INK)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nl)
	var sl := UiStyle.label(tr("%d点") % 0, score_size, GameConfig.COLOR_ACCENT.darkened(0.25))
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(sl)
	p.set_meta("score_label", sl)
	return p


func _update_podium_ui() -> void:
	if _podium_tags.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	for id in _podium_tags:
		var tag: Dictionary = _podium_tags[id]
		var p: Control = tag["panel"]
		if float(tag["start"]) < 0.0:
			continue
		var k := clampf((_st - float(tag["start"])) / COUNT_TIME, 0.0, 1.0)
		(tag["label"] as Label).text = tr("%d点") % roundi(float(tag["score"]) * k)
		var top := _view.actor_point(id, 1.95)
		if cam.is_position_behind(top):
			continue
		var sp := cam.unproject_position(top)
		p.reset_size()
		p.size = p.get_combined_minimum_size()
		p.position = Vector2(clampf(sp.x - p.size.x / 2.0, 4.0, vp.x - p.size.x - 4.0), maxf(sp.y - p.size.y, 70.0))


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 120
	p.lifetime = 2.6
	p.explosiveness = 0.85
	var vp := get_viewport().get_visible_rect().size
	p.position = Vector2(vp.x / 2.0, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x / 2.0, 10)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 14.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("EE6A4D"), Color("F2C14E"), Color("6DB58A"), Color("5B8FD9"), Color("B07CF0"), Color("EF8FB0")])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


# --- 称号 ---

## その人へカメラを動かす(スポットライトも移る)
func _focus(i: int) -> void:
	var a: Dictionary = _awards[i]
	if controls_view:
		_view.ceremony_focus(int(a["id"]), _face_of(a), false, _gesture_of(a))
	AudioDirector.sfx("drumroll", -8.0)


func _roll_time() -> float:
	return AWARD_ROLL_LAST if _award_i == _awards.size() - 1 else AWARD_ROLL


func _update_award() -> void:
	var a: Dictionary = _awards[_award_i]
	var card_at := AWARD_NAME_AT + _roll_time()
	if _st >= AWARD_NAME_AT and not _award_name.visible and not _card.visible:
		# 名前を大きく
		_award_name.text = _name_of(int(a["id"]))
		_award_name.visible = true
		var vp := get_viewport().get_visible_rect().size
		UiStyle.fit(_award_name, 56, vp.x * 0.42, 26)
		_award_name.reset_size()
		_award_name.size = _award_name.get_combined_minimum_size()
		_award_name.position = Vector2(vp.x * 0.75 - _award_name.size.x / 2.0, vp.y * 0.16)
		_pop(_award_name, 0.5)
		if _award_i == _awards.size() - 1:
			# 最後はドラムロールを長めに(オチ)
			AudioDirector.sfx("drumroll", -6.0)
	if _st >= card_at and not _card.visible:
		_show_card(a)
	if _st >= card_at + 0.4 and _card.visible and not _reason.visible:
		_reason.visible = true
		_reason.modulate.a = 0.0
		_reason.create_tween().tween_property(_reason, "modulate:a", 1.0, 0.2)
	if _st >= card_at + AWARD_AFTER:
		advance()


## 大きな称号のカード(くるっと回って表が出る)と、下に理由
func _show_card(a: Dictionary) -> void:
	var good := str(a.get("tone", "good")) == "good"
	_card_title.text = Titles.title_text(a)
	UiStyle.set_font_color(_card_title, GameConfig.COLOR_INK if good else Color.WHITE)
	_card_title.add_theme_color_override("font_outline_color", Color.WHITE if good else GameConfig.COLOR_INK)
	_card_style.bg_color = COLOR_GOLD if good else COLOR_FUNNY
	_card_style.border_color = COLOR_GOLD_DARK if good else GameConfig.COLOR_INK
	_reason.text = Titles.reason_text(a)
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * 0.46
	_card.custom_minimum_size = Vector2(w, vp.y * 0.3)
	UiStyle.fit(_card_title, 76, w - 60.0, 30)
	UiStyle.fit(_reason, 42, vp.x * 0.48, 22)
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	var top := _award_name.position.y + _award_name.size.y + 10.0
	_card.position = Vector2(vp.x * 0.75 - _card.size.x / 2.0, top)
	_card.position.x = minf(_card.position.x, vp.x - _card.size.x - 12.0)
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
	if good:
		AudioDirector.sfx("jajaan", -3.0)
	else:
		AudioDirector.sfx("gaan", -3.0)
	AudioDirector.sfx("title_pon", -6.0)


## 称号のポーズ(称号の表 Titles.LIST の gesture)
func _gesture_of(a: Dictionary) -> String:
	if a.has("gesture"):
		return str(a["gesture"])
	return str(Titles.find(str(a.get("title", ""))).get("gesture", "shrug"))


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


# --- 記念写真 ---

## みんなが横に並ぶ(このあと「はい、チーズ!」→ パシャッ)。instant なら、すぐ並んで撮ったあと
func _start_photo(instant: bool) -> void:
	_photo = true
	if _skip_button and is_instance_valid(_skip_button):
		_skip_button.visible = false
	var by := Titles.by_actor(_awards)
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
		_view.ceremony_photo(ranked, faces, gestures, instant)
	if instant:
		_build_photo_ui()
		_flashed = true


## パシャッ: 白いフラッシュと音、記念写真の文字とボタン
func _take_photo() -> void:
	_flashed = true
	_banner.visible = false
	AudioDirector.sfx("flash_pasha", -4.0)
	var w := ColorRect.new()
	w.color = Color.WHITE
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)
	var tw := w.create_tween()
	tw.tween_property(w, "color:a", 0.0, 0.45)
	tw.tween_callback(w.queue_free)
	_build_photo_ui()


func _build_photo_ui() -> void:
	if _photo_ui and is_instance_valid(_photo_ui):
		return
	var by := Titles.by_actor(_awards)
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
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", -6)
	hcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ht := UiStyle.label(tr("記念写真"), 40, COLOR_TITLE)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hl := UiStyle.label("%s ・ %s" % [tr("うしろ見ちゃダメ!"), tr(Items.STAGE_NAMES.get(_state.stage, "教室"))], 22, GameConfig.COLOR_INK)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hcol.add_child(ht)
	hcol.add_child(hl)
	head.add_child(hcol)
	_photo_ui.add_child(head)
	head.reset_size()
	head.size = head.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	head.position = Vector2((vp.x - head.size.x) / 2.0, 14.0)
	# 頭のすぐ上の称号バッジ(称号のある人だけ)と、足もとの名前と順位・点数
	for r in _rows:
		var id := int(r["title_id"])
		if by.has(id):
			var a: Dictionary = by[id]
			var good := str(a.get("tone", "good")) == "good"
			var b := PanelContainer.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bst := UiStyle.box(COLOR_GOLD if good else COLOR_FUNNY, true, 16, 3)
			bst.content_margin_left = 14
			bst.content_margin_right = 14
			bst.content_margin_top = 2
			bst.content_margin_bottom = 2
			b.add_theme_stylebox_override("panel", bst)
			b.add_child(UiStyle.label(Titles.title_text(a), 32, GameConfig.COLOR_INK if good else Color.WHITE))
			_photo_ui.add_child(b)
			_badges[id] = b
		var me: bool = r.get("me", false)
		var np := PanelContainer.new()
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nst := UiStyle.box(Color("FFF1B8") if me else Color.WHITE, false, 12, 4 if me else 3)
		nst.border_color = GameConfig.COLOR_ACCENT if me else r["color"]
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
		foot.add_child(_big_label(_footer_text, 22, Color.WHITE))
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


## 称号のバッジは頭のすぐ上(下向きの三角で頭を指す。となり同士のときだけ上下にずらす)。
## 名前と順位・点数は、まとめて足もと(床の高さ。1位は台の下)
func _update_photo_ui() -> void:
	if _photo_ui == null or not is_instance_valid(_photo_ui):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	for id in _names:
		var np: Control = _names[id]
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


# --- 画面の暗さと飾り ---

## 試合終了で照明を少し落とす。称号の人にスポットライト(カメラといっしょに動く)
func _update_dim() -> void:
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("size", vp)
	var dim := 0.0
	var hole := Vector3(-1000, -1000, 1)
	match _scene:
		"end":
			dim = 0.3 * clampf(_st / 0.4, 0.0, 1.0)
		"podium":
			dim = 0.3 * (1.0 - clampf(_st / 0.6, 0.0, 1.0))
		"intro":
			dim = 0.35 * clampf(_st / 0.5, 0.0, 1.0)
		"award":
			dim = 0.6
			var cam := get_viewport().get_camera_3d()
			var p3 := _view.actor_point(int(_awards[_award_i]["id"]), 1.0)
			if cam and not cam.is_position_behind(p3):
				var p := cam.unproject_position(p3)
				hole = Vector3(p.x, p.y, vp.y * 0.42)
		"photo":
			dim = 0.0
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("hole", hole)


## カードのまわりの飾り(いい称号は金色の星、笑える称号は青い縦線)と、記念写真のバッジの三角
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
	if _scene != "award" or not _card.visible:
		return
	var good := str(_awards[_award_i].get("tone", "good")) == "good"
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


## スマホの指: 「新しい試合へ」「スキップ」を押す
func _input(event: InputEvent) -> void:
	if visible:
		UiStyle.tap_buttons(event, [_next_button, _skip_button])


## 画面をタップ(またはスペースキー)すると、次の場面へ早送り
func _unhandled_input(ev: InputEvent) -> void:
	if not visible or (_photo and _flashed):
		return
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed) \
			or (ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_SPACE)
	if tap:
		get_viewport().set_input_as_handled()
		advance()
