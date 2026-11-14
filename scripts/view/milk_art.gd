class_name MilkArt
extends RefCounted
## 牛乳をかけられたときの白い絵(自作の SVG。ライセンスの心配なし。たれる蜂蜜のイラストの雰囲気を参考に描いた)。
## - 上の帯の下のふちは、大きさのちがう、ゆるく波打つふくらみ
## - ところどころに太いしずく(根元が太く、少しくびれて、先がぷっくり。先は左右にずれる)
## - 細い糸のようなたれと、その下に落ちかけの小さな粒
## - 全体のまわりに太い黒の輪郭(A案)、下のふちに水色のかげ
## 画面の大きさに合わせて SVG を作り、絵(テクスチャ)にする(同じ大きさなら使い回す)。

const INK := "#1E1B18"
const WHITE := "#FFFFFD"
const SHADE := "#CFE6F7"
## 海辺の水鉄砲の水しぶき(同じ形で、水色)
const WATER_WHITE := "#E3F6FF"
const WATER_SHADE := "#7CC8EE"
## 輪郭の太さ・かげの厚み(画面の高さ 720 のとき)
const LINE := 8.0
const SHADE_DEPTH := 10.0

## 帯の下のふちの、いちばん浅いところの高さ(高さの割合)。粒を落とす高さの目安にも使う
const BAND := 0.55
## 帯の下のふちの大きなふくらみ: [位置(横の割合), 深さ(高さの割合), 幅(横の割合)]
const LOBES := [
	[0.10, 0.07, 0.07],
	[0.27, 0.035, 0.05],
	[0.47, 0.10, 0.08],
	[0.66, 0.045, 0.05],
	[0.86, 0.08, 0.07],
]
## 太いしずく: [位置(横の割合), 根元の太さ(高さの割合), 長さ(高さの割合・帯のふちから),
##   くびれ(根元の太さに対する割合), 先の丸の大きさ(根元の半分に対する割合), 先のずれ(根元の半分に対する割合)]
const DRIPS := [
	[0.05, 0.12, 0.17, 0.7, 1.05, 0.3],
	[0.36, 0.11, 0.24, 0.55, 1.15, -0.3],
	[0.58, 0.13, 0.14, 0.75, 1.0, 0.25],
	[0.93, 0.12, 0.21, 0.6, 1.1, -0.35],
]
## 細いたれ: [位置(横の割合), 太さ(高さの割合), 長さ(高さの割合・帯のふちから)]。先の下に小さな粒が落ちかける
const THREADS := [
	[0.19, 0.022, 0.15],
	[0.43, 0.018, 0.10],
	[0.53, 0.024, 0.20],
	[0.74, 0.02, 0.17],
	[0.81, 0.016, 0.09],
]
## 太いしずくの先の下にも、落ちかけの粒を描く(番号)
const DRIP_DROPS := [1, 3]

static var _cache := {}


## 画面の大きさ size(論理ピクセル)の絵。pixel_scale 倍の細かさで作る
static func texture(size: Vector2, pixel_scale: float = 1.5, water: bool = false) -> Texture2D:
	var w := maxf(size.x, 64.0)
	var h := maxf(size.y, 64.0)
	var key := "%d|%d|%.2f|%s" % [int(w), int(h), pixel_scale, water]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var err := img.load_svg_from_string(svg(w, h, water), pixel_scale)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache.clear()
	_cache[key] = tex
	return tex


## 帯の下のふちの高さ(x の位置で)。ゆるい波+大きなふくらみ
static func band_edge(x: float, w: float, h: float) -> float:
	var u := x / w
	var y := h * (BAND + 0.012 * sin(u * TAU * 3.3 + 0.7) + 0.008 * sin(u * TAU * 7.9 + 1.9))
	for lb in LOBES:
		var d: float = (u - float(lb[0])) / float(lb[2])
		y += h * float(lb[1]) * exp(-d * d)
	return y


## 牛乳の形の SVG(幅 w・高さ h)
static func svg(w: float, h: float, water: bool = false) -> String:
	var white := WATER_WHITE if water else WHITE
	var shade := WATER_SHADE if water else SHADE
	var k := h / 720.0
	var shapes := _shapes(w, h)
	var out := PackedStringArray()
	out.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [int(w), int(h), int(w), int(h)])
	# 形をいくつも重ねるので、輪郭は「全部を太い黒の線で描く → 上から全部を塗る」で、外側だけに残す
	for d in shapes:
		out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % [d, INK, INK, LINE * k * 2.0])
	# 水色(かげ)を塗り、白を少し上にずらして重ねる(下のふちに水色が残る)
	for d in shapes:
		out.append('<path d="%s" fill="%s"/>' % [d, shade])
	for d in shapes:
		out.append('<path d="%s" fill="%s" transform="translate(0,%.1f)"/>' % [d, white, -SHADE_DEPTH * k])
	# 帯の中のうすい水色のむら
	for i in 4:
		var cx := w * (0.14 + 0.24 * float(i))
		var cy := h * BAND * (0.3 + 0.35 * fposmod(float(i) * 0.37, 1.0))
		out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.8"/>' % [cx, cy, h * 0.09, h * 0.02, shade])
	# 落ちかけの粒(それぞれ黒い輪郭)
	for drop in _loose_drops(w, h):
		out.append(_drop_svg(drop[0], drop[1], drop[2], k, white))
	out.append('</svg>')
	return "".join(out)


## 白い部分の形(SVG の path の d)の一覧: 帯・太いしずく・細いたれ
static func _shapes(w: float, h: float) -> Array:
	var list := []
	# 帯: 上の外側から、下のふちを右から左へなぞる
	var p := PackedStringArray()
	p.append("M -40 -40 L %.1f -40" % [w + 40.0])
	var steps := int(w / 6.0) + 14
	for i in steps + 1:
		var x := w + 40.0 - (w + 80.0) * float(i) / float(steps)
		p.append("L %.1f %.1f" % [x, band_edge(x, w, h)])
	p.append("Z")
	list.append(" ".join(p))
	for dr in DRIPS:
		var cx: float = w * float(dr[0])
		var half: float = h * float(dr[1]) / 2.0
		var edge := band_edge(cx, w, h)
		list.append(_drip_path(cx, edge - half, half, edge + h * float(dr[2]), half * float(dr[3]), half * float(dr[4]), half * float(dr[5])))
	for th in THREADS:
		var cx: float = w * float(th[0])
		var half: float = h * float(th[1]) / 2.0
		var edge := band_edge(cx, w, h)
		# 細いたれ: 根元が少し太く、先がほんの少しふくらむ
		list.append(_drip_path(cx, edge - h * 0.02, half * 2.2, edge + h * float(th[2]), half, half * 1.25, 0.0))
	return list


## 上の端 top(帯の中にかくれる)から、先 tip まで。根元の太さの半分 half、くびれの半分 neck、先の丸の半径 bulb、先のずれ sway
static func _drip_path(cx: float, top: float, half: float, tip: float, neck: float, bulb: float, sway: float) -> String:
	var x0 := cx - half
	var x1 := cx + half
	var bulb_y := tip - bulb
	var neck_y := top + (bulb_y - top) * 0.55
	var neck_x := cx + sway * 0.5
	var p := PackedStringArray()
	p.append("M %.1f %.1f" % [x0, top])
	p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [x0, top + (neck_y - top) * 0.55, neck_x - neck, neck_y - (neck_y - top) * 0.35, neck_x - neck, neck_y])
	p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [neck_x - neck, neck_y + (bulb_y - neck_y) * 0.5, cx + sway - bulb, bulb_y - (bulb_y - neck_y) * 0.45, cx + sway - bulb, bulb_y])
	p.append("A %.1f %.1f 0 0 0 %.1f %.1f" % [bulb, bulb, cx + sway + bulb, bulb_y])
	p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [cx + sway + bulb, bulb_y - (bulb_y - neck_y) * 0.45, neck_x + neck, neck_y + (bulb_y - neck_y) * 0.5, neck_x + neck, neck_y])
	p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [neck_x + neck, neck_y - (neck_y - top) * 0.35, x1, top + (neck_y - top) * 0.55, x1, top])
	p.append("Z")
	return " ".join(p)


## 落ちかけの粒: [x, y(粒の丸のまん中), 半径]
static func _loose_drops(w: float, h: float) -> Array:
	var out := []
	for th in THREADS:
		var cx: float = w * float(th[0])
		var r: float = h * float(th[1]) * 0.75
		out.append([cx, band_edge(cx, w, h) + h * float(th[2]) + h * 0.045, r])
	for i in DRIP_DROPS:
		var dr: Array = DRIPS[i]
		var half: float = h * float(dr[1]) / 2.0
		var cx: float = w * float(dr[0]) + half * float(dr[5])
		out.append([cx, band_edge(w * float(dr[0]), w, h) + h * float(dr[2]) + h * 0.06, half * 0.4])
	return out


## しずく形の粒(上がとがって、下が丸い。白に黒い輪郭)
static func _drop_svg(cx: float, cy: float, r: float, k: float, white: String = WHITE) -> String:
	return '<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f A %.1f %.1f 0 1 1 %.1f %.1f Q %.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="%.1f"/>' % [
		cx, cy - r * 2.3, cx + r * 0.25, cy - r * 1.2, cx + r, cy, r, r, cx - r, cy,
		cx - r * 0.25, cy - r * 1.2, cx, cy - r * 2.3, white, INK, LINE * k * 0.7]
