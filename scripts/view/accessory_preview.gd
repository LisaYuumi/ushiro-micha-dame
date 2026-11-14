class_name AccessoryPreview
extends SubViewportContainer
## ロビーの「小物」の画面の、キャラの見本(自分の体の色で、選んだ小物をつけて、ゆっくり左右に向きを変える)。
## 画面が見えている間だけ描く(見えていないときは描かないので軽い)。

var _vp: SubViewport
var _model: CharacterModel
var _time := 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 340)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.look_at_from_position(Vector3(0, 1.45, -4.3), Vector3(0, 1.12, 0))
	_vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	_vp.add_child(sun)


## 体の色と小物で、見本を作り直す
func rebuild(color: Color, acc: Dictionary) -> void:
	if _model:
		_model.queue_free()
	_model = CharacterModel.new()
	_vp.add_child(_model)
	_model.build(color, "", HudFont.get_font())
	_model.set_name_visible(false)
	_model.set_pose("idle")
	_model.set_accessories(acc)


## 小物だけ変える
func set_accessories(acc: Dictionary) -> void:
	if _model:
		_model.set_accessories(acc)


func set_active(v: bool) -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED
	set_process(v)


func _process(delta: float) -> void:
	if _model == null:
		return
	_time += delta
	# 正面(-Z)を見せながら、ゆっくり左右に向きを変える
	_model.rotation.y = sin(_time * 0.8) * 0.6
	_model.animate(delta, false)
