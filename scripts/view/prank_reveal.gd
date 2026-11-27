class_name PrankReveal
extends CanvasLayer
## いたずらっ子のネタばらし(いたずらっ子のラウンドで、書き換えが1つ以上あったときだけ)。
## 投票の結果のあと「次へ」を押したら、順位の一覧の前に、みんなの画面で同じ流れ:
## 1. 大きく「いたずらっ子のしわざ!」。いたずらっ子が飛んできて「にしし」と笑う
## 2. 書き換え1つずつ(1つ GameConfig.PRANK_REVEAL_ITEM_TIME 秒):
##    カメラが送った人に寄る → 頭の上に大きな吹き出しで、送った言葉 → いたずらっ子が消しゴムで消して、
##    クレヨンでひっくり返した言葉を書く → 下に小さく「→ 〇〇に届いた」
## 3. いたずらっ子が飛んでいって終わり(finished)
## タップで次の書き換えへ。「スキップ」で全部とばす。

signal finished

var _state: GameState
var _view: WorldView
var _items: Array = []
var _t := 0.0
var _phase := "intro" # intro / item / outro / done
var _idx := -1
var _item_t := 0.0
var _imp: PrankImp
var _laugh: Label
var _bubble: PanelContainer
var _bubble_style: StyleBoxFlat
var _word: Label
var _to: Label
var _skip: Button
var _sound_step := 0
var _hud_ref: Hud

const INTRO_TIME := 1.3
const OUTRO_TIME := 0.5
const IMP_SIZE := 130.0


func setup(state: GameState, view: WorldView, hud: Hud) -> void:
	_state = state
	_hud_ref = hud
	_view = view
	layer = 3
	_items = state.prank_log.duplicate()
	_imp = PrankImp.new()
	_imp.size = Vector2(IMP_SIZE, IMP_SIZE)
	add_child(_imp)
	var vp := _vp()
	_imp.position = Vector2(vp.x + 40.0, vp.y * 0.18)
	_laugh = UiStyle.label(tr("にしし"), 40, Color("FF6B9A"))
	_laugh.add_theme_color_override("font_outline_color", Color.WHITE)
	_laugh.add_theme_constant_override("outline_size", 10)
	_laugh.visible = false
	add_child(_laugh)
	# 大きな吹き出し(送った人の頭の上)
	_bubble_style = UiStyle.box(Color.WHITE, true, 26, 6)
	_bubble_style.content_margin_left = 30
	_bubble_style.content_margin_right = 30
	_bubble_style.content_margin_top = 10
	_bubble_style.content_margin_bottom = 12
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", _bubble_style)
	_bubble.visible = false
	add_child(_bubble)
	_word = UiStyle.label("", GameConfig.PRANK_REVEAL_FONT, GameConfig.COLOR_INK)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_child(_word)
	_to = UiStyle.label("", 30, GameConfig.COLOR_INK)
	_to.add_theme_color_override("font_outline_color", Color.WHITE)
	_to.add_theme_constant_override("outline_size", 10)
	_to.visible = false
	add_child(_to)
	_skip = Button.new()
	_skip.text = tr("スキップ ▶▶")
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.button(_skip, false, 26, GameConfig.COLOR_INK)
	add_child(_skip)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.anchor_top = 1.0
	_skip.anchor_bottom = 1.0
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -UiStyle.SAFE
	_skip.offset_bottom = -UiStyle.SAFE
	if _hud_ref:
		_hud_ref.show_banner(tr("いたずらっ子のしわざ!"), Color("E5483B"), INTRO_TIME, 84)
	AudioDirector.sfx("prank_laugh", -4.0)


func _hud() -> Hud:
	return _hud_ref


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)


func is_running() -> bool:
	return _phase != "done"


## 全部で何秒くらいか(テスト・目安用)
func total_time() -> float:
	return INTRO_TIME + GameConfig.PRANK_REVEAL_ITEM_TIME * _items.size() + OUTRO_TIME


func _process(delta: float) -> void:
	if _phase == "done":
		return
	_t += delta
	var vp := _vp()
	match _phase:
		"intro":
			# 右から飛んできて、上のまん中で「にしし」
			var k := clampf(_t / 0.45, 0.0, 1.0)
			var goal := Vector2(vp.x * 0.5 - IMP_SIZE * 0.5, vp.y * 0.24)
			_imp.position = Vector2(vp.x + 40.0, vp.y * 0.1).lerp(goal, 1.0 - pow(1.0 - k, 3.0)) \
					+ Vector2(0, -sin(_t * 9.0) * 6.0 * k)
			_imp.grin = 1.0 + 0.3 * absf(sin(_t * 12.0))
			_laugh.visible = _t > 0.4
			_laugh.position = _imp.position + Vector2(IMP_SIZE * 0.85, IMP_SIZE * 0.15 + sin(_t * 14.0) * 4.0)
			if _t >= INTRO_TIME:
				_laugh.visible = false
				_next_item()
		"item":
			_item_t += delta
			_run_item(vp)
			if _item_t >= GameConfig.PRANK_REVEAL_ITEM_TIME:
				_next_item()
		"outro":
			_imp.tool = ""
			_imp.position += Vector2(900.0, -500.0) * delta
			_bubble.modulate.a = maxf(_bubble.modulate.a - delta * 4.0, 0.0)
			_to.modulate.a = _bubble.modulate.a
			if _t >= OUTRO_TIME:
				_finish()


func _next_item() -> void:
	_idx += 1
	if _idx >= _items.size():
		_phase = "outro"
		_t = 0.0
		_view.set_vote_focus(-1)
		return
	_phase = "item"
	_item_t = 0.0
	_sound_step = 0
	var it: Dictionary = _items[_idx]
	var sid := int(it["sender"])
	_view.set_vote_focus(sid)
	_word.text = HeadOverlay.stamp_text(_state, sid, str(it["orig"]))
	_word.add_theme_color_override("font_color", HeadOverlay.kind_color(str(it["orig"])))
	_word.visible_ratio = 1.0
	_bubble_style.border_color = HeadOverlay.kind_color(str(it["orig"]))
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble.reset_size()
	_to.text = tr("→ %sに届いた") % HeadOverlay.evidence_name(_state, int(it["target"]))
	_to.visible = false
	_to.modulate.a = 1.0
	_to.reset_size()
	AudioDirector.sfx("vote_pon", -6.0)


## 1つの書き換え: 送った言葉 → 消しゴムで消す → クレヨンで書く → 「→ 〇〇に届いた」
func _run_item(vp: Vector2) -> void:
	var it: Dictionary = _items[_idx]
	var sid := int(it["sender"])
	var T := GameConfig.PRANK_REVEAL_ITEM_TIME
	var t_erase := T * 0.22
	var t_write := T * 0.45
	var t_to := T * 0.68
	# 吹き出しは送った人の頭の上(画面からはみ出さない)
	var head := vp * Vector2(0.5, 0.4)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := _view.actor_point(sid, 2.0)
		if not cam.is_position_behind(p):
			head = cam.unproject_position(p)
	var bs := _bubble.size
	var bp := Vector2(head.x - bs.x * 0.5, head.y - bs.y - 30.0)
	bp.x = clampf(bp.x, UiStyle.SAFE, vp.x - bs.x - UiStyle.SAFE)
	bp.y = clampf(bp.y, vp.y * 0.12, vp.y * 0.62 - bs.y)
	_bubble.position = _bubble.position.lerp(bp, 0.35) if _item_t > 0.05 else bp
	var pop := clampf(_item_t / 0.15, 0.0, 1.0)
	_bubble.pivot_offset = bs * 0.5
	_bubble.scale = Vector2.ONE * (0.3 + 0.7 * pop + 0.12 * sin(pop * PI))
	# いたずらっ子: 吹き出しの右上へ
	var spot := _bubble.position + Vector2(bs.x - IMP_SIZE * 0.25, -IMP_SIZE * 0.75)
	_imp.position = _imp.position.lerp(spot, 0.25)
	if _item_t < t_erase:
		_imp.tool = ""
	elif _item_t < t_write:
		# 消しゴムで消す(左から消えていく)
		_imp.tool = "eraser"
		if _sound_step == 0:
			_sound_step = 1
			AudioDirector.sfx("prank_erase", -4.0)
		var k := (_item_t - t_erase) / (t_write - t_erase)
		_word.visible_ratio = 1.0 - k
		_imp.position.x = _bubble.position.x + bs.x * (0.15 + 0.7 * k) - IMP_SIZE * 0.5
	else:
		# クレヨンで、ひっくり返した言葉を書く
		_imp.tool = "crayon"
		if _sound_step == 1:
			_sound_step = 2
			_word.text = HeadOverlay.stamp_text(_state, sid, str(it["flipped"]))
			_word.add_theme_color_override("font_color", HeadOverlay.kind_color(str(it["flipped"])))
			_bubble_style.border_color = HeadOverlay.kind_color(str(it["flipped"]))
			_bubble.reset_size()
			AudioDirector.sfx("prank_write", -4.0)
		var k := clampf((_item_t - t_write) / (t_to - t_write), 0.0, 1.0)
		_word.visible_ratio = k
		if k < 1.0:
			_imp.position.x = _bubble.position.x + bs.x * (0.15 + 0.7 * k) - IMP_SIZE * 0.5
	if _item_t >= t_to:
		_to.visible = true
		_to.position = Vector2(_bubble.position.x + (bs.x - _to.size.x) * 0.5, _bubble.position.y + bs.y + 8.0)


## タップ: 次の書き換えへ(前ふりの間なら、すぐ1つ目へ)
func advance() -> void:
	match _phase:
		"intro":
			_laugh.visible = false
			_next_item()
		"item":
			_next_item()


## スキップ: 全部とばす
func skip() -> void:
	if _phase == "done":
		return
	_finish()


func _input(event: InputEvent) -> void:
	if _phase == "done":
		return
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tap:
		return
	get_viewport().set_input_as_handled()
	if _skip.get_global_rect().grow(8.0).has_point(event.position):
		AudioDirector.click()
		skip()
	else:
		advance()


func _finish() -> void:
	if _phase == "done":
		return
	_phase = "done"
	if _view and is_instance_valid(_view):
		_view.set_vote_focus(-1)
	visible = false
	finished.emit()


func _exit_tree() -> void:
	if _phase != "done" and _view and is_instance_valid(_view):
		_view.set_vote_focus(-1)
