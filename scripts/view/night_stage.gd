class_name NightStage
extends RefCounted
## 夜の教室の落とし物(ハンカチは教室と同じ。ここでは2〜5つめ)。見た目だけ(ルールは GameState)。
## - 懐中電灯: 床で光り続ける(暗い席で目立ち、明るい席では月の光にまぎれる)
## - メトロノーム: 床で振り子がゆれて「カチ、カチ」と小さく鳴る
## - モナリザ: 額縁に入った絵。床に置かれると、目がゆっくりこっちを見て、目がキラッと光る(暗い席でも見える)
## - ガイコツ: 丸っこいにっこり顔。落とすとバラバラに崩れ、拾うと元の形に戻って抱えて走る
## 部品は item(WorldView の _handkerchief)の下に置く(見え方のルールで隠すため)。
## いつも見せる部品(モナリザの目の光)には meta "always_visible" をつける。

const ITEM_SIZES := [
	Vector3(0.55, 0.04, 0.55),  # ハンカチ(教室のもの)
	Vector3(0.16, 0.16, 0.44),  # 懐中電灯
	Vector3(0.26, 0.4, 0.22),   # メトロノーム
	Vector3(0.62, 0.8, 0.1),    # モナリザ(額縁)
	Vector3(0.5, 0.75, 0.4),    # ガイコツ(組み立てた形)
]
const OUTLINE := 0.03
const COLOR_BONE := Color("FFF6E4")
const COLOR_WOOD := Color("9A5B34")
const COLOR_GOLD := Color("E9B949")


## 落とし物を作り、あとで動かす部品を返す: {"glow", "glow_mat", "arm", "pupils", "eyes_base", "glints", "pile", "body"}
static func build_item(item: Node3D, index: int) -> Dictionary:
	var parts := {}
	match index:
		1:
			_build_flashlight(item, parts)
		2:
			_build_metronome(item, parts)
		3:
			_build_mona_lisa(item, parts)
		4:
			_build_skeleton(item, parts)
	return parts


static func _mesh(m: Mesh, c: Color, outline: float = OUTLINE) -> MeshInstance3D:
	return Toon.mesh(m, c, outline)


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## 懐中電灯: 黄色い筒を床に寝かせ、前(+Z)の白い光る面から、床に光の扇がのびる
static func _build_flashlight(item: Node3D, parts: Dictionary) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.06
	body.bottom_radius = 0.06
	body.height = 0.32
	body.radial_segments = 12
	var b := _mesh(body, Color("F2C14E"))
	b.rotation.x = PI / 2.0
	b.position = Vector3(0, 0.07, -0.04)
	item.add_child(b)
	var head := CylinderMesh.new()
	head.top_radius = 0.085
	head.bottom_radius = 0.065
	head.height = 0.1
	head.radial_segments = 12
	var h := _mesh(head, Color("3F6FD0"))
	h.rotation.x = PI / 2.0
	h.position = Vector3(0, 0.08, 0.16)
	item.add_child(h)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.07
	lm.bottom_radius = 0.07
	lm.height = 0.01
	lm.radial_segments = 12
	lens.mesh = lm
	lens.material_override = _glow(Color("FFFBD6"))
	lens.rotation.x = PI / 2.0
	lens.position = Vector3(0, 0.08, 0.215)
	item.add_child(lens)
	# 床に落ちる光の扇(半透明。光の計算はしない)
	var fan := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for k in n:
		var a0 := lerpf(-0.5, 0.5, float(k) / n)
		var a1 := lerpf(-0.5, 0.5, float(k + 1) / n)
		st.add_vertex(Vector3(0, 0, 0.22))
		st.add_vertex(Vector3(sin(a1) * 1.1, 0, 0.22 + cos(a1) * 1.1))
		st.add_vertex(Vector3(sin(a0) * 1.1, 0, 0.22 + cos(a0) * 1.1))
	fan.mesh = st.commit()
	var fm := _glow(Color(1.0, 0.95, 0.65, 0.5))
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fan.material_override = fm
	fan.position.y = 0.02
	item.add_child(fan)
	parts["glow"] = fan
	parts["glow_mat"] = fm


## メトロノーム: 木の三角の箱、前に白い目盛り板、ゆれる振り子(おもりつき)
static func _build_metronome(item: Node3D, parts: Dictionary) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.03
	body.bottom_radius = 0.17
	body.height = 0.38
	body.radial_segments = 4
	var b := _mesh(body, COLOR_WOOD)
	b.rotation.y = PI / 4.0
	b.position.y = 0.19
	item.add_child(b)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.08, 0.24, 0.01)
	var p := _mesh(plate, Color("F4EBD8"), 0.01)
	p.position = Vector3(0, 0.18, 0.075)
	p.rotation.x = -0.36
	item.add_child(p)
	var arm := Node3D.new()
	arm.position = Vector3(0, 0.06, 0.1)
	item.add_child(arm)
	var rod := BoxMesh.new()
	rod.size = Vector3(0.012, 0.3, 0.012)
	var r := _mesh(rod, Color("C9CED6"), 0.008)
	r.position.y = 0.15
	arm.add_child(r)
	var weight := BoxMesh.new()
	weight.size = Vector3(0.05, 0.04, 0.03)
	var w := _mesh(weight, COLOR_GOLD, 0.01)
	w.position.y = 0.2
	arm.add_child(w)
	parts["arm"] = arm


## モナリザ: 金の額縁に、緑がかった背景の絵(長い黒髪・やさしい笑顔)。目は白目と黒目(黒目が動く)と、キラッと光る点
static func _build_mona_lisa(item: Node3D, parts: Dictionary) -> void:
	var frame := BoxMesh.new()
	frame.size = Vector3(0.62, 0.8, 0.06)
	var f := _mesh(frame, COLOR_GOLD)
	f.position = Vector3(0, 0.42, 0)
	f.rotation.x = -0.12
	item.add_child(f)
	var canvas := Node3D.new()
	canvas.position = Vector3(0, 0.42, 0.0)
	canvas.rotation.x = -0.12
	item.add_child(canvas)
	var bg := BoxMesh.new()
	bg.size = Vector3(0.5, 0.68, 0.01)
	var g := _mesh(bg, Color("6F8A5A"), 0.0)
	g.position.z = 0.031
	canvas.add_child(g)
	var hair := SphereMesh.new()
	hair.radius = 0.13
	hair.height = 0.3
	var hm := _mesh(hair, Color("3A2A1E"), 0.0)
	hm.scale = Vector3(1.0, 1.2, 0.2)
	hm.position = Vector3(0, 0.06, 0.04)
	canvas.add_child(hm)
	var face := SphereMesh.new()
	face.radius = 0.085
	face.height = 0.19
	var fm := _mesh(face, Color("E8C49A"), 0.0)
	fm.scale = Vector3(1.0, 1.15, 0.25)
	fm.position = Vector3(0, 0.08, 0.05)
	canvas.add_child(fm)
	var dress := BoxMesh.new()
	dress.size = Vector3(0.36, 0.22, 0.012)
	var dm := _mesh(dress, Color("2E3324"), 0.0)
	dm.position = Vector3(0, -0.2, 0.04)
	canvas.add_child(dm)
	var hands := BoxMesh.new()
	hands.size = Vector3(0.14, 0.05, 0.014)
	var hd := _mesh(hands, Color("E8C49A"), 0.0)
	hd.position = Vector3(0, -0.22, 0.05)
	canvas.add_child(hd)
	var smile := BoxMesh.new()
	smile.size = Vector3(0.04, 0.008, 0.01)
	var sm := _mesh(smile, Color("8A4A3A"), 0.0)
	sm.position = Vector3(0, 0.035, 0.07)
	canvas.add_child(sm)
	var pupils: Array = []
	var bases: Array = []
	var glints: Array = []
	for x in [-0.03, 0.03]:
		var white := BoxMesh.new()
		white.size = Vector3(0.03, 0.016, 0.006)
		var wm := _mesh(white, Color.WHITE, 0.0)
		wm.position = Vector3(x, 0.1, 0.068)
		canvas.add_child(wm)
		var pupil := BoxMesh.new()
		pupil.size = Vector3(0.012, 0.014, 0.006)
		var pm := _mesh(pupil, Color("1E1B18"), 0.0)
		pm.position = Vector3(x, 0.1, 0.072)
		canvas.add_child(pm)
		pupils.append(pm)
		bases.append(pm.position)
		# キラッ: 暗い席でも見える光る点(いつも見せる)
		var glint := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.022, 0.022, 0.004)
		glint.mesh = gm
		glint.material_override = _glow(Color("FFFBE0"))
		glint.position = Vector3(x + 0.006, 0.106, 0.076)
		glint.rotation.z = PI / 4.0
		glint.set_meta("always_visible", true)
		canvas.add_child(glint)
		glints.append(glint)
	parts["pupils"] = pupils
	parts["eyes_base"] = bases
	parts["glints"] = glints


## ガイコツ: 丸い頭(にっこり顔)、あばら骨、背骨、手足の骨(はしが丸い)。
## 組み立てた形(body)と、床でバラバラに崩れた形(pile)の2つを作り、どちらかだけ出す
static func _build_skeleton(item: Node3D, parts: Dictionary) -> void:
	var body := Node3D.new()
	item.add_child(body)
	_skull(body, Vector3(0, 0.62, 0), Vector3.ZERO)
	_bone(body, Vector3(0, 0.36, 0), 0.26, Vector3.ZERO)   # 背骨
	for k in 3:
		_bone(body, Vector3(0, 0.45 - k * 0.07, 0.02), 0.22 - k * 0.03, Vector3(0, 0, PI / 2.0))  # あばら
	_bone(body, Vector3(0, 0.22, 0), 0.18, Vector3(0, 0, PI / 2.0))  # 骨盤
	for sx in [-1.0, 1.0]:
		_bone(body, Vector3(sx * 0.17, 0.4, 0), 0.22, Vector3(0, 0, sx * 0.35))  # 腕
		_bone(body, Vector3(sx * 0.07, 0.08, 0), 0.22, Vector3(0, 0, sx * 0.08))  # 脚
	var pile := Node3D.new()
	item.add_child(pile)
	# 床に散らばった骨(少しずつ向きを変えて)と、上にちょこんと乗った頭
	var spots := [[Vector3(-0.18, 0.03, 0.05), 0.4], [Vector3(0.15, 0.03, -0.08), 1.3], [Vector3(0.02, 0.05, 0.14), 2.2],
			[Vector3(-0.05, 0.03, -0.18), 0.9], [Vector3(0.22, 0.03, 0.12), 2.8], [Vector3(-0.22, 0.05, -0.1), 1.9],
			[Vector3(0.08, 0.07, -0.02), 0.2]]
	for sp in spots:
		_bone(pile, sp[0], 0.22, Vector3(PI / 2.0, sp[1], 0))
	_skull(pile, Vector3(0, 0.16, 0.02), Vector3(-0.25, 0.3, 0.15))
	pile.visible = false
	parts["body"] = body
	parts["pile"] = pile


static func _bone(parent: Node3D, pos: Vector3, length: float, rot: Vector3) -> void:
	var cap := CapsuleMesh.new()
	cap.radius = 0.03
	cap.height = length
	cap.radial_segments = 8
	cap.rings = 2
	var m := _mesh(cap, COLOR_BONE, 0.015)
	m.position = pos
	m.rotation = rot
	parent.add_child(m)


## 丸い頭: 白い玉に、にっこりした目(^ ^)と、笑った口
static func _skull(parent: Node3D, pos: Vector3, rot: Vector3) -> void:
	var head := Node3D.new()
	head.position = pos
	head.rotation = rot
	parent.add_child(head)
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.25
	sph.radial_segments = 14
	sph.rings = 7
	head.add_child(_mesh(sph, COLOR_BONE, 0.02))
	for x in [-0.045, 0.045]:
		for side in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.035, 0.012, 0.01)
			var e := _mesh(bar, Color("3A3633"), 0.0)
			e.position = Vector3(x + side * 0.013, 0.025, 0.125)
			e.rotation.z = side * -0.6
			head.add_child(e)
	for side in [-1.0, 1.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.045, 0.012, 0.01)
		var mo := _mesh(bar, Color("3A3633"), 0.0)
		mo.position = Vector3(side * 0.018, -0.045, 0.12)
		mo.rotation.z = side * 0.4
		head.add_child(mo)
	# ほっぺ(ピンク)
	for x in [-0.08, 0.08]:
		var ch := SphereMesh.new()
		ch.radius = 0.02
		ch.height = 0.04
		var cm := _mesh(ch, Color("F4A3B6"), 0.0)
		cm.position = Vector3(x, -0.02, 0.105)
		cm.scale = Vector3(1.0, 0.7, 0.4)
		head.add_child(cm)
