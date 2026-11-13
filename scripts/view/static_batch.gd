class_name StaticBatch
extends RefCounted
## 動かない背景の箱を、色ごとに1つの形(メッシュ)にまとめて描く(スマホで軽くするため)。
## 輪郭線は、箱ごとの中心からふくらませる(まとめても線が切れないように、中心を頂点に持たせる)。

## 立体感: 床に近いほど少し暗く(この高さ(メートル)で元の明るさ)、いちばん下の明るさ
const AO_HEIGHT := 1.3
const AO_FLOOR := 0.8
## 部品ごとの色むら(明るさを ± この割合だけ変える)
const JITTER := 0.05
## 角を丸める(面取りする)大きさ(メートル)
const BEVEL := 0.035

## 色と輪郭線の太さ -> {"color", "outline", "v": 頂点, "n": 法線, "c": 箱の中心, "k": 頂点の明るさ, "i": 番号}
var _groups := {}

static var _box_cache := {}


## 箱を1つ足す(xf: 箱の中心の位置と向き。まとめた形の座標で)
func add_box(size: Vector3, xf: Transform3D, color: Color, outline: float) -> void:
	var key := "%s|%.3f" % [color.to_html(), outline]
	if not _groups.has(key):
		_groups[key] = {"color": color, "outline": outline, "v": PackedVector3Array(), "n": PackedVector3Array(),
				"c": PackedFloat32Array(), "k": PackedColorArray(), "i": PackedInt32Array()}
	var g: Dictionary = _groups[key]
	# 輪郭線のある物は角を少し丸める(面取り)。薄い物(紙・線)はそのまま
	var bevel := 0.0
	var thin := minf(size.x, minf(size.y, size.z))
	if outline > 0.0 and thin > 0.05:
		bevel = minf(BEVEL, thin * 0.3)
	var arrays := chamfer_box(Vector3.ONE * 2.0, 0.0) if bevel <= 0.0 else chamfer_box(size, bevel)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# 面取りした箱は、すでに本当の大きさ。ふつうの箱は 1 辺 1 なので大きさをかける
	var scale_v := Vector3.ONE if bevel > 0.0 else size * 0.5
	var base: int = (g["v"] as PackedVector3Array).size()
	var nb := xf.basis.orthonormalized()
	var center := xf.origin
	var v: PackedVector3Array = g["v"]
	var n: PackedVector3Array = g["n"]
	var c: PackedFloat32Array = g["c"]
	var kk: PackedColorArray = g["k"]
	var ii: PackedInt32Array = g["i"]
	# 部品ごとに少しだけ明るさを変える(位置から決めるので、毎回同じ)
	var h := absf(sin(center.x * 12.9898 + center.y * 78.233 + center.z * 37.719) * 43758.5453)
	var jitter := 1.0 + (fmod(h, 1.0) * 2.0 - 1.0) * JITTER
	# 薄い物(床板・貼り紙など)は床に近くても暗くしない
	var ao := size.y > 0.12
	for k in verts.size():
		var p := xf * (verts[k] * scale_v)
		v.append(p)
		n.append((nb * norms[k]).normalized())
		c.append_array(PackedFloat32Array([center.x, center.y, center.z, 0.0]))
		var b := jitter
		if ao:
			b *= lerpf(AO_FLOOR, 1.0, clampf(p.y / AO_HEIGHT, 0.0, 1.0))
		kk.append(Color(b, b, b))
	for k in idx:
		ii.append(base + k)
	g["v"] = v
	g["n"] = n
	g["c"] = c
	g["k"] = kk
	g["i"] = ii


## まとめた形を作って parent に置く。描く回数は「色の数 × 2(塗り+輪郭線)」だけ
func build(parent: Node3D) -> void:
	for key in _groups:
		var g: Dictionary = _groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["v"]
		arrays[Mesh.ARRAY_NORMAL] = g["n"]
		arrays[Mesh.ARRAY_CUSTOM0] = g["c"]
		arrays[Mesh.ARRAY_COLOR] = g["k"]
		arrays[Mesh.ARRAY_INDEX] = g["i"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Toon.material_batched(g["color"], g["outline"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_groups.clear()


## 面取りした箱(中心が原点、大きさ size、角を r だけ削る)の頂点・法線・番号。
## 6つの面+12本の辺の斜め面+8つの角の三角(アニメ塗りに合うよう、面ごとに平らな法線)
static func chamfer_box(size: Vector3, r: float) -> Array:
	var key := "%s|%.3f" % [size, r]
	if _box_cache.has(key):
		return _box_cache[key]
	var h := size / 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		var base := verts.size()
		verts.append_array(PackedVector3Array([a, b, c, d]))
		norms.append_array(PackedVector3Array([n, n, n, n]))
		# Godot は時計回りが表なので、外向きの法線と逆の順に並べる
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		var base := verts.size()
		verts.append_array(PackedVector3Array([a, b, c]))
		norms.append_array(PackedVector3Array([n, n, n]))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1]))
	# 角の点: 軸 i を±h、ほかの軸は h - r だけ内側
	var pt := func(sx: float, sy: float, sz: float, axis: int) -> Vector3:
		var v := Vector3(sx * (h.x - r), sy * (h.y - r), sz * (h.z - r))
		v[axis] = [sx, sy, sz][axis] * h[axis]
		return v
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var w := (axis + 2) % 3
			var c := []
			for su in [-1.0, 1.0]:
				for sw in [-1.0, 1.0]:
					var s3 := [0.0, 0.0, 0.0]
					s3[axis] = sgn
					s3[u] = su
					s3[w] = sw
					c.append(pt.call(s3[0], s3[1], s3[2], axis))
			# 面(外向きになる順に)
			if sgn > 0.0:
				quad.call(c[0], c[2], c[3], c[1])
			else:
				quad.call(c[0], c[1], c[3], c[2])
	if r > 0.0:
		# 辺の斜め面: 2つの面にはさまれた細い四角
		for axis in 3:
			var u := (axis + 1) % 3
			var w := (axis + 2) % 3
			for su in [-1.0, 1.0]:
				for sw in [-1.0, 1.0]:
					var ends := []
					for sa in [-1.0, 1.0]:
						var s3 := [0.0, 0.0, 0.0]
						s3[axis] = sa
						s3[u] = su
						s3[w] = sw
						ends.append([pt.call(s3[0], s3[1], s3[2], u), pt.call(s3[0], s3[1], s3[2], w)])
					var a: Vector3 = ends[0][0]
					var b: Vector3 = ends[1][0]
					var cc: Vector3 = ends[1][1]
					var d: Vector3 = ends[0][1]
					var mid := (a + b + cc + d) / 4.0
					var n := (b - a).cross(cc - a)
					if n.dot(mid) < 0.0:
						quad.call(a, d, cc, b)
					else:
						quad.call(a, b, cc, d)
		# 角の三角
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var a: Vector3 = pt.call(sx, sy, sz, 0)
					var b: Vector3 = pt.call(sx, sy, sz, 1)
					var c: Vector3 = pt.call(sx, sy, sz, 2)
					var n := (b - a).cross(c - a)
					if n.dot(a + b + c) < 0.0:
						tri.call(a, c, b)
					else:
						tri.call(a, b, c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	_box_cache[key] = arrays
	return arrays


## 面取りした箱のメッシュ(1つだけ置く物用。輪郭線は Toon の材質で)
static func chamfer_mesh(size: Vector3, r: float) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chamfer_box(size, r))
	return m
