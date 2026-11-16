class_name VoteReveal
extends CanvasLayer
## 手下を当てる投票の発表(教室のまま。みんなの画面で同じ流れ)。秒数は GameConfig の REVEAL_*。
## 1. 票が飛ぶ: 「ドン!」で、投票した人から選んだ人へ、その人の色の矢印を一斉に。票を集めた人の頭の上に、票の数だけ指マーク
##    (矢印と指マークは、発表のあとも次のラウンドまで残す)
## 2. ため: 画面を少し暗くしてドラムロール
## 3. 発表: 手下だった人にスポットライト。名札を紫に「手下」。「ジャジャーン!」。手下はニヤッと笑う
##    (投票した全員が当てた手下は放心顔で「バレバレ!」、1票も入らなかった手下は「だましきった!」)
## 4. 点数: 手下に投票した人に「+1」。1票も入らなかった手下に「+1 だましきった!」
## このあと、ルールを動かす人が次のラウンドへ進める(GameState.reveal_left)。見た目だけ(状態は変えない)。

const DIM_SHADER := """
shader_type canvas_item;
uniform float dim = 0.0;
uniform vec2 size = vec2(1.0);
uniform int hole_count = 0;
uniform vec3 holes[4];
void fragment() {
	vec2 px = UV * size;
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= hole_count) { break; }
		float d = distance(px, holes[i].xy);
		lit = max(lit, 1.0 - smoothstep(holes[i].z * 0.6, holes[i].z, d));
	}
	COLOR = vec4(0.02, 0.02, 0.06, dim * (1.0 - lit));
}
"""

const COLOR_PURPLE := Color(0.55, 0.2, 0.7)
const COLOR_GOOD := Color("2E9E5B")

var _state: GameState
var _view: WorldView
var _overlay: HeadOverlay
var _votes: Dictionary = {}
var _tally: Dictionary = {}
var _minions: Array = []
var _fooled: Array = []
var _busted: Array = []
var _correct: Array = []
var _t := 0.0
var _step := -1
var _fx: ColorRect
var _mat: ShaderMaterial
var _canvas: Control
var _ui: Control
var _placed: Array[Rect2] = []


func setup(state: GameState, e: Dictionary, view: WorldView, overlay: HeadOverlay) -> void:
	layer = 2
	_state = state
	_view = view
	_overlay = overlay
	_votes = e.get("votes", {})
	_tally = e.get("tally", {})
	_minions = e.get("minions", [])
	_fooled = e.get("fooled", [])
	_busted = e.get("busted", [])
	_correct = e.get("correct", [])
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DIM_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_fx.material = _mat
	_fx.visible = false
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


func _exit_tree() -> void:
	# 次のラウンドへ進んだ: 名札と表情を元に戻す
	if _overlay and is_instance_valid(_overlay):
		_overlay.set_revealed([])
	if _view and is_instance_valid(_view):
		_view.set_reveal_faces({})


func _process(delta: float) -> void:
	_t += delta
	var marks := [0.0, GameConfig.REVEAL_ARROWS_TIME,
			GameConfig.REVEAL_ARROWS_TIME + GameConfig.REVEAL_DRUM_TIME,
			GameConfig.REVEAL_ARROWS_TIME + GameConfig.REVEAL_DRUM_TIME + GameConfig.REVEAL_SHOW_TIME]
	while _step + 1 < marks.size() and _t >= marks[_step + 1]:
		_step += 1
		_enter(_step)
	_update_fx()
	_canvas.queue_redraw()


func _enter(step: int) -> void:
	match step:
		0:
			# 1. 票が飛ぶ
			AudioDirector.sfx("vote_don", -2.0)
		1:
			# 2. ため
			AudioDirector.sfx("drumroll", -5.0)
		2:
			# 3. 発表
			AudioDirector.sfx("jajaan", -3.0)
			_overlay.set_revealed(_minions)
			var faces := {}
			for m in _minions:
				faces[m] = "dazed" if m in _busted else "smirk"
			_view.set_reveal_faces(faces)
			for m in _minions:
				var label := tr("手下!")
				if m in _busted:
					label = tr("バレバレ!")
				elif m in _fooled:
					label = tr("だましきった!")
				_pop(_pill_above(int(m), label, COLOR_PURPLE, Color.WHITE, 26, 2.3))
		3:
			# 4. 点数
			var any := false
			for id in _correct:
				_pop(_pill_above(int(id), "+%d" % GameConfig.SCORE_VOTE_CORRECT, COLOR_GOOD, Color.WHITE, 26, 2.3))
				any = true
			for m in _fooled:
				_pop(_pill_above(int(m), "+%d " % GameConfig.SCORE_MINION_FOOLED + tr("だましきった!"), COLOR_PURPLE, Color.WHITE, 24, 2.3))
				any = true
			if any:
				AudioDirector.sfx("vote_pon", -4.0)


## 画面の暗さ: ためで少し暗く、発表では手下だけ明るく(スポットライト)
func _update_fx() -> void:
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("size", vp)
	var dim := 0.0
	var holes := PackedVector3Array()
	if _step == 1:
		dim = 0.35 * clampf((_t - GameConfig.REVEAL_ARROWS_TIME) / 0.2, 0.0, 1.0)
	elif _step >= 2:
		dim = 0.55
		for m in _minions:
			if holes.size() < 4:
				var p := _screen(int(m), 0.9)
				holes.append(Vector3(p.x, p.y, vp.y * 0.16))
	_fx.visible = dim > 0.0
	while holes.size() < 4:
		holes.append(Vector3.ZERO)
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("hole_count", mini(_minions.size(), 4) if _step >= 2 else 0)
	_mat.set_shader_parameter("holes", holes)


func _draw_canvas() -> void:
	if _step < 0:
		return
	var vp := get_viewport().get_visible_rect().size
	var line := maxf(5.0, vp.y * 0.009)
	# 矢印: 飛んでいく(0.25秒で伸びる)。手下の発表のあとも、だれがだれに入れたか見えるように残す
	if _step >= 0:
		var grow := clampf(_t / 0.25, 0.0, 1.0)
		for voter in _votes:
			var a := _state.get_actor(int(voter))
			var col: Color = a.color if a else Color.WHITE
			var from := _screen(int(voter), 0.9)
			var to := _screen(int(_votes[voter]), 1.0)
			var tip := from.lerp(to, grow * 0.86)
			_canvas.draw_line(from, tip, GameConfig.COLOR_INK, line + 4.0, true)
			_canvas.draw_line(from, tip, col, line, true)
			var dir := (tip - from).normalized()
			var side := Vector2(-dir.y, dir.x)
			var head := PackedVector2Array([tip + dir * 18.0, tip - dir * 6.0 + side * 13.0, tip - dir * 6.0 - side * 13.0])
			_canvas.draw_colored_polygon(head, col)
			_canvas.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), GameConfig.COLOR_INK, 3.0, true)
	# 指マーク: 票を集めた人の頭の上に、票の数だけ重ねる
	var pop := clampf((_t - 0.15) / 0.2, 0.0, 1.0)
	for id in _tally:
		var n := int(_tally[id])
		var top := _screen(int(id), 1.55)
		for k in n:
			var c := top + Vector2((float(k) - float(n - 1) / 2.0) * 16.0, -float(k) * 10.0)
			_draw_finger(c, pop)


## 下を指す指(手の甲の丸と、人さし指)
func _draw_finger(c: Vector2, s: float) -> void:
	if s <= 0.0:
		return
	var ink := GameConfig.COLOR_INK
	var skin := Color("FFE0BD")
	var r := 13.0 * s
	var finger := Rect2(c + Vector2(-4.5, 4.0) * s, Vector2(9.0, 18.0) * s)
	_canvas.draw_rect(finger.grow(3.0), ink)
	_canvas.draw_circle(c, r + 3.0, ink)
	_canvas.draw_circle(c, r, skin)
	_canvas.draw_rect(finger, skin)


func _screen(id: int, height: float) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var p := _view.actor_point(id, height)
	if cam == null or cam.is_position_behind(p):
		return Vector2(-1000, -1000)
	return cam.unproject_position(p)


func _pill_above(id: int, text: String, bg: Color, fg: Color, font_size: int, height: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.box(bg, true, 14, 3))
	p.add_child(UiStyle.label(text, font_size, fg))
	_ui.add_child(p)
	p.reset_size()
	p.size = p.get_combined_minimum_size()
	p.pivot_offset = p.size / 2.0
	var pos := _screen(id, height)
	var vp := get_viewport().get_visible_rect().size
	var r := Rect2(pos - Vector2(p.size.x / 2.0, p.size.y), p.size)
	r.position.x = clampf(r.position.x, UiStyle.SAFE, vp.x - UiStyle.SAFE - r.size.x)
	r.position.y = clampf(r.position.y, 60.0, vp.y - r.size.y - 20.0)
	for k in 8:
		var hit := false
		for q in _placed:
			if q.grow(3.0).intersects(r):
				r.position.y = q.position.y - r.size.y - 4.0
				hit = true
		if not hit:
			break
	_placed.append(r)
	p.position = r.position
	return p


func _pop(c: Control) -> void:
	c.scale = Vector2(0.3, 0.3)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
