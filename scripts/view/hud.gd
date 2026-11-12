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
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
## 送った人の色の丸
var _slot_dots: Array[StyleBoxFlat] = []
var _slot_senders: Array[Label] = []
var _slot_icons: Array[StampIcon] = []
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
var _extra_pill: PanelContainer
## ラウンドが終わったときの結果カード(全員の点数もここに出す。手下がばれないように、ふだんは出さない)
var _result_card: PanelContainer
var _next_button: Button


func _ready() -> void:
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
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false


## 説明文(いまは出さない)
func set_help(text: String) -> void:
	_help.text = text


## 左上の札。extra が "" なら3つ目は出さない
func set_round_info(round_text: String, item_text: String, extra_text: String) -> void:
	_pill_text(_round_pill, round_text)
	_pill_text(_item_pill, item_text)
	_pill_text(_extra_pill, extra_text)
	_extra_pill.visible = extra_text != ""


## 結果カードを出す。
## title: 大きい見出し / sub: その下の一言 / notes: 小さい札(がまん・手下の発表など)/ color: 見出しの色 /
## rows: [{"name", "color", "score", "delta", "me", "mark"}](この順に並べる)/ footer: いちばん下の案内
## next_label: 「次へ」ボタンの文字("" なら出さない。ホストとひとりのときだけ出す)
func show_result_card(title: String, sub: String, notes: Array, color: Color, rows: Array, footer: String,
		next_label: String = "") -> void:
	hide_result_card()
	_result_card = PanelContainer.new()
	_result_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 28, 5)
	st.shadow_offset = Vector2(6, 8)
	st.set_content_margin_all(22)
	_result_card.add_theme_stylebox_override("panel", st)
	add_child(_result_card)
	_result_card.custom_minimum_size = Vector2(560, 0)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
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
	# 全員の点数(2列)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for r in rows:
		grid.add_child(_score_row(r))
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


func hide_result_card() -> void:
	if _result_card:
		_result_card.queue_free()
		_result_card = null
		_next_button = null


## 結果カードの「次へ」: キーボードの R と同じ操作を送る
func _press_next() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "restart"
		ev.pressed = pressed
		Input.parse_input_event(ev)


## スマホの指: 結果カードの「次へ」をタップしたら押す
func _input(event: InputEvent) -> void:
	if _next_button == null or not event is InputEventScreenTouch or not event.pressed:
		return
	if _next_button.is_visible_in_tree() and _next_button.get_global_rect().has_point(event.position):
		_press_next()
		get_viewport().set_input_as_handled()


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
	h.add_child(UiStyle.label("%d点" % r["score"], 18, GameConfig.COLOR_INK))
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
	row.add_child(_round_pill)
	row.add_child(_item_pill)
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


## 自分に届いているスタンプを並べる。list: [{"kind", "item", "sender", "sender_color"}](届いた順)
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
		# 白い札に「●送った人  [スタンプの絵]」。丸は送った人の体の色
		_slot_icons[i].kind = st["kind"]
		_slot_icons[i].item = st["item"]
		_slot_senders[i].text = st["sender"]
		_slot_dots[i].bg_color = st["sender_color"]
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

	var ink := Color(0.12, 0.12, 0.14)
	for i in GameConfig.STAMP_SLOTS:
		# 白くて丸い札。黒いふちと、下にずらした影
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = ink
		style.set_border_width_all(4)
		style.set_corner_radius_all(16)
		style.shadow_color = ink
		style.shadow_size = 1
		style.shadow_offset = Vector2(3, 5)
		style.content_margin_left = 10
		style.content_margin_right = 14
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", style)
		slot.visible = false
		col.add_child(slot)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		slot.add_child(row)
		# 送った人の体の色の丸
		var dot_style := StyleBoxFlat.new()
		dot_style.set_corner_radius_all(18)
		dot_style.border_color = ink
		dot_style.set_border_width_all(3)
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(34, 34)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", dot_style)
		row.add_child(dot)
		# 送った人の名前
		var sender := _make_label(20, ink)
		sender.add_theme_constant_override("outline_size", 0)
		sender.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sender.custom_minimum_size = Vector2(96, 0)
		sender.clip_text = true
		row.add_child(sender)
		# スタンプの絵(落とし物アイコン+記号)
		var icon := StampIcon.make(Stamps.DROPPED, 0, 52.0)
		row.add_child(icon)
		_slots.append(slot)
		_slot_styles.append(style)
		_slot_dots.append(dot_style)
		_slot_senders.append(sender)
		_slot_icons.append(icon)

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
