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


## モナリザ: かざりのある金の額縁(外わく・内わく・四すみの飾り)に、遠くの山と道の景色、ベールをかぶった長い黒髪、
## やさしい笑顔、組んだ手。目は白目と黒目(黒目が動く)と、キラッと光る点
static func _build_mona_lisa(item: Node3D, parts: Dictionary) -> void:
	var canvas := Node3D.new()
	canvas.position = Vector3(0, 0.42, 0.0)
	canvas.rotation.x = -0.12
	item.add_child(canvas)
	var add := func(m: Mesh, pos: Vector3, c: Color, outline: float, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var mi := _mesh(m, c, outline)
		mi.position = pos
		mi.scale = scl
		mi.rotation = rot
		canvas.add_child(mi)
		return mi
	# 額縁: 外わく(濃い金)、内わく(明るい金)、四すみの丸い飾り
	add.call(StaticBatch.chamfer_mesh(Vector3(0.64, 0.82, 0.06), 0.015), Vector3.ZERO, Color("C9962E"), OUTLINE)
	add.call(StaticBatch.chamfer_mesh(Vector3(0.56, 0.74, 0.02), 0.008), Vector3(0, 0, 0.03), COLOR_GOLD, 0.01)
	for cx in [-0.29, 0.29]:
		for cy in [-0.38, 0.38]:
			var orb := SphereMesh.new()
			orb.radius = 0.035
			orb.height = 0.07
			orb.radial_segments = 10
			orb.rings = 5
			add.call(orb, Vector3(cx, cy, 0.035), Color("F2D27A"), 0.01, Vector3(1, 1, 0.5))
	# 景色: 上は青みがかった空、下は緑と茶色の山、くねくねした道
	var bg := BoxMesh.new()
	bg.size = Vector3(0.5, 0.68, 0.01)
	add.call(bg, Vector3(0, 0, 0.042), Color("8FA98A"), 0.0)
	var sky := BoxMesh.new()
	sky.size = Vector3(0.5, 0.22, 0.008)
	add.call(sky, Vector3(0, 0.23, 0.046), Color("A9C3C0"), 0.0)
	for hx in [-0.13, 0.13]:
		var hill := SphereMesh.new()
		hill.radius = 0.1
		hill.height = 0.12
		add.call(hill, Vector3(hx, 0.12, 0.047), Color("6F8A5A"), 0.0, Vector3(1.05, 0.8, 0.05))
	var road := BoxMesh.new()
	road.size = Vector3(0.015, 0.12, 0.004)
	add.call(road, Vector3(-0.17, 0.03, 0.05), Color("C8A26E"), 0.0, Vector3.ONE, Vector3(0, 0, 0.5))
	# 体: 黒っぽい服(胸もとが丸くあいている)と肩
	var dress := SphereMesh.new()
	dress.radius = 0.2
	dress.height = 0.3
	add.call(dress, Vector3(0, -0.23, 0.05), Color("2E3324"), 0.0, Vector3(1.0, 0.85, 0.08))
	var neck := SphereMesh.new()
	neck.radius = 0.06
	neck.height = 0.08
	add.call(neck, Vector3(0, -0.06, 0.058), Color("E8C49A"), 0.0, Vector3(1.0, 0.7, 0.1))
	# 組んだ手(右手が左手の上)
	var hand := SphereMesh.new()
	hand.radius = 0.04
	hand.height = 0.06
	add.call(hand, Vector3(-0.03, -0.27, 0.066), Color("E8C49A"), 0.004, Vector3(1.4, 0.8, 0.3))
	add.call(hand, Vector3(0.035, -0.25, 0.07), Color("F0CFA6"), 0.004, Vector3(1.4, 0.8, 0.3))
	# 髪(長い黒髪が肩まで)と、うすいベール
	var hair := SphereMesh.new()
	hair.radius = 0.13
	hair.height = 0.34
	add.call(hair, Vector3(0, 0.04, 0.052), Color("3A2A1E"), 0.0, Vector3(1.0, 1.15, 0.12))
	var veil := SphereMesh.new()
	veil.radius = 0.12
	veil.height = 0.14
	add.call(veil, Vector3(0, 0.13, 0.056), Color("4A3A2C"), 0.0, Vector3(1.05, 0.7, 0.1))
	# 顔(たまご形)と、ほんのりほっぺ
	var face := SphereMesh.new()
	face.radius = 0.085
	face.height = 0.19
	add.call(face, Vector3(0, 0.07, 0.062), Color("E8C49A"), 0.0, Vector3(0.95, 1.12, 0.12))
	for cx in [-0.045, 0.045]:
		var cheek := SphereMesh.new()
		cheek.radius = 0.015
		cheek.height = 0.03
		add.call(cheek, Vector3(cx, 0.045, 0.072), Color("E9A88A"), 0.0, Vector3(1.2, 0.8, 0.2))
	# やさしい笑顔(口のはしが少し上がる)と、鼻
	for side in [-1.0, 1.0]:
		var lip := BoxMesh.new()
		lip.size = Vector3(0.026, 0.006, 0.004)
		add.call(lip, Vector3(side * 0.012, 0.022, 0.075), Color("8A4A3A"), 0.0, Vector3.ONE, Vector3(0, 0, side * 0.25))
	var nose := BoxMesh.new()
	nose.size = Vector3(0.006, 0.022, 0.004)
	add.call(nose, Vector3(0.004, 0.06, 0.075), Color("C99E76"), 0.0)
	var pupils: Array = []
	var bases: Array = []
	var glints: Array = []
	for x in [-0.03, 0.03]:
		var white := SphereMesh.new()
		white.radius = 0.016
		white.height = 0.02
		var wm: MeshInstance3D = add.call(white, Vector3(x, 0.09, 0.07), Color.WHITE, 0.0, Vector3(1.0, 0.6, 0.2))
		var pupil := SphereMesh.new()
		pupil.radius = 0.008
		pupil.height = 0.016
		var pm: MeshInstance3D = add.call(pupil, Vector3(x, 0.09, 0.074), Color("3A2A1E"), 0.0, Vector3(1.0, 1.0, 0.3))
		pupils.append(pm)
		bases.append(pm.position)
		# まゆ(うすい)
		var brow := BoxMesh.new()
		brow.size = Vector3(0.026, 0.004, 0.004)
		add.call(brow, Vector3(x, 0.108, 0.073), Color("6A4A34"), 0.0)
		# キラッ: 暗い席でも見える光る点(いつも見せる)
		var glint := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.02, 0.02, 0.004)
		glint.mesh = gm
		glint.material_override = _glow(Color("FFFBE0"))
		glint.position = Vector3(x + 0.006, 0.096, 0.078)
		glint.rotation.z = PI / 4.0
		glint.set_meta("always_visible", true)
		canvas.add_child(glint)
		glints.append(glint)
	parts["pupils"] = pupils
	parts["eyes_base"] = bases
	parts["glints"] = glints


## ガイコツ(理科室の標本。丸っこくてかわいい): 大きな丸い頭(にっこり顔・ほっぺ)、つぶがつながった背骨、
## 弓なりのあばら骨、骨盤、ひじとひざに丸い関節のある手足、丸い手と足。
## 組み立てた形(body)と、床でバラバラに崩れた形(pile)の2つを作り、どちらかだけ出す
static func _build_skeleton(item: Node3D, parts: Dictionary) -> void:
	var body := Node3D.new()
	item.add_child(body)
	_skull(body, Vector3(0, 0.63, 0), Vector3.ZERO)
	# 背骨(小さなつぶを縦に)
	for k in 6:
		_joint(body, Vector3(0, 0.49 - k * 0.045, -0.01), 0.022)
	# あばら骨(弓なりの骨を3段。前があいている)
	for k in 3:
		_rib(body, Vector3(0, 0.46 - k * 0.055, 0), 0.11 - k * 0.012)
	# 鎖骨と骨盤
	_bone(body, Vector3(0, 0.52, 0.01), 0.22, Vector3(0, 0, PI / 2.0))
	var pelvis := SphereMesh.new()
	pelvis.radius = 0.08
	pelvis.height = 0.1
	pelvis.radial_segments = 12
	pelvis.rings = 6
	var pm := _mesh(pelvis, COLOR_BONE, 0.015)
	pm.position = Vector3(0, 0.22, 0)
	pm.scale = Vector3(1.3, 0.7, 0.8)
	body.add_child(pm)
	for sx in [-1.0, 1.0]:
		# 腕: 上の骨・ひじの関節・下の骨・丸い手
		_bone(body, Vector3(sx * 0.15, 0.44, 0), 0.14, Vector3(0, 0, sx * 0.3))
		_joint(body, Vector3(sx * 0.175, 0.37, 0), 0.025)
		_bone(body, Vector3(sx * 0.19, 0.3, 0.02), 0.13, Vector3(0.2, 0, sx * 0.15))
		_joint(body, Vector3(sx * 0.2, 0.225, 0.035), 0.035)
		# 脚: ももの骨・ひざの関節・すねの骨・丸い足
		_bone(body, Vector3(sx * 0.065, 0.15, 0), 0.13, Vector3(0, 0, sx * 0.05))
		_joint(body, Vector3(sx * 0.07, 0.085, 0), 0.026)
		_bone(body, Vector3(sx * 0.072, 0.04, 0), 0.09, Vector3.ZERO)
		var foot := SphereMesh.new()
		foot.radius = 0.035
		foot.height = 0.05
		var fm := _mesh(foot, COLOR_BONE, 0.012)
		fm.position = Vector3(sx * 0.075, 0.012, 0.03)
		fm.scale = Vector3(1.0, 0.6, 1.5)
		body.add_child(fm)
	var pile := Node3D.new()
	item.add_child(pile)
	# 床に散らばった骨(長い骨・関節・あばら)と、上にちょこんと乗った頭
	var spots := [[Vector3(-0.18, 0.03, 0.05), 0.4], [Vector3(0.15, 0.03, -0.08), 1.3], [Vector3(0.02, 0.05, 0.14), 2.2],
			[Vector3(-0.05, 0.03, -0.18), 0.9], [Vector3(0.22, 0.03, 0.12), 2.8], [Vector3(-0.22, 0.05, -0.1), 1.9],
			[Vector3(0.08, 0.07, -0.02), 0.2]]
	for sp in spots:
		_bone(pile, sp[0], 0.16, Vector3(PI / 2.0, sp[1], 0))
	for j in [Vector3(-0.1, 0.03, 0.18), Vector3(0.18, 0.03, -0.16), Vector3(-0.24, 0.03, 0.12), Vector3(0.1, 0.03, 0.2)]:
		_joint(pile, j, 0.026)
	var r1 := Node3D.new()
	r1.position = Vector3(0.05, 0.02, -0.14)
	r1.rotation = Vector3(PI / 2.0, 0.6, 0)
	pile.add_child(r1)
	_rib(r1, Vector3.ZERO, 0.1)
	_skull(pile, Vector3(0, 0.16, 0.02), Vector3(-0.25, 0.3, 0.15))
	pile.visible = false
	parts["body"] = body
	parts["pile"] = pile


static func _bone(parent: Node3D, pos: Vector3, length: float, rot: Vector3) -> void:
	# はしがぷくっと丸い骨(まん中の棒と、両はしの丸いこぶ)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = rot
	parent.add_child(holder)
	var cap := CapsuleMesh.new()
	cap.radius = 0.022
	cap.height = length
	cap.radial_segments = 8
	cap.rings = 2
	holder.add_child(_mesh(cap, COLOR_BONE, 0.012))
	for e in [-1.0, 1.0]:
		var knob := SphereMesh.new()
		knob.radius = 0.03
		knob.height = 0.05
		knob.radial_segments = 8
		knob.rings = 4
		var km := _mesh(knob, COLOR_BONE, 0.012)
		km.position = Vector3(0, e * (length / 2.0 - 0.015), 0)
		km.scale = Vector3(1.2, 0.8, 1.0)
		holder.add_child(km)


static func _joint(parent: Node3D, pos: Vector3, r: float) -> void:
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	sph.radial_segments = 8
	sph.rings = 4
	var m := _mesh(sph, COLOR_BONE, 0.01)
	m.position = pos
	parent.add_child(m)


## 弓なりのあばら骨(輪の後ろ半分。前は少しあける)
static func _rib(parent: Node3D, pos: Vector3, r: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.016
	ring.outer_radius = r
	ring.rings = 16
	ring.ring_segments = 6
	var m := _mesh(ring, COLOR_BONE, 0.01)
	m.position = pos
	m.scale = Vector3(1.0, 1.0, 0.7)
	parent.add_child(m)


## 丸い頭: 白い玉に、にっこりした目(^ ^)、小さな鼻の穴、笑った口と、ほっぺ
static func _skull(parent: Node3D, pos: Vector3, rot: Vector3) -> void:
	var head := Node3D.new()
	head.position = pos
	head.rotation = rot
	parent.add_child(head)
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.25
	sph.radial_segments = 16
	sph.rings = 8
	head.add_child(_mesh(sph, COLOR_BONE, 0.02))
	# あご(少し下に出た丸み)
	var jaw := SphereMesh.new()
	jaw.radius = 0.08
	jaw.height = 0.1
	var jm := _mesh(jaw, COLOR_BONE, 0.015)
	jm.position = Vector3(0, -0.08, 0.035)
	jm.scale = Vector3(1.1, 0.7, 0.9)
	head.add_child(jm)
	var ink := Color("3A3633")
	for x in [-0.048, 0.048]:
		for side in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.036, 0.013, 0.01)
			var e := _mesh(bar, ink, 0.0)
			e.position = Vector3(x + side * 0.013, 0.03, 0.125)
			e.rotation.z = side * -0.6
			head.add_child(e)
	# 鼻の穴(小さな逆さハート形のかわりに、丸を2つ)
	for x in [-0.01, 0.01]:
		var hole := SphereMesh.new()
		hole.radius = 0.009
		hole.height = 0.014
		var hm := _mesh(hole, ink, 0.0)
		hm.position = Vector3(x, -0.01, 0.128)
		hm.scale = Vector3(1.0, 1.3, 0.4)
		head.add_child(hm)
	# 笑った口と、小さな歯の線(3本)
	for side in [-1.0, 1.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.05, 0.012, 0.01)
		var mo := _mesh(bar, ink, 0.0)
		mo.position = Vector3(side * 0.02, -0.06, 0.112)
		mo.rotation.z = side * 0.35
		head.add_child(mo)
	for k in 3:
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.004, 0.014, 0.008)
		var tm := _mesh(tooth, ink, 0.0)
		tm.position = Vector3((k - 1) * 0.016, -0.057, 0.114)
		head.add_child(tm)
	# ほっぺ(ピンク)
	for x in [-0.085, 0.085]:
		var ch := SphereMesh.new()
		ch.radius = 0.02
		ch.height = 0.04
		var cm := _mesh(ch, Color("F4A3B6"), 0.0)
		cm.position = Vector3(x, -0.02, 0.105)
		cm.scale = Vector3(1.0, 0.7, 0.4)
		head.add_child(cm)
