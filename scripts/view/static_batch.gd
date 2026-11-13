class_name StaticBatch
extends RefCounted
## 動かない背景の箱を、色ごとに1つの形(メッシュ)にまとめて描く(スマホで軽くするため)。
## 輪郭線は、箱ごとの中心からふくらませる(まとめても線が切れないように、中心を頂点に持たせる)。

## 立体感: 床に近いほど少し暗く(この高さ(メートル)で元の明るさ)、いちばん下の明るさ
const AO_HEIGHT := 1.3
const AO_FLOOR := 0.8
## 部品ごとの色むら(明るさを ± この割合だけ変える)
const JITTER := 0.05

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
	var arrays := _unit_box()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
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
		var p := xf * (verts[k] * size)
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


## 1辺 1 の箱(中心が原点)の頂点・法線・番号
static func _unit_box() -> Array:
	if _box_cache.is_empty():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_box_cache["a"] = b.get_mesh_arrays()
	return _box_cache["a"]
