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
var _slot_texts: Array[Label] = []
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
## 右上: 全員の点数
var _score_box: VBoxContainer
var _score_rows: Array = []
var _score_key := ""


func _ready() -> void:
	# 説明文は出さない(A案: 文字は札とボタンだけ)。古い呼び出しのために部品だけ残す
	_help = _make_label(22, GameConfig.COLOR_INK)
	_help.visible = false
	add_child(_help)
	_build_info_pills()
	_build_scoreboard()

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


## 右上の点数の表。rows: [{"name", "color", "score", "me"}](点数の多い順に並べて出す)
func show_scores(rows: Array) -> void:
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a, b): return a["score"] > b["score"])
	var key := str(sorted)
	if key == _score_key:
		return
	_score_key = key
	for i in _score_rows.size():
		var row: Dictionary = _score_rows[i]
		var panel: PanelContainer = row["panel"]
		panel.visible = i < sorted.size()
		if not panel.visible:
			continue
		var r: Dictionary = sorted[i]
		(row["dot"].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = r["color"]
		row["name"].text = r["name"]
		row["score"].text = "%d点" % r["score"]
		# 自分の行はオレンジのふち
		(panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = GameConfig.COLOR_ACCENT if r["me"] else GameConfig.COLOR_INK


func _pill_text(p: PanelContainer, text: String) -> void:
	(p.get_child(0) as Label).text = text


func _build_info_pills() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(16, 14)
	add_child(row)
	_round_pill = UiStyle.pill("ラウンド 1/5", 24, true)
	_item_pill = UiStyle.pill("いまの落とし物:ハンカチ", 24)
	_extra_pill = UiStyle.pill("", 24)
	row.add_child(_round_pill)
	row.add_child(_item_pill)
	row.add_child(_extra_pill)


func _build_scoreboard() -> void:
	_score_box = VBoxContainer.new()
	_score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_box.add_theme_constant_override("separation", 6)
	add_child(_score_box)
	_score_box.anchor_left = 1.0
	_score_box.anchor_right = 1.0
	_score_box.offset_left = -236
	_score_box.offset_right = -16
	_score_box.offset_top = 96
	for i in GameConfig.SEAT_COUNT + 1:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 12, 3)
		st.content_margin_top = 1
		st.content_margin_bottom = 2
		st.content_margin_left = 8
		st.content_margin_right = 10
		panel.add_theme_stylebox_override("panel", st)
		panel.visible = false
		_score_box.add_child(panel)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 6)
		panel.add_child(h)
		var d := UiStyle.dot(Color.WHITE, 20)
		h.add_child(d)
		var n := UiStyle.label("", 18, GameConfig.COLOR_INK)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		h.add_child(n)
		var sc := UiStyle.label("", 18, GameConfig.COLOR_INK)
		h.add_child(sc)
		_score_rows.append({"panel": panel, "dot": d, "name": n, "score": sc})


## 画面中央に大きく表示する。seconds 秒で消える(0 なら消さない)。
func show_message(text: String, outline: Color, seconds: float) -> void:
	_message.text = text
	_message.add_theme_color_override("font_outline_color", outline)
	_message.visible = true
	_message_left = seconds if seconds > 0.0 else INF


func hide_message() -> void:
	_message.visible = false
	_message_left = 0.0


## 自分に届いているスタンプを並べる。list: [{"text", "color", "sender", "sender_color"}](届いた順)
func show_my_stamps(list: Array) -> void:
	var keys := []
	for i in _slots.size():
		var box := _slots[i]
		if i >= list.size():
			box.visible = false
			continue
		var st: Dictionary = list[i]
		var key := "%s|%s" % [st["sender"], st["text"]]
		keys.append(key)
		# 白い札に「●送った人  !落ちてる」。丸は送った人の体の色、文字はスタンプの色
		var stamp_color: Color = st["color"]
		_slot_texts[i].text = "%s %s" % [st.get("mark", ""), st["text"]]
		_slot_texts[i].add_theme_color_override("font_color", stamp_color.darkened(0.2))
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
	_my_box.offset_left = 20
	_my_box.offset_right = 360
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
		# スタンプ(「!落ちてる」「○まだ平気」)
		var text := _make_label(32, ink)
		text.add_theme_constant_override("outline_size", 0)
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(text)
		_slots.append(slot)
		_slot_styles.append(style)
		_slot_dots.append(dot_style)
		_slot_senders.append(sender)
		_slot_texts.append(text)

	_badge = UiStyle.pill("", 24, true)
	(_badge.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	add_child(_badge)
	_badge.position = Vector2(16, 72)
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
