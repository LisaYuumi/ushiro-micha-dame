class_name TouchControls
extends CanvasLayer
## スマホ用の画面ボタン。押すとキーボードと同じ操作(アクション)を送るだけ。
## スマホでは指ごとに扱うので、2本指で同時に押せる。PC ではマウスでクリックして使える。

## ボタンと操作の組 [{"button": Button, "action": String}]
var _buttons := []
## 座っているときだけ出すボタン / 鬼のときだけ出すボタン
var _seated_buttons: Array[Button] = []
var _oni_buttons: Array[Button] = []
## 座っていて、追いかけっこ中だけ出すボタン(バナナの皮)
var _chase_buttons: Array[Button] = []
var _look_button: Button
## 鬼の「牛乳をかける」ボタンと、表示中の残り回数
var _milk_button: Button
var _milk_label: Label
var _milk_badge: Label
var _milk_shown := -1
## お手つきで抜けて、真ん中で見ているか(振り向くボタンを隠す)
var _out := false
## ⚙ボタンで開くメニューと、その中の「あそびかた」
var _menu: PanelContainer
var _help_panel: PanelContainer
var _personality_button: Button
var _stick: VirtualStick
## 「振り向く」ボタンの矢印・文字・残りの回数のバッジ
var _look_arrow: Control
var _look_title: Label
var _look_badge: PanelContainer
var _look_badge_label: Label
var _looks_shown := -2
var _mode := []
## 結果カードが出ている間は、ゲーム用のボタンを隠す(⚙は残す)
var _result := false
## 押している指の番号 -> 操作
var _touch_action := {}


func _ready() -> void:
	layer = 2
	# 右下: 振り向く(押している間)
	_look_button = _add_button("", "look_back", Vector2(1, 1), Rect2(-UiStyle.SAFE - 220, -250, 220, 220), 36)
	_seated_buttons.append(_look_button)
	# 0 回のときは灰色(押せない)
	var gray := UiStyle.box(Color("B9B4AC"))
	_look_button.add_theme_stylebox_override("disabled", gray)
	_build_look_face(_look_button)
	# 鬼のとき: 同じ場所に「止まる」(押している間)、その左に「落とす」、さらに左に「牛乳」と「フェイク」
	_oni_buttons.append(_add_button("止まる", "oni_stop", Vector2(1, 1), Rect2(-UiStyle.SAFE - 220, -250, 220, 220), 40))
	var drop := _add_button("", "oni_drop", Vector2(1, 1), Rect2(-UiStyle.SAFE - 410, -250, 175, 220), 32)
	_icon_face(drop, "drop", "落とす", Vector2(96, 80), 32, GameConfig.COLOR_PAPER)
	_oni_buttons.append(drop)
	# 牛乳(タップで選んだ人にかける。1ラウンド1回。相手を選んでいないときと、使ったあとは灰色)
	_milk_button = _add_button("", "oni_milk", Vector2(1, 1), Rect2(-UiStyle.SAFE - 575, -250, 150, 125), 24)
	var blue := UiStyle.box(GameConfig.COLOR_PAPER)
	blue.border_color = ButtonIcon.MILK_BLUE
	blue.set_border_width_all(6)
	_milk_button.add_theme_stylebox_override("normal", blue)
	_milk_button.add_theme_stylebox_override("hover", blue)
	_milk_button.add_theme_stylebox_override("disabled", UiStyle.box(Color("B9B4AC")))
	_milk_label = _icon_face(_milk_button, "milk", "牛乳", Vector2(60, 62), 24, GameConfig.COLOR_INK)
	_milk_badge = _corner_badge(_milk_button, Vector2(150 - 40, -18))
	_oni_buttons.append(_milk_button)
	var fake := _add_button("", "oni_feint", Vector2(1, 1), Rect2(-UiStyle.SAFE - 575, -112, 150, 82), 22)
	_icon_face(fake, "fake", "フェイク", Vector2(70, 34), 22, GameConfig.COLOR_INK)
	_oni_buttons.append(fake)
	# 追いかけっこ中のバナナの皮(下のまん中)
	_chase_buttons.append(_add_button("鬼にバナナ", "banana_oni", Vector2(0.5, 1), Rect2(-300, -110, 280, 90), 28))
	_chase_buttons.append(_add_button("追う人にバナナ", "banana_chaser", Vector2(0.5, 1), Rect2(20, -110, 280, 90), 28))
	# 左下: 走るためのスティック
	var stick := VirtualStick.new()
	add_child(stick)
	stick.anchor_left = 0
	stick.anchor_right = 0
	stick.anchor_top = 1
	stick.anchor_bottom = 1
	stick.offset_left = UiStyle.SAFE
	stick.offset_top = -250
	stick.offset_right = UiStyle.SAFE + 220
	stick.offset_bottom = -30
	_stick = stick
	# 右上: ⚙ボタン(開発用の操作や「あそびかた」はメニューの中)
	var gear := _add_button("", "", Vector2(1, 0), Rect2(-UiStyle.SAFE - 64, 14, 64, 58), 28, toggle_menu)
	_add_gear_icon(gear)
	_build_menu()
	set_oni_mode(false)


## 「振り向く」ボタンの中身: まん中に回る矢印(↻)と「振り向く」、右上の角に残りの回数のバッジ
func _build_look_face(b: Button) -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)
	var arrow := Control.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.custom_minimum_size = Vector2(0, 110)
	arrow.draw.connect(_draw_turn_arrow.bind(arrow))
	col.add_child(arrow)
	_look_arrow = arrow
	var title := UiStyle.label("振り向く", 30, GameConfig.COLOR_PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_look_title = title
	# 右上の角の数字バッジ(白い丸に黒枠)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = GameConfig.COLOR_PAPER
	st.border_color = GameConfig.COLOR_INK
	st.set_border_width_all(4)
	st.set_corner_radius_all(32)
	badge.add_theme_stylebox_override("panel", st)
	badge.custom_minimum_size = Vector2(64, 64)
	var num := UiStyle.label("2", 36, GameConfig.COLOR_INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(num)
	b.add_child(badge)
	badge.position = Vector2(220 - 44, -20)
	_look_badge = badge
	_look_badge_label = num


## 回る矢印(↻): 太い弧と、その先の三角。押している間は少し回る
func _draw_turn_arrow(c: Control) -> void:
	var center := c.size / 2.0
	var r := 36.0
	var color := GameConfig.COLOR_PAPER
	var spin := 0.5 if Input.is_action_pressed("look_back") else 0.0
	var start := deg_to_rad(-60.0) + spin
	var end := deg_to_rad(230.0) + spin
	c.draw_arc(center, r, start, end, 40, color, 12.0, true)
	# 矢じり(弧の終わりの向きに)
	var tip := center + Vector2(cos(end), sin(end)) * r
	var along := Vector2(-sin(end), cos(end))
	var out := Vector2(cos(end), sin(end))
	c.draw_colored_polygon(PackedVector2Array([
		tip + along * 20.0,
		tip - out * 18.0 - along * 4.0,
		tip + out * 18.0 - along * 4.0,
	]), color)


## 「振り向く」ボタンの残りの回数(-1 = 数えない場面: 追いかけっこ中・勝敗のあと)。
## 右上のバッジに数字で出し、0 回になったらボタン全体を灰色にして押せなくする
func set_looks_left(n: int) -> void:
	if _look_arrow:
		_look_arrow.queue_redraw()
	if n == _looks_shown:
		return
	_looks_shown = n
	_look_badge.visible = n >= 0
	_look_badge_label.text = str(maxi(n, 0))
	var empty := n == 0
	_look_button.disabled = empty
	if empty:
		_release_action("look_back")


## 鬼の牛乳の残り回数と、いまかけられるか(相手を選んでいるか)。かけられないときは灰色で押せない。
## 右上の角に残りの回数のバッジ
func set_milk_left(n: int, can_pour: bool = true) -> void:
	var key := n * 2 + (1 if can_pour else 0)
	if key == _milk_shown:
		return
	_milk_shown = key
	_milk_button.disabled = n <= 0 or not can_pour
	_milk_label.text = "牛乳" if n > 0 else "使った"
	_milk_badge.text = str(maxi(n, 0))
	if _milk_button.disabled:
		_release_action("oni_milk")


## ボタンの中身: 上に絵、下に名前
func _icon_face(b: Button, icon: String, text: String, icon_size: Vector2, font_size: int, color: Color) -> Label:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)
	var ic := ButtonIcon.make(icon, icon_size)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l := UiStyle.label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return l


## ボタンの右上の角の数字バッジ(白い丸に黒枠)
func _corner_badge(b: Button, pos: Vector2) -> Label:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = GameConfig.COLOR_PAPER
	st.border_color = GameConfig.COLOR_INK
	st.set_border_width_all(4)
	st.set_corner_radius_all(26)
	badge.add_theme_stylebox_override("panel", st)
	badge.custom_minimum_size = Vector2(52, 52)
	var num := UiStyle.label("1", 28, GameConfig.COLOR_INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(num)
	b.add_child(badge)
	badge.position = pos
	return num


## 鬼のとき/座っているとき/座っていて追いかけっこ中/お手つきで抜けたときで、出すボタンを切りかえる
func set_oni_mode(is_oni: bool, seated_in_chase: bool = false, out: bool = false) -> void:
	if _mode == [is_oni, seated_in_chase, _result, out]:
		return
	_mode = [is_oni, seated_in_chase, _result, out]
	_out = out
	for b in _seated_buttons:
		b.visible = not is_oni and not seated_in_chase and not _result and not out
	for b in _oni_buttons:
		b.visible = is_oni and not _result
	for b in _chase_buttons:
		b.visible = seated_in_chase and not _result
	# 切りかえで押しっぱなしになった指を離しておく
	for index in _touch_action.keys():
		var entry: Dictionary = _touch_action[index]
		_send(entry["action"], false)
		UiStyle.show_pressed(entry["button"], false)
	_touch_action.clear()


## A案の見た目でオレンジ地にするボタン(いちばん大事な操作)
const ACCENT_ACTIONS := ["look_back", "oni_stop", "oni_drop"]


## ⚙の絵(歯車)
func _add_gear_icon(b: Button) -> void:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.draw.connect(func() -> void:
		var c := g.size / 2.0 + Vector2(-1, -2)
		for k in 8:
			var t := TAU * k / 8.0
			var d := Vector2(cos(t), sin(t))
			var side := Vector2(-d.y, d.x) * 5.0
			g.draw_colored_polygon(PackedVector2Array([c + d * 9 - side, c + d * 9 + side, c + d * 17 + side * 0.7, c + d * 17 - side * 0.7]), GameConfig.COLOR_INK)
		g.draw_circle(c, 12.0, GameConfig.COLOR_INK)
		g.draw_circle(c, 5.0, GameConfig.COLOR_PAPER))
	b.add_child(g)


## ⚙メニュー: やり直し・役を変えて新試合・上から見る・ボットの性格の表示・あそびかた・とじる
func _build_menu() -> void:
	_menu = _panel(Vector2(420, 0))
	var col: VBoxContainer = _menu.get_child(0)
	var title := UiStyle.label("メニュー", 30, GameConfig.COLOR_INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_menu_button(col, "やり直し", _menu_action.bind("restart"))
	_menu_button(col, "役を変えて新しい試合", _menu_action.bind("toggle_role"))
	_menu_button(col, "上から見る(確認用)", _menu_action.bind("debug_top_camera"))
	_personality_button = _menu_button(col, "", _toggle_personality)
	_menu_button(col, "あそびかた", _show_help)
	if GameConfig.SHOW_PHOTO_MODE:
		_menu_button(col, "撮影モード(開発用)", _menu_action.bind("photo_mode"))
	_menu_button(col, "とじる", close_menu, true)
	_update_menu_texts()

	_help_panel = _panel(Vector2(760, 0))
	var hcol: VBoxContainer = _help_panel.get_child(0)
	var htitle := UiStyle.label("あそびかた", 30, GameConfig.COLOR_INK)
	htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hcol.add_child(htitle)
	var body := UiStyle.label(HOW_TO_PLAY, 20, GameConfig.COLOR_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(700, 0)
	hcol.add_child(body)
	_menu_button(hcol, "とじる", close_menu, true)


const HOW_TO_PLAY := """・振り向く(長押し): 押している間だけ後ろを見る。落ちていたら、そのまま拾って走る
・お手つき(なにもないのに振り向く): 輪から抜けて真ん中で休む。そのラウンドは0点。全員の後ろが見えて、だれにでもスタンプを送れる
・人をタップ: その人の頭の上にスタンプが出るので、選んで送る(同じ人には1ラウンド1回)
・鬼: スティックで歩く速さ。止まる・落とす・フェイク(落とす音だけ)・牛乳(人をタップして選び、牛乳ボタンでかける。画面が半周のあいだ白くなる。1ラウンド1回)
・追いかけっこ: 自動で走る。スティックの上で内側(近道)、下で外側。座っている人はバナナを投げられる
キーボード: スペース=振り向く/止まる 1〜4=スタンプ M=牛乳 Z X C V=鬼のスタンプ W/S=内側/外側 A/D=鬼の速さ
 E=落とす F=フェイク B/N=バナナ R=やり直し O=役を変える F1=上から見る K=転ぶ L=牛乳をかぶる(確認用) Tab=メニュー"""


func _menu_action(action: String) -> void:
	_tap_action(action)
	close_menu()


func _toggle_personality() -> void:
	_tap_action("toggle_personality")
	_update_menu_texts()


func _show_help() -> void:
	_menu.visible = false
	_help_panel.visible = true
	UiStyle.center(_help_panel)


func _update_menu_texts() -> void:
	_personality_button.text = "ボットの性格を表示: %s" % ("オン" if Profile.show_personality else "オフ")


## 画面のまん中に出す白いパネル(中に縦に並べる)
func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 26, 5)
	st.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	p.custom_minimum_size = min_size
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	p.visible = false
	return p


func _menu_button(parent: Container, text: String, on_press: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	UiStyle.button(b, accent, 24)
	parent.add_child(b)
	b.pressed.connect(on_press)
	_buttons.append({"button": b, "action": "", "call": on_press})
	return b


## 結果カードが出ている間: ゲーム用のボタンとスティックを隠す(⚙とメニューは使える)
func set_result_mode(v: bool) -> void:
	_result = v


## ジョイスティックは、立っているとき(鬼・追いかける人)だけ出す
func set_stick_visible(v: bool) -> void:
	v = v and not _result
	if _stick.visible != v:
		_stick.visible = v


func toggle_menu() -> void:
	if _menu.visible or _help_panel.visible:
		close_menu()
	else:
		_update_menu_texts()
		_menu.visible = true
		UiStyle.center(_menu)


func close_menu() -> void:
	_menu.visible = false
	_help_panel.visible = false


func is_menu_open() -> bool:
	return _menu.visible or _help_panel.visible


## 操作を1回押して離す(メニューから)
func _tap_action(action: String) -> void:
	_send(action, true)
	_send(action, false)


func _add_button(text: String, action: String, anchor: Vector2, rect: Rect2, font_size: int, on_press: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	# A案: 白地かオレンジ地、黒い太い枠、右下の影。スタンプはスタンプの色の文字
	var text_color := Color(0, 0, 0, 0)
	# キーボードのスペースでボタンが反応しないように、フォーカスを受けない(UiStyle.button の中で)
	UiStyle.button(b, action in ACCENT_ACTIONS, font_size, text_color)
	add_child(b)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = rect.position.x
	b.offset_top = rect.position.y
	b.offset_right = rect.position.x + rect.size.x
	b.offset_bottom = rect.position.y + rect.size.y
	# PC のマウス用
	if on_press.is_valid():
		b.pressed.connect(on_press)
	else:
		b.button_down.connect(_send.bind(action, true))
		b.button_up.connect(_send.bind(action, false))
	_buttons.append({"button": b, "action": action, "call": on_press})
	return b


## スマホの指: ボタンの上に触れたら押す、その指を離したら離す
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle_menu()
		return
	if not event is InputEventScreenTouch:
		return
	var t := event as InputEventScreenTouch
	if t.pressed:
		# あとから足した(上に重なっている)ボタンから調べる。メニューが開いているときはメニューの中だけ
		for k in range(_buttons.size() - 1, -1, -1):
			var entry: Dictionary = _buttons[k]
			var b: Button = entry["button"]
			if not b.is_visible_in_tree() or b.disabled or not b.get_global_rect().has_point(t.position):
				continue
			if is_menu_open() and not (_menu.is_ancestor_of(b) or _help_panel.is_ancestor_of(b)):
				continue
			var call: Callable = entry.get("call", Callable())
			if call.is_valid():
				call.call()
				get_viewport().set_input_as_handled()
				return
			_touch_action[t.index] = entry
			UiStyle.show_pressed(b, true)
			_send(entry["action"], true)
			get_viewport().set_input_as_handled()
			return
		if is_menu_open():
			# メニューの外や背景をタップしても、うしろの画面には届かない
			get_viewport().set_input_as_handled()
	elif _touch_action.has(t.index):
		var entry: Dictionary = _touch_action[t.index]
		_touch_action.erase(t.index)
		UiStyle.show_pressed(entry["button"], false)
		_send(entry["action"], false)


## その操作を押している指を離したことにする(ボタンが押せなくなったときなど)
func _release_action(action: String) -> void:
	for index in _touch_action.keys():
		var entry: Dictionary = _touch_action[index]
		if entry["action"] == action:
			_touch_action.erase(index)
			UiStyle.show_pressed(entry["button"], false)
			_send(action, false)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
