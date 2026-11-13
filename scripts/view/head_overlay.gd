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


func build(state: GameState, models: Dictionary, show_personality: bool) -> void:
	layer = 1
	for c in get_children():
		c.queue_free()
	_tags.clear()
	_tag_rects.clear()
	for a in state.actors:
		if a.id == state.local_player_id or not models.has(a.id):
			continue
		var tag_name: String = a.display_name if show_personality else a.display_name.get_slice("(", 0)
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
		_tags[a.id] = {"panel": p, "model": models[a.id], "bubbles": bubbles, "styles": styles, "labels": labels}
	_marker = UiStyle.pill(Texts.t("send_target") + " ▼", 20, true)
	(_marker.get_child(0) as Label).add_theme_color_override("font_color", GameConfig.COLOR_PAPER)
	_marker.visible = false
	add_child(_marker)
	_target = -1


## スタンプを送る相手を選ぶ(-1 でやめる)。その人の名札の上に「送る相手」の印が出る
func set_send_target(id: int) -> void:
	_target = id


func send_target() -> int:
	return _target


## 牛乳で前が白い間は、名札を隠す(吹き出しは出したまま)
func set_tags_hidden(v: bool) -> void:
	_tags_hidden = v


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
			b.visible = _tag_rects.has(id) and i < list.size()
			if not b.visible:
				continue
			var st: Dictionary = list[i]
			var sender := state.get_actor(st["sender"])
			var col: Color = sender.color if sender else Color.WHITE
			(t["styles"][i] as StyleBoxFlat).bg_color = col
			var l: Label = t["labels"][i]
			l.text = "%s:%s" % [sender_name(state, st["sender"]), Texts.stamp(st["kind"])]
			l.add_theme_color_override("font_color", Hud.text_color_on(col))
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


## 吹き出しに出す、送った人の名前(自分は「あなた」、鬼は「鬼」、ボットの性格は出さない)
static func sender_name(state: GameState, id: int) -> String:
	if id == state.local_player_id:
		return Texts.t("me")
	if id == state.oni_id:
		return Texts.t("oni")
	var a := state.get_actor(id)
	if a == null:
		return "?"
	return a.display_name.get_slice("(", 0)


func _dist(id: int, cam: Camera3D) -> float:
	var m: CharacterModel = _tags[id]["model"]
	return cam.global_position.distance_to(m.tag_anchor())
