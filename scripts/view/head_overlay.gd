class_name HeadOverlay
extends CanvasLayer
## 頭の上の名札を、3D の上に重ねた 2D で出す(A案: 白地・黒枠の丸い札)。
## - 距離に関係なく、画面の上で同じ大きさ
## - 画面の端で切れないように内側に寄せる
## - 名札どうしが重ならないように、重なる札は上へずらす
## 見た目だけ。状態は読むだけで変えない。

const FONT_SIZE := 20
## 名札を置かない上の帯(左上の札の下から)
const TOP_LIMIT := 70.0
## 送れない相手(8人のときの両どなり・このラウンド送った人)の名札の濃さ
const BLOCKED_ALPHA := 0.4

## id -> {"panel": PanelContainer, "label": Label}
var _tags := {}


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
		_tags[a.id] = {"panel": p, "model": models[a.id]}


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


func _dist(id: int, cam: Camera3D) -> float:
	var m: CharacterModel = _tags[id]["model"]
	return cam.global_position.distance_to(m.tag_anchor())
