class_name MinionPortrait
extends Control
## 結果カードの裏に出す、手下のキャラの絵(体の色の人型が、手を下ろして立つ。少しにやっとした顔)。

const INK := Color("1E1B18")

var body := Color.WHITE


func _init(body_color: Color = Color.WHITE) -> void:
	body = body_color
	custom_minimum_size = Vector2(150, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.58)
	var line := 4.0
	# 足
	for side in [-1.0, 1.0]:
		var hip := c + Vector2(side * 12, 26)
		var foot := c + Vector2(side * 16, 70)
		_limb(hip, foot, 17.0, line)
		draw_circle(foot + Vector2(side * 3, 2), 9 + line, INK)
		draw_circle(foot + Vector2(side * 3, 2), 9, body)
	# 腕(下ろしている)
	for side in [-1.0, 1.0]:
		var shoulder := c + Vector2(side * 24, -20)
		var hand := c + Vector2(side * 34, 22)
		_limb(shoulder, hand, 14.0, line)
		draw_circle(hand, 8 + line, INK)
		draw_circle(hand, 8, body)
	# 胴
	var torso := Rect2(c + Vector2(-26, -34), Vector2(52, 70))
	_rr(torso, 24, INK)
	_rr(torso.grow(-line), 20, body)
	# 頭
	var head := c + Vector2(0, -64)
	draw_circle(head, 32 + line, INK)
	draw_circle(head, 32, body)
	var face := Color.WHITE if body.get_luminance() < 0.25 else INK
	# にやっとした顔(細めた目と、片方上がった口)
	for side in [-1.0, 1.0]:
		var e := head + Vector2(side * 11, -2)
		draw_line(e + Vector2(-6, 0), e + Vector2(6, -2 * side), face, 3.5, true)
	draw_polyline(PackedVector2Array([head + Vector2(-9, 11), head + Vector2(1, 15), head + Vector2(11, 8)]), face, 3.5, true)


func _limb(a: Vector2, b: Vector2, w: float, line: float) -> void:
	draw_line(a, b, INK, w + line * 2, true)
	draw_line(a, b, body, w, true)
	draw_circle(a, w / 2.0 + line, INK)
	draw_circle(a, w / 2.0, body)


func _rr(r: Rect2, radius: int, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)
