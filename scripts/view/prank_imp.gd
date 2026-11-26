class_name PrankImp
extends Control
## いたずらっ子!: 小さくてかわいい、いたずら好きのキャラクター(2D で描く)。
## 黄色い丸い顔に、ピエロのような2つにとがった水色の帽子(先に鈴)、にやっと笑った口。
## (手下の紫とはちがう色と形)。tool: "" / "eraser"(消しゴム)/ "crayon"(クレヨン)を手に持つ

var tool := ""
var grin := 1.0
var _t := 0.0

const FACE := Color("FFD54A")
const HAT := Color("2BB5C7")
const HAT2 := Color("FF6B9A")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(60, 60)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var ink := GameConfig.COLOR_INK
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var r := s * 0.3
	# 帽子(2つにとがった、ピエロの帽子。先に鈴)
	var left := PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.55), c + Vector2(-r * 1.25, -r * 1.75), c + Vector2(0, -r * 0.8)])
	var right := PackedVector2Array([c + Vector2(r * 1.0, -r * 0.55), c + Vector2(r * 1.25, -r * 1.75), c + Vector2(0, -r * 0.8)])
	for poly in [[left, HAT], [right, HAT2]]:
		var pts: PackedVector2Array = poly[0]
		draw_colored_polygon(pts, poly[1])
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, ink, 2.0, true)
	for tip in [c + Vector2(-r * 1.25, -r * 1.75), c + Vector2(r * 1.25, -r * 1.75)]:
		draw_circle(tip, r * 0.2 + 1.5, ink)
		draw_circle(tip, r * 0.2, Color("FFE27A"))
	# 顔
	draw_circle(c, r + 2.5, ink)
	draw_circle(c, r, FACE)
	# ほっぺ
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * r * 0.6, r * 0.2), r * 0.16, Color(1.0, 0.5, 0.5, 0.6))
	# にやっとした目(への字)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.38, -r * 0.12)
		draw_polyline(PackedVector2Array([e + Vector2(-r * 0.16, r * 0.06), e + Vector2(0, -r * 0.08), e + Vector2(r * 0.16, r * 0.06)]),
				ink, 2.5, true)
	# にしし口(半月)
	var mouth := PackedVector2Array()
	for k in 9:
		var a := PI * float(k) / 8.0
		mouth.append(c + Vector2(cos(a) * r * 0.45, r * 0.18 + sin(a) * r * 0.35 * grin))
	draw_colored_polygon(mouth, ink)
	# 手に持つ道具
	var hand := c + Vector2(r * 1.15, r * 0.35 + sin(_t * 30.0) * (2.0 if tool != "" else 0.0))
	match tool:
		"eraser":
			var rect := Rect2(hand - Vector2(r * 0.45, r * 0.25), Vector2(r * 0.9, r * 0.5))
			draw_rect(rect.grow(2.0), ink)
			draw_rect(rect, Color("FF9EB5"))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.35, rect.size.y)), Color("4D7CFE"))
		"crayon":
			var a := hand + Vector2(-r * 0.2, r * 0.3)
			var b := hand + Vector2(r * 0.35, -r * 0.45)
			draw_line(a, b, ink, r * 0.32 + 3.0, true)
			draw_line(a, b, Color("E5483B"), r * 0.32, true)
