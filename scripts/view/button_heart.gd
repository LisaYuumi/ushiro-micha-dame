class_name ButtonHeart
extends Control
## ドキドキ(鬼が自分のうしろ3m以内・座っている本人の画面だけ): 振り向くボタンを「胸」にして、
## ボタンの左上の角からアニメっぽい赤いハートが、ゴムのように伸びて飛び出し、ボヨンと引っ込む(映画『マスク』のイメージ)。
## - ふだんは見えない。ドキドキしている間は、ボタンの左上の角に小さなハートがくっついている
## - 「ドック」で少し、「ドックン!」で大きく飛び出す(向きは GameConfig.HEART_DIR_DEG。左上=画面のまん中のほう)。
##   ボタンとハートの間はゴムのように細長く伸びる。戻るときは少し行きすぎて(ボタンにめりこんで)から弾んで戻る
## - 飛び出すときはふくらんで縦にのび、引っ込むときは横につぶれる(ハートの向きはいつも同じ)
## - 近いほど大きく・遠くまで・速く(すぐうしろではボタンの2〜3倍の大きさまで)
## - 拍ごとにハートの上に「ドック」「ドックン!」の文字
## - 鬼が離れたら、シュッとボタンに引っ込んで、小さく「ふぅ…」
## TouchControls の中で、ボタンよりうしろ(先の子)に置くので、ボタンの絵や文字を隠さない。タップは受け取らない。

var _anchor := Rect2() # 振り向くボタンの画面の範囲(見えていないときは空)
var _level := 0.0
var _vis := 0.0
var _avoid: Array = [] # かからないようにする範囲(送るバー・届いた言葉のカード)
var _ext := 0.0 # 飛び出している量(0 = 角にくっついている、1 = いちばん遠く。マイナス = ボタンにめりこむ)
var _ext_prev := 0.0
var _vel := 0.0
var _beat_t := 9.0
var _beat_from := 0.0
var _beat_amp := 0.0
var _t := 0.0
## ボタンをふくらませる量(TouchControls が読む)
var bulge := 0.0

const RED := Color("E8364A")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_root_rect(r: Rect2) -> void:
	_anchor = r


func set_level(level: float) -> void:
	_level = clampf(level, 0.0, 1.0)


func set_avoid(rects: Array) -> void:
	_avoid = rects


func is_showing() -> bool:
	return _vis > 0.001 and _anchor.has_area()


## 心臓の音の1拍(AudioDirector.heart_beat。「ドック」= 0.5、「ドックン」= 1.0)
func pulse(strength: float) -> void:
	if _level <= 0.01 or not _anchor.has_area():
		return
	_beat_from = _ext
	_beat_amp = clampf(strength, 0.0, 1.0)
	_beat_t = 0.0
	_word(strength >= 0.7)


func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if _level > 0.01 and _anchor.has_area() else 0.0
	_vis = move_toward(_vis, want, delta * (5.0 if want > 0.0 else 9.0))
	_beat_t += delta
	_ext_prev = _ext
	_ext = _ext_at(_beat_t) if want > 0.0 else move_toward(_ext, 0.0, delta * 8.0)
	_vel = (_ext - _ext_prev) / maxf(delta, 0.001)
	# ボタンも拍に合わせて少しだけふくらむ
	bulge = GameConfig.HEART_BUTTON_BULGE * clampf(_ext, 0.0, 1.0) * _vis
	visible = _vis > 0.001
	if visible:
		queue_redraw()


## 1拍の動き: 速く飛び出す → 少し行きすぎて(ボタンにめりこんで)弾みながら戻る
func _ext_at(t: float) -> float:
	var out := lerpf(GameConfig.HEART_OUT_FAR, GameConfig.HEART_OUT_NEAR, _level)
	if t < out:
		var k := t / out
		return lerpf(_beat_from, _beat_amp, 1.0 - pow(1.0 - k, 3.0))
	var tau := t - out
	return _beat_amp * exp(-GameConfig.HEART_DAMP * tau) * cos(GameConfig.HEART_SPRING * tau)


func _dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(GameConfig.HEART_DIR_DEG))


## いまのハート: [中心, 大きさ(はば px), 横の倍率, 縦の倍率, 角(根もと)]
func shape() -> Array:
	var bw := _anchor.size.x
	var corner := _anchor.position + Vector2(bw * 0.06, bw * 0.06)
	var e := clampf(_ext, -0.3, 1.2)
	var pe := maxf(e, 0.0)
	var rest := bw * GameConfig.HEART_REST_SIZE
	var peak := bw * lerpf(GameConfig.HEART_PEAK_FAR, GameConfig.HEART_PEAK_NEAR, _level)
	var size := lerpf(rest, peak, minf(pe, 1.0)) * _vis
	var dist := bw * lerpf(GameConfig.HEART_DIST_FAR, GameConfig.HEART_DIST_NEAR, _level) * pe
	# (角にくっついているときも、ハートの大部分はボタンの外に出す)
	var c := corner + _dir() * (rest * 0.42 + dist)
	# つぶし・伸ばし: 飛び出すとき縦にのびて、引っ込むとき・めりこむとき横につぶれる
	var v := clampf(_vel / 12.0, -1.0, 1.0)
	var squash := clampf(-v, 0.0, 1.0) * 0.25 + clampf(-e, 0.0, 0.3) * 1.2
	var stretch := clampf(v, 0.0, 1.0) * 0.18
	var sx := 1.0 + squash - stretch * 0.7
	var sy := 1.0 - squash * 0.8 + stretch
	# 送るバー・届いた言葉のカードにかからないように、上へよける
	var half := Vector2(size * 0.55 * sx, size * 0.5 * sy)
	for r in _avoid:
		var rr: Rect2 = r
		if not rr.has_area():
			continue
		var box := Rect2(c - half, half * 2.0)
		if box.intersects(rr):
			c.y = minf(c.y, rr.position.y - half.y - 4.0)
	return [c, size, sx, sy, corner]


func _draw() -> void:
	if not _anchor.has_area():
		return
	var sh := shape()
	var c: Vector2 = sh[0]
	var size: float = sh[1]
	var sx: float = sh[2]
	var sy: float = sh[3]
	var corner: Vector2 = sh[4]
	if size < 2.0:
		return
	var ink := GameConfig.COLOR_INK
	var line := clampf(size * 0.045, 3.5, 11.0)
	# ゴムの首: ボタンの角から、ハートの下のとがったところへ。伸びるほど細くなる
	var tip := c + Vector2(0, size * 0.42 * sy)
	var length := corner.distance_to(tip)
	if length > size * 0.3:
		# (伸びるほど細く。でも細くなりすぎない)
		var thin := clampf(140.0 / maxf(length, 1.0), 0.55, 1.0)
		var w0 := _anchor.size.x * 0.24 * thin
		var w1 := clampf(size * 0.2, 12.0, 56.0) * thin
		var bend := (tip - corner).orthogonal().normalized() * length * 0.08 * sin(_t * 9.0)
		var mid := (corner + tip) * 0.5 + bend
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var n := 10
		for i in n + 1:
			var k := float(i) / float(n)
			var p := corner.lerp(mid, k).lerp(mid.lerp(tip, k), k)
			var p2 := corner.lerp(mid, minf(k + 0.05, 1.0)).lerp(mid.lerp(tip, minf(k + 0.05, 1.0)), minf(k + 0.05, 1.0))
			var d := (p2 - p).normalized() if k < 1.0 else (tip - mid).normalized()
			var nrm := d.orthogonal()
			# まん中がいちばん細い(ゴムが伸びている感じ)
			var w := lerpf(w0, w1, k) * (1.0 - 0.3 * sin(k * PI))
			left.append(p + nrm * w * 0.5)
			right.append(p - nrm * w * 0.5)
		var poly := left.duplicate()
		for i in range(right.size() - 1, -1, -1):
			poly.append(right[i])
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, ink, line, true)
		draw_colored_polygon(poly, RED)
		# 首のつや
		var gloss := PackedVector2Array()
		for i in range(1, n):
			gloss.append(left[i].lerp(right[i], 0.25))
		draw_polyline(gloss, Color(1, 1, 1, 0.55), maxf(line * 0.45, 2.0), true)
	# ハート(いつもふつうの向き: 上が2つのふくらみ、下がとがる)
	var pts := PackedVector2Array()
	for k in 44:
		var t := TAU * float(k) / 44.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x * sx, -y * sy) * (size / 34.0))
	# 太い黒の輪郭: 少し大きいハートを黒でぬってから、赤をのせる(とがったところに線のトゲが出ないように)
	for outer in Geometry2D.offset_polygon(pts, line * 1.15, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(outer, ink)
	draw_colored_polygon(pts, RED)
	var shade := PackedVector2Array()
	for p in pts:
		if p.y > c.y + size * 0.08 * sy:
			shade.append(p)
	if shade.size() >= 3:
		draw_colored_polygon(shade, Color(0.72, 0.08, 0.2, 0.35))
	# 白いつや
	draw_circle(c + Vector2(-size * 0.25 * sx, -size * 0.17 * sy), size * 0.11, Color(1, 1, 1, 0.9))
	draw_circle(c + Vector2(-size * 0.11 * sx, -size * 0.28 * sy), size * 0.05, Color(1, 1, 1, 0.9))


## 拍ごとに、ハートの上に「ドック」「ドックン!」のマンガ文字をポンと出す(近いほど大きく)
func _word(big: bool) -> void:
	var sh := shape()
	var c: Vector2 = sh[0]
	# (文字は、飛び出しきったときのハートの上に出す)
	var bw := _anchor.size.x
	var peak := bw * lerpf(GameConfig.HEART_PEAK_FAR, GameConfig.HEART_PEAK_NEAR, _level) * (1.0 if big else 0.6)
	var dist := bw * lerpf(GameConfig.HEART_DIST_FAR, GameConfig.HEART_DIST_NEAR, _level) * _beat_amp
	c = (sh[4] as Vector2) + _dir() * (bw * GameConfig.HEART_REST_SIZE * 0.42 + dist)
	var fs := int(lerpf(26.0, 46.0, _level) * (1.0 if big else 0.75))
	var l := UiStyle.label(tr("ドックン!") if big else tr("ドック"), fs, RED)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (文字はハートが消えても残るように、となりに置く)
	(get_parent() if get_parent() else self).add_child(l)
	l.reset_size()
	var vp := get_viewport_rect().size
	var pos := c + Vector2(-l.size.x * 0.5, -peak * 0.5 - l.size.y - 6.0)
	pos.x = clampf(pos.x, UiStyle.SAFE, vp.x - l.size.x - UiStyle.SAFE)
	pos.y = maxf(pos.y, 90.0)
	l.position = pos
	l.rotation = -0.12 if big else 0.08
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.07)
	tw.tween_property(l, "scale", Vector2.ONE, 0.05)
	tw.tween_interval(0.14 if big else 0.02)
	tw.tween_property(l, "modulate:a", 0.0, 0.14 if big else 0.08)
	tw.tween_callback(l.queue_free)


## 鬼が離れた(心臓の音が止まった): ハートがシュッとボタンに引っ込むのといっしょに、小さく「ふぅ…」
func relief() -> void:
	if not _anchor.has_area():
		return
	var l := UiStyle.label(tr("ふぅ…"), 30, GameConfig.COLOR_INK)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (文字はハートが消えても残るように、となりに置く)
	(get_parent() if get_parent() else self).add_child(l)
	l.reset_size()
	l.position = _anchor.position + Vector2(-l.size.x * 0.6, -l.size.y - 10.0)
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(l, "position:y", l.position.y - 30.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
