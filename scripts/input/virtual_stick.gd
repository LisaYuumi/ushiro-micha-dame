class_name VirtualStick
extends Control
## スマホ用のスティック。指でなぞった向きを、矢印キーと同じ操作として送る。

const RADIUS := 90.0

var _touch_index := -1
var _knob := Vector2.ZERO # -1〜1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func() -> void:
		# 隠れたら、押していた向きを離す
		if not visible:
			_touch_index = -1
			_set_knob(Vector2.ZERO))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1 and is_visible_in_tree() and get_global_rect().has_point(t.position):
			_touch_index = t.index
			_update_knob(t.position)
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			_set_knob(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update_knob(d.position)


func _update_knob(pos: Vector2) -> void:
	var center := get_global_rect().get_center()
	_set_knob(((pos - center) / RADIUS).limit_length(1.0))


func _set_knob(v: Vector2) -> void:
	_knob = v
	_send("move_left", -v.x)
	_send("move_right", v.x)
	_send("move_up", -v.y)
	_send("move_down", v.y)
	queue_redraw()


func _send(action: String, strength: float) -> void:
	if strength > 0.1:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.25))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	draw_circle(c + _knob * RADIUS, 36.0, Color(1, 1, 1, 0.75))
