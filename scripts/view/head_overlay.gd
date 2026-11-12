class_name HeadOverlay
extends CanvasLayer
## 頭の上の名札を、3D の上に重ねた 2D で出す(A案: 白地・黒枠の丸い札)。
## - 距離に関係なく、画面の上で同じ大きさ
## - 画面の端で切れないように内側に寄せる
## - 名札どうしが重ならないように、重なる札は上へずらす
## - 届いているスタンプは、名札の上に小さなアイコンで並べる(輪の色 = 送った人)
## - スタンプを送るときは、相手の頭の上にスタンプの選択肢が丸く並ぶ(open_picker)
## 見た目だけ。状態は読むだけで変えない(押されたスタンプは main が命令にする)。

const FONT_SIZE := 20
## 名札を置かない上の帯(左上の札の下から)
const TOP_LIMIT := 70.0
## 送れない相手(8人のときの両どなり・このラウンド送った人)の名札の濃さ
const BLOCKED_ALPHA := 0.4

## 届いたスタンプのアイコンの大きさ/選択肢のアイコンの大きさ
const SHOWN_ICON := 40.0
const PICK_ICON := 84.0
## 選択肢を並べる半径(名札の上の点から)
const PICK_RADIUS := 92.0

## id -> {"panel": PanelContainer, "model": CharacterModel, "icons": Array[StampIcon]}
var _tags := {}
## スタンプの選択肢(開いている相手。-1 = 閉じている)
var _picker_target := -1
var _picker_icons: Array[StampIcon] = []
## 名札の画面の位置(選択肢を出す場所に使う)
var _tag_rects := {}


func build(state: GameState, models: Dictionary, show_personality: bool) -> void:
	layer = 1
	for c in get_children():
		c.queue_free()
	_tags.clear()
	for a in state.actors:
		if a.id == state.local_player_id or not models.has(a.id):
			continue
		var tag_name: String = a.display_name if show_personality else a.display_name.get_slice("(", 0)
		var p := UiStyle.pill(tag_name, FONT_SIZE)
		p.visible = false
		add_child(p)
		var icons: Array[StampIcon] = []
		for i in GameConfig.STAMP_SLOTS:
			var ic := StampIcon.make(Stamps.DROPPED, 0, SHOWN_ICON)
			ic.visible = false
			add_child(ic)
			icons.append(ic)
		_tags[a.id] = {"panel": p, "model": models[a.id], "icons": icons}
	_picker_icons.clear()
	for k in Stamps.ALL:
		var ic := StampIcon.make(k, 0, PICK_ICON, GameConfig.COLOR_INK)
		ic.visible = false
		add_child(ic)
		_picker_icons.append(ic)
	_picker_target = -1


## スタンプの選択肢を、この人の頭の上に丸く並べて出す
func open_picker(id: int) -> void:
	_picker_target = id


func close_picker() -> void:
	_picker_target = -1
	for ic in _picker_icons:
		ic.visible = false


func picker_target() -> int:
	return _picker_target


## 画面のこの位置にある名札の人(なければ -1)
func tag_hit(pos: Vector2) -> int:
	for id in _tags:
		var p: PanelContainer = _tags[id]["panel"]
		if p.visible and p.get_global_rect().grow(6.0).has_point(pos):
			return id
	return -1


## 画面のこの位置に、選択肢のどのスタンプがあるか(なければ "")
func picker_hit(pos: Vector2) -> String:
	if _picker_target < 0:
		return ""
	for i in _picker_icons.size():
		var ic := _picker_icons[i]
		if ic.visible and ic.get_global_rect().grow(6.0).has_point(pos):
			return Stamps.ALL[i]
	return ""


func update(state: GameState, cam: Camera3D) -> void:
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var me := state.get_local_player()
	var can_stamp := me != null and (me.role == GameState.Role.SEATED or me.role == GameState.Role.ONI) \
			and (state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED)
	var placed: Array[Rect2] = []
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
		if sp.x < -out or sp.x > vp.x + out or sp.y < 0.0 or sp.y > vp.y + sz.y:
			p.visible = false
			continue
		var r := Rect2(sp - Vector2(sz.x / 2.0, sz.y), sz)
		r.position.x = clampf(r.position.x, UiStyle.SAFE, vp.x - UiStyle.SAFE - sz.x)
		r.position.y = clampf(r.position.y, TOP_LIMIT, vp.y - sz.y - 8.0)
		for k in 6:
			var hit := false
			for q in placed:
				if q.grow(2.0).intersects(r):
					r.position.y = q.position.y - sz.y - 4.0
					hit = true
			if not hit:
				break
		r.position.y = maxf(r.position.y, TOP_LIMIT)
		placed.append(r)
		p.visible = true
		p.position = r.position.floor()
		var blocked := can_stamp and state.stamp_block_reason(me.id, id) in ["neighbor", "already"]
		p.modulate.a = BLOCKED_ALPHA if blocked else 1.0
		_tag_rects[id] = r
	# 届いているスタンプ(名札の上に、届いた順に並べる)
	for id in _tags:
		var t: Dictionary = _tags[id]
		var icons: Array = t["icons"]
		var p: PanelContainer = t["panel"]
		var list: Array = state.active_stamps.get(id, [])
		for i in icons.size():
			var ic: StampIcon = icons[i]
			ic.visible = p.visible and i < list.size() and id != _picker_target
			if not ic.visible:
				continue
			var st: Dictionary = list[i]
			var sender := state.get_actor(st["sender"])
			ic.kind = st["kind"]
			ic.item = state.round_index
			ic.ring = sender.color if sender else GameConfig.COLOR_INK
			var r: Rect2 = _tag_rects[id]
			var row_w := list.size() * (SHOWN_ICON + 2.0)
			ic.position = (Vector2(r.get_center().x - row_w / 2.0 + i * (SHOWN_ICON + 2.0), r.position.y - SHOWN_ICON - 2.0)).floor()
	_update_picker(state, vp)


## スタンプの選択肢: 相手の名札の上に半円で4つ並べる(画面からはみ出さないように)
func _update_picker(state: GameState, vp: Vector2) -> void:
	if _picker_target < 0:
		return
	var t: Dictionary = _tags.get(_picker_target, {})
	if t.is_empty() or not (t["panel"] as PanelContainer).visible or not _tag_rects.has(_picker_target):
		close_picker()
		return
	var r: Rect2 = _tag_rects[_picker_target]
	var center := Vector2(r.get_center().x, r.position.y - 6.0)
	center.x = clampf(center.x, UiStyle.SAFE + PICK_RADIUS + PICK_ICON / 2.0, vp.x - UiStyle.SAFE - PICK_RADIUS - PICK_ICON / 2.0)
	center.y = clampf(center.y, TOP_LIMIT + PICK_RADIUS + PICK_ICON / 2.0, vp.y - PICK_ICON)
	var n := _picker_icons.size()
	for i in n:
		var ic := _picker_icons[i]
		var a := deg_to_rad(lerpf(195.0, 345.0, float(i) / float(n - 1)))
		var c := center + Vector2(cos(a), sin(a)) * PICK_RADIUS
		ic.item = state.round_index
		ic.position = (c - Vector2(PICK_ICON, PICK_ICON) / 2.0).floor()
		ic.visible = true


func _dist(id: int, cam: Camera3D) -> float:
	var m: CharacterModel = _tags[id]["model"]
	return cam.global_position.distance_to(m.tag_anchor())
