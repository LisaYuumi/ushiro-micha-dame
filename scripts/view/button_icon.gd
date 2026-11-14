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
## 「落とす」「フェイク」のボタンに出す落とし物(ラウンドごとに変わる): ITEMS のどれか
var item := "hankie":
	set(v):
		item = v
		queue_redraw()

## 落とし物の絵の名前(舞台ごとに、ラウンドの順)
const ITEMS := {
	"classroom": ["hankie", "shoe", "randoseru", "desk", "podium"],
	"beach": ["shell", "ball", "ring", "castle", "boat"],
}


static func item_key(stage: String, round_index: int) -> String:
	var list: Array = ITEMS.get(stage, ITEMS["classroom"])
	return list[clampi(round_index, 0, list.size() - 1)]


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
			_draw_item(item, c, s, line, false)
		"fake":
			# うすい落とし物(ニセ)と、音の波
			_draw_item(item, c + Vector2(-s * 0.3, 0), s * 0.9, line, true)
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


# --- 落とし物の絵(落とす・フェイクのボタン) ---

## ghost = true なら、うすく塗って点線のふち(フェイク)
func _draw_item(it: String, c: Vector2, s: float, line: float, ghost: bool) -> void:
	match it:
		"hankie":
			_draw_hankie(c, s, line, ghost)
		"shoe":
			# 上履き: 白い本体、青いつま先(右)、赤い底
			_poly(_pts(c, s, [[-0.42, 0.12], [0.36, 0.12], [0.44, 0.02], [0.4, -0.08], [0.08, -0.1], [-0.08, -0.24], [-0.42, -0.24]]), Color.WHITE, line, ghost)
			_poly(_pts(c, s, [[0.12, 0.12], [0.36, 0.12], [0.44, 0.02], [0.4, -0.08], [0.12, -0.1]]), Color("3F86F0"), line, ghost)
			_poly(_pts(c, s, [[-0.44, 0.12], [0.38, 0.12], [0.36, 0.22], [-0.44, 0.22]]), Color("D9483B"), line, ghost)
		"randoseru":
			# ランドセル: 赤い本体、かぶせ、金の留め具
			_poly(_pts(c, s, [[-0.32, -0.3], [0.32, -0.3], [0.34, 0.4], [-0.34, 0.4]]), Color("C8322B"), line, ghost)
			_poly(_pts(c, s, [[-0.32, -0.3], [0.32, -0.3], [0.3, 0.1], [0.0, 0.18], [-0.3, 0.1]]), Color("E5483B"), line, ghost)
			_poly(_pts(c, s, [[-0.06, 0.1], [0.06, 0.1], [0.06, 0.22], [-0.06, 0.22]]), Color("F2C14E"), line * 0.7, ghost)
		"desk":
			# 机: 天板・物入れ・脚
			for x in [-0.3, 0.3]:
				_poly(_pts(c, s, [[x - 0.04, 0.0], [x + 0.04, 0.0], [x + 0.04, 0.42], [x - 0.04, 0.42]]), Color("9AA3AD"), line * 0.7, ghost)
			_poly(_pts(c, s, [[-0.34, -0.04], [0.34, -0.04], [0.34, 0.12], [-0.34, 0.12]]), Color("9AA3AD"), line, ghost)
			_poly(_pts(c, s, [[-0.44, -0.16], [0.44, -0.16], [0.44, -0.04], [-0.44, -0.04]]), Color("E2CDA6"), line, ghost)
		"podium":
			# 教卓: 台形の木の箱と天板
			_poly(_pts(c, s, [[-0.3, -0.18], [0.3, -0.18], [0.36, 0.42], [-0.36, 0.42]]), Color("8B5A33"), line, ghost)
			_poly(_pts(c, s, [[-0.42, -0.3], [0.42, -0.3], [0.42, -0.18], [-0.42, -0.18]]), Color("B67A45"), line, ghost)
		"shell":
			# 貝殻: 扇の形と、うね
			var fan := PackedVector2Array([c + Vector2(0, 0.3) * s])
			for k in 13:
				var a := deg_to_rad(lerpf(200.0, 340.0, float(k) / 12.0))
				fan.append(c + Vector2(cos(a), sin(a) * 0.95) * s * 0.44 + Vector2(0, 0.08) * s)
			_poly(fan, Color("F6B4C0"), line, ghost)
			if not ghost:
				for k in 5:
					var a := deg_to_rad(lerpf(225.0, 315.0, float(k) / 4.0))
					draw_line(c + Vector2(0, 0.3) * s, c + Vector2(cos(a), sin(a) * 0.95) * s * 0.4 + Vector2(0, 0.08) * s, INK, line * 0.5, true)
		"ball":
			# ビーチボール: 白い玉に、赤・青・黄のしま
			var cols := [Color("E5483B"), Color.WHITE, Color("3F86F0"), Color.WHITE, Color("F2C14E"), Color.WHITE]
			for k in 6:
				var wedge := PackedVector2Array([c])
				for j in 7:
					var a := TAU * (float(k) + float(j) / 6.0) / 6.0 - PI / 2.0
					wedge.append(c + Vector2(cos(a), sin(a)) * s * 0.4)
				var f: Color = cols[k]
				if ghost:
					f.a = 0.35
				draw_colored_polygon(wedge, f)
			_ring_outline(c, s * 0.4, line, ghost)
		"ring":
			# 浮き輪: 赤い輪に白い帯
			var col := Color("E5483B")
			if ghost:
				col.a = 0.35
			draw_arc(c, s * 0.3, 0.0, TAU, 40, col, s * 0.2, true)
			if not ghost:
				for k in 4:
					var a := TAU * float(k) / 4.0 + PI / 4.0
					draw_arc(c, s * 0.3, a - 0.18, a + 0.18, 6, Color.WHITE, s * 0.2, true)
			_ring_outline(c, s * 0.4, line, ghost)
			_ring_outline(c, s * 0.2, line, ghost)
		"castle":
			# 砂の城: 土台と2つの塔(とんがり屋根)と旗
			var sand := Color("E6C287")
			_poly(_pts(c, s, [[-0.4, 0.05], [0.4, 0.05], [0.4, 0.4], [-0.4, 0.4]]), sand, line, ghost)
			for x in [-0.26, 0.26]:
				_poly(_pts(c, s, [[x - 0.12, -0.15], [x + 0.12, -0.15], [x + 0.12, 0.05], [x - 0.12, 0.05]]), sand, line, ghost)
				_poly(_pts(c, s, [[x - 0.15, -0.15], [x + 0.15, -0.15], [x, -0.38]]), Color("F3D9A4"), line, ghost)
			_poly(_pts(c, s, [[-0.02, 0.05], [0.02, 0.05], [0.02, -0.42], [-0.02, -0.42]]), Color("8B6240"), line * 0.5, ghost)
			_poly(_pts(c, s, [[0.02, -0.42], [0.2, -0.36], [0.02, -0.3]]), Color("E5483B"), line * 0.6, ghost)
		_:
			# バナナボート: 黄色い弓なりの胴、茶色い先、青い取っ手
			var top := []
			var bottom := []
			for k in 13:
				var t := float(k) / 12.0
				var x := lerpf(-0.46, 0.46, t)
				var bend := 0.18 * (1.0 - pow(2.0 * t - 1.0, 2.0))
				top.append([x, -0.04 - bend])
				bottom.append([x, 0.16 - bend * 0.6])
			bottom.reverse()
			_poly(_pts(c, s, top + bottom), Color("FFD93B"), line, ghost)
			_poly(_pts(c, s, [[0.38, -0.08], [0.5, -0.12], [0.48, 0.06], [0.38, 0.12]]), Color("6B4A2B"), line * 0.7, ghost)
			if not ghost:
				for x in [-0.2, 0.05]:
					var bend := 0.18 * (1.0 - pow(2.0 * ((x + 0.46) / 0.92) - 1.0, 2.0))
					draw_line(c + Vector2(x - 0.06, -0.08 - bend) * s, c + Vector2(x + 0.06, -0.08 - bend) * s, Color("3F86F0"), line * 1.2, true)


## [[x, y], ...](大きさ s に対する割合)を、画面の点に
func _pts(c: Vector2, s: float, list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in list:
		out.append(c + Vector2(float(p[0]), float(p[1])) * s)
	return out


## 塗りと黒いふち(ghost ならうすく塗って点線のふち)
func _poly(pts: PackedVector2Array, fill: Color, line: float, ghost: bool) -> void:
	var f := fill
	if ghost:
		f.a = 0.35
	draw_colored_polygon(pts, f)
	if ghost:
		for i in pts.size():
			draw_dashed_line(pts[i], pts[(i + 1) % pts.size()], INK, line * 0.8, line * 1.6, true)
	else:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, INK, line, true)


func _ring_outline(c: Vector2, r: float, line: float, ghost: bool) -> void:
	if not ghost:
		draw_arc(c, r, 0.0, TAU, 40, INK, line, true)
		return
	for k in 16:
		var a := TAU * float(k) / 16.0
		draw_arc(c, r, a, a + TAU / 32.0, 3, INK, line * 0.8, true)
