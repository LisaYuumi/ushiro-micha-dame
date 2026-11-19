class_name HeadOverlay
extends CanvasLayer
## 頭の上の名札を、3D の上に重ねた 2D で出す(A案: 白地・黒枠の丸い札)。
## - 距離に関係なく、画面の上で同じ大きさ
## - 画面の端で切れないように内側に寄せる
## - 名札どうしが重ならないように、重なる札は上へずらす
## - 届いているスタンプは、名札の上に、送った人の色の吹き出しで「名前:言葉」と積む
## - スタンプを送る相手を選んでいるときは、その人の名札の上に「送る相手」の印を出す
## - 牛乳で前が白いときは名札を隠す(吹き出しは牛乳の上に出したまま)
## 見た目だけ。状態は読むだけで変えない(押されたスタンプは main が命令にする)。

const FONT_SIZE := 20
const BUBBLE_FONT := 20
## 名札を置かない上の帯(左上の札の下から)
const TOP_LIMIT := 70.0
## 送れない相手(8人のときの両どなり・このラウンド送った人)の名札の濃さ
const BLOCKED_ALPHA := 0.4

## id -> {"panel", "model", "bubbles": Array[PanelContainer], "styles": Array[StyleBoxFlat], "labels": Array[Label]}
var _tags := {}
## スタンプを送る相手(-1 = 選んでいない)と、その頭の上の「送る相手」の印
var _target := -1
var _marker: PanelContainer
## 名札の画面の位置(吹き出しと印を出す場所に使う。画面に出せる人だけ)
var _tag_rects := {}
## 牛乳で前が白い: 名札を隠す
var _tags_hidden := false
## 投票した人(名札にチェック)と、発表された手下(名札を紫に「手下」)
var _voted := {}
var _revealed := {}


func build(state: GameState, models: Dictionary, show_personality: bool) -> void:
	layer = 1
	for c in get_children():
		c.queue_free()
	_tags.clear()
	_tag_rects.clear()
	for a in state.actors:
		if a.id == state.local_player_id or not models.has(a.id):
			continue
		var tag_name: String = Locale.actor_name(a.display_name, show_personality)
		var p := UiStyle.pill(tag_name, FONT_SIZE)
		p.visible = false
		add_child(p)
		var bubbles: Array[PanelContainer] = []
		var styles: Array[StyleBoxFlat] = []
		var labels: Array[Label] = []
		for i in GameConfig.STAMP_SLOTS:
			var st := UiStyle.box(Color.WHITE, true, 12, 3)
			st.shadow_offset = Vector2(2, 3)
			st.content_margin_left = 9
			st.content_margin_right = 9
			st.content_margin_top = 2
			st.content_margin_bottom = 4
			var b := PanelContainer.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_theme_stylebox_override("panel", st)
			var l := UiStyle.label("", BUBBLE_FONT, GameConfig.COLOR_INK)
			b.add_child(l)
			b.visible = false
			add_child(b)
			bubbles.append(b)
			styles.append(st)
			labels.append(l)
		_tags[a.id] = {"panel": p, "model": models[a.id], "bubbles": bubbles, "styles": styles, "labels": labels,
				"name": tag_name, "style": p.get_theme_stylebox("panel"), "mark": ""}
	_voted.clear()
	_revealed.clear()
	_marker = UiStyle.pill(Locale.t("送る相手") + " ▼", 20, true)
	(_marker.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	_marker.visible = false
	add_child(_marker)
	_target = -1


## スタンプを送る相手を選ぶ(-1 でやめる)。その人の名札の上に「送る相手」の印が出る。
## text: 印の文字(投票では「あなたの票」)
func set_send_target(id: int, text: String = "") -> void:
	_target = id
	if _marker:
		var want := (text if text != "" else Locale.t("送る相手")) + " ▼"
		var l := _marker.get_child(0) as Label
		if l.text != want:
			l.text = want


## 投票した人の名札にチェックをつける(だれに入れたかは出さない)
func set_voted(ids: Array) -> void:
	var now := {}
	for id in ids:
		now[int(id)] = true
	if now == _voted:
		return
	_voted = now
	_refresh_marks()


## 発表: 手下だった人の名札を紫にして「手下」をつける(空の配列で元に戻す)
func set_revealed(ids: Array) -> void:
	_revealed.clear()
	for id in ids:
		_revealed[int(id)] = true
	_refresh_marks()


func _refresh_marks() -> void:
	for id in _tags:
		var t: Dictionary = _tags[id]
		var l := (t["panel"] as PanelContainer).get_child(0) as Label
		var text: String = t["name"]
		var purple := _revealed.has(id)
		if purple:
			text = Locale.t("手下") + " " + text
		elif _voted.has(id):
			text = "✓ " + text
		if l.text != text:
			l.text = text
		if purple:
			var st := UiStyle.box(Color(0.55, 0.2, 0.7), true, 14, 3)
			(t["panel"] as PanelContainer).add_theme_stylebox_override("panel", st)
			UiStyle.set_font_color(l, Color.WHITE)
		else:
			(t["panel"] as PanelContainer).add_theme_stylebox_override("panel", t["style"])
			UiStyle.set_font_color(l, Color("2E9E5B") if _voted.has(id) else GameConfig.COLOR_INK)


func send_target() -> int:
	return _target


## 牛乳で前が白い間は、名札を隠す(吹き出しは出したまま)
func set_tags_hidden(v: bool) -> void:
	_tags_hidden = v


## 届いている言葉の吹き出しを隠す(夜の教室のフラッシュでまぶしい間)
var _bubbles_hidden := false


func set_bubbles_hidden(v: bool) -> void:
	_bubbles_hidden = v


## 画面のこの位置にある名札の人(なければ -1)
func tag_hit(pos: Vector2) -> int:
	for id in _tags:
		var p: PanelContainer = _tags[id]["panel"]
		if p.visible and p.get_global_rect().grow(6.0).has_point(pos):
			return id
	return -1


func update(state: GameState, cam: Camera3D) -> void:
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var me := state.get_local_player()
	var can_stamp := me != null and (me.role == GameState.Role.SEATED or me.role == GameState.Role.ONI or me.role == GameState.Role.OUT) \
			and (state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED)
	var placed: Array[Rect2] = []
	_tag_rects.clear()
	# 手前(カメラに近い)人から置く。重なったら奥の人の札を上へずらす
	var order := _tags.keys()
	order.sort_custom(func(x, y): return _dist(x, cam) < _dist(y, cam))
	for id in order:
		var t: Dictionary = _tags[id]
		var p: PanelContainer = t["panel"]
		var m: CharacterModel = t["model"]
		var anchor := m.tag_anchor()
		if cam.is_position_behind(anchor):
			p.visible = false
			continue
		var sp := cam.unproject_position(anchor)
		var sz := p.get_combined_minimum_size()
		# 画面の外にいる人の名札は出さない(端にかかっている人だけ、内側に寄せて出す)
		var out := sz.x * 0.6
		# (頭が画面の上にはみ出しているだけの人は、上の端に寄せて出す)
		if sp.x < -out or sp.x > vp.x + out or sp.y > vp.y + sz.y or sp.y < -vp.y * 0.5:
			p.visible = false
			continue
		var r := Rect2(sp - Vector2(sz.x / 2.0, sz.y), sz)
		if r.position.y < TOP_LIMIT:
			# 頭の上に名札の場所がない(近くて頭が画面の上のほうに大きく映っている): 顔にかぶらないように、頭の横に出す
			var head := anchor - Vector3(0, CharacterModel.HEAD_RADIUS + 0.22, 0)
			if not cam.is_position_behind(head):
				var hc := cam.unproject_position(head)
				var edge := cam.unproject_position(head + cam.global_transform.basis.x * CharacterModel.HEAD_RADIUS * 1.15)
				var rad := absf(edge.x - hc.x)
				var right_x := hc.x + rad + 6.0
				var left_x := hc.x - rad - 6.0 - sz.x
				var x := right_x if right_x + sz.x <= vp.x - UiStyle.SAFE or left_x < UiStyle.SAFE else left_x
				r.position = Vector2(x, hc.y - sz.y / 2.0)
		r.position.x = clampf(r.position.x, UiStyle.SAFE, vp.x - UiStyle.SAFE - sz.x)
		r.position.y = clampf(r.position.y, TOP_LIMIT, vp.y - sz.y - 8.0)
		# 重なったら上へずらす。上の端に当たるときは下へずらす
		for k in 8:
			var hit := false
			for q in placed:
				if q.grow(2.0).intersects(r):
					var up := q.position.y - sz.y - 4.0
					r.position.y = up if up >= TOP_LIMIT else q.end.y + 4.0
					hit = true
			if not hit:
				break
		placed.append(r)
		p.visible = not _tags_hidden
		p.position = r.position.floor()
		var blocked := can_stamp and state.stamp_block_reason(me.id, id) in ["neighbor", "already"]
		p.modulate.a = BLOCKED_ALPHA if blocked else 1.0
		_tag_rects[id] = r
	# 届いているスタンプ: 名札の上に、届いた順に下から積む(送った人の色の吹き出しに「名前:言葉」)
	for id in _tags:
		var t: Dictionary = _tags[id]
		var bubbles: Array = t["bubbles"]
		var list: Array = state.active_stamps.get(id, [])
		var y := 0.0
		if _tag_rects.has(id):
			y = (_tag_rects[id] as Rect2).position.y - 4.0
		for i in bubbles.size():
			var b: PanelContainer = bubbles[i]
			b.visible = _tag_rects.has(id) and i < list.size() and not _bubbles_hidden
			if not b.visible:
				continue
			var st: Dictionary = list[i]
			var sender := state.get_actor(st["sender"])
			var col: Color = sender_color(state, st["sender"])
			UiStyle.set_bg(t["styles"][i] as StyleBoxFlat, col)
			var l: Label = t["labels"][i]
			l.text = "%s:%s" % [sender_name(state, st["sender"]), stamp_text(state, st["sender"], st["kind"])]
			UiStyle.set_font_color(l, Hud.text_color_on(col))
			var bs := b.get_combined_minimum_size()
			var r: Rect2 = _tag_rects[id]
			y -= bs.y + 2.0
			var x := clampf(r.get_center().x - bs.x / 2.0, 4.0, vp.x - bs.x - 4.0)
			b.position = Vector2(x, y).floor()
	# 「送る相手」の印: 吹き出しのさらに上
	_marker.visible = _target >= 0 and _tag_rects.has(_target)
	if _marker.visible:
		var r: Rect2 = _tag_rects[_target]
		var n: int = mini(state.active_stamps.get(_target, []).size(), GameConfig.STAMP_SLOTS)
		var top := r.position.y - 4.0
		for i in n:
			top -= (_tags[_target]["bubbles"][i] as PanelContainer).get_combined_minimum_size().y + 2.0
		var ms := _marker.get_combined_minimum_size()
		var mx := clampf(r.get_center().x - ms.x / 2.0, 4.0, vp.x - ms.x - 4.0)
		_marker.position = Vector2(mx, maxf(top - ms.y - 4.0, 4.0)).floor()


## スタンプの文字: 言葉+絵文字。スタンプは種類とシャッフルの番号で届き、受け取った人の言語で出す。
## 自作の言葉は、送った人と受け取った人の言語が同じときだけ出す(ちがえば、受け取った人の言語のシャッフルの言葉)。
## 「ほかの人の自作の言葉を表示しない」なら、同じ意味のシャッフルの言葉
static func stamp_text(state: GameState, sender: int, kind: String) -> String:
	var word := ""
	var same_lang := str(state.stamp_langs.get(sender, Locale.current())) == Locale.current()
	if sender == state.local_player_id or (not Profile.hide_custom_words and same_lang):
		word = str((state.stamp_words.get(sender, {}) as Dictionary).get(kind, ""))
	if word == "":
		# 自作の言葉がない(または出さない)ときは、その人のシャッフルの言葉を、受け取った人の言語で
		var pick: Dictionary = state.stamp_picks.get(sender, {})
		word = Texts.stamp_word(kind, int(pick.get(kind, 0)))
	return Texts.stamp(kind, word)


## 人数が少ないとき(6人まで)は、見える後ろが少ないので、スタンプの送り主は「だれか」にする(鬼と自分は別)
static func is_anonymous(state: GameState, id: int) -> bool:
	return state.seat_count <= GameConfig.STAMP_ANON_MAX_SEATS and id != state.oni_id and id != state.local_player_id


## 吹き出しの色: 送った人の体の色(送り主を出さないときは灰色)
static func sender_color(state: GameState, id: int) -> Color:
	if is_anonymous(state, id):
		return Color("B7B1A7")
	var a := state.get_actor(id)
	return a.color if a else Color.WHITE


## 吹き出しに出す、送った人の名前(自分は「あなた」、鬼は「鬼」、ボットの性格は出さない)
static func sender_name(state: GameState, id: int) -> String:
	if id == state.local_player_id:
		return Locale.t("あなた")
	if id == state.oni_id:
		return Locale.t("鬼")
	if is_anonymous(state, id):
		return Locale.t("だれか")
	var a := state.get_actor(id)
	if a == null:
		return "?"
	return Locale.actor_name(a.display_name)


func _dist(id: int, cam: Camera3D) -> float:
	var m: CharacterModel = _tags[id]["model"]
	return cam.global_position.distance_to(m.tag_anchor())
