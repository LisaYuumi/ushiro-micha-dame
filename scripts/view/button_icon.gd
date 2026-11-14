class_name ButtonIcon
extends Control
## ボタンなどに乗せる小さな絵(コードで描く。A案: 黒い太い輪郭)。
## "milk" 牛乳びん / "milk_pour" かたむけた牛乳パックとしずく / "milk_empty" 倒れた空っぽのパック /
## "drop" 赤い水玉のハンカチ / "fake" 点線のハンカチと音の波

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
		"milk_pour":
			# パックをかたむけて、口から青いしずくが飛ぶ(白い線で描く: 青い地の上に乗せるため)
			_draw_carton(c + Vector2(s * 0.06, s * 0.08), s * 0.85, line, deg_to_rad(-35.0), Color.WHITE, MILK_BLUE)
			for d in [Vector2(-0.36, -0.36), Vector2(-0.2, -0.46)]:
				_drop_shape(c + (d as Vector2) * s, s * 0.08, line * 0.7)
		"milk_empty":
			# 倒れた空っぽのパック(灰色っぽく)
			_draw_carton(c + Vector2(0, s * 0.1), s * 0.8, line, deg_to_rad(-80.0), Color("F2EFEA"), Color("B9B4AC"), Color("8A847C"))
		"water":
			_draw_water_gun(c, s, line, Color("FF8A3D"), Color("6CC6F2"), INK)
		"water_pour":
			# 水鉄砲から水が飛ぶ(白い線で描く: 青い地の上に乗せるため)
			_draw_water_gun(c + Vector2(s * 0.1, s * 0.05), s * 0.9, line, Color.WHITE, Color("BFE8FF"), INK)
			for d in [Vector2(-0.42, -0.2), Vector2(-0.3, -0.32), Vector2(-0.46, -0.04)]:
				_drop_shape(c + (d as Vector2) * s, s * 0.07, line * 0.7)
		"water_empty":
			_draw_water_gun(c, s * 0.9, line, Color("D8D3CC"), Color("ECE8E2"), Color("8A847C"))
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


## 牛乳パック(屋根の形の口)。rot で回す。outline の色は ink(ふつうは黒)
func _draw_carton(c: Vector2, s: float, line: float, rot: float, body: Color, band: Color, ink: Color = INK) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	var w := s * 0.5
	var h := s * 0.62
	var box := PackedVector2Array([Vector2(-w / 2, -h * 0.25), Vector2(w / 2, -h * 0.25), Vector2(w / 2, h * 0.6), Vector2(-w / 2, h * 0.6)])
	draw_colored_polygon(box, body)
	draw_rect(Rect2(Vector2(-w / 2, h * 0.08), Vector2(w, h * 0.22)), band)
	var roof := PackedVector2Array([Vector2(-w / 2, -h * 0.25), Vector2(w / 2, -h * 0.25), Vector2(w * 0.25, -h * 0.55), Vector2(-w * 0.25, -h * 0.55)])
	draw_colored_polygon(roof, body)
	var spout := Rect2(Vector2(-w * 0.25, -h * 0.68), Vector2(w * 0.5, h * 0.13))
	draw_rect(spout, body)
	for poly in [box, roof]:
		var closed: PackedVector2Array = (poly as PackedVector2Array).duplicate()
		closed.append(closed[0])
		draw_polyline(closed, ink, line, true)
	draw_rect(spout, ink, false, line * 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 水鉄砲(左向き): 銃身・上の水タンク・持ち手・引き金
func _draw_water_gun(c: Vector2, s: float, line: float, body: Color, tank: Color, ink: Color) -> void:
	var barrel := Rect2(c + Vector2(-s * 0.42, -s * 0.12), Vector2(s * 0.78, s * 0.2))
	var nozzle := Rect2(c + Vector2(-s * 0.5, -s * 0.08), Vector2(s * 0.1, s * 0.12))
	var grip := PackedVector2Array([c + Vector2(s * 0.08, s * 0.06), c + Vector2(s * 0.3, s * 0.06),
			c + Vector2(s * 0.36, s * 0.42), c + Vector2(s * 0.14, s * 0.42)])
	draw_colored_polygon(grip, body)
	var gc := grip.duplicate()
	gc.append(grip[0])
	draw_polyline(gc, ink, line, true)
	draw_rect(barrel, body)
	draw_rect(barrel, ink, false, line)
	draw_rect(nozzle, body)
	draw_rect(nozzle, ink, false, line * 0.8)
	# タンク(丸)
	var tc := c + Vector2(-s * 0.04, -s * 0.26)
	draw_circle(tc, s * 0.17 + line * 0.5, ink)
	draw_circle(tc, s * 0.17 - line * 0.5, tank)
	# 引き金
	draw_arc(c + Vector2(s * 0.02, s * 0.14), s * 0.07, 0.0, PI, 8, ink, line * 0.8, true)


## しずく(白に黒い輪郭)
func _drop_shape(c: Vector2, r: float, line: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.8)])
	# 下半分の丸(右から左へ)
	for k in 9:
		var a := PI * float(k) / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color.WHITE)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, line, true)


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
