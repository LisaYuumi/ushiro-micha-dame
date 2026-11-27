class_name Hud
extends CanvasLayer
## 画面の文字表示だけを担当する。

## 自分に届いたスタンプのまわりに出す枠の太さ
const FRAME_WIDTH := 18.0

var _help: Label
var _message: Label
var _message_left := 0.0
## 自分に届いたスタンプ(左下の「あなたへ」の箱に、送り主つきで3つまで積む)
## (送った人の色の吹き出しに「名前:言葉」)
## スタンプを送るときの、下のまん中の「◯◯に送る」と3つの言葉のボタン
var _send_panel: PanelContainer
var _send_title: Label
var _send_buttons: Array[Button] = []
## 前のフレームに出ていたスタンプ(新しく届いたものだけポンと飛び出させる)
var _shown_keys: Array = []
## 自分に届いたスタンプの間、画面のふちを光らせる枠
var _frame: Array[ColorRect] = []
## 手下の間ずっと出す、画面の四すみの紫のカギ形の枠(スタンプのふちの光とは形を変える)
var _minion_corners: Array[ColorRect] = []
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
## ルーム主の「発表へ」を押した
signal skip_vote_pressed
## 教室のままの投票: 上の「鬼の手下は誰?」と「4/6人 投票済み」、ルーム主の「発表へ」
var _vote_box: VBoxContainer
var _vote_panel: PanelContainer
var _next_wait: PanelContainer
var _vote_title: Label
var _vote_count: Label
var _skip_button: Button
var _chips := {}
var _vote_open := false
var _can_vote := false
var _my_vote := -1
## 投票中に薄くしている札(鬼の札。投票できないので)。発表で元に戻す
var _no_vote_chips: Array[Control] = []
var _card_hint_label: Label
## 役のお知らせカード(手下になったときなど)。しばらくすると消える
var _popup: PanelContainer
## 牛乳がかかったときの白い画面(いちばん下に置く。札やスタンプはその上に見える)
var _milk: Control
var _milk_group: CanvasGroup
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
## 海辺の舞台: 白い牛乳のかわりに、水色の水しぶき
var _water := false
## 夜の教室: 鬼の技はカメラのフラッシュ(画面がまぶしく真っ白になり、数秒で晴れる)
var _flash := false
var _milk_pill_icon: ButtonIcon
var _milk_bar: Control


## 名札(HeadOverlay・層 1)やボタン(層 2)より上に出す物: お知らせのカード・結果カード・真ん中の大きな文字
var _top: CanvasLayer
## 振り向く瞬間の集中線(画面のふちから中心へ向かう線)と、その残り時間
var _speed: Control
var _speed_left := 0.0
const SPEED_TIME := 0.3
## 画面の上のほうに出す派手な文字(「あったー!!」など。前が見えるように上のほう)
var _banner: Label
var _banner_tween: Tween


func _ready() -> void:
	_top = CanvasLayer.new()
	_top.layer = 5
	add_child(_top)
	_speed = Control.new()
	_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed.draw.connect(_draw_speed_lines)
	_speed.visible = false
	add_child(_speed)
	_banner = _make_label(84, Color("FFB020"))
	_banner.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.1
	_banner.anchor_bottom = 0.3
	_banner.visible = false
	_top.add_child(_banner)
	_milk = Control.new()
	_milk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milk.position = Vector2.ZERO
	_milk.draw.connect(_draw_milk)
	_milk.visible = false
	# 牛乳は 3D のすぐ上(層 0)に描く。名札の吹き出しやスタンプ、札はその上に見える
	var milk_layer := CanvasLayer.new()
	milk_layer.layer = 0
	add_child(milk_layer)
	# こすって薄くするとき、丸の重なりが透けないように、全部を1枚の絵にまとめてから薄くする
	_milk_group = CanvasGroup.new()
	milk_layer.add_child(_milk_group)
	_milk_group.add_child(_milk)
	_build_milk_pill()
	# 説明文は出さない(A案: 文字は札とボタンだけ)。古い呼び出しのために部品だけ残す
	_help = _make_label(22, GameConfig.COLOR_INK)
	_help.visible = false
	add_child(_help)
	_build_info_pills()

	# 画面中央の大きな文字(「お手つき!」など)
	_message = _make_label(72, Color.WHITE)
	_top.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_constant_override("outline_size", 16)
	_message.visible = false

	_build_stamp_display()


## 画面のまん中に出す大きなお知らせ(順位の一覧・ラウンドのお知らせ・役のカード・イベントの名前)は、
## 重ならないように順番待ちにして1つずつ出す: [{"fn": Callable, "dur": 秒}]
var _ann_queue: Array = []
var _ann_until := 0


## prio: 同じときに来たら小さい順(0 = 順位・ラウンドのお知らせ、1 = 役のカード、2 = イベントの名前)。
## (いつも次のフレームで出す。同じフレームに来たお知らせを、この順にならべるため)
func _announce(fn: Callable, dur: float, prio: int = 1) -> void:
	_ann_queue.append({"fn": fn, "dur": dur, "prio": prio, "n": _ann_serial})
	_ann_serial += 1


var _ann_serial := 0


func _run_announcements() -> void:
	if _ann_queue.is_empty() or Time.get_ticks_msec() < _ann_until:
		return
	var best := 0
	for i in _ann_queue.size():
		var a: Dictionary = _ann_queue[i]
		var b: Dictionary = _ann_queue[best]
		if int(a["prio"]) < int(b["prio"]) or (int(a["prio"]) == int(b["prio"]) and int(a["n"]) < int(b["n"])):
			best = i
	var pick: Dictionary = _ann_queue[best]
	_ann_queue.remove_at(best)
	(pick["fn"] as Callable).call()
	# (次のお知らせまで、少しだけ間をあける)
	_ann_until = Time.get_ticks_msec() + int((float(pick["dur"]) + 0.25) * 1000.0)


## 順番待ちのお知らせを全部やめる(ロビーにもどったときなど)
func clear_announcements() -> void:
	_ann_queue.clear()
	_ann_until = 0
	# (ロビーにもどったら、蜃気楼のモヤも消す)
	_haze_amount = 0.0
	_haze_want = 0.0
	if _haze:
		_haze.visible = false


## ラウンドのお知らせ(「ラウンド 2: 上履き」)。ほかの大きなお知らせと重ならないように順番に
func announce_message(text: String, outline: Color, seconds: float) -> void:
	_announce(show_message.bind(text, outline, seconds), seconds, 0)


func _process(delta: float) -> void:
	_run_announcements()
	# 飛び出すハート(拍で飛び出して、もどる)
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * GameConfig.HEART_RETURN, 0.0)
	_update_heart(delta)
	_layout_cards(minf(delta * 10.0, 1.0), delta)
	# 牛乳: かかるとすぐ白く、終わるときはゆっくり晴れる
	var want := 1.0 if _milk_on else 0.0
	if _milk_a != want or (_milk_on and _milk.visible):
		_milk_a = move_toward(_milk_a, want, delta / (0.15 if _milk_on else 0.8))
		# 手でゴシゴシこする: こするたびに(1秒に4回くらい)少しずつ薄くなる
		var stroke := 0.35 + 0.65 * absf(sin(_milk_t * TAU * 2.0))
		_milk_wipe = move_toward(_milk_wipe, 1.0 if _milk_wiping else 0.0, delta / GameConfig.MILK_WIPE_TIME * (stroke if _milk_wiping else 1.0))
		_milk_t = _milk_t + delta if _milk_on else _milk_t
		_milk.visible = _milk_a > 0.0
		_milk_group.self_modulate.a = _milk_a * (1.0 - GameConfig.MILK_WIPE_FADE * _milk_wipe)
		# (親が Control ではないので、大きさは画面に合わせて毎回決める)
		_milk.size = get_viewport().get_visible_rect().size
		_milk.queue_redraw()
		_milk_pill.visible = _milk_on
		_milk_bar.queue_redraw()
	if _speed_left > 0.0:
		_speed_left -= delta
		_speed.visible = _speed_left > 0.0
		_speed.queue_redraw()
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
## rows: [{"name", "color", "score", "delta", "me", "mark", "id"(投票できる札), "no_vote"(投票中は薄くする札)}](この順に並べる)/ footer: いちばん下の案内
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
	_top.add_child(_result_card)
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
	_announce(_show_popup_card.bind(title, tags, color, hint, seconds), seconds + 0.45, 1)


func _show_popup_card(title: String, tags: Array, color: Color, hint: String, seconds: float) -> void:
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
	_top.add_child(_popup)
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
	_no_vote_chips.clear()
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
	# 見逃しのラウンド: 手下が、気づかなかった人に送ったウソのスタンプ(投票のあとにわかる)
	for p in people:
		for w in p.get("lies", []):
			var lp := UiStyle.pill(tr("ウソ: %s") % str(w), 16)
			UiStyle.set_bg(lp.get_theme_stylebox("panel") as StyleBoxFlat, Color("E5483B"))
			UiStyle.set_font_color(lp.get_child(0) as Label, Color.WHITE)
			info.add_child(lp)
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
	if _skip_button and _skip_button.is_visible_in_tree() and not _skip_button.disabled \
			and _skip_button.get_global_rect().grow(6.0).has_point(pos):
		AudioDirector.click()
		skip_vote_pressed.emit()
		get_viewport().set_input_as_handled()
		return
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
	if r.get("no_vote", false) and _vote_open:
		panel.modulate.a = 0.45
		_no_vote_chips.append(panel)
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
	for p in _no_vote_chips:
		if is_instance_valid(p):
			p.modulate.a = 1.0
	_no_vote_chips.clear()
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
	# (長い文でも画面の幅に収まるように、文字を小さくする)
	_message.add_theme_font_size_override("font_size", UiStyle.fit_size(text, 72, get_viewport().get_visible_rect().size.x - 80.0, 28))
	_message.add_theme_color_override("font_outline_color", outline)
	_message.visible = true
	_message_left = seconds if seconds > 0.0 else INF


func hide_message() -> void:
	_message.visible = false
	_message_left = 0.0
	hide_result_card()


## 自分に届いているスタンプを並べる。list: [{"kind", "sender", "color"}](届いた順。色は言葉の意味: 見ろ系=赤・見るな系=青)。
## 送った人の色の吹き出しに「名前:言葉」
## 自分に届いた言葉(list: [{"kind","text","sender"(名前),"sender_id","sender_color","from"(画面の位置)}]、届いた順)。
## 送った人の席から小さな紙飛行機が飛んできて(STAMP_PLANE_TIME 秒)、ポンと開いてカードになる。
## カードは画面の下の左(振り向くボタン・送るバーにかからない)。新しいものがいちばん下で大きく、
## 古いものは上に小さく薄く(最大 STAMP_SLOTS 個)。ふちは送った人のキャラクターの色、上に小さく「〇〇から」
var _cards := {} # key -> {"card": PanelContainer, "text": Label, "from": Label, "plane": Control, "open": bool}
var _card_keys: Array = [] # 届いた順(古い → 新しい)
var _card_layer: CanvasLayer # (ほかの人の名札・吹き出し(層 1)より手前)


func show_my_stamps(list: Array) -> void:
	var keys := []
	for st in list:
		keys.append("%s|%s" % [st.get("sender_id", st["sender"]), st["kind"]])
	# 消えたもの: ふっと消す
	for k in _cards.keys():
		if not (k in keys):
			var c: Dictionary = _cards[k]
			_cards.erase(k)
			if c["plane"] and is_instance_valid(c["plane"]):
				c["plane"].queue_free()
			var card: Control = c["card"]
			var tw := card.create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.25)
			tw.tween_callback(card.queue_free)
	for i in list.size():
		var st: Dictionary = list[i]
		var key: String = keys[i]
		var col: Color = st.get("sender_color", Color.WHITE)
		var txt: String = str(st.get("text", Texts.stamp(st["kind"])))
		if _cards.has(key):
			var c: Dictionary = _cards[key]
			(c["text"] as Label).text = txt
			continue
		_cards[key] = _make_card(st, txt, col)
	_card_keys = keys
	_layout_cards(1.0, 0.0)
	# 出ていたスタンプが全部消えたら、ふちの光も消す
	# (参加者の画面では、届いたお知らせが状態より先に来ることがあるので「全部消えたとき」だけ)
	if list.is_empty() and not _shown_keys.is_empty():
		for r in _frame:
			r.visible = false
	_shown_keys = keys


func _cards_parent() -> Node:
	if _card_layer == null:
		_card_layer = CanvasLayer.new()
		_card_layer.layer = 2
		add_child(_card_layer)
	return _card_layer


func _make_card(st: Dictionary, txt: String, col: Color) -> Dictionary:
	var style := UiStyle.box(Color.WHITE, true, 20, GameConfig.STAMP_CARD_BORDER)
	style.border_color = col
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var from := UiStyle.label(tr("%sから") % str(st["sender"]), 22, GameConfig.COLOR_INK)
	box.add_child(from)
	# 言葉は意味の色(見ろ系=赤、見るな系=青)
	var l := UiStyle.label(txt, GameConfig.STAMP_CARD_FONT, HeadOverlay.kind_color(str(st["kind"])))
	l.add_theme_constant_override("outline_size", 0)
	box.add_child(l)
	_cards_parent().add_child(card)
	card.reset_size()
	card.visible = false
	var d := {"card": card, "text": l, "from": from, "plane": null, "open": false}
	# 紙飛行機: 送った人の席(画面の位置)から、カードの場所へ
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var start: Vector2 = st.get("from", Vector2(vp.x * 0.5, vp.y * 0.35))
	var plane := PaperPlane.new()
	plane.color = col
	_cards_parent().add_child(plane)
	plane.position = start
	d["plane"] = plane
	var tw := plane.create_tween()
	tw.tween_method(_fly_plane.bind(d, start), 0.0, 1.0, GameConfig.STAMP_PLANE_TIME)
	tw.tween_callback(_open_card.bind(d))
	return d


## 紙飛行機の1こま(少し弧をえがいて、進む向きを向く)
func _fly_plane(k: float, d: Dictionary, start: Vector2) -> void:
	var plane: Control = d["plane"]
	if plane == null or not is_instance_valid(plane):
		return
	var card: Control = d["card"]
	var goal := card.position + Vector2(card.size.x * 0.5, card.size.y * 0.5)
	var p := start.lerp(goal, k) + Vector2(0, -90.0 * sin(k * PI))
	var dir := p - plane.position
	if dir.length() > 0.5:
		plane.rotation = dir.angle()
	plane.position = p


## 紙飛行機がポンと開いて、カードになる
func _open_card(d: Dictionary) -> void:
	if d["plane"] and is_instance_valid(d["plane"]):
		d["plane"].queue_free()
	d["plane"] = null
	var card: Control = d["card"]
	if not is_instance_valid(card):
		return
	d["open"] = true
	d["pop"] = 0.0
	card.visible = true
	_layout_cards(0.0, 0.0)
	AudioDirector.sfx("vote_pon", -6.0, 1.15)


## カードの並び: いちばん新しいものが下で大きく、古いものほど上で小さく薄く
func _layout_cards(blend: float, delta: float) -> void:
	if _card_keys.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var bottom := vp.y - GameConfig.STAMP_CARD_BOTTOM
	var sp := send_panel_rect()
	if sp.size != Vector2.ZERO and sp.position.y < bottom + 4.0 and sp.position.x < UiStyle.SAFE + 380.0:
		bottom = sp.position.y - 10.0
	var y := bottom
	var n := _card_keys.size()
	for idx in range(n - 1, -1, -1):
		var c = _cards.get(_card_keys[idx])
		if c == null:
			continue
		var card: Control = c["card"]
		var age := n - 1 - idx # 0 = いちばん新しい
		var sc := 1.0 if age == 0 else (0.8 if age == 1 else 0.68)
		var a := 1.0 if age == 0 else (0.75 if age == 1 else 0.5)
		var h := card.size.y * sc
		var want := Vector2(UiStyle.SAFE, y - h)
		card.pivot_offset = Vector2(0, card.size.y * 0.5)
		# ポンと開く: 小さく → 少し大きく → ふつう
		var m := 1.0
		if c.get("pop", -1.0) >= 0.0:
			var k: float = c["pop"]
			m = lerpf(0.2, 1.15, k / 0.12) if k < 0.12 else lerpf(1.15, 1.0, clampf((k - 0.12) / 0.1, 0.0, 1.0))
			c["pop"] = k + delta if k < 0.22 else -1.0
		var cur_sc := card.scale.x / maxf(c.get("m", 1.0), 0.01)
		cur_sc = lerpf(cur_sc, sc, blend) if c["open"] else sc
		c["m"] = m
		card.scale = Vector2.ONE * cur_sc * m
		card.position = card.position.lerp(want, blend) if c["open"] else want
		card.modulate.a = lerpf(card.modulate.a, a, blend) if c["open"] else a
		y -= h + 8.0


## 地の色の上で読みやすい文字の色(明るい地なら黒、暗い地なら白)
static func text_color_on(bg: Color) -> Color:
	return GameConfig.COLOR_INK if bg.get_luminance() > 0.55 else GameConfig.COLOR_PAPER


## 言葉を送るバー: 画面の下に横長の細いバーで「catに送る: [落ちてる😨] [平気👍] [信じて🥺]  ×」。
## 右下のボタン(振り向く・落とす)やスティックにかからない場所に出す(main がよける場所を渡す)
var _send_close: Button
const SEND_BAR_FONT := 24
const SEND_BAR_HEIGHT := 62.0


func _build_send_panel() -> void:
	_send_panel = PanelContainer.new()
	_send_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color(1, 1, 1, 0.93), true, 18, 3)
	st.content_margin_left = 14
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 8
	_send_panel.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_send_panel.add_child(row)
	_send_title = UiStyle.label("", SEND_BAR_FONT, GameConfig.COLOR_INK)
	row.add_child(_send_title)
	for kind in Stamps.ALL:
		var b := Button.new()
		b.text = Texts.stamp(kind)
		# 押した判定は main がする(指の操作をまとめて扱うため)。ここでは見た目だけ
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 言葉の意味の色のふち(見ろ系=赤、見るな系=青)。地は白
		UiStyle.button(b, false, SEND_BAR_FONT, GameConfig.COLOR_INK)
		var bst := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
		bst.border_color = HeadOverlay.kind_color(kind)
		bst.set_border_width_all(4)
		bst.content_margin_left = 12
		bst.content_margin_right = 12
		b.add_theme_stylebox_override("normal", bst)
		b.custom_minimum_size = Vector2(0, SEND_BAR_HEIGHT - 14.0)
		row.add_child(b)
		_send_buttons.append(b)
	_send_close = Button.new()
	_send_close.text = "×"
	_send_close.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.button(_send_close, false, 30, GameConfig.COLOR_INK)
	_send_close.custom_minimum_size = Vector2(SEND_BAR_HEIGHT - 14.0, SEND_BAR_HEIGHT - 14.0)
	row.add_child(_send_close)
	add_child(_send_panel)
	_send_panel.visible = false


## 言葉を送るバーを出す。left・right: よける場所の、画面の左の端からの右のふち・右のふち(バーはその間の下に出す)
func open_send_panel(target_name: String, left := 0.0, right := -1.0) -> void:
	_send_title.text = Locale.t("%sに送る:") % target_name
	_send_panel.visible = true
	var vp := get_viewport().get_visible_rect().size
	if right < 0.0:
		right = vp.x
	var lo := maxf(left + 10.0, UiStyle.SAFE * 0.5)
	var hi := minf(right - 10.0, vp.x - UiStyle.SAFE * 0.5)
	# 入りきらないときは文字を少し小さく
	for fs in [SEND_BAR_FONT, 21, 18]:
		_send_title.add_theme_font_size_override("font_size", fs)
		for b in _send_buttons:
			b.add_theme_font_size_override("font_size", fs)
		_send_panel.reset_size()
		if _send_panel.get_combined_minimum_size().x <= hi - lo:
			break
	var sz := _send_panel.get_combined_minimum_size()
	_send_panel.size = sz
	var x := clampf((lo + hi - sz.x) / 2.0, lo, maxf(hi - sz.x, lo))
	_send_panel.position = Vector2(x, vp.y - sz.y - 14.0).floor()


## 言葉のボタンに、自分で決めた言葉を出す(絵文字はそのまま)
func set_send_words(words: Dictionary) -> void:
	for i in _send_buttons.size():
		var k: String = Stamps.ALL[i]
		_send_buttons[i].text = Texts.stamp(k, str(words.get(k, "")))
	UiStyle.refit_all()


func close_send_panel() -> void:
	_send_panel.visible = false


## 画面のこの位置にある、言葉のボタンの種類(なければ ""。×は "close")
func send_panel_hit(pos: Vector2) -> String:
	if not _send_panel.visible:
		return ""
	for i in _send_buttons.size():
		if _send_buttons[i].get_global_rect().grow(5.0).has_point(pos):
			return Stamps.ALL[i]
	if _send_close and _send_close.get_global_rect().grow(8.0).has_point(pos):
		return "close"
	return ""


## 言葉を送るバーの画面の範囲(出ていなければ空)。吹き出しをそこに置かないため
func send_panel_rect() -> Rect2:
	return _send_panel.get_global_rect().grow(6.0) if _send_panel and _send_panel.visible else Rect2()


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
## wiped: 走っているので、手でゴシゴシこすって薄くする(走っていて転ばないように)
func set_milk(on: bool, left: float = 1.0, wiped: bool = false) -> void:
	if on and not _milk_on:
		_milk_t = 0.0
		_milk_wipe = 0.0
	_milk_on = on
	_milk_left = clampf(left, 0.0, 1.0)
	if wiped and not _milk_wiping and on:
		# 「ゴシゴシ」: ぬぐいはじめ
		if not _flash:
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
	_milk_pill_icon = ButtonIcon.make("milk", Vector2(28, 34))
	row.add_child(_milk_pill_icon)
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
			fill.bg_color = ButtonIcon.MILK_BLUE if _water else Color("9A948C")
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


func set_water(v: bool) -> void:
	set_tool("water" if v else "eraser")


## 鬼の技の見た目: "eraser"(黒板消しの煙)/ "water"(水鉄砲の水)/ "camera"(フラッシュ)
func set_tool(tool: String) -> void:
	_water = tool == "water"
	_flash = tool == "camera"
	if _milk_pill_icon:
		_milk_pill_icon.kind = tool


## 上から白い牛乳がたれる: 見本をまねた絵(MilkArt の SVG)を上からすべり下ろして出し、
## その下で白い粒がゆっくり落ちる(黒い輪郭)
func _draw_milk() -> void:
	if _flash:
		_draw_flash()
		return
	if not _water:
		_draw_smoke()
		return
	var sz := _milk.size
	var t := Time.get_ticks_msec() / 1000.0
	var ink := GameConfig.COLOR_INK
	var white := Color(MilkArt.WATER_WHITE) if _water else Color(1.0, 1.0, 0.99)
	# かかった直後は、上からすべり下りてくる
	var grow := clampf(_milk_t / 0.6, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var tex := MilkArt.texture(sz, 1.5, _water)
	# 画面全体が、水でにじんで見えない(しずくの絵の下に、水色のにじみを全体に。ゆらゆら)
	var haze := Color(MilkArt.WATER_WHITE)
	haze.a = 0.9 * grow
	_milk.draw_rect(Rect2(Vector2.ZERO, sz), haze)
	for i in 6:
		var y := fposmod(float(i) * sz.y / 6.0 + t * 40.0, sz.y)
		_milk.draw_rect(Rect2(0, y, sz.x, sz.y * 0.05), Color(1, 1, 1, 0.12 * grow))
	if tex:
		var drop := -(1.0 - grow) * sz.y * 0.6 + sin(t * 1.3) * 3.0
		# こすっている間は、こする手に合わせて少し左右にゆれる
		var rub := sin(t * TAU * 2.0) * 10.0 if _milk_wiping else 0.0
		_milk.draw_texture_rect(tex, Rect2(Vector2(rub, drop), sz), false)
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
	_draw_scrub(sz, t)


## カメラのフラッシュ: 画面がまぶしく真っ白(まん中に光の筋と星)。残りが少なくなると、だんだん晴れる
func _draw_flash() -> void:
	var sz := _milk.size
	var t := Time.get_ticks_msec() / 1000.0
	var a := clampf(_milk_left * 1.6, 0.0, 1.0)
	_milk.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 1.0, 0.98, 0.97 * a))
	var c := sz / 2.0
	var ray := Color(1.0, 0.93, 0.55, 0.55 * a)
	for i in 12:
		var ang := TAU * float(i) / 12.0 + t * 0.4
		var dir := Vector2(cos(ang), sin(ang))
		_milk.draw_line(c + dir * sz.y * 0.12, c + dir * sz.y * (0.42 + 0.06 * sin(t * 6.0 + i)), ray, maxf(4.0, sz.y * 0.01), true)
	var star := Color(1.0, 0.85, 0.3, 0.8 * a)
	for k in 4:
		var ang2 := PI / 4.0 * k
		var d2 := Vector2(cos(ang2), sin(ang2))
		_milk.draw_line(c - d2 * sz.y * 0.08, c + d2 * sz.y * 0.08, star, maxf(6.0, sz.y * 0.014), true)


## ゴシゴシこすっている間: 画面のまん中あたりを、こすったあとのすじが左右に行き来する
func _draw_scrub(sz: Vector2, t: float) -> void:
	if not _milk_wiping:
		return
	var col := Color(GameConfig.COLOR_INK, 0.35)
	var cx := sz.x * 0.5 + sin(t * TAU * 2.0) * sz.x * 0.16
	for i in 3:
		var y := sz.y * (0.22 + 0.11 * float(i))
		var w := sz.x * (0.22 - 0.03 * float(i))
		var pts := PackedVector2Array()
		for j in 9:
			var u := float(j) / 8.0
			pts.append(Vector2(cx - w / 2.0 + w * u, y + (12.0 if j % 2 == 0 else -12.0)))
		_milk.draw_polyline(pts, col, maxf(3.0, sz.y * 0.006), true)


## 画面の四すみの紫のカギ形(手下のしるし)
func _build_minion_corners() -> void:
	var col := Color(0.55, 0.2, 0.7, 0.9)
	var long := 170.0
	var thick := 18.0
	for corner in 4:
		var right := corner % 2 == 1
		var bottom := corner >= 2
		for horizontal in [true, false]:
			var r := ColorRect.new()
			r.color = col
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.anchor_left = 1.0 if right else 0.0
			r.anchor_right = r.anchor_left
			r.anchor_top = 1.0 if bottom else 0.0
			r.anchor_bottom = r.anchor_top
			var w := long if horizontal else thick
			var h := thick if horizontal else long
			r.offset_left = -w if right else 0.0
			r.offset_right = 0.0 if right else w
			r.offset_top = -h if bottom else 0.0
			r.offset_bottom = 0.0 if bottom else h
			r.visible = false
			add_child(r)
			_minion_corners.append(r)


## 手下のしるし(四すみの紫のカギ形)を出す・消す
func set_minion_mark(on: bool) -> void:
	for r in _minion_corners:
		if r.visible != on:
			r.visible = on


## 教室の黒板消し: 上からもくもくの白い煙(下のふちは大小の丸が並んで黒い輪郭)、中に灰色の粉のつぶ、
## 下に小さな粒がゆっくり落ちる。画面の上の 2/3 くらいがかくれる(走っている間は手でゴシゴシこすって薄くする)
func _draw_smoke() -> void:
	var sz := _milk.size
	var t := Time.get_ticks_msec() / 1000.0
	var ink := GameConfig.COLOR_INK
	var white := Color(1.0, 1.0, 0.995)
	var dust := Color("E3DED6")
	var grow := clampf(_milk_t / 0.5, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var lift := -(1.0 - grow) * sz.y * 0.6
	var band := sz.y * 0.47 + lift
	var line := maxf(4.0, sz.y * 0.008)
	# 下のふちの丸(左から右へ、大きさを変えて並べる。ゆっくりふくらんだりしぼんだり)
	var puffs := []
	var x := -sz.x * 0.02
	var k := 0
	while x < sz.x * 1.05:
		var r := sz.y * (0.12 + 0.04 * sin(float(k) * 2.3 + 0.7)) * (1.0 + 0.03 * sin(t * 1.5 + float(k)))
		puffs.append([Vector2(x + r * 0.8, band + sz.y * 0.02 * sin(float(k) * 1.7)), r])
		x += r * 1.45
		k += 1
	for p in puffs:
		_milk.draw_circle(p[0], p[1] + line, ink)
	_milk.draw_rect(Rect2(0, -10, sz.x, band + 10), white)
	for p in puffs:
		_milk.draw_circle(p[0], p[1], white)
	# 煙の中の、灰色の粉のつぶ(ゆっくりただよう)
	for i in 9:
		var cx := sz.x * fposmod(0.08 + 0.115 * float(i) + 0.01 * sin(t * 0.4 + float(i)), 1.0)
		var cy := band * (0.2 + 0.6 * fposmod(float(i) * 0.37, 1.0)) + 6.0 * sin(t * 0.7 + float(i) * 2.0)
		var rr := sz.y * (0.025 + 0.02 * fposmod(float(i) * 0.53, 1.0))
		_milk.draw_circle(Vector2(cx, cy), rr, dust)
	# 下に落ちていく小さな粒(白に黒い輪郭)。こすって薄くなってきたら出さない
	if _milk_wipe < 0.5:
		for i in 12:
			var px := sz.x * (0.05 + 0.08 * float(i)) + sin(float(i) * 4.1) * 18.0
			var fall := fmod(t * (30.0 + 10.0 * float(i % 3)) + float(i) * 61.0, sz.y * 0.32)
			var py := band + sz.y * 0.08 + fall
			var pr := 3.5 + 2.0 * float(i % 2)
			_milk.draw_circle(Vector2(px, py), pr + 2.0, ink)
			_milk.draw_circle(Vector2(px, py), pr, white)
	_draw_scrub(sz, t)


## 振り向く瞬間のタメ: 画面のふちから中心へ向かう集中線を、少しの間だけ出す(見た目だけ)
func speed_lines() -> void:
	_speed_left = SPEED_TIME
	_speed.visible = true
	_speed.queue_redraw()


func _draw_speed_lines() -> void:
	var sz := _speed.size
	var c := sz / 2.0
	var a := clampf(_speed_left / SPEED_TIME, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 40)
	var far := c.length() * 1.05
	for i in 56:
		var ang := TAU * (float(i) + rng.randf() * 0.6) / 56.0
		var dir := Vector2(cos(ang), sin(ang))
		var inner := far * rng.randf_range(0.42, 0.62)
		var w := rng.randf_range(2.0, 7.0)
		_speed.draw_line(c + dir * inner, c + dir * far, Color(0.12, 0.1, 0.09, 0.55 * a), w, true)


## 画面の上のほうに、派手な文字をポンと出して、seconds 秒で消す(前の障害物が見えるように上のほう)
func show_banner(text: String, color: Color, seconds: float, font_size: int = 84) -> void:
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", font_size)
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.5, 0.5)
	_banner.modulate.a = 1.0
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2(1.15, 1.15), 0.08)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.06)
	_banner_tween.tween_interval(maxf(seconds - 0.24, 0.05))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.1)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)


## 1試合に1回のイベントの名前を大きく出し、下にひとこと
## (役のカードと同じ形の、画面のまん中のカード。上の帯の札と並ばないように)
func show_event(title: String, sub: String, color: Color) -> void:
	_announce(_show_popup_card.bind(title, [], color, sub, 2.2), 2.65, 2)


## 突風: 砂が舞って画面が見えにくい(alpha = 0 で消す)。砂のすじが流れる
var _gust: Control
var _gust_alpha := 0.0


func set_gust(alpha: float) -> void:
	if alpha <= 0.0 and _gust == null:
		return
	if _gust == null:
		_gust = Control.new()
		_gust.set_anchors_preset(Control.PRESET_FULL_RECT)
		_gust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gust.draw.connect(_draw_gust)
		add_child(_gust)
		move_child(_gust, 0)
	_gust_alpha = alpha
	_gust.visible = alpha > 0.0
	if _gust.visible:
		_gust.queue_redraw()


func _draw_gust() -> void:
	var vp := _gust.get_viewport_rect().size
	var a := _gust_alpha
	_gust.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.86, 0.74, 0.52, a))
	var t := Time.get_ticks_msec() / 1000.0
	for i in 40:
		var y := fposmod(float(i) * 97.0 + sin(float(i)) * 40.0, vp.y)
		var x := fposmod(float(i) * 173.0 + t * (500.0 + float(i % 7) * 60.0), vp.x + 300.0) - 150.0
		_gust.draw_line(Vector2(x, y), Vector2(x - 120.0, y + 8.0), Color(0.95, 0.85, 0.65, a * 0.9), 4.0, true)


## 鬼がうしろに近いとき(心臓の音が鳴っている間)、自分の胸(画面の下のほう)から、アニメっぽい赤いハートが
## 「ドック・ドックン」に合わせてボヨンと飛び出して戻る(映画『マスク』のような、笑える演出)。自分の画面だけ。
## 近いほど大きく・遠くまで(すぐうしろなら画面のまん中近くまでビヨーン)。拍ごとに「ドクン!」の文字。
## 鬼が離れたら、シュッと胸にもどって消える
var _danger_level := 0.0
var _pulse := 0.0
var _heart: Control
var _heart_layer: CanvasLayer
var _heart_vis := 0.0
var _heart_t := 0.0


func set_danger(level: float) -> void:
	_danger_level = clampf(level, 0.0, 1.0)


## 心臓の音の1拍(AudioDirector.heart_beat): ハートを飛び出させ(飛び出して戻る)、「ドクン!」を出す
var _beat_t := 9.0
var _beat_amp := 0.0
const BEAT_TIME := 0.34


func heart_pulse(strength: float) -> void:
	if _danger_level <= 0.01:
		return
	_beat_t = 0.0
	_beat_amp = strength
	_pulse = maxf(_pulse, strength)
	if strength >= 0.7:
		_heart_word()


func _update_heart(delta: float) -> void:
	var want := 1.0 if _danger_level > 0.01 else 0.0
	# (出るときはポンと、もどるときはシュッと速く)
	_heart_vis = move_toward(_heart_vis, want, delta * (4.0 if want > 0.0 else 7.0))
	if _heart_vis <= 0.001:
		if _heart:
			_heart.visible = false
		return
	if _heart == null:
		_heart = Control.new()
		_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_heart.draw.connect(_draw_heart)
		# (ほかの人の名札・吹き出し(層 1)より手前。ボタンや送るバーとは重ならない位置に出す)
		_heart_layer = CanvasLayer.new()
		_heart_layer.layer = 2
		add_child(_heart_layer)
		_heart_layer.add_child(_heart)
	_heart_t += delta
	_beat_t += delta
	_heart.visible = true
	_heart.queue_redraw()


## ハートの胸の位置(画面の下。振り向くボタン(右下)と言葉を送るバーにかからないように)
func _heart_base() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var bottom := vp.y + 10.0
	var bar := send_panel_rect()
	if bar.has_area():
		bottom = bar.position.y - 6.0
	return Vector2(vp.x * GameConfig.HEART_POP_X, bottom)


## いまのハートのまん中と大きさ(と、つぶれ・のび)
func _heart_shape() -> Array:
	var vp := get_viewport().get_visible_rect().size
	var size := lerpf(GameConfig.HEART_SIZE_FAR, GameConfig.HEART_SIZE_NEAR, _danger_level)
	var rise := lerpf(GameConfig.HEART_RISE_FAR, GameConfig.HEART_RISE_NEAR, _danger_level) * vp.y
	var base := _heart_base()
	# 1拍: 飛び出して(縦にのびる)、もどる(着いたときに横につぶれる)
	var k := clampf(_beat_t / BEAT_TIME, 0.0, 1.0)
	var p := sin(k * PI) * _beat_amp
	var land := sin(clampf((_beat_t - BEAT_TIME) / 0.12, 0.0, 1.0) * PI) * _beat_amp
	var sx := 1.0 - 0.16 * p + 0.22 * land
	var sy := 1.0 + 0.3 * p - 0.2 * land
	var scale := size * (1.0 + 0.4 * p) * _heart_vis
	var c := base + Vector2(0, -scale * 0.55 - rise * p - 6.0 * sin(_heart_t * 3.0) * _heart_vis)
	return [c, scale, sx, sy]


func _draw_heart() -> void:
	var sh := _heart_shape()
	var c: Vector2 = sh[0]
	var sz: float = sh[1]
	var sx: float = sh[2]
	var sy: float = sh[3]
	if sz < 2.0:
		return
	var pts := PackedVector2Array()
	for k in 40:
		var t := TAU * float(k) / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x * sx, -y * sy) * (sz / 34.0))
	var ink := GameConfig.COLOR_INK
	# 太い輪郭線 → 赤 → 下のほうの濃い赤 → つや
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(c + (p - c) * 1.0)
	_heart.draw_colored_polygon(pts, Color("E8364A"))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_heart.draw_polyline(loop, ink, maxf(sz * 0.07, 3.0), true)
	var shade := PackedVector2Array()
	for p in pts:
		if p.y > c.y + sz * 0.05:
			shade.append(p)
	if shade.size() >= 3:
		_heart.draw_colored_polygon(shade, Color(0.75, 0.1, 0.2, 0.35))
	_heart.draw_circle(c + Vector2(-sz * 0.24 * sx, -sz * 0.18 * sy), sz * 0.11, Color(1, 1, 1, 0.85))
	_heart.draw_circle(c + Vector2(-sz * 0.12 * sx, -sz * 0.27 * sy), sz * 0.05, Color(1, 1, 1, 0.85))


## 拍ごとに、ハートの横に「ドクン!」のマンガ文字をポンと出す(近いほど大きく)
func _heart_word() -> void:
	var sh := _heart_shape()
	var c: Vector2 = sh[0]
	var sz: float = sh[1]
	var l := UiStyle.label(tr("ドクン!"), int(lerpf(24.0, 44.0, _danger_level)), Color("E8364A"))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_heart_layer if _heart_layer else self).add_child(l)
	l.reset_size()
	var side := 1.0 if randf() < 0.6 else -1.0
	l.position = c + Vector2(side * (sz * 0.7 + 10.0) - (l.size.x if side < 0.0 else 0.0), -sz * 0.6)
	l.rotation = side * 0.18
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_property(l, "scale", Vector2.ONE, 0.06)
	tw.tween_interval(0.18)
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(l.queue_free)

## 鬼が離れた(心臓の音が止まった): ハートがシュッと戻って消えるのといっしょに、小さく「ふぅ…」
func heart_relief() -> void:
	var base := _heart_base()
	var l := UiStyle.label(tr("ふぅ…"), 30, GameConfig.COLOR_INK)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _heart_layer == null:
		return
	_heart_layer.add_child(l)
	l.reset_size()
	l.position = base + Vector2(-l.size.x * 0.5, -l.size.y - 70.0)
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(l, "position:y", l.position.y - 30.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 画面の上のまん中に、役を出す(空文字で消す)。color の地に白い文字
func set_role_badge(text: String, color: Color) -> void:
	_pill_text(_badge, text)
	_badge.visible = text != "" and not _vote_screen
	UiStyle.set_bg(_badge.get_theme_stylebox("panel") as StyleBoxFlat, color)


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

	_build_send_panel()

	_build_minion_corners()
	_badge = UiStyle.pill("", 28, true)
	(_badge.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	add_child(_badge)
	_badge.position = Vector2(UiStyle.SAFE, 72)
	_badge.visible = false


## 発表のあと: ルーム主には「次へ ▶」、ほかの人には「ルーム主が「次へ」を押すのを待っています」
func set_next_ui(show: bool, host: bool) -> void:
	if _vote_panel == null:
		if not show:
			return
		_build_vote_ui()
	if not show:
		if _next_wait:
			_next_wait.visible = false
		return
	_vote_panel.visible = false
	_skip_button.visible = host
	if _skip_button.text != tr("次へ ▶"):
		_skip_button.text = tr("次へ ▶")
	_skip_button.disabled = false
	_skip_button.modulate.a = 1.0
	if _next_wait == null:
		_next_wait = UiStyle.pill(tr("ルーム主が「次へ」を押すのを待っています"), 22)
		_next_wait.anchor_left = 0.5
		_next_wait.anchor_right = 0.5
		_next_wait.anchor_top = 1.0
		_next_wait.anchor_bottom = 1.0
		_next_wait.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_next_wait.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_next_wait.offset_bottom = -UiStyle.SAFE
		_top.add_child(_next_wait)
	_next_wait.visible = not host


## 教室のままの投票の表示。show: 投票中か / voted・total: 投票した人数 / hint: 下の小さな案内 /
## skip: ルーム主の「発表へ」を出すか / skip_ready: 押せるか(始まって5秒たったか)
## いたずらっ子!のラウンドの間、画面のすみ(右上の帯の中)に小さないたずらっ子を出しておく
var _corner_imp: PrankImp


func set_prankster(on: bool) -> void:
	if not on:
		if _corner_imp:
			_corner_imp.visible = false
		return
	if _corner_imp == null:
		_corner_imp = PrankImp.new()
		_corner_imp.custom_minimum_size = Vector2(54, 54)
		_corner_imp.size = _corner_imp.custom_minimum_size
		add_child(_corner_imp)
	var vp := get_viewport().get_visible_rect().size
	var rank_w := _rank_pill.size.x + 10.0 if _rank_pill and _rank_pill.visible else 0.0
	_corner_imp.position = Vector2(vp.x - UiStyle.SAFE - 64.0 - 14.0 - rank_w - 54.0, 10.0 + sin(Time.get_ticks_msec() / 300.0) * 2.0)
	_corner_imp.visible = not _vote_screen


## 蜃気楼!の始まり: 画面のふちが1秒ほど、弱くゆらゆらする(3D の上だけ)
var _shimmer_layer: CanvasLayer
var _shimmer: ColorRect
const SHIMMER_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float t = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = min(uv, 1.0 - uv);
	float edge = 1.0 - smoothstep(0.0, 0.18, min(d.x, d.y));
	vec2 off = vec2(sin(uv.y * 40.0 + t * 9.0), cos(uv.x * 32.0 + t * 7.0)) * 0.006 * edge * amount;
	COLOR = vec4(texture(screen_tex, uv + off).rgb, 1.0);
}
"""


func mirage_shimmer(seconds: float) -> void:
	if _shimmer_layer == null:
		_shimmer_layer = CanvasLayer.new()
		_shimmer_layer.layer = 0
		add_child(_shimmer_layer)
		_shimmer = ColorRect.new()
		_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = SHIMMER_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_shimmer.material = mat
		_shimmer_layer.add_child(_shimmer)
		_shimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shimmer.visible = true
	var mat2 := _shimmer.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat2.set_shader_parameter("amount", sin(v * PI))
		mat2.set_shader_parameter("t", v * seconds), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void: _shimmer.visible = false)


## 蜃気楼のあいだずっと: 画面(3D だけ。名札や吹き出しは見やすいまま)に薄い白いかすみと、ゆらゆらしたモヤ。
## いつからいつまで蜃気楼か分かるように。始まり・終わりは0.6秒でふわっと
var _haze_layer: CanvasLayer
var _haze: ColorRect
var _haze_amount := 0.0
var _haze_want := 0.0
const HAZE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float t = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	// ゆらゆら(下のほうほど強く。陽炎のように)
	float low = smoothstep(0.25, 1.0, uv.y);
	vec2 off = vec2(sin(uv.y * 55.0 + t * 3.2) * 0.0025, cos(uv.x * 38.0 + t * 2.4) * 0.0015) * (0.4 + low) * amount;
	vec3 c = texture(screen_tex, uv + off).rgb;
	// 白っぽいかすみ(ゆっくり流れるもやの濃淡)
	float n = sin(uv.x * 7.0 + t * 0.6) * sin(uv.y * 5.0 - t * 0.45) * 0.5 + 0.5;
	float n2 = sin(uv.x * 3.1 - t * 0.35 + sin(uv.y * 4.0 + t * 0.5)) * 0.5 + 0.5;
	float mist = (0.2 + 0.14 * n + 0.12 * n2 + 0.08 * low) * amount;
	c = mix(c, vec3(1.0, 0.97, 0.9), mist);
	COLOR = vec4(c, 1.0);
}
"""


func set_mirage_haze(on: bool) -> void:
	_haze_want = 1.0 if on else 0.0
	if _haze_want == 0.0 and _haze == null:
		return
	if _haze == null:
		_haze_layer = CanvasLayer.new()
		_haze_layer.layer = 0
		add_child(_haze_layer)
		_haze = ColorRect.new()
		_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = HAZE_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_haze.material = mat
		_haze_layer.add_child(_haze)
		_haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_haze_amount = move_toward(_haze_amount, _haze_want, get_process_delta_time() / 0.6)
	_haze.visible = _haze_amount > 0.001
	var m := _haze.material as ShaderMaterial
	m.set_shader_parameter("amount", _haze_amount)
	m.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)


## 自分の順位(右上の⚙の左に小さく「3位」。"" で消す)
var _rank_pill: PanelContainer


func set_my_rank(text: String) -> void:
	if text == "":
		if _rank_pill:
			_rank_pill.visible = false
		return
	if _rank_pill == null:
		_rank_pill = UiStyle.pill("", 20)
		add_child(_rank_pill)
	var l := _rank_pill.get_child(0) as Label
	if l.text != text:
		l.text = text
	_rank_pill.visible = not _vote_screen
	_rank_pill.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var sz := _rank_pill.get_combined_minimum_size()
	# (⚙ボタンの左。画面の上の帯の中)
	_rank_pill.position = Vector2(vp.x - UiStyle.SAFE - 64.0 - 12.0 - sz.x, 18.0)


## ラウンドの合間の順位と点数の一覧(2〜3秒。タップで早く閉じる)。
## rows: [{"rank", "name", "score", "move": 1(上がった)/-1(下がった)/0, "me", "color"}](順位の順)。sub: 下の小さな一文
var _standings: PanelContainer
var _standings_tween: Tween


func show_standings(title: String, rows: Array, sub: String, seconds: float) -> void:
	_announce(_show_standings.bind(title, rows, sub, seconds), seconds + 0.35, 0)


func _show_standings(title: String, rows: Array, sub: String, seconds: float) -> void:
	hide_standings()
	_standings = PanelContainer.new()
	_standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color(1, 1, 1, 0.95), true, 22, 4)
	st.set_content_margin_all(16)
	_standings.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	_standings.add_child(col)
	var t := UiStyle.label(title, 28, GameConfig.COLOR_INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	# 10人でも横画面に入るように、6人より多ければ2列
	var grid := GridContainer.new()
	grid.columns = 2 if rows.size() > 6 else 1
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	for r in rows:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		var ink := Color("D9480F") if r.get("me", false) else GameConfig.COLOR_INK
		var rk := UiStyle.label(tr("%d位") % int(r["rank"]), 22, ink)
		rk.custom_minimum_size = Vector2(52, 0)
		line.add_child(rk)
		var dot := ColorRect.new()
		dot.color = r.get("color", Color.WHITE)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var nm := UiStyle.label(str(r["name"]), 22, ink)
		nm.custom_minimum_size = Vector2(150, 0)
		line.add_child(nm)
		var sc := UiStyle.label(tr("%d点") % int(r["score"]), 22, ink)
		sc.custom_minimum_size = Vector2(56, 0)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(sc)
		var mv := int(r.get("move", 0))
		var arrow := UiStyle.label("↑" if mv > 0 else ("↓" if mv < 0 else ""), 18, Color("2E9E5B") if mv > 0 else Color("C92A2A"))
		arrow.custom_minimum_size = Vector2(16, 0)
		line.add_child(arrow)
		grid.add_child(line)
	if sub != "":
		var sl := UiStyle.label(sub, 18, GameConfig.COLOR_INK.lightened(0.3))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sl)
	_top.add_child(_standings)
	UiStyle.center(_standings)
	_standings_tween = create_tween()
	_standings_tween.tween_interval(seconds)
	_standings_tween.tween_property(_standings, "modulate:a", 0.0, 0.3)
	_standings_tween.tween_callback(hide_standings)


func hide_standings() -> void:
	# (タップで早く閉じたら、次のお知らせをすぐ出す)
	if _standings and is_instance_valid(_standings):
		_ann_until = mini(_ann_until, Time.get_ticks_msec())
	if _standings_tween and _standings_tween.is_valid():
		_standings_tween.kill()
	if _standings and is_instance_valid(_standings):
		_standings.queue_free()
	_standings = null


func is_standings_open() -> bool:
	return _standings != null and is_instance_valid(_standings)


## 画面の上の「UI 専用の帯」の下のふち(ラウンド・落とし物・点数・「あなたは鬼の手下」などの札が出ている範囲)。
## 名札や言葉の吹き出しは、この帯に入らないように下に押し下げる。投票の間は「鬼の手下は誰?」の枠も帯に入れる
func top_band_bottom() -> float:
	var bottom := 0.0
	for c in [_round_pill.get_parent() if _round_pill else null, _badge, _milk_pill, _vote_panel, _rank_pill]:
		var ctl := c as Control
		if ctl and ctl.is_visible_in_tree():
			bottom = maxf(bottom, ctl.get_global_rect().end.y)
	return bottom


## 「発表へ」「次へ」のボタンの画面の範囲(出ていなければ空)。名札や吹き出しをそこに置かないため
func vote_button_rect() -> Rect2:
	if _skip_button and _skip_button.visible:
		return _skip_button.get_global_rect().grow(6.0)
	return Rect2()


## 投票の前の「振り返り」の字幕(画面の下のまん中に大きく。"" で消す。seconds > 0 ならその秒数で消える)
var _caption: PanelContainer
var _caption_tween: Tween


func set_caption(text: String, seconds: float = 0.0) -> void:
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	if text == "":
		if _caption:
			_caption.visible = false
		return
	if _caption == null:
		_caption = PanelContainer.new()
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := UiStyle.box(Color(1, 1, 1, 0.95), true, 22, 4)
		st.content_margin_left = 28
		st.content_margin_right = 28
		st.content_margin_top = 6
		st.content_margin_bottom = 10
		_caption.add_theme_stylebox_override("panel", st)
		_caption.add_child(UiStyle.label("", 34, GameConfig.COLOR_INK))
		_top.add_child(_caption)
	var l := _caption.get_child(0) as Label
	l.text = text
	l.add_theme_font_size_override("font_size", UiStyle.fit_size(text, 34, get_viewport().get_visible_rect().size.x - 120.0, 20))
	_caption.visible = true
	_caption.modulate.a = 1.0
	_caption.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var sz := _caption.get_combined_minimum_size()
	# (「発表へ」「次へ」のボタンが出ているときは、その上に)
	var lift := 100.0 if _skip_button and _skip_button.visible else 40.0
	_caption.position = Vector2((vp.x - sz.x) / 2.0, vp.y - sz.y - lift)
	if seconds > 0.0:
		_caption_tween = create_tween()
		_caption_tween.tween_interval(seconds)
		_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.3)
		_caption_tween.tween_callback(func() -> void: _caption.visible = false)


## 投票の画面: ラウンド・落とし物・点数・役のいつもの札を隠す(上は「鬼の手下は誰?」の枠だけ)
var _vote_screen := false


func set_vote_screen(on: bool) -> void:
	_vote_screen = on
	if _rank_pill and on:
		_rank_pill.visible = false
	if _round_pill:
		_round_pill.get_parent().visible = not on
	if _badge and on:
		_badge.visible = false


## 上の枠の下のふち(画面の y。枠がなければ 0)。名前のラベルはこれより下に置く
func vote_panel_bottom() -> float:
	if _vote_panel == null or not _vote_panel.visible:
		return 0.0
	return _vote_panel.get_global_rect().end.y


func set_vote_ui(show: bool, voted: int = 0, total: int = 0, hint: String = "", skip: bool = false, skip_ready: bool = false,
		count_visible := true) -> void:
	if _vote_box == null:
		if not show:
			return
		_build_vote_ui()
	_vote_panel.visible = show
	_skip_button.visible = show and skip
	if not show:
		return
	if _skip_button.text != tr("発表へ ▶"):
		_skip_button.text = tr("発表へ ▶")
	# 3行目(小さく): 「3/9人 投票済み」と、ひとことの案内
	var count_text := tr("%d/%d人 投票済み") % [voted, total]
	if hint != "":
		count_text += "  ・  " + hint
	if _vote_count.text != count_text:
		_vote_count.text = count_text
		_vote_count.add_theme_font_size_override("font_size", UiStyle.fit_size(count_text, 20, minf(get_viewport().get_visible_rect().size.x - 120.0, 1100.0), 14))
	_vote_count.visible = count_visible
	if _skip_button.disabled == skip_ready:
		_skip_button.disabled = not skip_ready
		_skip_button.modulate.a = 1.0 if skip_ready else 0.5


## 投票の画面の上に出す、ただ1つの枠: 「鬼の手下は誰?」(大きく)/ 「3/8人 投票済み」(小さく)。
## 画面の上のまん中(撮影モードでも同じ枠を使う)
static func make_vote_frame() -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(Color(1, 1, 1, 0.94), true, 20, 4)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 2
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 8
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := UiStyle.label(TranslationServer.translate("鬼の手下は誰?"), 42, Color(0.55, 0.2, 0.7))
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var count := UiStyle.label("", 24, GameConfig.COLOR_INK.lightened(0.2))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)
	return {"panel": panel, "box": box, "title": title, "count": count}


func _build_vote_ui() -> void:
	var f := make_vote_frame()
	var panel: PanelContainer = f["panel"]
	_top.add_child(panel)
	_vote_panel = panel
	_vote_box = f["box"]
	_vote_title = f["title"]
	_vote_count = f["count"]
	_skip_button = Button.new()
	_skip_button.text = tr("発表へ ▶")
	_skip_button.custom_minimum_size = Vector2(240, 66)
	UiStyle.button(_skip_button, true, 28)
	_skip_button.pressed.connect(func() -> void: skip_vote_pressed.emit())
	# (画面の右下。まん中だと、手前の人の名札や吹き出しが隠れるので)
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_top = 1.0
	_skip_button.anchor_bottom = 1.0
	_skip_button.offset_left = -240 - UiStyle.SAFE
	_skip_button.offset_right = -UiStyle.SAFE
	_skip_button.offset_top = -66 - UiStyle.SAFE
	_skip_button.offset_bottom = -UiStyle.SAFE
	_skip_button.visible = false
	_top.add_child(_skip_button)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
