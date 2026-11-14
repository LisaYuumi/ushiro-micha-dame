class_name BlackoutLayer
extends CanvasLayer
## 停電イベントの暗い幕(見た目だけ)。3D の上・名札や吹き出し・ボタンの下にかける(名札や表示は暗くならない)。
## - 真っ黒にはしない(GameConfig.BLACKOUT_BRIGHTNESS)
## - キャラの目だけ、うっすら光る点で描く
## - ときどき窓の外の稲光で、一瞬だけ明るくなる(間かくは GameConfig)
## - 自分が鬼なら、懐中電灯で自分のまわりがうっすら見える(鬼の画面だけ。ほかの人には鬼の場所はわからない)

const _SHADER := """
shader_type canvas_item;
uniform float darkness = 0.85;
uniform vec2 hole_center = vec2(0.5, 0.5);
uniform float hole_radius = 0.0;
uniform float hole_bright = 0.6;
uniform float aspect = 1.78;
void fragment() {
	float a = darkness;
	if (hole_radius > 0.0) {
		vec2 d = (SCREEN_UV - hole_center) * vec2(aspect, 1.0);
		float k = smoothstep(hole_radius * 0.35, hole_radius, length(d));
		a = darkness * mix(1.0 - hole_bright, 1.0, k);
	}
	COLOR = vec4(0.02, 0.03, 0.08, a);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _eyes: Control
var _eye_points: PackedVector2Array = PackedVector2Array()
var _on := false
var _flash := 0.0
var _lightning_left := 0.0
var _flash_plan: Array = []


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = _SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
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
	_mat.set_shader_parameter("darkness", 1.0 - bright)
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	# 自分が鬼なら懐中電灯(自分の足もとのまわり)
	var me := state.get_local_player()
	var oni := state.get_actor(state.oni_id)
	if me != null and oni != null and me.id == oni.id and not cam.is_position_behind(oni.position):
		var sp := cam.unproject_position(oni.position + Vector3(0, 0.6, 0))
		_mat.set_shader_parameter("hole_center", sp / vp)
		_mat.set_shader_parameter("hole_radius", GameConfig.BLACKOUT_FLASHLIGHT_RADIUS)
		_mat.set_shader_parameter("hole_bright", GameConfig.BLACKOUT_FLASHLIGHT_BRIGHTNESS)
	else:
		_mat.set_shader_parameter("hole_radius", 0.0)
	# キャラの目(暗い中で、うっすら光る)
	_eye_points = PackedVector2Array()
	for id in models:
		if id == skip_id:
			continue
		var m := models[id] as CharacterModel
		if m == null:
			continue
		for p in m.eye_points():
			if cam.is_position_behind(p):
				continue
			if cam.global_position.distance_to(p) > 30.0:
				continue
			_eye_points.append(cam.unproject_position(p))
	_eyes.queue_redraw()


func _draw_eyes() -> void:
	var glow := Color(1.0, 0.95, 0.7, 0.18 * (1.0 - _flash))
	var core := Color(1.0, 0.98, 0.85, 0.85 * (1.0 - _flash))
	for p in _eye_points:
		_eyes.draw_circle(p, 9.0, glow)
		_eyes.draw_circle(p, 3.2, core)
