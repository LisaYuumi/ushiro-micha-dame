class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

## 自分に届いたスタンプのまわりに出す枠の太さ
const FRAME_WIDTH := 18.0

var _help: Label
var _message: Label
var _message_left := 0.0
## 自分に届いたスタンプ(左下の「あなたへ」の箱に、送り主つきで3つまで積む)
var _my_box: PanelContainer
## (送った人の色の吹き出しに「名前:言葉」)
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_labels: Array[Label] = []
## スタンプを送るときの、下のまん中の「◯◯に送る」と3つの言葉のボタン
var _send_panel: PanelContainer
var _send_title: Label
var _send_buttons: Array[Button] = []
## 前のフレームに出ていたスタンプ(新しく届いたものだけポンと飛び出させる)
var _shown_keys: Array = []
## 自分に届いたスタンプの間、画面のふちを光らせる枠
var _frame: Array[ColorRect] = []
var _frame_tween: Tween
## 役の表示(手下のとき)
var _badge: PanelContainer
## 左上の札: ラウンド(黒地)・いまの落とし物・鬼の周回など
var _round_pill: PanelContainer
var _item_pill: PanelContainer
## 自分の点数(自分にしか見えない)
var _score_pill: PanelContainer
var _extra_pill: PanelContainer
## ラウンドが終わったときの結果カード(全員の点数もここに出す。手下がばれないように、ふだんは出さない)
var _result_card: PanelContainer
var _next_button: Button
## 結果カードの右の、手下のカード(裏向き→タップで表)
var _minion_card: Control
var _card_front: Control
var _card_back: Control
var _flipping := false
## 手下を当てる投票: 得点の札(id -> {"panel", "style", "score", "delta", "col", "base"})・投票中か・自分が投票できるか・自分の投票・案内の札
signal vote_pressed(target_id: int)
var _chips := {}
var _vote_open := false
var _can_vote := false
var _my_vote := -1
var _card_hint_label: Label
## 役のお知らせカード(手下になったときなど)。しばらくすると消える
var _popup: PanelContainer
## 牛乳がかかったときの白い画面(いちばん下に置く。札やスタンプはその上に見える)
var _milk: Control
var _milk_on := false
var _milk_a := 0.0
## かかってからの時間(しずくがのびる動き)と、晴れるまでの残り(1 → 0)
var _milk_t := 0.0
var _milk_left := 1.0
## 追いかけっこで走っている間は、手で牛乳をぬぐって下のほうが見える(0 = ぬぐっていない、1 = ぬぐった)
var _milk_wipe := 0.0
var _milk_wiping := false
## 上のまん中の「(牛乳びん) 見えるまで ▭▭▭」の札と、その棒
var _milk_pill: PanelContainer
var _milk_bar: Control


func _ready() -> void:
	_milk = Control.new()
	_milk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_milk.draw.connect(_draw_milk)
	_milk.visible = false
	# 牛乳は 3D のすぐ上(層 0)に描く。名札の吹き出しやスタンプ、札はその上に見える
	var milk_layer := CanvasLayer.new()
	milk_layer.layer = 0
	add_child(milk_layer)
	milk_layer.add_child(_milk)
	_build_milk_pill()
	# 説明文は出さない(A案: 文字は札とボタンだけ)。古い呼び出しのために部品だけ残す
	_help = _make_label(22, GameConfig.COLOR_INK)
	_help.visible = false
	add_child(_help)
	_build_info_pills()

	# 画面中央の大きな文字(「お手つき!」など)
	_message = _make_label(72, Color.WHITE)
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_constant_override("outline_size", 16)
	_message.visible = false

	_build_stamp_display()


func _process(delta: float) -> void:
	# 牛乳: かかるとすぐ白く、終わるときはゆっくり晴れる
	var want := 1.0 if _milk_on else 0.0
	if _milk_a != want or (_milk_on and _milk.visible):
		_milk_a = move_toward(_milk_a, want, delta / (0.15 if _milk_on else 0.8))
		# 手でぬぐう: 0.5秒くらいで、牛乳が上へよけていく
		_milk_wipe = move_toward(_milk_wipe, 1.0 if _milk_wiping else 0.0, delta / 0.5)
		_milk_t = _milk_t + delta if _milk_on else _milk_t
		_milk.visible = _milk_a > 0.0
		_milk.modulate.a = _milk_a
		_milk.queue_redraw()
		_milk_pill.visible = _milk_on
		_milk_bar.queue_redraw()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false


## 説明文(いまは出さない)
func set_help(text: String) -> void:
	_help.text = text


## 左上の札(ラウンド・いまの落とし物・自分の点数)。extra が "" なら最後の札は出さない
func set_round_info(round_text: String, item_text: String, extra_text: String, score_text: String = "") -> void:
	_pill_text(_round_pill, round_text)
	_pill_text(_item_pill, item_text)
	_pill_text(_score_pill, score_text)
	_score_pill.visible = score_text != ""
	_pill_text(_extra_pill, extra_text)
	_extra_pill.visible = extra_text != ""


## 結果カードを出す。
## title: 大きい見出し / sub: その下の一言 / notes: 小さい札(がまん・手下の発表など)/ color: 見出しの色 /
## rows: [{"name", "color", "score", "delta", "me", "mark"}](この順に並べる)/ footer: いちばん下の案内
## next_label: 「次へ」ボタンの文字("" なら出さない。ホストとひとりのときだけ出す)
## rows の札に "id" があれば、投票のときにタップできる
## minion: {"people": [{"name", "color", "is_me", "bonus"}]}(手下が2人なら2つ)。あれば、左に得点表、右に裏向きの手下のカードを出す。
## 手下のカードをタップすると、そのカードだけ裏返って手下(キャラの絵と名前)が出る
## vote: {"open": 投票中か, "can_vote": 自分が投票できるか}。投票中は、得点の札をタップして手下だと思う人に投票する。
## 投票が終わるまでは、手下のカードはめくれない
func show_result_card(title: String, sub: String, notes: Array, color: Color, rows: Array, footer: String,
		next_label: String = "", minion: Dictionary = {}, vote: Dictionary = {}) -> void:
	hide_result_card()
	_vote_open = bool(vote.get("open", false))
	_can_vote = bool(vote.get("can_vote", false))
	_my_vote = -1
	_result_card = PanelContainer.new()
	_result_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 28, 5)
	st.shadow_offset = Vector2(6, 8)
	st.set_content_margin_all(32)
	_result_card.add_theme_stylebox_override("panel", st)
	add_child(_result_card)
	_result_card.custom_minimum_size = Vector2(600, 0)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 16)
	_result_card.add_child(col)
	var t := UiStyle.label(title, 54, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	t.add_theme_constant_override("outline_size", 10)
	col.add_child(t)
	if sub != "":
		var sl := UiStyle.label(sub, 26, GameConfig.COLOR_INK)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sl)
	if not notes.is_empty():
		var nrow := HFlowContainer.new()
		nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nrow.alignment = FlowContainer.ALIGNMENT_CENTER
		nrow.add_theme_constant_override("h_separation", 8)
		nrow.add_theme_constant_override("v_separation", 8)
		col.add_child(nrow)
		for n in notes:
			nrow.add_child(UiStyle.pill(str(n), 20))
	# 左に得点(大きい数字のカードを2段に並べる)、右に手下のカード(タップすると、そのカードだけ裏返る)
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 28)
	col.add_child(body)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = maxi(1, ceili(rows.size() / 2.0))
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for r in rows:
		grid.add_child(_score_chip(r))
	if not minion.is_empty():
		_build_minion_card(body, minion)
	_update_vote_hint()
	if footer != "":
		var f := UiStyle.label(footer, 20, GameConfig.COLOR_INK.lightened(0.35))
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(f)
	if next_label != "":
		var nb := Button.new()
		nb.text = next_label
		nb.custom_minimum_size = Vector2(0, 60)
		UiStyle.button(nb, true, 26)
		nb.pressed.connect(_press_next)
		col.add_child(nb)
		_next_button = nb
	# 画面のまん中に、ポンと出る
	UiStyle.center(_result_card)
	_result_card.pivot_offset = _result_card.size / 2.0
	_result_card.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_result_card, "scale", Vector2(1.06, 1.06), 0.14)
	tw.tween_property(_result_card, "scale", Vector2.ONE, 0.1)


## 役のお知らせカード: 色のふちの白いカードに、大きい見出し・小さい札・ひとこと。seconds 秒で消える
func show_popup_card(title: String, tags: Array, color: Color, hint: String, seconds: float) -> void:
	if _popup:
		_popup.queue_free()
	_popup = PanelContainer.new()
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 30, 6)
	st.border_color = color
	st.shadow_offset = Vector2(6, 8)
	st.content_margin_left = 56
	st.content_margin_right = 56
	st.content_margin_top = 36
	st.content_margin_bottom = 36
	_popup.add_theme_stylebox_override("panel", st)
	add_child(_popup)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 22)
	_popup.add_child(col)
	var t := UiStyle.label(title, 50, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	t.add_theme_constant_override("outline_size", 10)
	col.add_child(t)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	for tag in tags:
		var p := UiStyle.pill(str(tag), 26)
		var ps := p.get_theme_stylebox("panel") as StyleBoxFlat
		ps.bg_color = color.lightened(0.75)
		ps.content_margin_left = 22
		ps.content_margin_right = 22
		ps.content_margin_top = 8
		ps.content_margin_bottom = 10
		row.add_child(p)
	if hint != "":
		var h := UiStyle.label(hint, 22, GameConfig.COLOR_INK.lightened(0.3))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(h)
	UiStyle.center(_popup)
	_popup.position.y -= 60.0
	# ポンと出て、しばらくしたら小さくなって消える
	var card := _popup
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.15)
	tw.tween_property(card, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(seconds)
	tw.tween_property(card, "scale", Vector2(0.0, 0.0), 0.18)
	tw.tween_callback(func() -> void:
		if is_instance_valid(card):
			card.queue_free())


func hide_result_card() -> void:
	if _result_card:
		_result_card.queue_free()
		_result_card = null
		_next_button = null
		_minion_card = null
		_card_front = null
		_card_back = null
		_flipping = false
	_chips.clear()
	_vote_open = false
	_card_hint_label = null


## 手下のカード: 裏(紫に「手下はだれ?」と「?」)と表(左にキャラの絵、右に名前)。タップで裏返る
func _build_minion_card(parent: Container, minion: Dictionary) -> void:
	var purple := Color(0.55, 0.2, 0.7)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var people: Array = minion.get("people", [])
	var two := people.size() >= 2
	holder.custom_minimum_size = Vector2(420 if two else 360, 250)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(holder)
	_minion_card = holder

	# 裏向き
	var back := PanelContainer.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bst := UiStyle.box(purple, true, 22, 4)
	bst.set_content_margin_all(14)
	back.add_theme_stylebox_override("panel", bst)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(back)
	var bcol := VBoxContainer.new()
	bcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bcol.alignment = BoxContainer.ALIGNMENT_CENTER
	back.add_child(bcol)
	var q1 := UiStyle.label("手下はだれ?", 26, Color.WHITE)
	q1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bcol.add_child(q1)
	var q2 := UiStyle.label("?", 60, Color.WHITE)
	q2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bcol.add_child(q2)
	var hint := UiStyle.pill("タップでめくってね", 18)
	(hint.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("F2E6FA")
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bcol.add_child(hint)
	_card_hint_label = hint.get_child(0) as Label
	_card_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "scale", Vector2(1.06, 1.06), 0.45)
	tw.tween_property(hint, "scale", Vector2.ONE, 0.45)
	_card_back = back

	# 表: 左にキャラの絵、右に名前
	var front := PanelContainer.new()
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fst := UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4)
	fst.border_color = purple
	fst.set_content_margin_all(12)
	front.add_theme_stylebox_override("panel", fst)
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.visible = false
	holder.add_child(front)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	front.add_child(row)
	for p in people:
		var pic := MinionPortrait.new(p["color"])
		if two:
			pic.custom_minimum_size = Vector2(100, 190)
		row.add_child(pic)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4 if two else 6)
	row.add_child(info)
	info.add_child(UiStyle.label("鬼の手下は…", 20 if two else 22, GameConfig.COLOR_INK.lightened(0.3)))
	var any_bonus := false
	for p in people:
		var nm := UiStyle.label("あなた!" if p["is_me"] else "%s!" % p["name"], 26 if two else 38, purple)
		nm.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
		nm.add_theme_constant_override("outline_size", 8)
		info.add_child(nm)
		any_bonus = any_bonus or bool(p["bonus"])
	info.add_child(UiStyle.label("2人だったよ!" if two else "だったよ!", 22 if two else 24, GameConfig.COLOR_INK))
	if any_bonus:
		var bp := UiStyle.pill(tr("鬼がかって +%d点") % GameConfig.SCORE_MINION_ONI_WIN, 18)
		(bp.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = purple.lightened(0.75)
		info.add_child(bp)
	_card_front = front


## 手下のカードだけを、くるっと裏返す(横につぶれて、表と裏を入れかえて、また広がる)
func _flip_minion_card() -> void:
	# 投票が終わるまでは、めくれない
	if _flipping or _minion_card == null or _vote_open:
		return
	_flipping = true
	# 鬼の手下の正体発表「ジャジャーン」
	AudioDirector.sfx("reveal", -3.0)
	var card := _minion_card
	card.pivot_offset = card.size / 2.0
	var tw := create_tween()
	tw.tween_property(card, "scale:x", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(card) or _card_front == null:
			return
		var show_front := not _card_front.visible
		_card_front.visible = show_front
		_card_back.visible = not show_front)
	tw.tween_property(card, "scale:x", 1.0, 0.15)
	tw.tween_callback(func() -> void: _flipping = false)


## 紙吹雪(自分が勝ったとき)。画面の上から、色とりどりの紙がひらひら落ちる
func confetti() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 110
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


## 結果カードの大きさが変わったら、まん中に置き直す
func _recenter_result() -> void:
	if _result_card:
		var keep := _result_card.scale
		UiStyle.center(_result_card)
		_result_card.scale = keep


## 結果カードの「次へ」: キーボードの R と同じ操作を送る
func _press_next() -> void:
	AudioDirector.click()
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "restart"
		ev.pressed = pressed
		Input.parse_input_event(ev)


## スマホの指(と PC のクリック): 結果カードの「次へ」を押す/手下のカードをタップして裏返す
func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tap:
		return
	var pos: Vector2 = event.position
	if _next_button and _next_button.is_visible_in_tree() and _next_button.get_global_rect().has_point(pos):
		if event is InputEventScreenTouch:
			_press_next()
			get_viewport().set_input_as_handled()
		return
	# 投票中: 得点の札をタップすると、その人に投票する
	if _vote_open and _can_vote and _my_vote < 0:
		for id in _chips:
			if (_chips[id]["panel"] as Control).get_global_rect().has_point(pos):
				AudioDirector.click()
				vote_pressed.emit(int(id))
				get_viewport().set_input_as_handled()
				return
	# 手下のカードをタップしたら裏返す
	if _minion_card and _minion_card.get_global_rect().has_point(pos):
		_flip_minion_card()
		get_viewport().set_input_as_handled()


## 得点のカード: 上に色の丸と名前(小さく)、まん中に点数(大きく)、下にこのラウンドで増えた分
func _score_chip(r: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color("FFF6D8") if r["me"] else GameConfig.COLOR_PAPER, true, 16, 3)
	st.border_color = GameConfig.COLOR_ACCENT if r["me"] else GameConfig.COLOR_INK
	st.shadow_offset = Vector2(3, 4)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(128, 104)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 5)
	col.add_child(top)
	top.add_child(UiStyle.dot(r["color"], 16))
	var n := UiStyle.label(r["name"], 17, GameConfig.COLOR_INK)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(88, 0)
	top.add_child(n)
	var mark: String = r.get("mark", "")
	if mark != "":
		var mk := UiStyle.label(mark, 17, GameConfig.COLOR_ACCENT.darkened(0.2))
		mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(mk)
	var sc := UiStyle.label(tr("%d点") % r["score"], 36, GameConfig.COLOR_INK)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sc)
	var d: int = r.get("delta", 0)
	var dl := UiStyle.label(("%+d" % d) if d != 0 else " ", 18, Color("2E9E5B") if d > 0 else Color("D9483B"))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dl)
	if r.has("id"):
		_chips[int(r["id"])] = {"panel": panel, "style": st, "score": sc, "delta": dl, "col": col, "base": r}
	return panel


## 投票の案内: 手下のカードの裏の札に出す
func _update_vote_hint() -> void:
	if _card_hint_label == null or not is_instance_valid(_card_hint_label):
		return
	if _vote_open:
		if _can_vote and _my_vote < 0:
			_card_hint_label.text = tr("手下だと思う人の札をタップ!\n当たれば +%d点") % GameConfig.SCORE_VOTE_CORRECT
		elif _can_vote:
			_card_hint_label.text = tr("投票した!\nみんなを待っています")
		else:
			_card_hint_label.text = tr("みんなが手下を\n当てています…")
	else:
		_card_hint_label.text = tr("タップでめくってね")
	_recenter_result()


## 投票中か(main が、押された札を命令にするかを決めるのに使う)
func is_vote_open() -> bool:
	return _vote_open


## 自分が投票した: その人の札に「投票」の印をつける
func mark_my_vote(target_id: int) -> void:
	_my_vote = target_id
	if _chips.has(target_id):
		var st: StyleBoxFlat = _chips[target_id]["style"]
		st.border_color = Color(0.55, 0.2, 0.7)
		st.set_border_width_all(6)
		var tag := UiStyle.pill("投票", 16)
		(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("F2E6FA")
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		(_chips[target_id]["col"] as VBoxContainer).add_child(tag)
	_update_vote_hint()


## 投票の発表: 当てた人の札に「当たり +2」、点数を新しくする。手下のカードがめくれるようになる
func apply_vote_result(correct: Array, scores: Dictionary) -> void:
	if not _vote_open and _chips.is_empty():
		return
	_vote_open = false
	for id in _chips:
		var c: Dictionary = _chips[id]
		if scores.has(id):
			(c["score"] as Label).text = tr("%d点") % int(scores[id])
		if id in correct:
			var base: Dictionary = c["base"]
			var dl: Label = c["delta"]
			dl.text = "%+d" % (int(base.get("delta", 0)) + GameConfig.SCORE_VOTE_CORRECT)
			dl.add_theme_color_override("font_color", Color("2E9E5B"))
			var tag := UiStyle.pill(tr("当たり +%d") % GameConfig.SCORE_VOTE_CORRECT, 16)
			(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("DDF5E4")
			tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			(c["col"] as VBoxContainer).add_child(tag)
	_update_vote_hint()


func _score_row(r: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color("FFF6D8") if r["me"] else GameConfig.COLOR_PAPER, false, 12, 3)
	st.border_color = GameConfig.COLOR_ACCENT if r["me"] else GameConfig.COLOR_INK
	st.content_margin_top = 1
	st.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(260, 0)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)
	var mark: String = r.get("mark", "")
	if mark != "":
		h.add_child(UiStyle.label(mark, 18, GameConfig.COLOR_ACCENT.darkened(0.2)))
	h.add_child(UiStyle.dot(r["color"], 20))
	var n := UiStyle.label(r["name"], 18, GameConfig.COLOR_INK)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	var d: int = r.get("delta", 0)
	if d != 0:
		var dl := UiStyle.label("%+d" % d, 16, Color("2E9E5B") if d > 0 else Color("D9483B"))
		h.add_child(dl)
	h.add_child(UiStyle.label(tr("%d点") % r["score"], 18, GameConfig.COLOR_INK))
	return panel


func _pill_text(p: PanelContainer, text: String) -> void:
	(p.get_child(0) as Label).text = text


func _build_info_pills() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(UiStyle.SAFE, 14)
	add_child(row)
	_round_pill = UiStyle.pill("ラウンド 1/5", 24, true)
	_item_pill = UiStyle.pill("いまの落とし物:ハンカチ", 24)
	_extra_pill = UiStyle.pill("", 24)
	_score_pill = UiStyle.pill("", 24)
	row.add_child(_round_pill)
	row.add_child(_item_pill)
	row.add_child(_score_pill)
	row.add_child(_extra_pill)


## 画面中央に大きく表示する。seconds 秒で消える(0 なら消さない)。
func show_message(text: String, outline: Color, seconds: float) -> void:
	_message.text = text
	_message.add_theme_color_override("font_outline_color", outline)
	_message.visible = true
	_message_left = seconds if seconds > 0.0 else INF


func hide_message() -> void:
	_message.visible = false
	_message_left = 0.0
	hide_result_card()


## 自分に届いているスタンプを並べる。list: [{"kind", "sender", "sender_color"}](届いた順)。
## 送った人の色の吹き出しに「名前:言葉」
func show_my_stamps(list: Array) -> void:
	var keys := []
	for i in _slots.size():
		var box := _slots[i]
		if i >= list.size():
			box.visible = false
			continue
		var st: Dictionary = list[i]
		var key := "%s|%s" % [st["sender"], st["kind"]]
		keys.append(key)
		var col: Color = st["sender_color"]
		_slot_styles[i].bg_color = col
		_slot_labels[i].text = "%s:%s" % [st["sender"], st.get("text", Texts.stamp(st["kind"]))]
		_slot_labels[i].add_theme_color_override("font_color", text_color_on(col))
		box.visible = true
		if not (key in _shown_keys):
			# 新しく届いた: ポンと大きくなってから元の大きさへ
			box.pivot_offset = Vector2(0, 28) # 左の端からポンと出る
			box.scale = Vector2(0.3, 0.3)
			var tw := create_tween()
			tw.tween_property(box, "scale", Vector2(1.12, 1.12), 0.12)
			tw.tween_property(box, "scale", Vector2.ONE, 0.1)
	# 届いた分だけ出す(1つもなければ箱ごと消す)
	_my_box.visible = not list.is_empty()
	# 出ていたスタンプが全部消えたら、ふちの光も消す
	# (参加者の画面では、届いたお知らせが状態より先に来ることがあるので「全部消えたとき」だけ)
	if list.is_empty() and not _shown_keys.is_empty():
		for r in _frame:
			r.visible = false
	_shown_keys = keys


## 地の色の上で読みやすい文字の色(明るい地なら黒、暗い地なら白)
static func text_color_on(bg: Color) -> Color:
	return GameConfig.COLOR_INK if bg.get_luminance() > 0.55 else GameConfig.COLOR_PAPER


## 下のまん中の「◯◯に送る」と、3つの言葉のボタン(子どもの指でも押しやすい大きさ)
func _build_send_panel() -> void:
	_send_panel = PanelContainer.new()
	_send_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 8
	st.content_margin_bottom = 14
	_send_panel.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	_send_panel.add_child(col)
	_send_title = UiStyle.label("", 26, GameConfig.COLOR_INK)
	_send_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_send_title)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for kind in Stamps.ALL:
		var b := Button.new()
		b.text = Texts.stamp(kind)
		# 押した判定は main がする(指の操作をまとめて扱うため)。ここでは見た目だけ
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 3つとも白い地に黒い文字(絵文字で区別する)
		UiStyle.button(b, false, 32, GameConfig.COLOR_INK)
		b.custom_minimum_size = Vector2(210, 104)
		row.add_child(b)
		_send_buttons.append(b)
		# 英語など言葉が長くても、ボタンからはみ出さないように
		UiStyle.fit(b, 32, 186.0)
	add_child(_send_panel)
	_send_panel.anchor_left = 0.5
	_send_panel.anchor_right = 0.5
	_send_panel.anchor_top = 1.0
	_send_panel.anchor_bottom = 1.0
	_send_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_send_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_send_panel.visible = false


## 「◯◯に送る」を出す。above_buttons = true なら、鬼のボタンの上に出す(重ならないように)
func open_send_panel(target_name: String, above_buttons: bool) -> void:
	_send_title.text = Locale.t("%sに送る") % target_name
	_send_panel.visible = true
	var bottom := -280.0 if above_buttons else -24.0
	# 鬼のボタン(右下)と重ならないよう、鬼のときは少し左に寄せる
	var shift := -160.0 if above_buttons else -60.0
	_send_panel.offset_left = shift
	_send_panel.offset_right = shift
	_send_panel.offset_top = bottom
	_send_panel.offset_bottom = bottom


## 言葉のボタンに、自分で決めた言葉を出す(絵文字はそのまま)
func set_send_words(words: Dictionary) -> void:
	for i in _send_buttons.size():
		var k: String = Stamps.ALL[i]
		_send_buttons[i].text = Texts.stamp(k, str(words.get(k, "")))
	UiStyle.refit_all()


func close_send_panel() -> void:
	_send_panel.visible = false


## 画面のこの位置にある、言葉のボタンの種類(なければ "")
func send_panel_hit(pos: Vector2) -> String:
	if not _send_panel.visible:
		return ""
	for i in _send_buttons.size():
		if _send_buttons[i].get_global_rect().grow(6.0).has_point(pos):
			return Stamps.ALL[i]
	return ""


## 「◯◯に送る」の上(ボタンのすき間など)をタップしたか(閉じないようにするため)
func send_panel_contains(pos: Vector2) -> bool:
	return _send_panel.visible and _send_panel.get_global_rect().has_point(pos)


## 自分あてにスタンプが届いたとき、画面のふちを光らせる
func flash_stamp(color: Color) -> void:
	if _frame_tween:
		_frame_tween.kill()
	for r in _frame:
		r.color = color
		r.visible = true
	_frame_tween = create_tween()
	for i in 3:
		_frame_tween.tween_callback(_set_frame_alpha.bind(0.25))
		_frame_tween.tween_interval(0.15)
		_frame_tween.tween_callback(_set_frame_alpha.bind(0.9))
		_frame_tween.tween_interval(0.15)
	_frame_tween.tween_callback(_set_frame_alpha.bind(0.5))


## 牛乳がかかっている間は、上から白い牛乳がたれてくる(鬼の影や向かいの人の後ろが見えにくい)。
## left: 晴れるまでの残り(1 → 0)。上のまん中の「見えるまで」の棒に出す
## wiped: 走っているので、手でぬぐって下のほうを見えるようにする(走っていて転ばないように)
func set_milk(on: bool, left: float = 1.0, wiped: bool = false) -> void:
	if on and not _milk_on:
		_milk_t = 0.0
		_milk_wipe = 0.0
	_milk_on = on
	_milk_left = clampf(left, 0.0, 1.0)
	if wiped and not _milk_wiping and on:
		# 「ゴシゴシ」: ぬぐいはじめ
		show_message(tr("ゴシゴシ!"), Color(0.3, 0.45, 0.7), 0.8)
	_milk_wiping = wiped


func is_milk_shown() -> bool:
	return _milk.visible


## 「(牛乳びん) 見えるまで [青い棒]」の札
func _build_milk_pill() -> void:
	_milk_pill = PanelContainer.new()
	_milk_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milk_pill.add_theme_stylebox_override("panel", UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_milk_pill.add_child(row)
	row.add_child(ButtonIcon.make("milk", Vector2(28, 34)))
	var l := UiStyle.label("見えるまで", 20, GameConfig.COLOR_INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_milk_bar = Control.new()
	_milk_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milk_bar.custom_minimum_size = Vector2(150, 34)
	_milk_bar.draw.connect(func() -> void:
		var r := Rect2(Vector2(0, 8), Vector2(_milk_bar.size.x, 18))
		var bg := StyleBoxFlat.new()
		bg.bg_color = GameConfig.COLOR_PAPER
		bg.border_color = GameConfig.COLOR_INK
		bg.set_border_width_all(3)
		bg.set_corner_radius_all(9)
		_milk_bar.draw_style_box(bg, r)
		if _milk_left > 0.01:
			var fill := StyleBoxFlat.new()
			fill.bg_color = ButtonIcon.MILK_BLUE
			fill.set_corner_radius_all(6)
			_milk_bar.draw_style_box(fill, Rect2(r.position + Vector2(4, 4), Vector2((r.size.x - 8) * _milk_left, r.size.y - 8))))
	row.add_child(_milk_bar)
	_milk_pill.visible = false
	add_child(_milk_pill)
	_milk_pill.anchor_left = 0.5
	_milk_pill.anchor_right = 0.5
	# 左上の札(ラウンド・落とし物・点数)の下の段のまん中
	_milk_pill.offset_top = 66
	_milk_pill.offset_left = -170
	_milk_pill.offset_right = 170
	_milk_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH


## 上から白い牛乳がたれる: 見本をまねた絵(MilkArt の SVG)を上からすべり下ろして出し、
## その下で白い粒がゆっくり落ちる(黒い輪郭)
func _draw_milk() -> void:
	var sz := _milk.size
	var t := Time.get_ticks_msec() / 1000.0
	var ink := GameConfig.COLOR_INK
	var white := Color(1.0, 1.0, 0.99)
	# かかった直後は、上からすべり下りてくる
	var grow := clampf(_milk_t / 0.6, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var tex := MilkArt.texture(sz)
	if tex:
		var drop := -(1.0 - grow) * sz.y * 0.6 + sin(t * 1.3) * 3.0
		# 手でぬぐったら、牛乳は上のほうだけに(走る先の下半分が見える)
		drop -= _milk_wipe * sz.y * GameConfig.MILK_WIPE_UP
		_milk.draw_texture_rect(tex, Rect2(Vector2(0, drop), sz), false)
	# 落ちていく粒(しずくの下から、ゆっくり落ちてくり返す)。ぬぐったら出さない
	var band := sz.y * MilkArt.BAND
	for i in (0 if _milk_wipe > 0.5 else 7):
		var x := sz.x * (0.08 + 0.135 * float(i)) + sin(float(i) * 4.1) * 20.0
		var start := band + sz.y * 0.12
		var fall := fmod(t * (40.0 + 12.0 * float(i % 3)) + float(i) * 97.0, sz.y * 0.3)
		var y := start + fall
		var rr := 7.0 + 3.0 * float(i % 2)
		_milk.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 1.35))
		_milk.draw_circle(Vector2.ZERO, rr + 3.0, ink)
		_milk.draw_circle(Vector2.ZERO, rr, white)
		_milk.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 画面の上のまん中に、役を出す(空文字で消す)。color の地に白い文字
func set_role_badge(text: String, color: Color) -> void:
	_pill_text(_badge, text)
	_badge.visible = text != ""
	(_badge.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color


func _set_frame_alpha(a: float) -> void:
	for r in _frame:
		r.modulate.a = a


func _build_stamp_display() -> void:
	# 画面のふちの枠(上下左右の4本)
	for side in 4:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		add_child(r)
		match side:
			0: # 上
				r.set_anchors_preset(Control.PRESET_TOP_WIDE)
				r.offset_bottom = FRAME_WIDTH
			1: # 下
				r.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				r.offset_top = -FRAME_WIDTH
			2: # 左
				r.set_anchors_preset(Control.PRESET_LEFT_WIDE)
				r.offset_right = FRAME_WIDTH
			3: # 右
				r.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
				r.offset_left = -FRAME_WIDTH
		_frame.append(r)

	# 自分あてのスタンプは、左下(スティックの上)の「あなたへ」の箱に、届いた順に上から積む。
	# ほかの人あてのスタンプは 3D の頭の上に出るので、場所で区別できる
	_my_box = PanelContainer.new()
	_my_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_my_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_my_box)
	_my_box.anchor_left = 0.0
	_my_box.anchor_right = 0.0
	_my_box.anchor_top = 1.0
	_my_box.anchor_bottom = 1.0
	_my_box.offset_left = UiStyle.SAFE
	_my_box.offset_right = UiStyle.SAFE + 340
	# 下の端をスティックのすぐ上に固定して、届いた数だけ上にのびる
	_my_box.offset_top = -262
	_my_box.offset_bottom = -262
	_my_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_my_box.visible = false

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	_my_box.add_child(col)

	for i in GameConfig.STAMP_SLOTS:
		# 送った人の色の吹き出し(黒いふち・左下にしっぽ)に「名前:言葉」
		var style := UiStyle.box(Color.WHITE, true, 18, 4)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 6
		style.content_margin_bottom = 8
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", style)
		slot.visible = false
		slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(slot)
		var l := UiStyle.label("", 26, GameConfig.COLOR_INK)
		slot.add_child(l)
		_slots.append(slot)
		_slot_styles.append(style)
		_slot_labels.append(l)

	_build_send_panel()

	_badge = UiStyle.pill("", 24, true)
	(_badge.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	add_child(_badge)
	_badge.position = Vector2(UiStyle.SAFE, 72)
	_badge.visible = false


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
