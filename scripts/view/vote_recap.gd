class_name VoteRecap
extends Node
## 投票の前の「振り返り」(6〜8秒。タップで早送り)。みんなの画面で同じ流れ(見た目だけ。投票はうしろで始まっている)。
## 1. 「鬼の手下は誰?」を大きく
## 2. 「さっきの場面を思い出してみよう…」。画面(3D だけ)が少しセピア色になる
## 3. カメラが落とされた人に寄る →「dogのうしろに ハンカチ が落ちていた!」→ 頭の上に、届いていた言葉が1つずつポン、ポン、ポン
## 4. お手つきの人がいれば、その人へ →「catが振り向いたけど、何もなかった…」→ ガーン顔のマークと、届いていた言葉が1つずつ
## 5. カメラが引いて全員が見える位置に戻り、セピア色が元に戻る →「あやしい人をタップして投票!」
## 終わったら finished。投票中も、言葉・落とし物の▼・お手つきのマークは出したまま。

signal finished

const TITLE_TIME := 1.0
const INTRO_TIME := 1.1
## 1人あたり: カメラが寄ってから文字が出るまで / 言葉の間かく / 言葉のあとの間
const FOCUS_LEAD := 0.5
const POP_GAP := 0.38
const FOCUS_TAIL := 0.5
const OUTRO_TIME := 0.9

var _state: GameState
var _view: WorldView
var _hud: Hud
var _overlay: HeadOverlay
var _t := 0.0
var _done := false
## 場面の予定: [{"at", "kind": "title"|"intro"|"focus"|"caption"|"pop"|"mark"|"item"|"outro"|"end", ...}]
var _plan: Array = []
var _next := 0
## 言葉をいくつ見せたか(id -> 数)と、目印を見せたか
var _shown := {}
var _item_on := false
var _marks_on: Array = []
var _sepia_layer: CanvasLayer
var _sepia: ColorRect
var _sepia_amount := 0.0
var _sepia_want := 0.0

const SEPIA_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sep = vec3(g * 1.08 + 0.06, g * 0.96 + 0.03, g * 0.76);
	COLOR = vec4(mix(c, sep, amount * 0.85), 1.0);
}
"""


func setup(state: GameState, view: WorldView, hud: Hud) -> void:
	_state = state
	_view = view
	_hud = hud
	_overlay = view.get_overlay()
	# セピア色: 3D の上・名札や吹き出し(層 1)の下に重ねる(言葉の色はそのまま見えるように)
	_sepia_layer = CanvasLayer.new()
	_sepia_layer.layer = 0
	add_child(_sepia_layer)
	_sepia = ColorRect.new()
	_sepia.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sepia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SEPIA_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_sepia.material = mat
	_sepia.visible = false
	_sepia_layer.add_child(_sepia)
	_build_plan()
	_apply_reveal()


func is_running() -> bool:
	return not _done


func _build_plan() -> void:
	var t := 0.0
	_plan.append({"at": t, "kind": "title"})
	t += TITLE_TIME
	_plan.append({"at": t, "kind": "intro"})
	t += INTRO_TIME
	var ev := HeadOverlay.evidence_bubbles(_state)
	var dropped := _state.round_dropped_on
	if dropped >= 0:
		_plan.append({"at": t, "kind": "focus", "id": dropped})
		_plan.append({"at": t, "kind": "item"})
		t += FOCUS_LEAD
		_plan.append({"at": t, "kind": "caption", "text": tr("%sのうしろに %s が落ちていた!") % [HeadOverlay.evidence_name(_state, dropped), _state.item_name()]})
		for i in (ev.get(dropped, []) as Array).size():
			t += POP_GAP
			_plan.append({"at": t, "kind": "pop", "id": dropped, "n": i + 1})
		t += FOCUS_TAIL
	for id in _state.round_otetsuki:
		# (お手つきの人が何人いても、全体が長くなりすぎないように、2人目からは少し速く)
		var quick: bool = int(id) != int(_state.round_otetsuki[0])
		_plan.append({"at": t, "kind": "focus", "id": int(id)})
		t += FOCUS_LEAD * (0.6 if quick else 1.0)
		_plan.append({"at": t, "kind": "caption", "text": tr("%sが振り向いたけど、何もなかった…") % HeadOverlay.evidence_name(_state, int(id))})
		_plan.append({"at": t, "kind": "mark", "id": int(id)})
		for i in (ev.get(int(id), []) as Array).size():
			t += POP_GAP * (0.7 if quick else 1.0)
			_plan.append({"at": t, "kind": "pop", "id": int(id), "n": i + 1})
		t += FOCUS_TAIL * (0.6 if quick else 1.0)
	_plan.append({"at": t, "kind": "outro"})
	t += OUTRO_TIME
	_plan.append({"at": t, "kind": "end"})


## 全体の長さ(秒)
func total_time() -> float:
	return float(_plan[_plan.size() - 1]["at"]) if not _plan.is_empty() else 0.0


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	while _next < _plan.size() and float(_plan[_next]["at"]) <= _t:
		_run(_plan[_next], true)
		_next += 1
	_sepia_amount = move_toward(_sepia_amount, _sepia_want, delta / 0.4)
	_sepia.visible = _sepia_amount > 0.001
	(_sepia.material as ShaderMaterial).set_shader_parameter("amount", _sepia_amount)


func _run(step: Dictionary, with_sound: bool) -> void:
	match str(step["kind"]):
		"title":
			_hud.show_banner(tr("鬼の手下は誰?"), Color(0.55, 0.2, 0.7), TITLE_TIME + 0.2, 96)
			if with_sound:
				AudioDirector.sfx("vote_don", -6.0)
		"intro":
			_hud.set_caption(tr("さっきの場面を思い出してみよう…"))
			_sepia_want = 1.0
		"focus":
			_view.set_vote_focus(int(step["id"]))
		"caption":
			_hud.set_caption(str(step["text"]))
		"item":
			_item_on = true
			_apply_reveal()
		"mark":
			_marks_on.append(int(step["id"]))
			_apply_reveal()
			if with_sound:
				AudioDirector.sfx("gaan", -10.0)
		"pop":
			_shown[int(step["id"])] = int(step["n"])
			_apply_reveal()
			if with_sound:
				AudioDirector.sfx("vote_pon", -8.0, 1.0 + 0.08 * float(step["n"]))
		"outro":
			_view.set_vote_focus(-1)
			_sepia_want = 0.0
			_hud.set_caption(tr("あやしい人をタップして投票!"))
		"end":
			_finish()


func _apply_reveal() -> void:
	if _overlay:
		_overlay.set_evidence_reveal(false, _shown, _item_on, _marks_on)


## タップで早送り: のこりを全部すぐ出して終わる
func skip() -> void:
	if _done:
		return
	while _next < _plan.size():
		var st: Dictionary = _plan[_next]
		_next += 1
		if str(st["kind"]) == "end":
			break
		if str(st["kind"]) != "title":
			_run(st, false)
	_sepia_amount = 0.0
	_sepia_want = 0.0
	_sepia.visible = false
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_view.set_vote_focus(-1)
	if _overlay:
		_overlay.set_evidence_reveal(true)
	_hud.set_caption(tr("あやしい人をタップして投票!"), 1.6)
	finished.emit()


func _exit_tree() -> void:
	if not _done and _view and is_instance_valid(_view):
		_view.set_vote_focus(-1)
	if _overlay and is_instance_valid(_overlay):
		_overlay.set_evidence_reveal(true)
