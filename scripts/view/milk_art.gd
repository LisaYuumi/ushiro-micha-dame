class_name MilkArt
extends RefCounted
## 牛乳をかけられたときの白い絵(見本をまねた自作の SVG。ライセンスの心配なし)。
## 上の帯から、ぷっくりしたしずくがたれる。しずくの間は丸いアーチ。太い黒の輪郭と、下のふちに水色のかげ。
## 画面の大きさに合わせて SVG を作り、絵(テクスチャ)にする(同じ大きさなら使い回す)。

const INK := "#1E1B18"
const WHITE := "#FFFFFD"
const SHADE := "#CFE6F7"
## 輪郭の太さ・かげの厚み(画面の高さ 720 のとき)
const LINE := 9.0
const SHADE_DEPTH := 11.0

## しずく: [まん中の位置(横の割合), 根元の太さ(高さの割合), 長さ(高さの割合・アーチの高さから),
##   くびれ(根元の太さに対する割合), 先の丸の大きさ(根元の太さの半分に対する割合), 先のずれ(根元の太さの半分に対する割合。+ で右)]
## まっすぐな棒にならないように、根元は太く、途中で少しくびれて、先がぷっくり。先は左右に少しずれる
const DRIPS := [
	[0.035, 0.12, 0.26, 0.75, 1.0, 0.25],
	[0.13, 0.10, 0.46, 0.55, 1.15, -0.35],
	[0.225, 0.13, 0.18, 0.9, 0.95, 0.15],
	[0.33, 0.09, 0.54, 0.5, 1.2, 0.4],
	[0.43, 0.14, 0.27, 0.7, 1.0, -0.2],
	[0.535, 0.10, 0.40, 0.55, 1.15, 0.3],
	[0.635, 0.13, 0.17, 0.9, 0.95, -0.1],
	[0.735, 0.09, 0.50, 0.5, 1.2, -0.4],
	[0.835, 0.13, 0.25, 0.75, 1.0, 0.2],
	[0.94, 0.11, 0.38, 0.6, 1.1, -0.3],
]
## 先から離れて落ちかけている粒を描くしずく(番号)
const LOOSE_DROPS := [1, 5, 9]
## 帯の下のふち(アーチのいちばん上)の高さ(高さの割合)
const BAND := 0.24

static var _cache := {}


## 画面の大きさ size(論理ピクセル)の絵。pixel_scale 倍の細かさで作る
static func texture(size: Vector2, pixel_scale: float = 1.5) -> Texture2D:
	var w := maxf(size.x, 64.0)
	var h := maxf(size.y, 64.0)
	var key := "%d|%d|%.2f" % [int(w), int(h), pixel_scale]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var err := img.load_svg_from_string(svg(w, h), pixel_scale)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache.clear()
	_cache[key] = tex
	return tex


## 牛乳の形の SVG(幅 w・高さ h)
static func svg(w: float, h: float) -> String:
	var k := h / 720.0
	var d := _outline_path(w, h)
	var out := PackedStringArray()
	out.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [int(w), int(h), int(w), int(h)])
	# 1) 水色(かげ) 2) 白を少し上にずらして重ねる(下のふちに水色が残る) 3) 黒い輪郭
	out.append('<path d="%s" fill="%s"/>' % [d, SHADE])
	out.append('<path d="%s" fill="%s" transform="translate(0,%.1f)"/>' % [d, WHITE, -SHADE_DEPTH * k])
	# 帯の中のうすい水色のむら
	for i in 4:
		var cx := w * (0.14 + 0.24 * float(i))
		var cy := h * BAND * (0.35 + 0.15 * sin(float(i) * 2.3))
		out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.8"/>' % [cx, cy, h * 0.09, h * 0.022, SHADE])
	# しずくの中の、てかり(白い小さな楕円)と、水色の小さな粒
	for i in DRIPS.size():
		var dr: Array = DRIPS[i]
		if i % 3 == 1:
			var cx: float = w * dr[0] - h * dr[1] * 0.18
			var cy: float = h * (BAND + dr[2] * 0.55)
			out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % [cx, cy, h * 0.008, h * 0.022, SHADE])
	out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % [d, INK, LINE * k])
	# 先から離れて落ちかけている粒
	for i in LOOSE_DROPS:
		var dr: Array = DRIPS[i]
		var half: float = h * dr[1] / 2.0
		var cx: float = w * dr[0] + half * dr[5]
		var cy: float = h * (BAND + dr[2]) + h * 0.06
		var r := half * 0.42
		out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f A %.1f %.1f 0 1 1 %.1f %.1f Q %.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="%.1f"/>' % [
			cx, cy - r * 2.2, cx + r * 0.2, cy - r * 1.2, cx + r, cy, r, r, cx - r, cy,
			cx - r * 0.2, cy - r * 1.2, cx, cy - r * 2.2, WHITE, INK, LINE * k * 0.8])
	out.append('</svg>')
	return "".join(out)


## 牛乳の外側の線: 左上の外から、しずくとアーチを左から順にたどって、右上の外へ
static func _outline_path(w: float, h: float) -> String:
	var band := h * BAND
	# しずくの左右の端(x)と、先の丸の下の端(y)
	var lefts := []
	var rights := []
	var tips := []
	for dr in DRIPS:
		var cx: float = w * dr[0]
		var half: float = h * dr[1] / 2.0
		lefts.append(cx - half)
		rights.append(cx + half)
		tips.append(band + h * dr[2])
	# 端のしずくは、画面の外までつなげる
	lefts[0] = minf(lefts[0], -20.0)
	rights[rights.size() - 1] = maxf(rights[rights.size() - 1], w + 20.0)
	# アーチの両はしの高さ(すき間の半分だけ下がる: 半円のアーチ)
	var gap_y := []
	for i in DRIPS.size() - 1:
		var g: float = maxf(lefts[i + 1] - rights[i], 2.0)
		gap_y.append(band + g / 2.0)
	var p := PackedStringArray()
	p.append("M %.1f %.1f" % [-40.0, -40.0])
	var first_y: float = band + h * 0.05
	p.append("L %.1f %.1f" % [-40.0, first_y])
	p.append("L %.1f %.1f" % [lefts[0], first_y])
	var y_left: float = first_y
	for i in DRIPS.size():
		var dr: Array = DRIPS[i]
		var x0: float = lefts[i]
		var x1: float = rights[i]
		var half: float = h * dr[1] / 2.0
		var cx: float = w * dr[0]
		var tip: float = tips[i]
		var y_right: float = gap_y[i] if i < gap_y.size() else band + h * 0.05
		var neck: float = half * dr[3]
		var bulb: float = half * dr[4]
		var sway: float = half * dr[5]
		var bulb_y := tip - bulb
		var top_y := minf(y_left, y_right)
		var neck_y := top_y + (bulb_y - top_y) * 0.55
		var neck_x := cx + sway * 0.5
		# 左の辺: 根元から内へ曲がってくびれ、ふくらんで先の丸へ
		p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [
			x0, y_left + (neck_y - y_left) * 0.55, neck_x - neck, neck_y - (neck_y - y_left) * 0.35, neck_x - neck, neck_y])
		p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [
			neck_x - neck, neck_y + (bulb_y - neck_y) * 0.5, cx + sway - bulb, bulb_y - (bulb_y - neck_y) * 0.45, cx + sway - bulb, bulb_y])
		# 先の丸(下を回る)
		p.append("A %.1f %.1f 0 0 0 %.1f %.1f" % [bulb, bulb, cx + sway + bulb, bulb_y])
		# 右の辺: 左と逆に上へ
		p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [
			cx + sway + bulb, bulb_y - (bulb_y - neck_y) * 0.45, neck_x + neck, neck_y + (bulb_y - neck_y) * 0.5, neck_x + neck, neck_y])
		p.append("C %.1f %.1f %.1f %.1f %.1f %.1f" % [
			neck_x + neck, neck_y - (neck_y - y_right) * 0.35, x1, y_right + (neck_y - y_right) * 0.55, x1, y_right])
		y_left = y_right
		if i < gap_y.size():
			# 次のしずくまで、上に丸いアーチ
			var g: float = (lefts[i + 1] - x1) / 2.0
			p.append("A %.1f %.1f 0 0 1 %.1f %.1f" % [maxf(g, 1.0), maxf(g, 1.0), lefts[i + 1], y_right])
	p.append("L %.1f %.1f" % [w + 40.0, band + h * 0.05])
	p.append("L %.1f %.1f Z" % [w + 40.0, -40.0])
	return " ".join(p)
