class_name MinionReveal
extends Control
## 結果カードの「手下はだれ?」: 裏向きのカードをタップすると、くるっとめくれて
## 手下のキャラが仁王立ちしている絵と名前が出る。めくると flipped を出す(点数を見せる合図)。

signal flipped

const W := 300.0
const H := 270.0
const INK := Color("1E1B18")
const PURPLE := Color(0.55, 0.2, 0.7)

var _name := ""
var _color := Color.WHITE
var _is_me := false
var _bonus := false
var _open := false
var _flipping := false
var _time := 0.0


func setup(minion_name: String, body_color: Color, is_me: bool, bonus: bool) -> void:
	_name = minion_name
	_color = body_color
	_is_me = is_me
	_bonus = bonus
	custom_minimum_size = Vector2(W, H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return _open


## タップされた: くるっとめくる(横につぶれて、裏返って、また広がる)
func flip() -> void:
	if _open or _flipping:
		return
	_flipping = true
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.16)
	tw.tween_callback(func() -> void:
		_open = true
		queue_redraw())
	tw.tween_property(self, "scale:x", 1.08, 0.16)
	tw.tween_property(self, "scale:x", 1.0, 0.08)
	tw.tween_callback(func() -> void:
		_flipping = false
		flipped.emit())


func _process(delta: float) -> void:
	_time += delta
	if not _open:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _open:
		_draw_front(r)
	else:
		_draw_back(r)


## 裏: 紫のカードに大きい「?」と「手下はだれ?」、タップをうながす指(ぴょこぴょこ動く)
func _draw_back(r: Rect2) -> void:
	_card(r, PURPLE)
	var font := HudFont.get_font()
	var c := r.get_center()
	# 星もよう
	for p in [Vector2(0.15, 0.2), Vector2(0.85, 0.25), Vector2(0.2, 0.8), Vector2(0.82, 0.78)]:
		_star(r.position + r.size * (p as Vector2), 9.0, Color(1, 1, 1, 0.5))
	draw_string(font, Vector2(r.position.x, c.y + 10), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 110, Color.WHITE)
	draw_string(font, Vector2(r.position.x, r.position.y + 44), "手下はだれ?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color.WHITE)
	var bob := sin(_time * 6.0) * 5.0
	draw_string(font, Vector2(r.position.x, r.end.y - 22 + bob * 0.3), "タップしてめくってね", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.95))
	_finger(Vector2(r.end.x - 46, r.end.y - 70 + bob))


## 表: 白いカードに、手下のキャラが仁王立ち+名前
func _draw_front(r: Rect2) -> void:
	_card(r, Color.WHITE, PURPLE)
	var font := HudFont.get_font()
	_draw_figure(Vector2(r.get_center().x, r.position.y + 112), 1.0)
	var who := "あなたが手下だったよ!" if _is_me else "%s が手下だったよ!" % _name
	draw_string(font, Vector2(r.position.x, r.end.y - 38), who, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, INK)
	if _bonus:
		draw_string(font, Vector2(r.position.x, r.end.y - 12), "鬼がかったので +%d点" % GameConfig.SCORE_MINION_ONI_WIN,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, PURPLE)


## 仁王立ち: 足を開いて、手を腰に。ちょっと得意げな顔
func _draw_figure(base: Vector2, k: float) -> void:
	var line := 4.0
	var body := _color
	# 足(開いて立つ)
	for side in [-1.0, 1.0]:
		var hip := base + Vector2(side * 12, 22) * k
		var foot := base + Vector2(side * 30, 62) * k
		draw_line(hip, foot, INK, 18 * k + line * 2, true)
		draw_line(hip, foot, body, 18 * k, true)
		draw_circle(foot + Vector2(side * 4, 2) * k, 10 * k + line, INK)
		draw_circle(foot + Vector2(side * 4, 2) * k, 10 * k, body)
	# 腕(ひじを張って、手は腰)
	for side in [-1.0, 1.0]:
		var shoulder := base + Vector2(side * 22, -22) * k
		var elbow := base + Vector2(side * 50, -2) * k
		var hand := base + Vector2(side * 26, 16) * k
		for seg in [[shoulder, elbow], [elbow, hand]]:
			draw_line(seg[0], seg[1], INK, 15 * k + line * 2, true)
			draw_line(seg[0], seg[1], body, 15 * k, true)
		draw_circle(hand, 9 * k + line, INK)
		draw_circle(hand, 9 * k, body)
	# 胴(カプセル)
	var torso := Rect2(base + Vector2(-26, -34) * k, Vector2(52, 66) * k)
	_round_rect(torso, 24 * k, INK, line)
	_round_rect(torso.grow(-line), 24 * k - line, body, 0.0)
	# 頭
	var head := base + Vector2(0, -62) * k
	draw_circle(head, 30 * k + line, INK)
	draw_circle(head, 30 * k, body)
	var face := Color.WHITE if body.get_luminance() < 0.25 else INK
	# 得意げな目(への字)と、にやっとした口
	for side in [-1.0, 1.0]:
		var e := head + Vector2(side * 11, -3) * k
		draw_polyline(PackedVector2Array([e + Vector2(-6, 2) * k, e + Vector2(0, -3) * k, e + Vector2(6, 2) * k]), face, 3.5 * k, true)
	draw_arc(head + Vector2(2, 9) * k, 9 * k, 0.15, PI - 0.6, 10, face, 3.5 * k, true)
	# キラッ
	_star(head + Vector2(36, -26) * k, 8 * k, Color("F6C945"))


func _card(r: Rect2, fill: Color, border: Color = INK) -> void:
	_round_rect(Rect2(r.position + Vector2(5, 6), r.size), 22, INK, 0.0)
	_round_rect(r, 22, border, 0.0)
	_round_rect(r.grow(-5), 18, fill, 0.0)


func _round_rect(r: Rect2, radius: float, color: Color, _w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _star(c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
	draw_colored_polygon(pts, color)


## タップをうながす指(丸い手と、のびた人さし指)
func _finger(tip: Vector2) -> void:
	var hand := tip + Vector2(10, 24)
	draw_line(tip, hand, INK, 14, true)
	draw_line(tip, hand, Color.WHITE, 8, true)
	draw_circle(hand + Vector2(4, 10), 15, INK)
	draw_circle(hand + Vector2(4, 10), 11, Color.WHITE)
