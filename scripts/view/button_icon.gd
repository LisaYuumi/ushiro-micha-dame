class_name ButtonIcon
extends Control
## ボタンなどに乗せる小さな絵(コードで描く。A案: 黒い太い輪郭)。
## "milk" 牛乳びん / "drop" 赤い水玉のハンカチ / "fake" 点線のハンカチと音の波

const INK := Color("1E1B18")
const MILK_BLUE := Color("4D96FF")
const HANKIE_RED := Color("E0483B")

var kind := "milk":
	set(v):
		kind = v
		queue_redraw()


static func make(k: String, size_px: Vector2) -> ButtonIcon:
	var ic := ButtonIcon.new()
	ic.kind = k
	ic.custom_minimum_size = size_px
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var line := maxf(2.0, s * 0.07)
	match kind:
		"milk":
			draw_milk_bottle(self, c, s, line)
		"drop":
			_draw_hankie(c, s, line, false)
		"fake":
			_draw_hankie(c + Vector2(-s * 0.3, 0), s * 0.9, line, true)
			# 音の波
			for k in 2:
				var r := s * (0.22 + 0.18 * k)
				draw_arc(c + Vector2(s * 0.2, 0), r, -0.75, 0.75, 10, INK, line, true)


## 牛乳びん: 白いびん、青いふたと帯(ほかの絵からも使う)
static func draw_milk_bottle(ci: CanvasItem, c: Vector2, s: float, line: float) -> void:
	var w := s * 0.42
	var body := PackedVector2Array([
		c + Vector2(-w * 0.32, -s * 0.36), c + Vector2(w * 0.32, -s * 0.36),
		c + Vector2(w * 0.32, -s * 0.22), c + Vector2(w * 0.5, -s * 0.08),
		c + Vector2(w * 0.5, s * 0.42), c + Vector2(-w * 0.5, s * 0.42),
		c + Vector2(-w * 0.5, -s * 0.08), c + Vector2(-w * 0.32, -s * 0.22),
	])
	ci.draw_colored_polygon(body, Color.WHITE)
	# 青い帯
	ci.draw_rect(Rect2(c + Vector2(-w * 0.5, s * 0.02), Vector2(w, s * 0.17)), MILK_BLUE)
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, INK, line, true)
	# ふた
	var cap := Rect2(c + Vector2(-w * 0.4, -s * 0.47), Vector2(w * 0.8, s * 0.12))
	ci.draw_rect(cap, MILK_BLUE)
	ci.draw_rect(cap, INK, false, line * 0.8)


## ハンカチ: 白い布に赤い水玉。dashed = true なら点線のふち(ニセ)
func _draw_hankie(c: Vector2, s: float, line: float, dashed: bool) -> void:
	var h := s * 0.4
	var rot := deg_to_rad(-6.0)
	var pts := PackedVector2Array()
	for q in [Vector2(-1, -0.8), Vector2(1, -0.8), Vector2(1, 0.8), Vector2(-1, 0.8)]:
		pts.append(c + ((q as Vector2) * h).rotated(rot))
	if not dashed:
		draw_colored_polygon(pts, Color.WHITE)
		for d in [Vector2(-0.5, -0.35), Vector2(0.3, -0.45), Vector2(0.55, 0.3), Vector2(-0.2, 0.35), Vector2(0.05, -0.02)]:
			draw_circle(c + ((d as Vector2) * h).rotated(rot), s * 0.065, HANKIE_RED)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, INK, line, true)
	else:
		for i in 4:
			draw_dashed_line(pts[i], pts[(i + 1) % 4], INK, line, s * 0.09, true)
