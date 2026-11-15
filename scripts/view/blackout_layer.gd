class_name BlackoutLayer
extends CanvasLayer
## 停電イベント(見た目だけ)。3D の塗りそのものを暗くする(Toon.set_darkness。画面全体に幕を重ねると、
## そのぶん描く量が増えて重くなるので使わない)。名札や表示は 2D なので暗くならない。
## - 真っ黒にはしない(GameConfig.BLACKOUT_BRIGHTNESS)
## - キャラの目だけ、うっすら光る点で描く
## - ときどき窓の外の稲光で、一瞬だけ明るくなる(間かくは GameConfig)
## - 自分が鬼なら、懐中電灯で自分のまわりがうっすら見える(鬼の画面だけ。ほかの人には鬼の場所はわからない)

var _eyes: Control
## いまの明るさ(1 = ふつう。空の色を暗くするのに WorldView が読む)
var _bright := 1.0
var _eye_points: PackedVector2Array = PackedVector2Array()
var _on := false
var _flash := 0.0
var _lightning_left := 0.0
var _flash_plan: Array = []


func _ready() -> void:
	layer = 0
	Toon.set_darkness(1.0)
	_eyes = Control.new()
	_eyes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_eyes.draw.connect(_draw_eyes)
	add_child(_eyes)
	visible = false


## 毎フレーム: 停電中なら幕をかけ、目の位置と懐中電灯の丸を合わせる
func update(state: GameState, cam: Camera3D, models: Dictionary, delta: float, skip_id: int = -1) -> void:
	var on := state.blackout and state.phase != GameState.Phase.RESULT
	if on != _on:
		_on = on
		visible = on
		_lightning_left = randf_range(2.0, 5.0)
		_flash_plan = []
		if not on:
			_bright = 1.0
			Toon.set_darkness(1.0)
	if not on or cam == null:
		return
	# 稲光: ピカッ、少しおいてもう一度ピカッ
	_lightning_left -= delta
	if _lightning_left <= 0.0:
		_lightning_left = randf_range(GameConfig.BLACKOUT_LIGHTNING_MIN, GameConfig.BLACKOUT_LIGHTNING_MAX)
		_flash_plan = [[0.0, 0.08], [0.18, 0.07]]
	_flash = 0.0
	var keep: Array = []
	for f in _flash_plan:
		f[0] -= delta
		if f[0] <= 0.0:
			f[1] -= delta
			if f[1] > 0.0:
				_flash = 1.0
				keep.append(f)
		else:
			keep.append(f)
	_flash_plan = keep
	var bright := lerpf(GameConfig.BLACKOUT_BRIGHTNESS, GameConfig.BLACKOUT_LIGHTNING_BRIGHTNESS, _flash)
	_bright = bright
	# 自分が鬼なら懐中電灯(自分の足もとのまわりが、うっすら明るい)
	var me := state.get_local_player()
	var oni := state.get_actor(state.oni_id)
	if me != null and oni != null and me.id == oni.id:
		Toon.set_darkness(bright, oni.position, GameConfig.BLACKOUT_FLASHLIGHT_RADIUS, GameConfig.BLACKOUT_FLASHLIGHT_BRIGHTNESS)
	else:
		Toon.set_darkness(bright)
	# キャラの目(暗い中で、うっすら光る)
	_eye_points = PackedVector2Array()
	var cam_pos := cam.global_position
	for id in models:
		if id == skip_id:
			continue
		var m := models[id] as CharacterModel
		if m == null:
			continue
		for p in m.eye_points_facing(cam_pos):
			if cam.is_position_behind(p):
				continue
			if cam_pos.distance_to(p) > 30.0:
				continue
			if _hidden_by_body(cam_pos, p, id, models):
				continue
			_eye_points.append(cam.unproject_position(p))
	_eyes.queue_redraw()


## カメラから目までの間に、ほかの人の体(足もとから頭までの太い棒とみなす)があれば、目はかくれている
func _hidden_by_body(cam_pos: Vector3, eye: Vector3, owner_id: int, models: Dictionary) -> bool:
	for id in models:
		if id == owner_id:
			continue
		var m := models[id] as Node3D
		if m == null or not m.visible:
			continue
		var base := m.global_position
		var a := base + Vector3(0, 0.25, 0)
		var b := base + Vector3(0, 1.75, 0)
		var pq := Geometry3D.get_closest_points_between_segments(cam_pos, eye, a, b)
		var on_ray: Vector3 = pq[0]
		var on_body: Vector3 = pq[1]
		# 目より手前で、体の太さ(0.3m)より近くを通るなら、かくれている
		if on_ray.distance_to(on_body) < 0.3 and on_ray.distance_to(eye) > 0.35:
			return true
	return false


func _draw_eyes() -> void:
	var glow := Color(1.0, 0.95, 0.7, 0.18 * (1.0 - _flash))
	var core := Color(1.0, 0.98, 0.85, 0.85 * (1.0 - _flash))
	for p in _eye_points:
		_eyes.draw_circle(p, 9.0, glow)
		_eyes.draw_circle(p, 3.2, core)


func brightness() -> float:
	return _bright


func _exit_tree() -> void:
	# ラウンドが変わって作り直すときは、明るさを戻しておく
	Toon.set_darkness(1.0)
