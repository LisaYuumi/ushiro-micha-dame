class_name MissedReplay
extends CanvasLayer
## 見逃しの答え合わせリプレイ「そのとき後ろでは…」。誰が本当のことを言い、誰がウソをついたかを明かす。
## 1. 巻き戻し(セピア・走査線・キュルキュル)
## 2. 鬼の足取り(上から。足あとを残して2倍速。下に時間のバー)
## 3. ここで落とした!(スローにして一時停止。落とし物を丸で囲む。落とされた人以外は少し暗く)
## 4. 誰が何を言ったか(落とした後に届いたスタンプを送った順に。送った人から線、吹き出し、ほんと/ウソのハンコ)
## 5. ウソつきにスポットライト(ウソがなければ「みんな正直だった!」)
## 6. このラウンドで入った点数
## スタンプが1つも届いていなければ、4 と 5 の代わりに「だれも教えてくれなかった…」(落とされた人だけ明るく、風、ヒュ〜。
## 後ろが見えていた人に「見てたのに…!」)。秒数は GameConfig の REPLAY_*。
## 見た目だけ(状態は読むだけ)。WorldView が毎フレーム tick を呼び、鬼の位置と落とし物の見え方を読む。
## 全員の画面で、同じ結果(result)から同じ流れになる。

signal finished

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float sepia = 0.0;
uniform float scan = 0.0;
uniform float dim = 0.0;
uniform vec2 size = vec2(1.0);
uniform int hole_count = 0;
uniform vec3 holes[8];
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sp = vec3(g * 1.08 + 0.05, g * 0.9 + 0.03, g * 0.66);
	c = mix(c, sp, sepia);
	vec2 px = UV * size;
	c *= 1.0 - scan * 0.28 * step(0.5, fract(px.y / 5.0));
	float lit = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= hole_count) { break; }
		float d = distance(px, holes[i].xy);
		lit = max(lit, 1.0 - smoothstep(holes[i].z * 0.7, holes[i].z, d));
	}
	c *= 1.0 - dim * (1.0 - lit);
	COLOR = vec4(c, 1.0);
}
"""

const COLOR_TRUE := Color("2E9E5B")
const COLOR_LIE := Color("E5483B")
const COLOR_FOOT := Color(0.22, 0.14, 0.08, 0.75)
## 時間のバーの、落とした瞬間の位置(0〜1)。そこまでが鬼の足取り、そのあとがスタンプが届いた時間
const BAR_DROP := 0.62

var _state: GameState
var _res: Dictionary
var _cam: Camera3D
var _nodes: Dictionary
var _oni: int
var _loser: int
var _drop_pos := Vector3.ZERO
var _a_drop := 0.0
var _a_start := 0.0
var _a_from := 0.0
var _steps: Array = []
var _step := -1
var _step_t := 0.0
var _stamps: Array = []
var _liars: Array = []

var _fx: ColorRect
var _mat: ShaderMaterial
var _canvas: Control
var _ui: Control
## 鬼の今の角度と、歩いているか(WorldView が読む)
var oni_angle := 0.0
var oni_walking := false
## 落とし物を見せるか(落とした瞬間から)
var item_shown := false
var _bar := 0.0
var _feet: Array[Vector3] = []
var _walked := 0.0
var _ring_t := -1.0
## 出したスタンプ: {"from", "truthful", "bubble"}
var _shown: Array = []
var _placed: Array[Rect2] = []
var _done := false
## 風の演出の時計
var _wind_t := -1.0


func setup(state: GameState, res: Dictionary, cam: Camera3D, nodes: Dictionary, oni_from: Vector3) -> void:
	layer = 4
	_state = state
	_res = res
	_cam = cam
	_nodes = nodes
	_oni = state.oni_id
	_loser = int(res.get("loser", -1))
	_drop_pos = res.get("drop_pos", Vector3.ZERO)
	_a_drop = float(res.get("drop_angle", 0.0))
	if not is_finite(_a_drop):
		_a_drop = atan2(_drop_pos.x, _drop_pos.z)
	# 鬼が2倍速で REPLAY_WALK_TIME 歩くぶん、落とした場所より手前から
	var span := GameConfig.ONI_WALK_SPEED * GameConfig.REPLAY_WALK_SPEED * GameConfig.REPLAY_WALK_TIME / GameConfig.ONI_WALK_RADIUS
	_a_start = _a_drop - span
	_a_from = atan2(oni_from.x, oni_from.z)
	# 今の場所から、落とした場所の手前まで逆回りにもどる(巻き戻し)
	_a_from = _a_start + fposmod(_a_from - _a_start, TAU)
	oni_angle = _a_from
	_stamps = replay_stamps(res)
	for st in _stamps:
		if not bool(st.get("truthful", true)) and not (int(st["sender"]) in _liars):
			_liars.append(int(st["sender"]))
	_steps = ["intro", "walk", "drop"]
	if not _stamps.is_empty():
		_steps.append("stamps")
		_steps.append("spot" if not _liars.is_empty() else "honest")
	else:
		_steps.append("nobody")
	_steps.append("score")

	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_fx.material = _mat
	add_child(_fx)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_next_step()


func step_name() -> String:
	return _steps[_step] if _step >= 0 and _step < _steps.size() else ""


static func step_time(step_id: String) -> float:
	match step_id:
		"intro":
			return GameConfig.REPLAY_INTRO_TIME
		"walk":
			return GameConfig.REPLAY_WALK_TIME
		"drop":
			return GameConfig.REPLAY_DROP_TIME
		"stamps":
			return GameConfig.REPLAY_STAMPS_TIME
		"spot":
			return GameConfig.REPLAY_SPOT_TIME
		"honest":
			return GameConfig.REPLAY_HONEST_TIME
		"nobody":
			return GameConfig.REPLAY_NOBODY_TIME
		"score":
			return GameConfig.REPLAY_SCORE_TIME
	return 0.0


## リプレイで出すスタンプ: 落とした後に届いたものだけ(落とす前の「平気」は、そのときは本当なので、出すとまぎらわしい)
static func replay_stamps(res: Dictionary) -> Array:
	var out := []
	for st in res.get("missed_stamps", []):
		if bool(st.get("after_drop", true)):
			out.append(st)
	return out


## リプレイ全体の秒数(この結果のとき)
static func total_time(res: Dictionary) -> float:
	var t := step_time("intro") + step_time("walk") + step_time("drop") + step_time("score")
	var stamps: Array = replay_stamps(res)
	if not stamps.is_empty():
		var lie := false
		for st in stamps:
			if not bool(st.get("truthful", true)):
				lie = true
		t += step_time("stamps") + step_time("spot" if lie else "honest")
	else:
		t += step_time("nobody")
	return t


## 落とされた人の後ろが見えていた人(鬼と本人は別。座っている人は両どなりを除く。抜けて真ん中にいる人は全員見える)
static func watchers(state: GameState, loser_id: int) -> Array:
	var out := []
	var loser := state.get_actor(loser_id)
	if loser == null:
		return out
	var seat := loser.seat_index if loser.seat_index >= 0 else loser.home_seat
	if seat < 0:
		return out
	for a in state.actors:
		if a.id == loser_id or a.id == state.oni_id:
			continue
		if a.role == GameState.Role.OUT or (a.role == GameState.Role.SEATED and a.seat_index >= 0 and state.can_see_behind(a.seat_index, seat)):
			out.append(a.id)
	return out


func tick(delta: float) -> void:
	if _done:
		return
	_step_t += delta
	var dur := step_time(step_name())
	var k := clampf(_step_t / maxf(dur, 0.001), 0.0, 1.0)
	_update_step(step_name(), k)
	_canvas.queue_redraw()
	if _step_t >= dur:
		_next_step()


func _next_step() -> void:
	_step += 1
	_step_t = 0.0
	_clear_ui()
	if _step >= _steps.size():
		_done = true
		finished.emit()
		return
	var vp := _vp()
	_mat.set_shader_parameter("size", vp)
	_set_fx(0.0, 0.0, 0.0, [])
	match step_name():
		"intro":
			AudioDirector.sfx("rewind_kyuru", -3.0)
			_set_fx(1.0, 1.0, 0.0, [])
			var title := _big_text(tr("そのとき後ろでは…"), 56, Color.WHITE)
			title.position = (vp - title.size) / 2.0
			var rw := _big_text("◀◀", 48, Color.WHITE)
			rw.position = Vector2((vp.x - rw.size.x) / 2.0, title.position.y - rw.size.y - 6.0)
		"walk":
			oni_walking = true
		"drop":
			pass
		"stamps":
			item_shown = true
		"spot":
			AudioDirector.sfx("jajaan", -3.0)
			for id in _liars:
				var p := _pill_above(id, tr("ウソつき!"), COLOR_LIE, Color.WHITE, 26)
				_pop_in(p)
		"nobody":
			AudioDirector.sfx("hyuu", -3.0)
			_wind_t = 0.0
			_set_fx(0.0, 0.0, 0.55, [[_loser, 1.0]])
			var t2 := _big_text(tr("だれも教えてくれなかった…"), 44, Color("D8E6F2"))
			# (まん中は「見てたのに…!」の札と重なるので、上のほうに出す)
			t2.position = Vector2((vp.x - t2.size.x) / 2.0, 70.0)
			_placed.append(Rect2(t2.position, t2.size))
			_pop_in(t2)
			for id in watchers(_state, _loser):
				var p2 := _pill_above(id, tr("見てたのに…!"), Color("6B5B95"), Color.WHITE, 20)
				_pop_in(p2)
		"honest":
			AudioDirector.sfx("honest", -4.0)
			var t := _big_text(tr("みんな正直だった!"), 50, Color("FFD24A"))
			t.position = (vp - t.size) / 2.0
			_pop_in(t)
		"score":
			oni_walking = false
			var gains: Dictionary = _res.get("round_gains", {})
			var any := false
			for id in gains:
				var g: int = int(gains[id])
				if g == 0 or not _nodes.has(int(id)):
					continue
				var a := _state.get_actor(int(id))
				var col: Color = a.color if a else Color.WHITE
				var p := _pill_above(int(id), "%s %+d" % [_short(int(id)), g], col, Hud.text_color_on(col), 24)
				_pop_in(p)
				any = true
			if any:
				AudioDirector.sfx("replay_pon", -4.0, 1.2)


func _update_step(step_id: String, k: float) -> void:
	match step_id:
		"intro":
			# 今の場所から、足取りの始まりまで逆回りにもどる
			oni_angle = lerpf(_a_from, _a_start, k * k * (3.0 - 2.0 * k))
		"walk":
			_set_angle(lerpf(_a_start, _a_drop - 0.06, k))
			_bar = BAR_DROP * 0.9 * k
		"drop":
			var slow := GameConfig.REPLAY_DROP_SLOW
			if k < slow:
				# スローで落とす瞬間へ
				var s := k / slow
				_set_angle(lerpf(_a_drop - 0.06, _a_drop, 1.0 - (1.0 - s) * (1.0 - s)))
				_bar = lerpf(BAR_DROP * 0.9, BAR_DROP, s)
				oni_walking = true
			elif not item_shown:
				# 落とした! 一時停止
				_set_angle(_a_drop)
				_bar = BAR_DROP
				oni_walking = false
				item_shown = true
				_ring_t = 0.0
				AudioDirector.sfx("replay_don", -8.0, 1.4)
				var vp := _vp()
				var lab := _pill_at(_screen(_drop_pos + Vector3(0, 0.2, 0)) - Vector2(0, 70), tr("ここで落とした!"), COLOR_LIE, Color.WHITE, 26)
				_pop_in(lab)
				var pause := _make_pill("❚❚ " + tr("一時停止"), GameConfig.COLOR_INK, Color.WHITE, 20)
				pause.position = Vector2(vp.x - pause.size.x - UiStyle.SAFE, 70)
				# 落とされた人以外は少し暗く
				_set_fx(0.0, 0.0, 0.45, [[_loser, 1.0], [-1, 0.8]])
			if _ring_t >= 0.0:
				_ring_t += get_process_delta_time()
		"stamps":
			var n := _stamps.size()
			_bar = lerpf(BAR_DROP, 1.0, k)
			var want := mini(n, int(floor(k * n)) + 1)
			while _shown.size() < want:
				_show_stamp(_stamps[_shown.size()])
		"nobody":
			_wind_t += get_process_delta_time()
		"spot":
			var holes := []
			for id in _liars:
				holes.append([id, 1.0])
			_set_fx(0.0, 0.0, 0.6, holes)


func _set_angle(a: float) -> void:
	var prev := _ring(oni_angle)
	oni_angle = a
	var now := _ring(a)
	_walked += prev.distance_to(now)
	if _walked >= 0.32:
		_walked = 0.0
		# 足あと: 歩く向きの左右に交互に
		var dir := Vector3(cos(a), 0.0, -sin(a))
		var side := dir.cross(Vector3.UP).normalized() * (0.09 if _feet.size() % 2 == 0 else -0.09)
		_feet.append(now + side)


func _ring(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, cos(a)) * GameConfig.ONI_WALK_RADIUS


## 届いたスタンプを1つ出す: 送った人から落とされた人へ線、送った人の上に吹き出し、ハンコ
func _show_stamp(st: Dictionary) -> void:
	var sender: int = int(st["sender"])
	var truthful: bool = bool(st.get("truthful", true))
	var a := _state.get_actor(sender)
	var col: Color = a.color if a else Color.WHITE
	var text := "%s:%s" % [_name(sender), HeadOverlay.stamp_text(_state, sender, str(st["kind"]))]
	var bubble := _make_pill(text, col, Hud.text_color_on(col), 20)
	var hanko := _make_hanko(truthful)
	var head := _screen(_body(sender) + Vector3(0, 0.75, 0))
	# 吹き出しの右上にハンコが少しはみ出すぶん、上に余白をとって置く
	var r := Rect2(head - Vector2(bubble.size.x / 2.0, bubble.size.y + 8.0), bubble.size + Vector2(hanko.size.x * 0.6, hanko.size.y * 0.5))
	r.position.y -= hanko.size.y * 0.5
	r = _fit(r)
	bubble.position = r.position + Vector2(0, hanko.size.y * 0.5)
	hanko.position = bubble.position + Vector2(bubble.size.x - hanko.size.x * 0.4, -hanko.size.y * 0.55)
	_shown.append({"from": sender, "truthful": truthful, "bubble": bubble})
	_stamp_in(hanko)
	AudioDirector.sfx("replay_pon" if truthful else "replay_don", -3.0)


func _make_hanko(truthful: bool) -> PanelContainer:
	var c := COLOR_TRUE if truthful else COLOR_LIE
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color.WHITE, false, 8, 4)
	st.border_color = c
	st.content_margin_left = 6
	st.content_margin_right = 6
	p.add_theme_stylebox_override("panel", st)
	var l := UiStyle.label(("○ " + tr("ほんと")) if truthful else ("× " + tr("ウソ")), 18, c)
	p.add_child(l)
	_ui.add_child(p)
	p.reset_size()
	p.size = p.get_combined_minimum_size()
	p.pivot_offset = p.size / 2.0
	p.rotation = -0.2
	return p


func _draw_canvas() -> void:
	var vp := _vp()
	# 足あと
	for f in _feet:
		if not _cam.is_position_behind(f):
			_canvas.draw_circle(_screen(f), 7.0, COLOR_FOOT)
	# 落とし物を丸で囲む(ドクンと大きくなってから落ちつく)
	if item_shown and step_name() == "drop":
		var c := _screen(_drop_pos)
		var pulse := 1.0 + 0.35 * exp(-maxf(_ring_t, 0.0) * 6.0)
		_canvas.draw_arc(c, 34.0 * pulse, 0.0, TAU, 40, COLOR_LIE, 5.0, true)
	# スタンプの線(ほんと: 緑・ウソ: 赤の点線)
	if step_name() == "stamps":
		var to := _screen(_body(_loser))
		for s in _shown:
			var from := _screen(_body(int(s["from"])))
			_canvas.draw_dashed_line(from, to, COLOR_TRUE if s["truthful"] else COLOR_LIE, 4.0, 10.0)
	# だれも教えてくれなかった: 落とされた人のまわりに、風のすじが横に流れる
	if step_name() == "nobody" and _wind_t >= 0.0:
		var c := _screen(_body(_loser))
		var r := vp.y * 0.16
		for i in 9:
			var y := c.y - r + (2.0 * r) * (float(i) + 0.5) / 9.0 + sin(_wind_t * 3.0 + i) * 6.0
			var phase := fposmod(_wind_t * 1.4 + float(i) * 0.37, 1.0)
			var x := c.x - r * 1.8 + phase * r * 3.6
			var ln := r * (0.35 + 0.25 * sin(float(i) * 1.7))
			var a := sin(phase * PI) * 0.8
			var col := Color(0.92, 0.96, 1.0, a)
			_canvas.draw_line(Vector2(x, y), Vector2(x + ln, y - ln * 0.08), col, 3.0, true)
			# くるっと巻く小さな渦
			if i % 3 == 0:
				_canvas.draw_arc(Vector2(x + ln, y - ln * 0.08 - 6.0), 6.0, PI * 0.5, PI * 2.0, 10, col, 2.5, true)
	# 時間のバー(鬼の足取り → 落とした瞬間の印 → スタンプが届いた時間)
	if step_name() in ["walk", "drop", "stamps"]:
		var w := minf(vp.x * 0.6, 640.0)
		var rect := Rect2(Vector2((vp.x - w) / 2.0, vp.y - 40.0), Vector2(w, 16.0))
		_canvas.draw_rect(rect.grow(3.0), GameConfig.COLOR_INK)
		_canvas.draw_rect(rect, Color.WHITE)
		_canvas.draw_rect(Rect2(rect.position, Vector2(w * _bar, rect.size.y)), COLOR_LIE)
		var mx := rect.position.x + w * BAR_DROP
		_canvas.draw_line(Vector2(mx, rect.position.y - 8.0), Vector2(mx, rect.end.y + 8.0), GameConfig.COLOR_INK, 4.0)


## 画面の効果: セピア・走査線・暗さと、明るく残す丸(holes: [[人の id(-1 は落とし物), 大きさ], ...])
func _set_fx(sepia: float, scan: float, dim: float, holes: Array) -> void:
	_fx.visible = sepia > 0.0 or scan > 0.0 or dim > 0.0
	_mat.set_shader_parameter("sepia", sepia)
	_mat.set_shader_parameter("scan", scan)
	_mat.set_shader_parameter("dim", dim)
	var list := PackedVector3Array()
	var r := _vp().y * 0.12
	for h in holes:
		if list.size() >= 8:
			break
		var id: int = h[0]
		var p := _screen(_drop_pos) if id < 0 else _screen(_body(id))
		list.append(Vector3(p.x, p.y, r * float(h[1])))
	while list.size() < 8:
		list.append(Vector3.ZERO)
	_mat.set_shader_parameter("hole_count", mini(holes.size(), 8))
	_mat.set_shader_parameter("holes", list)


func _body(id: int) -> Vector3:
	var n: Node3D = _nodes.get(id)
	return (n.global_position if n else Vector3.ZERO) + Vector3(0, 0.8, 0)


func _screen(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _name(id: int) -> String:
	if id == _state.local_player_id:
		return tr("あなた")
	if id == _oni:
		return tr("鬼")
	var a := _state.get_actor(id)
	return Locale.actor_name(a.display_name) if a else "?"


func _short(id: int) -> String:
	return _name(id)


func _clear_ui() -> void:
	for c in _ui.get_children():
		c.queue_free()
	_placed.clear()
	_shown.clear()


func _make_pill(text: String, bg: Color, fg: Color, font_size: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.box(bg, true, 14, 3))
	p.add_child(UiStyle.label(text, font_size, fg))
	_ui.add_child(p)
	p.reset_size()
	p.size = p.get_combined_minimum_size()
	p.pivot_offset = p.size / 2.0
	return p


func _big_text(text: String, font_size: int, color: Color) -> Label:
	var l := UiStyle.label(text, font_size, color)
	l.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	l.add_theme_constant_override("outline_size", 14)
	_ui.add_child(l)
	l.reset_size()
	l.size = l.get_combined_minimum_size()
	l.pivot_offset = l.size / 2.0
	return l


func _pill_above(id: int, text: String, bg: Color, fg: Color, font_size: int) -> PanelContainer:
	var head := _screen(_body(id) + Vector3(0, 0.75, 0))
	return _pill_at(head - Vector2(0, 8), text, bg, fg, font_size)


## 下のまん中が pos に来るように札を出す(画面の外や、ほかの札と重ならないように)
func _pill_at(pos: Vector2, text: String, bg: Color, fg: Color, font_size: int) -> PanelContainer:
	var p := _make_pill(text, bg, fg, font_size)
	var r := _fit(Rect2(pos - Vector2(p.size.x / 2.0, p.size.y), p.size))
	p.position = r.position
	return p


func _fit(r: Rect2) -> Rect2:
	var vp := _vp()
	r.position.x = clampf(r.position.x, UiStyle.SAFE, vp.x - UiStyle.SAFE - r.size.x)
	r.position.y = clampf(r.position.y, 60.0, vp.y - r.size.y - 60.0)
	for k in 8:
		var hit := false
		for q in _placed:
			if q.grow(3.0).intersects(r):
				var up := q.position.y - r.size.y - 4.0
				r.position.y = up if up >= 60.0 else q.end.y + 4.0
				hit = true
		if not hit:
			break
	_placed.append(r)
	return r


func _pop_in(c: Control) -> void:
	c.scale = Vector2(0.3, 0.3)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## ハンコ: 大きく浮いてから、ドンと押す
func _stamp_in(c: Control) -> void:
	c.scale = Vector2(2.2, 2.2)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 1.0, 0.1)
