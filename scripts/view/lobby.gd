class_name Lobby
extends CanvasLayer
## 最初の画面: 名前と体の色を決めて、「ひとりで遊ぶ」「部屋を作る」「部屋に入る」。
## 部屋に入るときは、4桁の合言葉を数字ボタンで入れる(スマホでもキーボードいらず)。
## 画面の表示とボタンだけ。つなぐ処理は NetSession、試合を始めるのは main がやる。

signal solo_pressed
signal host_pressed
signal join_pressed(code: String)
signal start_pressed
## 言語ボタン(日本語 ⇔ English)。切りかえは main がする(画面全体の文字を作り直すため)
signal language_pressed
## 名前・色・小物・スタンプの言葉が変わった(オンラインのときは、ホストに送り直す)
signal profile_changed

var _panel: PanelContainer
var _title: Label
var _status: Label
var _code_label: Label
var _players_label: Label
var _menu: VBoxContainer
var _join_box: VBoxContainer
var _host_box: VBoxContainer
var _code := ""
## 遊ぶ人数(鬼をふくむ全員の数)。ひとりで遊ぶとき・部屋を作るときに使う
var players: int = GameConfig.PLAYER_COUNT_DEFAULT
## 人数の「− 8人 +」
var _players_label_btn: Label
var _players_minus: Button
var _players_plus: Button
## 舞台(タップで変える。この端末に保存)
var _stage_button: Button
## スマホの指で押せるように、ボタンは自分で当たり判定をする
var _buttons: Array[Button] = []
## 名前と色(Profile に保存する)
var _name_button: Button
var _name_edit: LineEdit
var _code_edit: LineEdit
var _color_buttons: Array[Button] = []
## スタンプの言葉を変える画面(言葉のボタン/入力欄と、「ほかの人の自作の言葉」の切りかえ)
var _words_box: VBoxContainer
## ロビーに出す、今の3つのスタンプの言葉(次の試合で使う)
var _words_label: Label
var _word_buttons := {}
var _word_edits := {}
var _hide_words_button: Button
var _lang_button: Button
var _volume_box: VBoxContainer
var _volume_panel: VolumePanel
var _preview: Panel
## ブラウザ版の入力の窓(ページを止めないので、入力している間も音が止まらない)
var _web_input: WebInput
## 小物の画面(見本のキャラと、小物ごとの形・色のボタン)
var _acc_box: VBoxContainer
## 宣伝用: ボットの名前を決める画面(開発用。GameConfig.SHOW_PHOTO_MODE のときだけ)
var _bots_box: VBoxContainer
var _bot_edits: Array = []
## 題名・イヤホンの案内など(きせかえの画面では、場所をあけるために隠す)
var _header: Array[Control] = []
var _acc_preview: AccessoryPreview
## 小物の形のボタン(slot -> {kind("" = なし) -> Button})と色のボタン(slot -> [Button])
var _acc_kind_buttons := {}
var _acc_color_buttons := {}


func _ready() -> void:
	layer = 10
	_web_input = WebInput.new()
	add_child(_web_input)
	Profile.load_saved()
	# 言語: 自分で選んだ言語、なければ端末の言語
	Locale.setup(Profile.lang)
	var bg := ColorRect.new()
	var sky := GameConfig.COLOR_SKY
	sky.a = 1.0
	bg.color = sky
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.offset_left = -430
	root.offset_right = 430
	root.offset_top = -350
	root.offset_bottom = 350

	_title = _label("うしろ見ちゃダメ!", 56)
	root.add_child(_title)
	_header.append(_title)
	# 音が手がかりになるゲームなので、イヤホンをすすめる
	var phones := _label("🎧 イヤホン推奨", 22)
	root.add_child(phones)
	_header.append(phones)
	# GPU を使えていないブラウザ: 重くなる理由と、直し方を出す
	if Device.light_mode():
		var note := _label("このブラウザは GPU を使っていないので重くなります(軽い動きにしています)。\nChrome の設定 → システム →「グラフィック アクセラレーションが使用可能な場合は使用する」をオンにすると軽くなります", 18)
		note.add_theme_color_override("font_color", Color("B4372B"))
		root.add_child(note)
		_header.append(note)
	_status = _label("", 22)
	root.add_child(_status)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	root.add_child(_menu)
	_build_menu_summary(_menu)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	_menu.add_child(row2)
	# 今の3つのスタンプの言葉と、「シャッフル」(押すとその場で引き直す。何度でも)
	var words_panel := PanelContainer.new()
	words_panel.add_theme_stylebox_override("panel", UiStyle.box(GameConfig.COLOR_PAPER, false, 16, 3))
	words_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(words_panel)
	_words_label = _label("", 22)
	_words_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	words_panel.add_child(_words_label)
	row2.add_child(_button("シャッフル", func() -> void: _shuffle_words(), Vector2(150, 58), true))
	# 言語の切りかえ(どの言語の人にもわかるように、地球の印と言語の名前で)
	_lang_button = _button("", func() -> void: language_pressed.emit(), Vector2(190, 58))
	row2.add_child(_lang_button)
	row2.add_child(_button("🔊", func() -> void: _show_volume(), Vector2(90, 58)))
	_update_language_button()
	# 大きいボタンを2列に(押しやすいように)
	var menu_grid := GridContainer.new()
	menu_grid.columns = 2
	menu_grid.add_theme_constant_override("h_separation", 16)
	menu_grid.add_theme_constant_override("v_separation", 16)
	_menu.add_child(menu_grid)
	var big := Vector2(0, 110)
	var solo := _button("ひとりで遊ぶ", func() -> void: solo_pressed.emit(), big, true)
	solo.add_theme_font_size_override("font_size", 36)
	menu_grid.add_child(solo)
	# 人数と舞台(上下に半分ずつ)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	menu_grid.add_child(opts)
	var half := Vector2(0, (big.y - 10.0) / 2.0)
	# 人数: 「−」「+」で1人ずつ(5〜10人)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	opts.add_child(prow)
	_players_minus = _button("−", func() -> void: _change_players(-1), Vector2(64, half.y))
	prow.add_child(_players_minus)
	var mid := PanelContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_stylebox_override("panel", UiStyle.box(GameConfig.COLOR_PAPER, false, 14, 3))
	_players_label_btn = UiStyle.label("", 26, GameConfig.COLOR_INK)
	_players_label_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_label_btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.add_child(_players_label_btn)
	prow.add_child(mid)
	_players_plus = _button("+", func() -> void: _change_players(1), Vector2(64, half.y))
	prow.add_child(_players_plus)
	_stage_button = _button("", func() -> void: _toggle_stage(), half)
	opts.add_child(_stage_button)
	_update_players_button()
	_update_stage_button()
	menu_grid.add_child(_button("部屋を作る\n(ホスト)", func() -> void: host_pressed.emit(), big))
	menu_grid.add_child(_button("部屋に入る\n(合言葉)", func() -> void: _show_join(), big))
	for b in menu_grid.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 10)
	root.add_child(_join_box)
	_code_label = _label("合言葉: ____", 44)
	_join_box.add_child(_code_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_join_box.add_child(grid)
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "けす", "0", "入る"]:
		var digit: String = d
		grid.add_child(_button(digit, func() -> void: _on_key(digit), Vector2(270, 76)))
	_join_box.add_child(_button("もどる", func() -> void: show_menu(), Vector2(0, 70)))

	_build_words_box(root)
	_build_acc_box(root)
	if GameConfig.SHOW_PHOTO_MODE:
		_build_bots_box(root)
	# 音量の画面(全体・BGM・効果音)
	_volume_box = VBoxContainer.new()
	_volume_box.add_theme_constant_override("separation", 14)
	root.add_child(_volume_box)
	_volume_panel = VolumePanel.new()
	_volume_box.add_child(_volume_panel)
	_volume_box.add_child(_button("もどる", func() -> void: show_menu(), Vector2(0, 64), true))

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 12)
	root.add_child(_host_box)
	_players_label = _label("", 26)
	_host_box.add_child(_players_label)
	_host_box.add_child(_button("スタート", func() -> void: start_pressed.emit(), Vector2(0, 100), true))

	show_menu()
	# 小物の画面の見本のキャラは、ここで1回だけ作っておく(開くたびに作ると重くて音が止まるので)
	_acc_preview.prepare(Profile.color, Profile.accessories)
	_acc_preview.warm_up()
	# ほかの画面(ボタン)が先にできていても、決まった言語の文字の長さで大きさを合わせ直す
	UiStyle.refit_all()


## ロビーのいちばん上: 自分の色の丸と名前(見るだけ)と、「きせかえ」のボタン
var _menu_dot: Panel
var _menu_name: Label


func _build_menu_summary(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	_menu_dot = UiStyle.dot(Profile.color, 56)
	row.add_child(_menu_dot)
	_menu_name = _label("", 30)
	_menu_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_menu_name)
	var dress := _button("きせかえ ▶", func() -> void: _show_acc(), Vector2(260, 64), true)
	row.add_child(dress)


## 名前(タップで入力)と、体の色(10色+カラーコード)。「きせかえ」の画面の上に出す
func _build_profile_rows(parent: VBoxContainer) -> void:
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	parent.add_child(name_row)
	_preview = UiStyle.dot(Profile.color, 44)
	name_row.add_child(_preview)
	if OS.has_feature("web"):
		# ブラウザ: 画面に重ねる入力の窓で聞く(WebInput)
		_name_button = _button("", func() -> void: _ask_name(), Vector2(0, 52))
		_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(_name_button)
	else:
		_name_edit = LineEdit.new()
		_name_edit.text = Profile.player_name
		_name_edit.max_length = Profile.NAME_MAX
		_name_edit.placeholder_text = "なまえ"
		_name_edit.custom_minimum_size = Vector2(0, 52)
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.add_theme_font_override("font", HudFont.get_font())
		_name_edit.add_theme_font_size_override("font_size", 30)
		_name_edit.add_theme_stylebox_override("normal", UiStyle.box(GameConfig.COLOR_PAPER))
		_name_edit.add_theme_stylebox_override("focus", UiStyle.box(GameConfig.COLOR_PAPER))
		_name_edit.add_theme_color_override("font_color", GameConfig.COLOR_INK)
		_name_edit.text_changed.connect(func(t: String) -> void: _set_name(t))
		name_row.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	color_row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(color_row)
	for c in Profile.COLORS:
		var col: Color = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _set_color(col))
		color_row.add_child(b)
		_buttons.append(b)
		_color_buttons.append(b)
	if OS.has_feature("web"):
		color_row.add_child(_button("#", func() -> void: _ask_color(), Vector2(56, 38)))
	else:
		_code_edit = LineEdit.new()
		_code_edit.placeholder_text = "#4D96FF"
		_code_edit.custom_minimum_size = Vector2(110, 38)
		_code_edit.add_theme_font_override("font", HudFont.get_font())
		_code_edit.add_theme_font_size_override("font_size", 22)
		_code_edit.text_submitted.connect(func(t: String) -> void: _set_color(Profile.parse_color(t, Profile.color)))
		color_row.add_child(_code_edit)
	_update_profile()


## きせかえの画面: 左に見本のキャラ、右に名前・体の色と、小物ごとの「なし/形」のボタンと色のボタン(全部同時につけられる)
func _build_acc_box(root: VBoxContainer) -> void:
	_acc_box = VBoxContainer.new()
	_acc_box.add_theme_constant_override("separation", 10)
	_acc_box.visible = false
	root.add_child(_acc_box)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	_acc_box.add_child(body)
	_acc_preview = AccessoryPreview.new()
	body.add_child(_acc_preview)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(col)
	# 名前と体の色も、ここで変える
	_build_profile_rows(col)
	for sl in Accessories.SLOTS:
		var slot: String = sl
		# 1行目: 小物の名前と色のボタン/2行目: 「なし」と形のボタン
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		col.add_child(crow)
		var name_l := _label(Accessories.SLOT_NAMES[slot], 24)
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crow.add_child(name_l)
		_acc_color_buttons[slot] = []
		for i in Accessories.COLORS.size():
			var idx: int = i
			var cb := Button.new()
			cb.custom_minimum_size = Vector2(34, 34)
			cb.focus_mode = Control.FOCUS_NONE
			cb.pressed.connect(func() -> void: AudioDirector.click())
			cb.pressed.connect(func() -> void: _set_acc_color(slot, idx))
			crow.add_child(cb)
			_buttons.append(cb)
			_acc_color_buttons[slot].append(cb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		_acc_kind_buttons[slot] = {}
		var kinds: Array = [""] + Accessories.KINDS[slot]
		for k in kinds:
			var kind: String = k
			var label: String = "なし" if kind == "" else Accessories.KIND_NAMES[kind]
			var b := _button(label, func() -> void: _set_acc(slot, kind), Vector2(130, 50))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			_acc_kind_buttons[slot][kind] = b
	# 下: 自作のスタンプの言葉を作る画面へ/もどる
	var acc_bottom := HBoxContainer.new()
	acc_bottom.add_theme_constant_override("separation", 12)
	_acc_box.add_child(acc_bottom)
	var make_words := _button("スタンプの言葉を自分で作る ▶", func() -> void: _show_words(), Vector2(0, 60))
	make_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc_bottom.add_child(make_words)
	if GameConfig.SHOW_PHOTO_MODE:
		var bots := _button("ボットの名前(宣伝用) ▶", func() -> void: _show_bots(), Vector2(0, 60))
		bots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acc_bottom.add_child(bots)
	var acc_back := _button("もどる", func() -> void: show_menu(), Vector2(0, 60), true)
	acc_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc_bottom.add_child(acc_back)


## 宣伝用: ボット1〜9の名前(空ならふつうの「ボット1」など)。次に始める試合から使う
func _build_bots_box(root: VBoxContainer) -> void:
	_bots_box = VBoxContainer.new()
	_bots_box.add_theme_constant_override("separation", 8)
	_bots_box.visible = false
	root.add_child(_bots_box)
	_bots_box.add_child(_label(tr("ボットの名前(宣伝用・開発用。空ならふつうの名前。次の試合から)"), 22))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_bots_box.add_child(grid)
	_bot_edits.clear()
	for i in Profile.BOT_NAME_SLOTS:
		var slot := i
		if OS.has_feature("web"):
			var b := _button("", func() -> void: _ask_bot_name(slot), Vector2(250, 56))
			grid.add_child(b)
			_bot_edits.append(b)
		else:
			var e := LineEdit.new()
			e.max_length = Profile.NAME_MAX
			e.placeholder_text = "ボット%d" % (slot + 1)
			e.custom_minimum_size = Vector2(250, 56)
			e.add_theme_font_override("font", HudFont.get_font())
			e.add_theme_font_size_override("font_size", 26)
			e.add_theme_stylebox_override("normal", UiStyle.box(GameConfig.COLOR_PAPER))
			e.add_theme_stylebox_override("focus", UiStyle.box(GameConfig.COLOR_PAPER))
			e.add_theme_color_override("font_color", GameConfig.COLOR_INK)
			e.text_submitted.connect(func(t: String) -> void: _set_bot_name(slot, t))
			e.focus_exited.connect(func() -> void: _set_bot_name(slot, e.text))
			grid.add_child(e)
			_bot_edits.append(e)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_bots_box.add_child(bottom)
	var clear := _button("全部ふつうの名前にもどす", func() -> void: _clear_bot_names(), Vector2(0, 60))
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(clear)
	var back := _button("もどる", func() -> void: _show_acc(), Vector2(0, 60), true)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(back)


func _show_bots() -> void:
	show_menu()
	_menu.visible = false
	_bots_box.visible = true
	_update_bot_names()


func _ask_bot_name(slot: int) -> void:
	var names := Profile.clean_bot_names(Profile.bot_names)
	_web_input.ask(tr("ボット%dの名前(空ならふつうの名前)") % (slot + 1), str(names[slot]), Profile.NAME_MAX,
			func(t: String) -> void: _set_bot_name(slot, t))


func _set_bot_name(slot: int, text: String) -> void:
	var names := Profile.clean_bot_names(Profile.bot_names)
	names[slot] = Profile.clean_name(text) if text.strip_edges() != "" else ""
	Profile.bot_names = names
	Profile.save()
	_update_bot_names()


func _clear_bot_names() -> void:
	Profile.bot_names = []
	Profile.save()
	_update_bot_names()


func _update_bot_names() -> void:
	var names := Profile.clean_bot_names(Profile.bot_names)
	for i in _bot_edits.size():
		var n: String = names[i]
		if _bot_edits[i] is LineEdit:
			var e := _bot_edits[i] as LineEdit
			if not e.has_focus():
				e.text = n
		else:
			(_bot_edits[i] as Button).text = n if n != "" else tr("ボット%d") % (i + 1)


func _show_acc() -> void:
	show_menu()
	_menu.visible = false
	_acc_box.visible = true
	for h in _header:
		h.visible = false
	_acc_preview.prepare(Profile.color, Profile.accessories)
	_acc_preview.set_active(true)
	_update_acc()


func _hide_acc() -> void:
	for h in _header:
		h.visible = true
	if _bots_box:
		_bots_box.visible = false
	if _acc_box:
		_acc_box.visible = false
		_acc_preview.set_active(false)


func _set_acc(slot: String, kind: String) -> void:
	var a := Accessories.clean(Profile.accessories)
	a[slot] = kind
	Profile.accessories = a
	Profile.save()
	_acc_preview.set_accessories(a)
	_update_acc()
	profile_changed.emit()


func _set_acc_color(slot: String, idx: int) -> void:
	var a := Accessories.clean(Profile.accessories)
	a[slot + "_c"] = idx
	# 色を選んだら、つけていなければつける(いちばん目の形)
	if a[slot] == "":
		a[slot] = Accessories.KINDS[slot][0]
	Profile.accessories = a
	Profile.save()
	_acc_preview.set_accessories(a)
	_update_acc()
	profile_changed.emit()


## 選んでいる形のボタンはオレンジ、選んでいる色は太いふち
func _update_acc() -> void:
	var a := Accessories.clean(Profile.accessories)
	for slot in _acc_kind_buttons:
		for kind in _acc_kind_buttons[slot]:
			var b: Button = _acc_kind_buttons[slot][kind]
			UiStyle.button(b, a[slot] == kind, 28)
		var list: Array = _acc_color_buttons[slot]
		for i in list.size():
			var c: Color = Accessories.COLORS[i]
			var chosen := int(a[slot + "_c"]) == i
			var st := UiStyle.box(c, false, 20, 5 if chosen else 2)
			st.border_color = GameConfig.COLOR_ACCENT if chosen else GameConfig.COLOR_INK
			for k in ["normal", "hover", "pressed", "hover_pressed"]:
				(list[i] as Button).add_theme_stylebox_override(k, st)
	UiStyle.refit_all()


## スタンプの言葉を変える画面: 絵文字は決まっていて、言葉だけ変えられる(6文字まで・使えない言葉はチェック)
func _build_words_box(root: VBoxContainer) -> void:
	_words_box = VBoxContainer.new()
	_words_box.add_theme_constant_override("separation", 10)
	root.add_child(_words_box)
	_words_box.add_child(_label(tr("スタンプの言葉(%d文字まで。絵文字は変わりません)") % WordFilter.MAX_LEN, 24))
	for k in Stamps.ALL:
		var kind: String = k
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_words_box.add_child(row)
		var emoji := _label(Texts.STAMP_EMOJI[kind], 44)
		emoji.custom_minimum_size = Vector2(70, 0)
		row.add_child(emoji)
		if OS.has_feature("web"):
			# スマホのブラウザ: ブラウザの入力ダイアログで聞く(名前と同じ)
			var b := _button("", func() -> void: _ask_word(kind), Vector2(0, 64))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			_word_buttons[kind] = b
		else:
			var e := LineEdit.new()
			e.max_length = WordFilter.MAX_LEN
			e.placeholder_text = Profile.my_stamp_word(kind)
			e.custom_minimum_size = Vector2(0, 64)
			e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			e.add_theme_font_override("font", HudFont.get_font())
			e.add_theme_font_size_override("font_size", 30)
			e.add_theme_stylebox_override("normal", UiStyle.box(GameConfig.COLOR_PAPER))
			e.add_theme_stylebox_override("focus", UiStyle.box(GameConfig.COLOR_PAPER))
			e.add_theme_color_override("font_color", GameConfig.COLOR_INK)
			e.text_submitted.connect(func(t: String) -> void: _set_word(kind, t))
			e.focus_exited.connect(func() -> void: _set_word(kind, e.text))
			row.add_child(e)
			_word_edits[kind] = e
	_hide_words_button = _button("", func() -> void: _toggle_hide_words(), Vector2(0, 60))
	_words_box.add_child(_hide_words_button)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_words_box.add_child(bottom)
	var back := _button("もどる", func() -> void: _show_acc(), Vector2(0, 64), true)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(back)
	_update_words()


func _show_volume() -> void:
	_menu.visible = false
	_hide_acc()
	_words_box.visible = false
	_join_box.visible = false
	_host_box.visible = false
	_volume_box.visible = true
	_volume_panel.refresh()
	set_status("")


func _show_words() -> void:
	_menu.visible = false
	_hide_acc()
	_volume_box.visible = false
	_words_box.visible = true
	_join_box.visible = false
	_host_box.visible = false
	set_status("")
	_update_words()


func _ask_word(kind: String) -> void:
	var now: String = Profile.my_stamp_word(kind)
	_web_input.ask(tr("%s の言葉(%d文字まで)") % [Texts.STAMP_EMOJI[kind], WordFilter.MAX_LEN], now, WordFilter.MAX_LEN,
			func(t: String) -> void:
				if t != "":
					_set_word(kind, t))


## 言葉を決める: チェックを通ったら保存。だめなら理由を出して、前の言葉のまま
func _set_word(kind: String, text: String) -> void:
	var w := text.strip_edges()
	if w == "" or w == Texts.stamp_word(kind, int(Profile.stamp_pick.get(kind, 0))):
		Profile.stamp_words.erase(kind)
	else:
		var why := WordFilter.check(w)
		if why != "":
			set_status(WordFilter.reason_text(why))
			_update_words()
			return
		Profile.stamp_words[kind] = w
	Profile.save()
	set_status("")
	_update_words()
	profile_changed.emit()


## 「シャッフル」: 自作の言葉をやめて、3つの言葉をその場で引き直す(何度でも)
func _shuffle_words() -> void:
	Profile.shuffle_words()
	_update_words()
	profile_changed.emit()


func _toggle_hide_words() -> void:
	Profile.hide_custom_words = not Profile.hide_custom_words
	Profile.save()
	_update_words()


func _update_words() -> void:
	for k in Stamps.ALL:
		var word: String = Profile.stamp_words.get(k, "")
		if _word_buttons.has(k):
			(_word_buttons[k] as Button).text = tr("%s(タップで変える)") % Profile.my_stamp_word(k)
		if _word_edits.has(k):
			var e: LineEdit = _word_edits[k]
			if not e.has_focus():
				e.text = word
	_hide_words_button.text = tr("ほかの人の自作の言葉: %s") % (tr("表示しない(シャッフルの言葉で表示)") if Profile.hide_custom_words else tr("表示する"))
	# ロビーの、今の3つの言葉(次の試合で使う)
	if _words_label:
		var parts := PackedStringArray()
		for k in Stamps.ALL:
			parts.append(Profile.my_stamp_word(k) + Texts.STAMP_EMOJI[k])
		_words_label.text = "  ".join(parts)
		_words_label.add_theme_font_size_override("font_size", UiStyle.fit_size(_words_label.text, 22, 370.0, 12))


func _ask_name() -> void:
	_web_input.ask(tr("名前(%d文字まで)") % Profile.NAME_MAX, Profile.player_name, Profile.NAME_MAX,
			func(t: String) -> void:
				if t != "":
					_set_name(t))


func _ask_color() -> void:
	_web_input.ask(tr("カラーコード(例: #4D96FF)"), "#" + Profile.color.to_html(false), 9, _set_color_code)


func _set_color_code(t: String) -> void:
	if t == "":
		return
	var c := Profile.parse_color(t, Color(0, 0, 0, 0))
	if c.a == 0.0:
		set_status("カラーコードが読めませんでした(例: #4D96FF)")
		return
	_set_color(c)




func _set_name(text: String) -> void:
	Profile.player_name = Profile.clean_name(text)
	Profile.save()
	_update_profile()
	profile_changed.emit()


func _set_color(c: Color) -> void:
	Profile.color = c
	Profile.save()
	_update_profile()
	profile_changed.emit()
	# きせかえの見本のキャラも、新しい色にする
	if _acc_box and _acc_box.visible:
		_acc_preview.prepare(Profile.color, Profile.accessories)


func _update_profile() -> void:
	(_preview.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Profile.color
	if _menu_dot:
		(_menu_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Profile.color
		_menu_name.text = Locale.actor_name(Profile.player_name)
	if _name_button:
		_name_button.text = tr("%s(タップで名前を変える)") % Locale.actor_name(Profile.player_name)
	for i in _color_buttons.size():
		var c: Color = Profile.COLORS[i]
		var chosen := c.is_equal_approx(Profile.color)
		var st := UiStyle.box(c, false, 24, 6 if chosen else 3)
		st.border_color = GameConfig.COLOR_ACCENT if chosen else GameConfig.COLOR_INK
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			_color_buttons[i].add_theme_stylebox_override(k, st)


func _change_players(d: int) -> void:
	players = clampi(players + d, GameConfig.PLAYER_COUNT_MIN, GameConfig.PLAYER_COUNT_MAX)
	_update_players_button()


func _toggle_stage() -> void:
	var list: Array = Items.STAGES
	Profile.stage = list[(list.find(Profile.stage) + 1) % list.size()]
	Profile.save()
	_update_stage_button()


func _update_stage_button() -> void:
	_stage_button.text = tr("舞台: %s ▶") % Items.stage_name(Profile.stage)


func _update_language_button() -> void:
	_lang_button.text = "🌐 " + str(Locale.NAMES.get(Locale.current(), Locale.current()))


## 言語を切りかえたあと: 名前・人数・スタンプの言葉など、% で作った文字を作り直す
## (そのままの文字は、Godot が自動で新しい言語にする)
func refresh_texts() -> void:
	_update_language_button()
	_update_profile()
	_update_players_button()
	_update_stage_button()
	_update_words()
	if _words_box.visible:
		set_status("")


func _update_players_button() -> void:
	_players_label_btn.text = tr("人数: %d人") % players
	# 端まで来たら、その向きのボタンは薄くする
	_players_minus.disabled = players <= GameConfig.PLAYER_COUNT_MIN
	_players_plus.disabled = players >= GameConfig.PLAYER_COUNT_MAX


func show_menu() -> void:
	_menu.visible = true
	_hide_acc()
	_words_box.visible = false
	_volume_box.visible = false
	_join_box.visible = false
	_host_box.visible = false
	set_status("")


## ホスト: 合言葉と、入っている人数を出す
func show_host(code: String, joined: int) -> void:
	_menu.visible = false
	_hide_acc()
	_volume_box.visible = false
	_words_box.visible = false
	_join_box.visible = false
	_host_box.visible = true
	_players_label.text = tr("合言葉: %s\n入っている人: %d人(あなたをふくむ) / %d人で遊ぶ\n足りない席はボットが座ります") % [code, joined, players]


## 参加者: ホストがスタートするのを待つ
func show_waiting(text: String) -> void:
	_menu.visible = false
	_hide_acc()
	_volume_box.visible = false
	_words_box.visible = false
	_join_box.visible = false
	_host_box.visible = false
	set_status(text)


func set_status(text: String) -> void:
	_status.text = text


func _show_join() -> void:
	_menu.visible = false
	_hide_acc()
	_volume_box.visible = false
	_words_box.visible = false
	_join_box.visible = true
	_host_box.visible = false
	_code = ""
	_update_code()
	set_status("ホストの画面に出ている4桁の数字を入れてください")


func _on_key(key: String) -> void:
	match key:
		"けす":
			_code = _code.substr(0, maxi(_code.length() - 1, 0))
		"入る":
			if _code.length() == 4:
				join_pressed.emit(_code)
			else:
				set_status("4桁入れてください")
		_:
			if _code.length() < 4:
				_code += key
	_update_code()


func _update_code() -> void:
	_code_label.text = tr("合言葉: %s") % (_code + "____".substr(0, 4 - _code.length()))


# --- 部品 ---

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", HudFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GameConfig.COLOR_INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, on_press: Callable, min_size := Vector2(0, 66), accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	UiStyle.button(b, accent, 28)
	b.pressed.connect(func() -> void: AudioDirector.click())
	b.pressed.connect(on_press)
	_buttons.append(b)
	# 英語など言葉が長くても、ボタンからはみ出さないように(広がるボタンは、半分の幅を目安に)
	UiStyle.fit(b, 28, (min_size.x if min_size.x > 0.0 else 400.0) - 28.0)
	return b


## スマホの指: 見えているボタンの上をタップしたら押す
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventScreenTouch or not event.pressed:
		return
	for b in _buttons:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(event.position):
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return
