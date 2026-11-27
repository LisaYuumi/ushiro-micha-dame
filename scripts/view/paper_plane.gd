class_name PaperPlane
extends Control
## 自分に届いた言葉の紙飛行機(小さな白い紙飛行機。翼の折り目に送った人の色)。右(+X)が進む向き

var color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO


func _draw() -> void:
	var s := GameConfig.STAMP_PLANE_SIZE
	var ink := GameConfig.COLOR_INK
	var nose := Vector2(s * 0.6, 0)
	var top := Vector2(-s * 0.5, -s * 0.42)
	var bot := Vector2(-s * 0.5, s * 0.42)
	var mid := Vector2(-s * 0.28, 0)
	var keel := Vector2(-s * 0.4, s * 0.12)
	# 上の翼・下の翼(白)、真ん中の折り目(送った人の色)
	for poly in [[nose, top, mid], [nose, mid, bot]]:
		var pts := PackedVector2Array(poly)
		draw_colored_polygon(pts, Color.WHITE)
		pts.append(pts[0])
		draw_polyline(pts, ink, 2.0, true)
	var fold := PackedVector2Array([nose, mid, keel])
	draw_colored_polygon(fold, color)
	fold.append(fold[0])
	draw_polyline(fold, ink, 2.0, true)
