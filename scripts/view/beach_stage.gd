class_name BeachStage
extends RefCounted
## 舞台「海辺」の見た目(WorldView から呼ぶ。見た目だけで、状態は変えない)。
## - 砂浜(少し色のちがう砂のむら)・波打ちぎわ・海(遠くまで)・白い波の線
## - ヤシの木・ビーチパラソル・レジャーシート・海の家・岩・ヒトデ・バケツとスコップ
## - 落とし物: 貝殻 → ビーチボール → 浮き輪 → 砂の城 → バナナボート
## - 追いかけっこの障害物: 砂山とスコップ・クーラーボックス・ビーチチェア
## 輪(席と追いかけっこのコース)は半径 5.6 m くらいまで。飾りはその外に置く。
## 全部アニメ塗り+黒い輪郭線(A案)

const COLOR_SAND := Color("F3D9A4")
const COLOR_SAND_DARK := Color("E6C287")
const COLOR_SAND_LIGHT := Color("FAE8C2")
const COLOR_WET_SAND := Color("D9B57E")
const COLOR_SEA := Color("3FB4DA")
const COLOR_SEA_FAR := Color("2C93C9")
const COLOR_FOAM := Color("FFFFFF")
const COLOR_SKY := Color("9EDCF5")
const COLOR_PALM_TRUNK := Color("B98552")
const COLOR_PALM_RING := Color("8E6038")
const COLOR_PALM_LEAF := Color("4FB25A")
const COLOR_PALM_LEAF_DARK := Color("3A9446")
const COLOR_COCONUT := Color("7A5230")
const COLOR_ROCK := Color("9C9A94")
const COLOR_WOOD := Color("C08A55")
const COLOR_ROOF := Color("E5594A")
const COLOR_STRAW := Color("EAC66A")
## 海は、この z より前(-Z の側)
const SHORE_Z := -10.5


## 砂浜と海と飾り(WorldView の _batch がある間に呼ぶ。箱はまとめて、丸い物は1つずつ)
static func build_world(v: WorldView) -> void:
	# 砂浜: 下地と、少し色のちがう砂のむら
	v._part(Vector3(80, 0.04, 70), Vector3(0, -0.02, 12.0), COLOR_SAND, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var r := rng.randf_range(2.0, 22.0)
		var a := rng.randf() * TAU
		var p := Vector3(sin(a) * r, 0.002, cos(a) * r)
		if p.z < SHORE_Z + 1.0:
			continue
		var s := rng.randf_range(0.6, 1.8)
		var col := COLOR_SAND_DARK if i % 3 == 0 else COLOR_SAND_LIGHT
		v._part(Vector3(s * 1.6, 0.01, s), p, col, 0.0, null, Vector3(0, rng.randf() * PI, 0))
	# 波打ちぎわ: ぬれた砂の帯、白い波の線(ゆるく波打つ)、海
	v._part(Vector3(80, 0.03, 2.4), Vector3(0, -0.005, SHORE_Z + 0.2), COLOR_WET_SAND, 0.0)
	v._part(Vector3(80, 0.04, 60), Vector3(0, -0.04, SHORE_Z - 30.0), COLOR_SEA, 0.0)
	v._part(Vector3(200, 0.04, 80), Vector3(0, -0.06, SHORE_Z - 90.0), COLOR_SEA_FAR, 0.0)
	for k in 3:
		var z := SHORE_Z - 0.9 - float(k) * 3.2
		var n := 16
		for i in n:
			var x := -40.0 + 80.0 * (float(i) + 0.5) / float(n)
			var w := 80.0 / float(n) * (0.7 if k == 0 else 0.45)
			v._part(Vector3(w, 0.02, 0.22 - 0.05 * float(k)), Vector3(x + float(k) * 1.3, 0.005, z + 0.25 * sin(float(i) * 1.7)),
					COLOR_FOAM, 0.0, null, Vector3(0, 0.08 * sin(float(i) * 2.3), 0))
	# 遠くの島
	v._part(Vector3(9, 1.6, 4), Vector3(-26, 0.5, -70), Color("7CC28A"), 0.04)
	v._part(Vector3(5, 2.4, 3), Vector3(-24, 0.9, -70), Color("6DB57C"), 0.04)
	# ヤシの木
	_palm(v, Vector3(-8.2, 0, -6.6), 0.3, 4.6)
	_palm(v, Vector3(8.6, 0, -7.4), -0.4, 5.2)
	_palm(v, Vector3(-9.6, 0, 4.4), 0.9, 4.2)
	_palm(v, Vector3(10.4, 0, 6.8), -1.2, 4.8)
	# 海の家(後ろ): 木の小屋に赤い屋根と、のれん
	_beach_hut(v, Vector3(0, 0, 11.5))
	# レジャーシート(しま模様)
	_sheet(v, Vector3(-7.2, 0, 1.0), 0.4, Color("4D96FF"))
	_sheet(v, Vector3(7.4, 0, -1.6), -0.6, Color("EE6A4D"))
	_sheet(v, Vector3(5.2, 0, 8.6), 1.2, Color("7CC576"))
	# 岩(波打ちぎわ)
	for p in [Vector3(-12.5, 0, -9.6), Vector3(-11.2, 0, -10.2), Vector3(13.4, 0, -9.2)]:
		v._part(Vector3(1.2, 0.7, 1.0), p + Vector3(0, 0.3, 0), COLOR_ROCK, 0.04, null, Vector3(0.1, 0.6, 0.05))
		v._part(Vector3(0.7, 0.45, 0.6), p + Vector3(0.8, 0.2, 0.4), COLOR_ROCK.darkened(0.08), 0.04, null, Vector3(0, 0.3, 0.1))
	# 砂にささった木の看板
	v._part(Vector3(0.1, 1.2, 0.1), Vector3(-6.6, 0.6, -7.8), COLOR_WOOD, 0.03)
	v._part(Vector3(1.0, 0.5, 0.06), Vector3(-6.6, 1.1, -7.8), COLOR_SAND_LIGHT, 0.03)


## 丸い物(パラソル・ヒトデ・バケツなど)は、まとめずに置く(_batch を使わない)
static func build_props(v: WorldView) -> void:
	_parasol(v, Vector3(-7.0, 0, 2.6), Color("EE6A4D"))
	_parasol(v, Vector3(7.6, 0, 0.2), Color("4D96FF"))
	_parasol(v, Vector3(6.6, 0, 9.4), Color("F2AA4C"))
	# ヒトデ
	for p in [Vector3(-5.6, 0, -8.6), Vector3(4.4, 0, -8.9), Vector3(-9.2, 0, 7.8)]:
		var star := Node3D.new()
		star.position = p + Vector3(0, 0.03, 0)
		star.rotation.y = p.x
		for k in 5:
			var arm := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.09, 0.04, 0.24), 0.02), Color("F28A5B"), 0.015)
			var ang := TAU * float(k) / 5.0
			arm.rotation.y = ang
			arm.position = Vector3(sin(ang), 0, cos(ang)) * 0.1
			star.add_child(arm)
		v.add_child(star)
	# バケツとスコップ
	var pail := CylinderMesh.new()
	pail.top_radius = 0.2
	pail.bottom_radius = 0.15
	pail.height = 0.3
	var pm := Toon.mesh(pail, Color("F2C14E"), 0.03)
	pm.position = Vector3(-6.4, 0.15, -3.6)
	v.add_child(pm)
	var spade := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.18, 0.03, 0.5), 0.01), Color("EE6A4D"), 0.02)
	spade.position = Vector3(-6.0, 0.03, -3.2)
	spade.rotation.y = 0.7
	v.add_child(spade)
	# 小さな砂山
	var mound := SphereMesh.new()
	mound.radius = 0.6
	mound.height = 0.5
	mound.is_hemisphere = true
	var mm := Toon.mesh(mound, COLOR_SAND_DARK, 0.03)
	mm.position = Vector3(-6.9, 0, -4.3)
	mm.scale = Vector3(1, 0.7, 1)
	v.add_child(mm)


static func _palm(v: WorldView, base: Vector3, yaw: float, height: float) -> void:
	# 幹: 少しずつ傾いて重なる輪切り(弓なり)
	var segs := 9
	var top := base
	var lean := Vector3(sin(yaw), 0, cos(yaw))
	for i in segs:
		var t := float(i) / float(segs)
		var off := lean * (t * t) * 1.4
		var p := base + off + Vector3(0, height * (t + 0.5 / float(segs)), 0)
		var w := lerpf(0.42, 0.28, t)
		var tilt := atan2(2.0 * t * 1.4, height)
		v._part(Vector3(w, height / float(segs) + 0.04, w), p, COLOR_PALM_TRUNK if i % 2 == 0 else COLOR_PALM_RING, 0.03,
				null, Vector3(tilt * lean.z, 0, -tilt * lean.x))
		top = p
	top += Vector3(0, height / float(segs) * 0.5, 0)
	# 葉: まわりに垂れ下がる、細長い葉(2段に曲げる)
	for k in 7:
		var ang := TAU * float(k) / 7.0 + yaw
		var dir := Vector3(sin(ang), 0, cos(ang))
		var col := COLOR_PALM_LEAF if k % 2 == 0 else COLOR_PALM_LEAF_DARK
		v._part(Vector3(0.5, 0.06, 1.3), top + dir * 0.6 + Vector3(0, 0.12, 0), col, 0.03, null, Vector3(0, ang, 0) + _tilt(ang, -0.25))
		v._part(Vector3(0.42, 0.06, 1.1), top + dir * 1.6 - Vector3(0, 0.25, 0), col, 0.03, null, Vector3(0, ang, 0) + _tilt(ang, 0.55))
	# ヤシの実
	for k in 3:
		var ang := TAU * float(k) / 3.0
		v._part(Vector3(0.22, 0.22, 0.22), top + Vector3(sin(ang) * 0.2, -0.18, cos(ang) * 0.2), COLOR_COCONUT, 0.025)


## 葉の向き ang に沿って、先を下げる(x の回転を、葉の向きに合わせる)
static func _tilt(_ang: float, down: float) -> Vector3:
	return Vector3(down, 0, 0)


static func _beach_hut(v: WorldView, at: Vector3) -> void:
	# 床・柱・カウンター・屋根・のれん
	v._part(Vector3(6.4, 0.2, 3.2), at + Vector3(0, 0.1, 0), COLOR_WOOD.darkened(0.1), 0.04)
	for x in [-3.0, 3.0]:
		for z in [-1.4, 1.4]:
			v._part(Vector3(0.2, 2.6, 0.2), at + Vector3(x, 1.4, z), COLOR_WOOD, 0.03)
	v._part(Vector3(6.4, 2.6, 0.15), at + Vector3(0, 1.4, 1.5), Color("F6E7C8"), 0.03)
	v._part(Vector3(5.6, 0.9, 0.5), at + Vector3(0, 0.65, -1.2), COLOR_WOOD, 0.03)
	v._part(Vector3(5.8, 0.08, 0.6), at + Vector3(0, 1.12, -1.2), COLOR_WOOD.lightened(0.15), 0.03)
	# 屋根(赤と白のしま)
	for i in 8:
		var col := COLOR_ROOF if i % 2 == 0 else Color.WHITE
		v._part(Vector3(0.9, 0.16, 4.0), at + Vector3(-3.15 + 0.9 * float(i), 2.85, 0), col, 0.03, null, Vector3(-0.15, 0, 0))
	# のれん(青)
	for i in 5:
		v._part(Vector3(1.0, 0.5, 0.03), at + Vector3(-2.2 + 1.1 * float(i), 2.35, -1.55), Color("3F6FD0"), 0.02)
	# 看板の上のかき氷の旗
	v._part(Vector3(0.06, 1.6, 0.06), at + Vector3(3.6, 0.8, -1.8), COLOR_WOOD, 0.02)
	v._part(Vector3(0.6, 0.8, 0.03), at + Vector3(3.92, 1.2, -1.8), Color("FBF8EF"), 0.02)
	v._part(Vector3(0.4, 0.14, 0.035), at + Vector3(3.92, 1.36, -1.8), Color("E5483B"), 0.0)
	v._part(Vector3(0.4, 0.14, 0.035), at + Vector3(3.92, 1.06, -1.8), Color("3F86F0"), 0.0)


static func _sheet(v: WorldView, at: Vector3, yaw: float, col: Color) -> void:
	v._part(Vector3(1.8, 0.02, 1.3), at + Vector3(0, 0.012, 0), Color.WHITE, 0.02, null, Vector3(0, yaw, 0))
	var basis := Basis(Vector3.UP, yaw)
	for i in 3:
		var off := basis * Vector3(-0.6 + 0.6 * float(i), 0, 0)
		v._part(Vector3(0.3, 0.025, 1.3), at + off + Vector3(0, 0.014, 0), col, 0.0, null, Vector3(0, yaw, 0))


static func _parasol(v: WorldView, at: Vector3, col: Color) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.z = 0.12
	var pole := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.06, 2.2, 0.06), 0.01), Color.WHITE, 0.02)
	pole.position.y = 1.1
	root.add_child(pole)
	# かさ: 2色のしま(8枚)
	for k in 8:
		var piece := Toon.mesh(_cone_slice(1.25, 0.5, TAU * float(k) / 8.0, TAU * float(k + 1) / 8.0), col if k % 2 == 0 else Color.WHITE, 0.03)
		piece.position.y = 2.0
		root.add_child(piece)
	v.add_child(root)


# --- 落とし物 ---

## 落とし物の大きさ(持ち方と、床に置く高さに使う)
const ITEM_SIZES := [
	Vector3(0.3, 0.08, 0.28),   # 貝殻
	Vector3(0.42, 0.42, 0.42),  # ビーチボール
	Vector3(0.7, 0.2, 0.7),     # 浮き輪
	Vector3(0.7, 0.75, 0.7),    # 砂の城
	Vector3(0.6, 0.5, 1.9),     # バナナボート
]


## 落とし物の部品を item(WorldView の _handkerchief)のすぐ下に置く(見え方のルールで隠すため)
static func build_item(item: Node3D, index: int) -> void:
	match index:
		0:
			# 貝殻(ホタテ): 扇形にひらいたうね+根元の耳。ピンクとクリーム色
			for k in 7:
				var ang := lerpf(-0.95, 0.95, float(k) / 6.0)
				var col := Color("F6B4C0") if k % 2 == 0 else Color("FFE6D8")
				var rib := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.07, 0.05, 0.26), 0.02), col, 0.02)
				rib.rotation.y = ang
				rib.position = Vector3(sin(ang) * 0.1, 0.035 + 0.01 * cos(ang * 2.0), cos(ang) * 0.1 - 0.06)
				item.add_child(rib)
			var ear := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.12, 0.04, 0.06), 0.015), Color("F6B4C0"), 0.02)
			ear.position = Vector3(0, 0.03, -0.08)
			item.add_child(ear)
		1:
			# ビーチボール: 白い玉に、赤・青・黄のしま(6つの区切り)
			var cols := [Color("E5483B"), Color.WHITE, Color("3F86F0"), Color.WHITE, Color("F2C14E"), Color.WHITE]
			for k in 6:
				var mi := Toon.mesh(_lune(0.21, TAU * float(k) / 6.0, TAU * float(k + 1) / 6.0), cols[k], 0.025)
				mi.position.y = 0.21
				item.add_child(mi)
			var cap := SphereMesh.new()
			cap.radius = 0.05
			cap.height = 0.03
			var cm := Toon.mesh(cap, Color.WHITE, 0.01)
			cm.position.y = 0.42
			item.add_child(cm)
		2:
			# 浮き輪: 赤い輪に、白い帯が4つ
			var torus := TorusMesh.new()
			torus.inner_radius = 0.2
			torus.outer_radius = 0.35
			torus.rings = 24
			torus.ring_segments = 10
			var tm := Toon.mesh(torus, Color("E5483B"), 0.03)
			tm.position.y = 0.08
			item.add_child(tm)
			for k in 4:
				var ang := TAU * float(k) / 4.0 + PI / 4.0
				var band := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.17, 0.165, 0.12), 0.05), Color.WHITE, 0.0)
				band.rotation.y = ang + PI / 2.0
				band.position = Vector3(sin(ang) * 0.275, 0.08, cos(ang) * 0.275)
				item.add_child(band)
		3:
			# 砂の城: 四角い土台、まん中の大きい塔、四すみの小さい塔(とんがり屋根)、旗
			var sand := COLOR_SAND_DARK
			var base := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.62, 0.2, 0.62), 0.03), sand, 0.03)
			base.position.y = 0.1
			item.add_child(base)
			var keep := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.28, 0.3, 0.28), 0.02), sand, 0.03)
			keep.position.y = 0.35
			item.add_child(keep)
			for x in [-0.24, 0.24]:
				for z in [-0.24, 0.24]:
					var tower := CylinderMesh.new()
					tower.top_radius = 0.08
					tower.bottom_radius = 0.09
					tower.height = 0.3
					tower.radial_segments = 10
					var tw := Toon.mesh(tower, sand, 0.025)
					tw.position = Vector3(x, 0.35, z)
					item.add_child(tw)
					var roof := CylinderMesh.new()
					roof.top_radius = 0.0
					roof.bottom_radius = 0.1
					roof.height = 0.14
					roof.radial_segments = 10
					var rf := Toon.mesh(roof, COLOR_SAND, 0.025)
					rf.position = Vector3(x, 0.57, z)
					item.add_child(rf)
			var pole := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.02, 0.26, 0.02), 0.005), Color("8B6240"), 0.01)
			pole.position.y = 0.63
			item.add_child(pole)
			var flag := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.14, 0.09, 0.01), 0.004), Color("E5483B"), 0.01)
			flag.position = Vector3(0.08, 0.71, 0)
			item.add_child(flag)
		_:
			# バナナボート: 黄色い長い胴(前が少し上がる)・先の顔の黒い点・青い取っ手・左右の浮き
			var body := CapsuleMesh.new()
			body.radius = 0.24
			body.height = 1.8
			body.radial_segments = 14
			body.rings = 6
			var bm := Toon.mesh(body, Color("FFD93B"), 0.035)
			bm.rotation.x = PI / 2.0 + 0.06
			bm.position.y = 0.3
			item.add_child(bm)
			var tip := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.16, 0.16, 0.18), 0.06), Color("6B4A2B"), 0.02)
			tip.position = Vector3(0, 0.4, -0.94)
			item.add_child(tip)
			for z in [-0.45, 0.05, 0.55]:
				var handle := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.3, 0.06, 0.05), 0.02), Color("3F86F0"), 0.015)
				handle.position = Vector3(0, 0.57, z)
				item.add_child(handle)
			for x in [-0.33, 0.33]:
				var side := CapsuleMesh.new()
				side.radius = 0.11
				side.height = 1.3
				side.radial_segments = 10
				side.rings = 4
				var sdm := Toon.mesh(side, Color("FFC21A"), 0.025)
				sdm.rotation.x = PI / 2.0
				sdm.position = Vector3(x, 0.13, 0.15)
				item.add_child(sdm)


## かさの1枚(底の半径 r・高さ h の円すいの、角度 a0〜a1 の部分。底の面はなし)
static func _cone_slice(r: float, h: float, a0: float, a1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, h, 0)
	var segs := 3
	for j in segs:
		var p0 := lerpf(a0, a1, float(j) / float(segs))
		var p1 := lerpf(a0, a1, float(j + 1) / float(segs))
		var b0 := Vector3(cos(p0) * r, 0, sin(p0) * r)
		var b1 := Vector3(cos(p1) * r, 0, sin(p1) * r)
		var n := (b1 - apex).cross(b0 - apex).normalized()
		# 外側(上から見える面)と、内側(下から見える面)
		for q in [apex, b0, b1]:
			st.set_normal(n)
			st.add_vertex(q)
		for q in [apex, b1, b0]:
			st.set_normal(-n)
			st.add_vertex(q)
	return st.commit()


## 玉の、経度 a0〜a1 の部分(ビーチボールのしま1つ)
static func _lune(r: float, a0: float, a1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := 4
	for i in rings:
		var t0 := PI * float(i) / float(rings)
		var t1 := PI * float(i + 1) / float(rings)
		for j in segs:
			var p0 := lerpf(a0, a1, float(j) / float(segs))
			var p1 := lerpf(a0, a1, float(j + 1) / float(segs))
			var v00 := _sph(r, t0, p0)
			var v01 := _sph(r, t0, p1)
			var v10 := _sph(r, t1, p0)
			var v11 := _sph(r, t1, p1)
			for q in [v00, v10, v11, v00, v11, v01]:
				st.set_normal((q as Vector3).normalized())
				st.add_vertex(q)
	return st.commit()


static func _sph(r: float, theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)) * r


# --- 追いかけっこの障害物(海の物) ---

## kind は教室と同じ(bucket: 低い物/chair・desk: 高い物)。見た目だけ海の物にする
static func build_obstacle(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"bucket":
			# 砂山にささったスコップ
			var mound := SphereMesh.new()
			mound.radius = 0.32
			mound.height = 0.32
			mound.is_hemisphere = true
			var mm := Toon.mesh(mound, COLOR_SAND_DARK, 0.03)
			mm.scale = Vector3(1, 0.8, 1)
			root.add_child(mm)
			var handle := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.04, 0.4, 0.04), 0.01), Color("3F86F0"), 0.015)
			handle.position = Vector3(0.05, 0.38, 0)
			handle.rotation.z = -0.25
			root.add_child(handle)
			var blade := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.14, 0.16, 0.03), 0.01), Color("3F86F0"), 0.015)
			blade.position = Vector3(0.0, 0.2, 0)
			blade.rotation.z = -0.25
			root.add_child(blade)
		"chair":
			# クーラーボックス(青い箱に白いふた、取っ手)
			var box := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.56, 0.36, 0.38), 0.03), Color("3F86F0"), 0.025)
			box.position.y = 0.18
			root.add_child(box)
			var lid := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.58, 0.08, 0.4), 0.03), Color.WHITE, 0.025)
			lid.position.y = 0.4
			root.add_child(lid)
			var h := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.36, 0.04, 0.04), 0.01), Color("2E2B28"), 0.01)
			h.position.y = 0.47
			root.add_child(h)
		"desk":
			# ビーチチェア(しまの布を、木の枠に斜めに張る)
			for x in [-0.27, 0.27]:
				var frame := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.04, 0.04, 0.9), 0.01), COLOR_WOOD, 0.015)
				frame.position = Vector3(x, 0.32, 0)
				frame.rotation.x = 0.55
				root.add_child(frame)
				var leg := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.04, 0.4, 0.04), 0.01), COLOR_WOOD, 0.015)
				leg.position = Vector3(x, 0.2, -0.28)
				root.add_child(leg)
			for i in 3:
				var cloth := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.18, 0.02, 0.86), 0.005),
						Color("EE6A4D") if i % 2 == 0 else Color.WHITE, 0.012)
				cloth.position = Vector3(-0.18 + 0.18 * float(i), 0.33, 0)
				cloth.rotation.x = 0.55
				root.add_child(cloth)
		_:
			root.free()
			return null
	return root
