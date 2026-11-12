class_name StampIcon
extends Control
## スタンプの絵: 白い丸の中に「落とし物アイコン」(そのラウンドの落とし物)か「うるうる顔」、
## 右下に記号のバッジ(落ちてる=!、まだ平気=×、ニセかも=?、信じて=!)。
## 外側の輪の色で、送った人がわかる(ring)。全部コードで描く(A案: 黒い太い輪郭)。

## スタンプの種類(Stamps の名前)
var kind := Stamps.DROPPED:
	set(v):
		if kind != v:
			kind = v
			queue_redraw()
## 落とし物の番号(Items の順: 0 ハンカチ / 1 上履き / 2 ランドセル / 3 机 / 4 教卓)
var item := 0:
	set(v):
		if item != v:
			item = v
			queue_redraw()
## 外側の輪の色(送った人の体の色。透明なら黒い輪だけ)
var ring := Color(0, 0, 0, 0):
	set(v):
		if not ring.is_equal_approx(v):
			ring = v
			queue_redraw()

const INK := Color("1E1B18")


static func make(k: String, item_index: int, size_px: float, ring_color := Color(0, 0, 0, 0)) -> StampIcon:
	var s := StampIcon.new()
	s.kind = k
	s.item = item_index
	s.ring = ring_color
	s.custom_minimum_size = Vector2(size_px, size_px)
	s.size = Vector2(size_px, size_px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0 - 3.0
	var c := size / 2.0
	var line := maxf(2.0, r * 0.08)
	# 白い丸(送った人の色の輪つき)
	if ring.a > 0.0:
		draw_circle(c, r, ring)
		draw_circle(c, r * 0.84, Color.WHITE)
	else:
		draw_circle(c, r, Color.WHITE)
	draw_arc(c, r, 0.0, TAU, 40, INK, line, true)
	# 中の絵
	var ic := c + Vector2(-r * 0.08, -r * 0.08)
	if kind == Stamps.TRUST:
		_draw_teary_face(ic, r * 0.62, line)
	else:
		_draw_item(ic, r * 0.5, line)
	# 右下の記号バッジ
	var bc := c + Vector2(r * 0.6, r * 0.6)
	var br := r * 0.42
	var col: Color = WorldView.STAMP_COLORS.get(kind, INK)
	draw_circle(bc, br, col)
	draw_arc(bc, br, 0.0, TAU, 24, INK, line * 0.8, true)
	_draw_symbol(bc, br * 0.62, Stamps.SYMBOLS.get(kind, "!"), maxf(2.0, br * 0.28))


## 記号: 「!」「×」「?」を白で
func _draw_symbol(c: Vector2, s: float, sym: String, w: float) -> void:
	var white := Color.WHITE
	match sym:
		"x":
			draw_line(c + Vector2(-s, -s) * 0.75, c + Vector2(s, s) * 0.75, white, w, true)
			draw_line(c + Vector2(s, -s) * 0.75, c + Vector2(-s, s) * 0.75, white, w, true)
		"?":
			draw_arc(c + Vector2(0, -s * 0.35), s * 0.5, PI * 1.05, PI * 2.35, 12, white, w, true)
			draw_line(c + Vector2(s * 0.05, s * 0.05), c + Vector2(0, s * 0.45), white, w, true)
			draw_circle(c + Vector2(0, s * 0.85), w * 0.6, white)
		_:
			draw_line(c + Vector2(0, -s * 0.9), c + Vector2(0, s * 0.35), white, w * 1.1, true)
			draw_circle(c + Vector2(0, s * 0.85), w * 0.65, white)


## 落とし物アイコン(s: 大きさの目安)
func _draw_item(c: Vector2, s: float, line: float) -> void:
	match item:
		0: # ハンカチ: 水色の四角に白い線(少し傾ける)
			var pts := _pts(c, s, [Vector2(-0.95, -0.75), Vector2(0.8, -0.95), Vector2(0.95, 0.75), Vector2(-0.8, 0.95)])
			_poly(pts, Color("8FD3E8"), line)
			draw_line(c + Vector2(-0.85, 0.0) * s, c + Vector2(0.9, -0.15) * s, Color.WHITE, line, true)
			draw_line(c + Vector2(-0.05, -0.85) * s, c + Vector2(0.1, 0.85) * s, Color.WHITE, line, true)
		1: # 上履き: 白いくつ(横から)、つま先のゴムは青、底は赤
			_poly(_pts(c, s, [Vector2(-1.0, 0.4), Vector2(-1.0, -0.15), Vector2(-0.5, -0.45), Vector2(0.15, -0.35),
					Vector2(0.95, 0.0), Vector2(1.05, 0.4)]), Color.WHITE, line)
			_poly(_pts(c, s, [Vector2(0.35, -0.24), Vector2(0.95, 0.0), Vector2(1.05, 0.4), Vector2(0.4, 0.4)]), Color("4D96FF"), line)
			_poly(_pts(c, s, [Vector2(-1.05, 0.4), Vector2(1.1, 0.4), Vector2(1.1, 0.62), Vector2(-1.05, 0.62)]), Color("D9483B"), line)
		2: # ランドセル: 赤い箱に、かぶせと金具
			_poly(_pts(c, s, [Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, 0.95), Vector2(-0.8, 0.95)]), Color("D9483B"), line)
			_poly(_pts(c, s, [Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, 0.3), Vector2(-0.8, 0.3)]), Color("A9332A"), line)
			_poly(_pts(c, s, [Vector2(-0.18, 0.15), Vector2(0.18, 0.15), Vector2(0.18, 0.5), Vector2(-0.18, 0.5)]), Color("F6C945"), line * 0.7)
		3: # 机: うすい茶色の天板と、灰色の脚
			for x in [-0.8, 0.62]:
				_poly(_pts(c, s, [Vector2(x, -0.2), Vector2(x + 0.18, -0.2), Vector2(x + 0.18, 0.95), Vector2(x, 0.95)]), Color("8A8A8F"), line * 0.7)
			_poly(_pts(c, s, [Vector2(-1.05, -0.55), Vector2(1.05, -0.55), Vector2(1.05, -0.15), Vector2(-1.05, -0.15)]), Color("E2B47A"), line)
		_: # 教卓: 茶色の台(下がすぼまる)と天板
			_poly(_pts(c, s, [Vector2(-0.8, -0.4), Vector2(0.8, -0.4), Vector2(0.62, 0.95), Vector2(-0.62, 0.95)]), Color("B67A45"), line)
			_poly(_pts(c, s, [Vector2(-1.05, -0.72), Vector2(1.05, -0.72), Vector2(1.05, -0.4), Vector2(-1.05, -0.4)]), Color("8E5A30"), line)


## 「信じて」: うるうるした目の顔
func _draw_teary_face(c: Vector2, s: float, line: float) -> void:
	draw_circle(c, s, Color("F6C945"))
	draw_arc(c, s, 0.0, TAU, 32, INK, line, true)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * s * 0.38, -s * 0.08)
		draw_circle(e, s * 0.26, INK)
		draw_circle(e + Vector2(-s * 0.08, -s * 0.09), s * 0.09, Color.WHITE)
		draw_circle(e + Vector2(s * 0.08, s * 0.08), s * 0.05, Color.WHITE)
	# 涙と、ふるえる口
	var tear := c + Vector2(-s * 0.42, s * 0.3)
	draw_colored_polygon(PackedVector2Array([tear + Vector2(0, -s * 0.16), tear + Vector2(s * 0.1, s * 0.03),
			tear + Vector2(0, s * 0.12), tear + Vector2(-s * 0.1, s * 0.03)]), Color("6EC1F0"))
	draw_arc(c + Vector2(0, s * 0.62), s * 0.22, PI * 1.15, PI * 1.85, 10, INK, line, true)


func _pts(c: Vector2, s: float, list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in list:
		out.append(c + (p as Vector2) * s)
	return out


func _poly(pts: PackedVector2Array, fill: Color, line: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, line, true)
