class_name HeadOverlay
extends CanvasLayer
## キャラの名札と言葉の吹き出しを、3D の上に重ねた 2D で出す。
## - 名札は足もと(半透明の黒に白い文字。ひかえめ)。頭の上は言葉の吹き出し専用
## - 吹き出しの色は言葉の意味でそろえる: 見ろ系(落ちてる😨・信じて🥺)は赤、見るな系(平気👍)は青。送った人の色は使わない
## - 距離に関係なく、画面の上で同じ大きさ。画面の端(⚙ボタンの裏など)からはみ出さないように内側に寄せる
## - 重なりそうな札・吹き出しは少しずらす
## - スタンプを送る相手を選んでいるときは、その人の頭の上に「送る相手」の印
## - 投票の間は、落とされた人・お手つきの人の頭の上に「証拠」(大事な時間に届いた言葉を、プレイ中と同じ吹き出しで再現)
## - 牛乳で前が白いときは名札を隠す(吹き出しは牛乳の上に出したまま)
## 見た目だけ。状態は読むだけで変えない(押されたスタンプは main が命令にする)。

const FONT_SIZE := 18
const BUBBLE_FONT := 20
const EVIDENCE_FONT := 24
## 吹き出し・名札を置かない上の帯(左上の札の下から)
const TOP_LIMIT := 70.0
## 送れない相手(8人のときの両どなり・このラウンド送った人)の名札の濃さ
const BLOCKED_ALPHA := 0.4
## 吹き出しの色(見ろ系 = 赤、見るな系 = 青)
const COLOR_LOOK := Color("E5483B")
const COLOR_DONT := Color("2F7FE0")
## 名札の地(半透明の黒)
const TAG_BG := Color(0, 0, 0, 0.55)
## 右上の⚙ボタンのあたり(吹き出しを置かない)
const GEAR_SIZE := Vector2(120, 100)

## id -> {"panel", "label", "model", "bubbles": Array[PanelContainer], "styles": Array[StyleBoxFlat], "labels": Array[Label], "name", "style"}
var _tags := {}
## スタンプを送る相手(-1 = 選んでいない)と、その頭の上の「送る相手」の印
var _target := -1
var _marker: PanelContainer
## 名札の画面の位置(タップで相手を選ぶ。画面に出せる人だけ)と、頭の上の吹き出しのかたまりの位置
var _tag_rects := {}
var _head_rects := {}
## 牛乳で前が白い: 名札を隠す
var _tags_hidden := false
## 投票した人(名札にチェック)と、発表された手下(名札を紫に「手下」)
var _voted := {}
var _revealed := {}
## 全員のキャラ(自分も)
var _models := {}
var _self_id := -1
## 投票の証拠: id -> 吹き出しの配列(大事な人だけ)
var _vote_on := false
var _evidence := {}
var _ev_nodes := {}
## 吹き出しを置かない上の帯の高さ(投票の間は、上の「鬼の手下は誰?」の枠の下。main が決める)
var _label_top := TOP_LIMIT


func build(state: GameState, models: Dictionary, show_personality: bool) -> void:
	layer = 1
	for c in get_children():
		c.queue_free()
	_tags.clear()
	_tag_rects.clear()
	_head_rects.clear()
	_models = models
	_self_id = state.local_player_id
	_vote_on = false
	_evidence.clear()
	_ev_nodes.clear()
	for a in state.actors:
		if a.id == state.local_player_id or not models.has(a.id):
			continue
		var tag_name: String = Locale.actor_name(a.display_name, show_personality)
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tst := _tag_style(TAG_BG)
		p.add_theme_stylebox_override("panel", tst)
		var tl := UiStyle.label(tag_name, FONT_SIZE, Color.WHITE)
		p.add_child(tl)
		p.visible = false
		add_child(p)
		var bubbles: Array[PanelContainer] = []
		var styles: Array[StyleBoxFlat] = []
		var labels: Array[Label] = []
		for i in GameConfig.STAMP_SLOTS:
			var st := _bubble_style(COLOR_LOOK)
			var b := PanelContainer.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_theme_stylebox_override("panel", st)
			var l := UiStyle.label("", BUBBLE_FONT, Color.WHITE)
			b.add_child(l)
			b.visible = false
			add_child(b)
			bubbles.append(b)
			styles.append(st)
			labels.append(l)
		_tags[a.id] = {"panel": p, "label": tl, "model": models[a.id], "bubbles": bubbles, "styles": styles, "labels": labels,
				"name": tag_name, "style": tst}
	_voted.clear()
	_revealed.clear()
	_marker = UiStyle.pill(Locale.t("送る相手") + " ▼", 20, true)
	(_marker.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	_marker.visible = false
	add_child(_marker)
	_target = -1


static func _tag_style(bg: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 0
	st.content_margin_bottom = 2
	return st


static func _bubble_style(bg: Color) -> StyleBoxFlat:
	var st := UiStyle.box(bg, true, 12, 3)
	st.shadow_offset = Vector2(2, 3)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 1
	st.content_margin_bottom = 3
	return st


## 言葉の意味の色: 見ろ系(落ちてる・信じて)は赤、見るな系(平気)は青
static func kind_color(kind: String) -> Color:
	if kind == "more":
		return Color("8A8A8A")
	return COLOR_DONT if kind == Stamps.SAFE else COLOR_LOOK


## スタンプを送る相手を選ぶ(-1 でやめる)。その人の頭の上に「送る相手」の印が出る。
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
		var l: Label = t["label"]
		var text: String = t["name"]
		var st: StyleBoxFlat = t["style"]
		if _revealed.has(id):
			text = Locale.t("手下") + " " + text
			st.bg_color = Color(0.55, 0.2, 0.7, 0.95)
			UiStyle.set_font_color(l, Color.WHITE)
		else:
			if _voted.has(id):
				text = "✓ " + text
			st.bg_color = TAG_BG
			UiStyle.set_font_color(l, Color("8EF0B0") if _voted.has(id) else Color.WHITE)
		if l.text != text:
			l.text = text


func send_target() -> int:
	return _target


## 投票の証拠を出す(on = false で消す)。ev: id -> [{"text", "kind"}](大事な人に、大事な時間に届いた言葉)
func set_vote_evidence(on: bool, ev: Dictionary = {}) -> void:
	if not on:
		ev = {}
	if _vote_on == on and ev == _evidence:
		return
	_vote_on = on
	_evidence = ev.duplicate(true)
	for id in _ev_nodes:
		for n in _ev_nodes[id]:
			# (消すときは、ふっと消える)
			var c := n as Control
			if not on and c.visible:
				var tw := c.create_tween()
				tw.tween_property(c, "modulate:a", 0.0, 0.35)
				tw.tween_callback(c.queue_free)
			else:
				c.queue_free()
	_ev_nodes.clear()
	for id in _evidence:
		var list := []
		for line in _evidence[id]:
			var b := PanelContainer.new()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_theme_stylebox_override("panel", _bubble_style(kind_color(str(line["kind"]))))
			b.add_child(UiStyle.label(str(line["text"]), EVIDENCE_FONT, Color.WHITE))
			b.visible = false
			add_child(b)
			list.append(b)
		_ev_nodes[id] = list
	if _marker:
		move_child(_marker, get_child_count() - 1)


## 吹き出しを置かない上の帯の高さ(画面の上の枠の下)
func set_label_top(y: float) -> void:
	_label_top = maxf(y, 8.0)


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
		if p.visible and p.get_global_rect().grow(8.0).has_point(pos):
			return id
	return -1


func update(state: GameState, cam: Camera3D) -> void:
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var me := state.get_local_player()
	var can_stamp := me != null and (me.role == GameState.Role.SEATED or me.role == GameState.Role.ONI or me.role == GameState.Role.OUT) \
			and (state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED)
	var top := _label_top if _vote_on else TOP_LIMIT
	_tag_rects.clear()
	_head_rects.clear()
	# 手前(カメラに近い)人から置く
	var order := _models.keys()
	order.sort_custom(func(x, y): return _dist(x, cam) < _dist(y, cam))
	# ⚙ボタンのあたりには置かない
	var placed: Array[Rect2] = [Rect2(Vector2(vp.x - GEAR_SIZE.x, 0), GEAR_SIZE)]
	# 1) 名札: 足もとのすぐ下
	for id in order:
		if not _tags.has(id):
			continue
		var t: Dictionary = _tags[id]
		var p: PanelContainer = t["panel"]
		var m: CharacterModel = t["model"]
		var foot := m.global_position
		if cam.is_position_behind(foot) or not m.visible:
			p.visible = false
			continue
		var sp := cam.unproject_position(foot)
		var sz := p.get_combined_minimum_size()
		p.size = sz
		if sp.x < -sz.x or sp.x > vp.x + sz.x or sp.y > vp.y + sz.y * 2.0 or sp.y < 0.0:
			p.visible = false
			continue
		var r := Rect2(Vector2(sp.x - sz.x / 2.0, sp.y + 2.0), sz)
		r = _fit(r, vp, top, placed, sz.y * 0.6, 9)
		placed.append(r)
		p.visible = not _tags_hidden
		p.position = r.position.floor()
		var blocked := can_stamp and state.stamp_block_reason(me.id, id) in ["neighbor", "already"]
		p.modulate.a = BLOCKED_ALPHA if blocked else 1.0
		_tag_rects[id] = r
	# 2) 頭の上: 届いている言葉(プレイ中)または証拠(投票中)を、頭のすぐ上に下から積む
	# (投票の証拠は、名札はよけない。頭の真上から離さないように、ほかの証拠と⚙だけよける)
	var ev_placed: Array[Rect2] = [Rect2(Vector2(vp.x - GEAR_SIZE.x, 0), GEAR_SIZE)]
	for id in order:
		var nodes: Array = []
		if _vote_on:
			nodes = _ev_nodes.get(id, [])
		elif _tags.has(id):
			nodes = _play_bubbles(state, id)
		if _tags.has(id) and _vote_on:
			for b in _tags[id]["bubbles"]:
				(b as Control).visible = false
		var m: CharacterModel = _models.get(id)
		var alive: bool = m != null and is_instance_valid(m) and m.visible
		var anchor: Vector3 = (m.tag_anchor() - Vector3(0, 0.15, 0)) if alive else Vector3.ZERO
		if nodes.is_empty() or not alive or cam.is_position_behind(anchor):
			for n in nodes:
				(n as Control).visible = false
			if alive and not cam.is_position_behind(anchor):
				var hp := cam.unproject_position(anchor)
				_head_rects[id] = Rect2(hp, Vector2.ZERO)
			continue
		var sp := cam.unproject_position(anchor)
		var w := 0.0
		var h := 0.0
		for n in nodes:
			var bs := (n as Control).get_combined_minimum_size()
			(n as Control).size = bs
			w = maxf(w, bs.x)
			h += bs.y + 2.0
		var r := Rect2(Vector2(sp.x - w / 2.0, sp.y - h), Vector2(w, h))
		# (投票の証拠は、頭のすぐ上から離さない。2人がとなり同士のときだけ、横に並べる)
		if _vote_on:
			r = _fit(r, vp, top, ev_placed, 18.0, 9, 1.05)
			ev_placed.append(r)
		else:
			r = _fit(r, vp, top, placed, h * 0.3 + 6.0, 13, 0.7)
		placed.append(r)
		_head_rects[id] = r
		var y := r.end.y
		for n in nodes:
			var c := n as Control
			var bs := c.size
			y -= bs.y + 2.0
			c.position = Vector2(r.get_center().x - bs.x / 2.0, y).floor()
			c.visible = not _bubbles_hidden or _vote_on
	# 「送る相手」「あなたの票」の印: 頭の上の吹き出しのさらに上
	_marker.visible = _target >= 0 and _head_rects.has(_target)
	if _marker.visible:
		var r: Rect2 = _head_rects[_target]
		var ms := _marker.get_combined_minimum_size()
		var mx := clampf(r.get_center().x - ms.x / 2.0, 4.0, vp.x - ms.x - GEAR_SIZE.x * 0.5)
		_marker.position = Vector2(mx, maxf(r.position.y - ms.y - 4.0, 4.0)).floor()


## プレイ中に頭の上に出す、届いている言葉の吹き出し(色は言葉の意味。「送った人:言葉」)
func _play_bubbles(state: GameState, id: int) -> Array:
	var t: Dictionary = _tags[id]
	var bubbles: Array = t["bubbles"]
	var list: Array = state.active_stamps.get(id, [])
	var out := []
	for i in bubbles.size():
		var b: PanelContainer = bubbles[i]
		if i >= list.size() or _bubbles_hidden:
			b.visible = false
			continue
		var st: Dictionary = list[i]
		var col := kind_color(str(st["kind"]))
		(t["styles"][i] as StyleBoxFlat).bg_color = col
		var l: Label = t["labels"][i]
		var text := "%s:%s" % [sender_name(state, st["sender"]), stamp_text(state, st["sender"], st["kind"])]
		if l.text != text:
			l.text = text
		out.append(b)
	return out


## 札を画面の内側に収め、ほかの札と重ならない近くの場所をさがす(上下に少しずつ、少しだけ左右にも)
func _fit(base: Rect2, vp: Vector2, top: float, placed: Array[Rect2], step: float, tries: int, side := 0.7) -> Rect2:
	var sz := base.size
	var best := base
	var best_cost := INF
	for k in tries:
		var dy := step * float((k + 1) / 2) * (-1.0 if k % 2 == 1 else 1.0)
		for dx in [0.0, -sz.x * side * 0.5, sz.x * side * 0.5, -sz.x * side, sz.x * side]:
			var r := base
			r.position += Vector2(dx, dy)
			r.position.x = clampf(r.position.x, UiStyle.SAFE, vp.x - UiStyle.SAFE - sz.x)
			r.position.y = clampf(r.position.y, top, vp.y - sz.y - 6.0)
			var cost := 0.0
			for q in placed:
				var inter := q.grow(2.0).intersection(r)
				if inter.has_area():
					cost += inter.get_area()
			if cost <= 0.0:
				return r
			if cost < best_cost:
				best_cost = cost
				best = r
	return best


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


## 証拠の名前(自分は「あなた」、鬼は「鬼」)
static func evidence_name(state: GameState, id: int) -> String:
	if id == state.local_player_id:
		return TranslationServer.translate("あなた")
	if id == state.oni_id:
		return TranslationServer.translate("鬼")
	var a := state.get_actor(id)
	return Locale.actor_name(a.display_name) if a else "?"


## 人数が少ないとき(6人まで)は、見える後ろが少ないので、スタンプの送り主は「だれか」にする(鬼と自分は別)
static func is_anonymous(state: GameState, id: int) -> bool:
	return state.seat_count <= GameConfig.STAMP_ANON_MAX_SEATS and id != state.oni_id and id != state.local_player_id


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
	var m: Node3D = _models.get(id)
	return cam.global_position.distance_to(m.global_position) if m and is_instance_valid(m) else 999.0


## 投票の証拠: 大事な人(落とされた人・お手つきの人)の頭の上に、「大事な時間」に届いた言葉を再現する
## (id -> [{"text": "送った人:言葉", "kind"}]。プレイ中の吹き出しと同じ形・意味の色)。多いときは新しい EVIDENCE_MAX 個と、
## いちばん上に灰色の「ほか2件」({"text", "kind": "more"})
const EVIDENCE_MAX := 5


static func evidence_bubbles(state: GameState) -> Dictionary:
	var ev := {}
	for id in state.evidence_key_ids():
		var lines := []
		for x in state.evidence_received(int(id)):
			var kind := str(x["kind"])
			lines.append({"text": "%s:%s" % [evidence_name(state, int(x["sender"])), stamp_text(state, int(x["sender"]), kind)],
					"kind": kind})
		if lines.size() > EVIDENCE_MAX:
			var more := lines.size() - EVIDENCE_MAX
			lines = lines.slice(lines.size() - EVIDENCE_MAX)
			lines.append({"text": TranslationServer.translate("ほか%d件") % more, "kind": "more"})
		if not lines.is_empty():
			ev[int(id)] = lines
	return ev
