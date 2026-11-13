class_name CharacterModel
extends Node3D
## 人型のキャラクター(A案「放課後ポップ」)。正面は -Z。
## - 骨組みと動き: Quaternius「Universal Animation Library」(CC0。docs/CREDITS.md)
##   付属の人形は使わず、骨に「丸い頭・カプセルの胴・短い手足(指なし)」をくっつけて見せる
## - 顔: 点の目と線の口。表情(set_expression)とお手つきの崩れ(set_fluster)
## - 動き: 座る/歩く/走る/立っている(set_pose)。振り向きは頭→上半身の順に少し遅れて回る(set_look)
## 状態(GameState)は持たない。WorldView が毎フレーム表情と姿勢を決めて渡す。

const NORMAL := "normal"       # ふだん: 点の目・まっすぐな口
const SURPRISED := "surprised" # 振り向いた/スタンプが届いた: 丸い大きな目・「o」の口
const OOPS := "oops"           # お手つき: 汗・「へ」の口
const PANIC := "panic"         # 追いかける/逃げる: 細い目・汗・「o」の口・前のめり
const WIN := "win"             # 勝ち: にっこり(「^」の目・U の口)
const LOSE := "lose"           # 負け: しょんぼり(下がった目・への字の口・うなだれる)

## お手つきでだんだん崩れる顔(set_fluster)
## 0: ふだん / 1: 困り眉・汗 / 2: 汗2つ・目がちぐはぐ・への字口・ふるえる / 3: 放心(×の目・ぽかん口・ふらふら)
const FLUSTER_MAX := 3

## 顔の部品は、頭の球の中心を原点にした「顔」ノードの上に置く
const HEAD_Y := 0.0
const FACE_Z := -0.222

## 骨組みと動きの素材
const RIG_SCENE := preload("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf")
## 素材の人形(身長 約1.75m)の大きさの倍率(転ぶときの物理演算のため 1.0 のまま)
const BODY_SCALE := 1.0
## 座っているとき、腰が椅子の上に来るように体全体を前へずらす量(メートル。体の向きで前)
const SEAT_SHIFT := 0.33
## 体育座り(床に座る): 座る動きから、ももを上げてひざを立て、すねを手前にたたみ、腕でひざをかかえる。
## 腰は床まで下げ、体は少しだけ後ろへ傾ける。角度は度(+ で前へ曲げる/- で前へ上げる)
const FLOOR_LEAN := 0.12
const FLOOR_BEND := {
	"DEF-thigh.L": -55.0, "DEF-thigh.R": -55.0,
	"DEF-shin.L": 85.0, "DEF-shin.R": 85.0,
	"DEF-spine.001": 14.0,
	"DEF-upper_arm.L": -35.0, "DEF-upper_arm.R": -35.0,
}
## いすに座ったときの腰の高さ/体育座りの腰の高さ(メートル)
const SIT_HIP_HEIGHT := 0.5
const FLOOR_HIP_HEIGHT := 0.14
## 転ぶ: 物理演算でぐにゃっと倒れる時間と、起き上がる(動きに戻る)時間(秒)。合わせて GameConfig.SLIP_TIME くらい
const RAGDOLL_FALL_TIME := 0.7
const RAGDOLL_RISE_TIME := 0.35
## 物理演算で動かす骨 [骨, 次の関節(長さを測る), 太さ]。次の関節が "" なら球
const RAGDOLL_BONES := [
	["DEF-hips", "DEF-spine.001", 0.17],
	["DEF-spine.001", "DEF-neck", 0.18],
	["DEF-head", "", 0.21],
	["DEF-upper_arm.L", "DEF-forearm.L", 0.065],
	["DEF-forearm.L", "DEF-hand.L", 0.06],
	["DEF-upper_arm.R", "DEF-forearm.R", 0.065],
	["DEF-forearm.R", "DEF-hand.R", 0.06],
	["DEF-thigh.L", "DEF-shin.L", 0.085],
	["DEF-shin.L", "DEF-foot.L", 0.075],
	["DEF-thigh.R", "DEF-shin.R", 0.085],
	["DEF-shin.R", "DEF-foot.R", 0.075],
]
## 転ぶ体がぶつかる層(床)と、体の層(体どうしはぶつからない)
const FLOOR_LAYER := 1
const RAGDOLL_LAYER := 2


## 頭の球の大きさと、首の骨からの高さ(素材の大きさで。BODY_SCALE がかかる)
const HEAD_RADIUS := 0.22
const HEAD_LIFT := 0.16
## 振り向くとき、骨ごとにひねる角度(度)。合わせて約180度。頭が先、上半身があと
const LOOK_TWIST := {"DEF-spine.002": 30.0, "DEF-spine.003": 35.0, "DEF-neck": 50.0, "DEF-head": 65.0}
const LOOK_HEAD_TIME := 0.12
const LOOK_BODY_TIME := 0.32

## 姿勢ごとの動き(素材の動きの名前)
const ANIM_SIT := "Sitting_Idle_Loop"
const ANIM_SIT_DOWN := "Sitting_Enter"
const ANIM_STAND_UP := "Sitting_Exit"
const ANIM_RUN := "Sprint_Loop"
const ANIM_WALK := "Walk_Loop"
const ANIM_IDLE := "Idle_Loop"

var _pivot: Node3D
var _rig: Node3D
var _skel: Skeleton3D
## 転ぶときの物理演算
var _sim: PhysicalBoneSimulator3D
var _pbones: Array[PhysicalBone3D] = []
## 骨の番号 -> その骨の物理演算の体
var _pb_by_bone := {}
var _ragdoll_t := -1.0
## 倒れたまま起き上がらない(撮影モード用)
var _ragdoll_hold := false
## 物理演算の形をどれだけ見た目に使うか(1 = 倒れている、0 = ふつうの動き)
var _ragdoll_w := 0.0
## 体の部品をくっつけた骨 [{"node": 骨についていく Node3D, "bone": 骨の番号}]
var _attachments: Array = []
var _anim: AnimationPlayer
var _face: Node3D
var _pose := ""
var _seat_shift := 0.0
## 体育座りの度合い(0 = いす、1 = 床)
var _floor_w := 0.0
## 体育座りで曲げる骨(骨の番号 -> 角度・ラジアン)
var _bend_bones := {}
var _look_target := 0.0
var _look_head := 0.0
var _look_body := 0.0
## ひねる骨の番号 -> 角度(ラジアン)
var _twist_bones := {}
## 動きの名前(小文字、「_loop」なしも)-> 読みこんだあとの本当の名前
var _anim_names := {}
## 頭の上の名札(札と文字)
var _name_label: Label3D
var _name_tag: Node3D
## 目・口・眉の色(体の色が暗いときは白)
var _face_color: Color = GameConfig.COLOR_INK
var _eyes: Array[MeshInstance3D] = []
var _happy_eyes: Array[Node3D] = []
var _mouth_flat: MeshInstance3D
var _mouth_o: MeshInstance3D
var _mouth_smile: Node3D
var _mouth_frown: Node3D
var _sweat: MeshInstance3D
var _sweat2: MeshInstance3D
var _brows: Array[MeshInstance3D] = []
var _x_eyes: Array[Node3D] = []
var _expression := ""
var _fluster := -1
var _hop := 0.0
var _lean := 0.0
var _slump := 0.0
var _time := 0.0
var _slip := 0.0
## まばたき: 次のまばたきまでの時間と、目を閉じている残り時間
var _blink_wait := randf_range(1.5, 4.0)
var _blink_left := 0.0
## 鬼だけがかぶる、学校の黄色い帽子
var _hat: Node3D
const COLOR_HAT := Color("FFD43B")
const COLOR_HAT_BAND := Color("F2B705")


func build(color: Color, display_name: String, font: Font) -> void:
	# 黒っぽい体では、目と口を白にする(黒い顔の部品が見えなくなるので)
	_face_color = GameConfig.COLOR_PAPER if color.get_luminance() < 0.25 else GameConfig.COLOR_INK
	_pivot = Node3D.new()
	add_child(_pivot)
	_build_rig()
	_build_body(color)

	_face = Node3D.new()
	_attach("DEF-head", _face, _head_transform())
	_build_hat()

	# 点の目
	for x in [-0.08, 0.08]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		var eye := _mesh(eye_mesh, _face_color)
		eye.position = Vector3(x, HEAD_Y + 0.04, FACE_Z + 0.005)
		_face.add_child(eye)
		_eyes.append(eye)
		# にっこりの「^」の目
		var happy := _bent_line(Vector3(x, HEAD_Y + 0.045, FACE_Z), 0.05, 0.4)
		_face.add_child(happy)
		_happy_eyes.append(happy)

	# 口のいろいろ
	_mouth_flat = _box(Vector3(0.1, 0.016, 0.01), Vector3(0, HEAD_Y - 0.08, FACE_Z))
	_face.add_child(_mouth_flat)
	var o_mesh := SphereMesh.new()
	o_mesh.radius = 0.035
	o_mesh.height = 0.07
	_mouth_o = _mesh(o_mesh, Color(0.25, 0.05, 0.05))
	_mouth_o.position = Vector3(0, HEAD_Y - 0.09, FACE_Z + 0.01)
	_face.add_child(_mouth_o)
	_mouth_smile = _bent_line(Vector3(0, HEAD_Y - 0.09, FACE_Z), 0.06, -0.5)
	_face.add_child(_mouth_smile)
	_mouth_frown = _bent_line(Vector3(0, HEAD_Y - 0.1, FACE_Z), 0.06, 0.5)
	_face.add_child(_mouth_frown)

	# 汗(水色のしずく)
	var sweat_mesh := SphereMesh.new()
	sweat_mesh.radius = 0.04
	sweat_mesh.height = 0.11
	_sweat = _mesh(sweat_mesh, Color(0.45, 0.75, 1.0))
	_sweat.position = Vector3(0.2, HEAD_Y + 0.1, -0.08)
	_face.add_child(_sweat)
	_sweat2 = _mesh(sweat_mesh, Color(0.45, 0.75, 1.0))
	_sweat2.position = Vector3(-0.21, HEAD_Y + 0.02, -0.1)
	_face.add_child(_sweat2)

	# 困り眉(ハの字)と、放心の「×」の目
	for x in [-0.08, 0.08]:
		var brow := _box(Vector3(0.075, 0.015, 0.01), Vector3(x, HEAD_Y + 0.115, FACE_Z + 0.01))
		brow.rotation.z = 0.4 if x < 0.0 else -0.4
		_face.add_child(brow)
		_brows.append(brow)
		var xe := Node3D.new()
		xe.position = Vector3(x, HEAD_Y + 0.04, FACE_Z)
		for r in [0.785, -0.785]:
			var bar := _box(Vector3(0.07, 0.014, 0.01), Vector3.ZERO)
			bar.rotation.z = r
			xe.add_child(bar)
		_face.add_child(xe)
		_x_eyes.append(xe)

	_build_name_tag(display_name, font)
	_build_ragdoll()

	set_expression(NORMAL)
	set_pose("sit")


## 頭の上の名札の位置の目印(名札そのものは HeadOverlay が 2D で出す)。頭といっしょに動く
func _build_name_tag(_display_name: String, _font: Font) -> void:
	var tag := Node3D.new()
	var at := _head_transform()
	at.origin += Vector3(0, HEAD_RADIUS + 0.22, 0)
	at.basis = Basis.IDENTITY
	_attach("DEF-head", tag, at)
	_name_tag = tag


## 骨の今の位置と向き(世界の座標)。手に持つ・背負う物の位置に使う
func bone_world(bone: String) -> Transform3D:
	var i := _skel.find_bone(bone) if _skel else -1
	for a in _attachments:
		if a["bone"] == i:
			return (a["node"] as Node3D).global_transform
	# 部品がついていない骨(背骨の上など)は、骨組みから直接位置を求める
	if i >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(i)
	return global_transform


## 名札を出す位置(世界の座標)
func tag_anchor() -> Vector3:
	return _name_tag.global_position if _name_tag and _name_tag.is_inside_tree() else global_position + Vector3(0, 2.0, 0)


## 転ぶときの物理演算の体: 骨ごとにカプセルの当たりをつけ、関節は自由に曲がる(ぐにゃっと倒れる)
func _build_ragdoll() -> void:
	_sim = PhysicalBoneSimulator3D.new()
	_skel.add_child(_sim)
	for def in RAGDOLL_BONES:
		var bone: String = def[0]
		var child: String = def[1]
		var radius: float = def[2]
		var i := _skel.find_bone(bone)
		if i < 0:
			continue
		var length := 0.0 if child == "" else _rest_pos(bone).distance_to(_rest_pos(child))
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone
		pb.bone_name = bone
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		# 体の中心は骨の中ほど、関節は骨の根もと
		pb.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length / 2.0 if child != "" else HEAD_LIFT, 0))
		pb.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0, -length / 2.0 if child != "" else -HEAD_LIFT, 0))
		pb.mass = 3.0 if bone == "DEF-hips" or bone == "DEF-spine.001" else 1.0
		pb.linear_damp = 0.3
		pb.angular_damp = 1.5
		pb.friction = 0.9
		pb.collision_layer = 1 << (RAGDOLL_LAYER - 1)
		pb.collision_mask = 1 << (FLOOR_LAYER - 1)
		var cs := CollisionShape3D.new()
		if child == "":
			var sph := SphereShape3D.new()
			sph.radius = radius
			cs.shape = sph
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = radius
			cap.height = maxf(length + radius * 2.0, radius * 2.0 + 0.01)
			cs.shape = cap
		pb.add_child(cs)
		_sim.add_child(pb)
		_pbones.append(pb)
		_pb_by_bone[i] = pb


## 骨組みと動きを読みこむ。付属の人形(皮膚のメッシュ)は使わないので消す
func _build_rig() -> void:
	_rig = RIG_SCENE.instantiate()
	# 素材は +Z が正面。このキャラは -Z が正面なので半回転
	_rig.rotation.y = PI
	_rig.scale = Vector3.ONE * BODY_SCALE
	_pivot.add_child(_rig)
	_skel = _rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		mi.queue_free()
	_anim = _rig.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	# 動きはこちらで進める(振り向きのひねりを、動きのあとに足すため)
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# 読みこむときに名前の「_Loop」が外れることがあるので、どちらの名前でも探せるようにする
	for anim_name in _anim.get_animation_list():
		_anim_names[anim_name.to_lower()] = anim_name
		_anim_names[anim_name.to_lower().trim_suffix("_loop")] = anim_name
	for base in [ANIM_SIT, ANIM_RUN, ANIM_WALK, ANIM_IDLE]:
		var real := anim_of(base)
		if real != "":
			_anim.get_animation(real).loop_mode = Animation.LOOP_LINEAR
	for bone_name in LOOK_TWIST:
		var i := _skel.find_bone(bone_name)
		if i >= 0:
			_twist_bones[i] = deg_to_rad(LOOK_TWIST[bone_name])
	for bone_name in FLOOR_BEND:
		var i := _skel.find_bone(bone_name)
		if i >= 0:
			_bend_bones[i] = deg_to_rad(FLOOR_BEND[bone_name])


## 骨にくっつける体の部品: 丸い頭、カプセルの胴、短い手足(指なし)。全部同じ体の色
func _build_body(color: Color) -> void:
	var line := GameConfig.OUTLINE_WIDTH / BODY_SCALE
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	_attach("DEF-head", _mesh(head_mesh, color, line), _head_transform())
	# 胴: 腰から首まで。お腹は丸く
	_limb("DEF-spine.001", "DEF-hips", "DEF-neck", 0.19, color, line)
	# 腕・脚(関節から次の関節まで)
	for side in ["L", "R"]:
		_limb("DEF-upper_arm." + side, "DEF-upper_arm." + side, "DEF-forearm." + side, 0.065, color, line)
		_limb("DEF-forearm." + side, "DEF-forearm." + side, "DEF-hand." + side, 0.06, color, line)
		_limb("DEF-thigh." + side, "DEF-thigh." + side, "DEF-shin." + side, 0.085, color, line)
		_limb("DEF-shin." + side, "DEF-shin." + side, "DEF-foot." + side, 0.075, color, line)
		_limb("DEF-foot." + side, "DEF-foot." + side, "DEF-toe." + side, 0.07, color, line)
		# 手は指のない丸
		var hand := SphereMesh.new()
		hand.radius = 0.075
		hand.height = 0.15
		var at := Transform3D(Basis.IDENTITY, _rest_pos("DEF-hand." + side) + _bone_dir("DEF-hand." + side) * 0.05)
		_attach("DEF-hand." + side, _mesh(hand, color, line), at)


## 学校の黄色い帽子: 丸い山と、ぐるっと一周のつば、帽子の帯(ふだんは隠しておく)
func _build_hat() -> void:
	var line := GameConfig.OUTLINE_WIDTH / BODY_SCALE
	_hat = Node3D.new()
	_attach("DEF-head", _hat, _head_transform())
	var crown := SphereMesh.new()
	crown.radius = 0.215
	crown.height = 0.215
	crown.is_hemisphere = true
	var crown_mi := _mesh(crown, COLOR_HAT, line)
	crown_mi.position = Vector3(0, HEAD_Y + 0.13, 0)
	crown_mi.scale = Vector3(1.0, 0.8, 1.0)
	_hat.add_child(crown_mi)
	var band := CylinderMesh.new()
	band.top_radius = 0.218
	band.bottom_radius = 0.222
	band.height = 0.04
	band.radial_segments = 24
	var band_mi := _mesh(band, COLOR_HAT_BAND, 0.0)
	band_mi.position = Vector3(0, HEAD_Y + 0.155, 0)
	_hat.add_child(band_mi)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.3
	brim.bottom_radius = 0.31
	brim.height = 0.022
	brim.radial_segments = 28
	var brim_mi := _mesh(brim, COLOR_HAT, line)
	brim_mi.position = Vector3(0, HEAD_Y + 0.13, 0)
	# つばは前(-Z)が少し下がる
	brim_mi.rotation.x = -0.08
	_hat.add_child(brim_mi)
	_hat.visible = false


## 帽子をかぶる/ぬぐ(鬼だけがかぶる)
func set_hat(v: bool) -> void:
	if _hat:
		_hat.visible = v


## 頭の球の位置と向き(骨組みの座標で)。顔の -Z が体の正面(素材の +Z)を向く
func _head_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), _rest_pos("DEF-head") + Vector3(0, HEAD_LIFT, 0))


## 関節 from から関節 to まで、太さ radius のカプセルを bone にくっつける
func _limb(bone: String, from: String, to: String, radius: float, color: Color, line: float) -> void:
	var a := _rest_pos(from)
	var b := _rest_pos(to)
	var length := a.distance_to(b)
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = length + radius * 2.0
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var b3 := Basis(x, y, x.cross(y).normalized())
	_attach(bone, _mesh(cap, color, line), Transform3D(b3, (a + b) / 2.0))


## 骨組みの座標で決めた位置(立った形のとき)に node を置き、骨 bone といっしょに動くようにする。
## 骨についていく役は自分で動かす(_follow_bones。転んでいる間は物理演算の体についていく)
func _attach(bone: String, node: Node3D, rest_transform: Transform3D) -> void:
	var i := _skel.find_bone(bone)
	var holder: Node3D = null
	for a in _attachments:
		if a["bone"] == i:
			holder = a["node"]
	if holder == null:
		holder = Node3D.new()
		holder.name = "On_" + bone
		_skel.add_child(holder)
		holder.transform = _skel.get_bone_global_rest(i)
		_attachments.append({"node": holder, "bone": i})
	holder.add_child(node)
	node.transform = _skel.get_bone_global_rest(i).affine_inverse() * rest_transform


## 体の部品を骨の位置に動かす。転んでいる間は、物理演算の体の位置とまぜる
func _follow_bones() -> void:
	var to_skel := Transform3D.IDENTITY
	if _ragdoll_w > 0.0:
		to_skel = _skel.global_transform.affine_inverse()
	for a in _attachments:
		var bone: int = a["bone"]
		var t := _skel.get_bone_global_pose(bone)
		if _ragdoll_w > 0.0:
			var rt := _ragdoll_pose(bone, to_skel)
			t = t.interpolate_with(rt, _ragdoll_w)
		(a["node"] as Node3D).transform = t


## 転んでいる間の骨の形(骨組みの座標で)。物理演算の体がない骨は、いちばん近い親の体についていく
func _ragdoll_pose(bone: int, to_skel: Transform3D) -> Transform3D:
	var b := bone
	while b >= 0 and not _pb_by_bone.has(b):
		b = _skel.get_bone_parent(b)
	if b < 0:
		return _skel.get_bone_global_pose(bone)
	var pb: PhysicalBone3D = _pb_by_bone[b]
	var anc := to_skel * pb.global_transform * pb.body_offset.affine_inverse()
	if b == bone:
		return anc
	return anc * (_skel.get_bone_global_rest(b).affine_inverse() * _skel.get_bone_global_rest(bone))


func _rest_pos(bone: String) -> Vector3:
	return _skel.get_bone_global_rest(_skel.find_bone(bone)).origin


## 骨の向き(骨組みの座標で。骨は +Y の向きにのびている)
func _bone_dir(bone: String) -> Vector3:
	return _skel.get_bone_global_rest(_skel.find_bone(bone)).basis.y.normalized()


## 素材の動きの名前から、読みこんだあとの本当の名前を返す(なければ "")
func anim_of(base: String) -> String:
	var k := base.to_lower()
	return _anim_names.get(k, _anim_names.get(k.trim_suffix("_loop"), ""))


func _play(base: String, blend: float = -1.0, speed: float = 1.0) -> void:
	var real := anim_of(base)
	if real != "":
		_anim.play(real, blend, speed)


func _queue(base: String) -> void:
	var real := anim_of(base)
	if real != "":
		_anim.queue(real)


## 姿勢: "sit"(座る)/"floor"(体育座り)/"walk"(歩く)/"run"(走る)/"idle"(立っている)
## 座っている→走るときは立ち上がってから、立っている→座るときは座ってから続ける
func set_pose(pose: String) -> void:
	if pose == _pose or _anim == null:
		return
	var prev := _pose
	_pose = pose
	_anim.clear_queue()
	match pose:
		"sit", "floor":
			if prev == "sit" or prev == "floor":
				return
			if prev == "":
				_play(ANIM_SIT)
			else:
				_play(ANIM_SIT_DOWN, 0.15, 2.0)
				_queue(ANIM_SIT)
		"run":
			if prev == "sit" or prev == "floor":
				_play(ANIM_STAND_UP, 0.1, 3.0)
				_queue(ANIM_RUN)
			else:
				_play(ANIM_RUN, 0.2)
		"walk":
			_play(ANIM_WALK, 0.25)
		_:
			_play(ANIM_IDLE, 0.25)
	if prev == "":
		_anim.advance(0.0)


## 振り向く(true)/前を向く(false)。頭が先に回り、上半身が少し遅れてついてくる
func set_look(back: bool) -> void:
	_look_target = 1.0 if back else 0.0


## 頭の上の名前を出す/消す(自分の名前は自分の画面には出さない)
func set_name_visible(v: bool) -> void:
	if _name_tag:
		_name_tag.visible = v


## 自分のカメラから隠すときなどに、すべての見た目のレイヤーをまとめて変える
func set_layers(layer_bits: int) -> void:
	_set_layers_rec(self, layer_bits)


func set_expression(expr: String) -> void:
	if expr == _expression:
		return
	_expression = expr
	_apply_face()


## お手つきの回数に合わせて、顔をだんだん崩す(0〜FLUSTER_MAX)
func set_fluster(level: int) -> void:
	level = clampi(level, 0, FLUSTER_MAX)
	if level == _fluster:
		return
	_fluster = level
	_apply_face()


func _apply_face() -> void:
	var expr := _expression
	var happy := expr == WIN
	for e in _eyes:
		e.visible = not happy
	for h in _happy_eyes:
		h.visible = happy
	_mouth_flat.visible = expr == NORMAL
	_mouth_o.visible = expr == SURPRISED or expr == PANIC
	_mouth_smile.visible = expr == WIN
	_mouth_frown.visible = expr == OOPS or expr == LOSE
	_sweat.visible = expr == OOPS or expr == PANIC
	var eye_scale := Vector3.ONE
	match expr:
		SURPRISED:
			eye_scale = Vector3(1.7, 1.7, 1.7)
		PANIC:
			eye_scale = Vector3(1.3, 0.45, 1.0)
		LOSE:
			eye_scale = Vector3(1.2, 0.5, 1.0)
	for e in _eyes:
		e.scale = eye_scale

	# --- お手つきで崩れた顔を上からかぶせる(勝ち・負け・走っているときは、その顔を優先) ---
	var f := maxi(_fluster, 0)
	var calm := expr == NORMAL or expr == SURPRISED or expr == OOPS
	for b in _brows:
		b.visible = f >= 1 and expr != WIN
	_sweat.visible = _sweat.visible or f >= 1
	_sweat2.visible = f >= 2
	for xe in _x_eyes:
		xe.visible = false
	if not calm:
		return
	if f >= 3:
		# 放心: ×の目・ぽかん口
		for e in _eyes:
			e.visible = false
		for xe in _x_eyes:
			xe.visible = true
		_mouth_flat.visible = false
		_mouth_frown.visible = false
		_mouth_o.visible = true
	elif f >= 2 and expr == NORMAL:
		# 目がちぐはぐ・への字口
		_eyes[0].scale = Vector3(1.5, 1.5, 1.0)
		_eyes[1].scale = Vector3(0.75, 0.75, 1.0)
		_mouth_flat.visible = false
		_mouth_frown.visible = true


## 振り向いたときなどに、ピョンと跳ねる
func hop() -> void:
	_hop = 1.0


## バナナの皮で、つるっと転ぶ: 物理演算でぐにゃっと倒れて、少しして起き上がる。
## hold = true なら倒れたまま(撮影モード用。stop_ragdoll で元に戻す)
func slip(hold: bool = false) -> void:
	_slip = 1.0
	_ragdoll_hold = hold
	if _sim == null or not is_inside_tree() or _pbones.is_empty():
		return
	_sim.influence = 1.0
	_sim.physical_bones_start_simulation()
	_ragdoll_t = 0.0
	_ragdoll_w = 1.0
	# 走っていた向きへ、上半身を前に投げ出し、足をすくう
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for pb in _pbones:
		var b := String(pb.bone_name)
		if b.begins_with("DEF-thigh") or b.begins_with("DEF-shin"):
			pb.apply_central_impulse(-fwd * 1.6 * pb.mass)
		elif b == "DEF-hips":
			pb.apply_central_impulse((fwd * 0.5 + Vector3.DOWN * 1.5) * pb.mass)
		else:
			pb.apply_central_impulse((fwd * 3.0 + Vector3.DOWN * 1.0) * pb.mass)


## 倒れているのをやめて、ふつうの動きに戻す
func stop_ragdoll() -> void:
	if _ragdoll_t < 0.0:
		return
	_sim.physical_bones_stop_simulation()
	_ragdoll_t = -1.0
	_ragdoll_w = 0.0
	_ragdoll_hold = false
	_slip = 0.0


## 転んでいる間の物理演算を進める: 倒れきったら、だんだん元の動きに戻す(起き上がる)
func _update_ragdoll(delta: float) -> void:
	if _ragdoll_t < 0.0:
		return
	_ragdoll_t += delta
	if _ragdoll_hold:
		return
	if _ragdoll_t > RAGDOLL_FALL_TIME:
		_ragdoll_w = clampf(1.0 - (_ragdoll_t - RAGDOLL_FALL_TIME) / RAGDOLL_RISE_TIME, 0.0, 1.0)
	if _ragdoll_t >= RAGDOLL_FALL_TIME + RAGDOLL_RISE_TIME:
		_sim.physical_bones_stop_simulation()
		_ragdoll_t = -1.0
		_ragdoll_w = 0.0


## 毎フレームの動き。running: 走っている(大げさに揺れる)
func animate(delta: float, running: bool) -> void:
	_time += delta
	_update_blink(delta)
	_update_rig(delta)
	_update_ragdoll(delta)
	_follow_bones()
	_hop = maxf(_hop - delta * 4.0, 0.0)
	_lean = move_toward(_lean, 1.0 if running else 0.0, delta * 5.0)
	_slump = move_toward(_slump, 1.0 if _expression == LOSE else 0.0, delta * 3.0)
	var hop_y := sin(_hop * PI) * 0.18
	# 走るときは前(-Z)に傾けて小刻みに揺らす。負けたらうなだれる
	var bob := sin(_time * 18.0) * 0.04 * _lean
	_pivot.position = Vector3(0, hop_y + bob, 0)
	_slip = maxf(_slip - delta / GameConfig.SLIP_TIME, 0.0)
	# 転ぶ: 物理演算が使えないとき(画面に出ていないときなど)だけ、横にばったり倒れる動きで代わりにする
	_pivot.rotation.z = 0.0
	if _ragdoll_t < 0.0:
		_pivot.rotation.z = sin(minf(_slip * 3.0, 1.0) * PI / 2.0) * 1.3 * minf(_slip * 1.5, 1.0)
	# お手つきが重なるほど落ち着きがなくなる: 2回でふるえ、放心でふらふら
	if _fluster == 2:
		_pivot.position.x = sin(_time * 45.0) * 0.012
	elif _fluster >= 3:
		_pivot.rotation.z += sin(_time * 2.5) * 0.15
		_pivot.position.x = 0.0
	else:
		_pivot.position.x = 0.0
	# 座っているときは、ゆっくり少し揺れる
	if _pose == "sit" or _pose == "floor":
		_pivot.rotation.z += sin(_time * 1.6 + float(get_instance_id() % 7)) * 0.025
	# 走る動きは素材が前のめりなので、ここでは少しだけ足す
	_pivot.rotation.x = -0.1 * _lean * (1.0 - _slip) - 0.25 * _slump
	_pivot.scale = Vector3(1.0, 1.0 - 0.08 * _slump, 1.0)
	# 体育座り: 腰を中心に後ろへ傾ける(ひざが立つ)。腰が床の上に来るように下げる
	_floor_w = move_toward(_floor_w, 1.0 if _pose == "floor" else 0.0, delta * 2.5)
	if _floor_w > 0.0:
		var lean := FLOOR_LEAN * _floor_w
		_pivot.rotation.x += lean
		var hip_y := lerpf(SIT_HIP_HEIGHT, FLOOR_HIP_HEIGHT, _floor_w)
		_pivot.position += Vector3(0, hip_y - SIT_HIP_HEIGHT * cos(lean), -SIT_HIP_HEIGHT * sin(lean))
	# 汗はぷるぷる揺れる
	if _sweat.visible:
		_sweat.position.y = HEAD_Y + 0.1 + sin(_time * 10.0) * 0.015
	if _sweat2.visible:
		_sweat2.position.y = HEAD_Y + 0.02 + sin(_time * 12.0 + 1.0) * 0.015


## まばたき: ときどき一瞬だけ目を細くする(点の目のときだけ)
func _update_blink(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_apply_face()
		return
	_blink_wait -= delta
	if _blink_wait > 0.0:
		return
	_blink_wait = randf_range(2.0, 5.0)
	if _expression == NORMAL or _expression == OOPS:
		_blink_left = 0.12
		for e in _eyes:
			if e.visible:
				e.scale = Vector3(e.scale.x, 0.15, e.scale.z)


## 骨の動きを進め、座っているときの位置と、振り向きのひねりを足す
func _update_rig(delta: float) -> void:
	if _anim == null:
		return
	# ひねる骨は、いったん元に戻してから動きを当てる(ひねりが積み重ならないように)
	for i in _twist_bones:
		_skel.set_bone_pose_rotation(i, _skel.get_bone_rest(i).basis.get_rotation_quaternion())
	for i in _bend_bones:
		_skel.set_bone_pose_rotation(i, _skel.get_bone_rest(i).basis.get_rotation_quaternion())
	_anim.advance(delta)
	# 体育座り: 骨組みの横の軸(素材の +X)のまわりに曲げる(素材は +Z が正面なので、+ の角度で前へ曲がる)
	if _floor_w > 0.0:
		for i in _bend_bones:
			var g := _skel.get_bone_global_pose(i).basis.get_rotation_quaternion()
			var axis := (g.inverse() * Vector3.RIGHT).normalized()
			_skel.set_bone_pose_rotation(i, _skel.get_bone_pose_rotation(i) * Quaternion(axis, _bend_bones[i] * _ease(_floor_w)))
	# 座る動きは腰が後ろに下がるので、体全体を前へずらして椅子の上に乗せる
	_seat_shift = move_toward(_seat_shift, SEAT_SHIFT if _pose == "sit" or _pose == "floor" else 0.0, delta / 0.5 * SEAT_SHIFT)
	_rig.position = Vector3(0, 0, -_seat_shift)
	# 振り向き: 頭は速く、上半身はゆっくり
	_look_head = move_toward(_look_head, _look_target, delta / LOOK_HEAD_TIME)
	_look_body = move_toward(_look_body, _look_target, delta / LOOK_BODY_TIME)
	for i in _twist_bones:
		var bone_name := _skel.get_bone_name(i)
		var t := _look_head if bone_name == "DEF-neck" or bone_name == "DEF-head" else _look_body
		if t <= 0.0:
			continue
		var angle: float = _twist_bones[i] * _ease(t)
		_skel.set_bone_pose_rotation(i, _skel.get_bone_pose_rotation(i) * Quaternion(Vector3.UP, angle))


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# --- 部品づくり ---

## 「^」や「U」のような折れ線(2本の棒)。bend > 0 で山形、< 0 で谷形
func _bent_line(center: Vector3, width: float, bend: float) -> Node3D:
	var n := Node3D.new()
	n.position = center
	for side in [-1.0, 1.0]:
		var bar := _box(Vector3(width * 0.6, 0.016, 0.01), Vector3(side * width * 0.27, 0, 0))
		bar.rotation.z = -side * bend
		n.add_child(bar)
	return n


func _box(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := _mesh(m, _face_color)
	mi.position = pos
	return mi


## アニメ塗りの見た目。outline > 0 なら黒い輪郭線もつける(顔の点や線にはつけない)
func _mesh(mesh: Mesh, color: Color, outline: float = 0.0) -> MeshInstance3D:
	return Toon.mesh(mesh, color, outline)


func _set_layers_rec(node: Node, bits: int) -> void:
	for c in node.get_children():
		if c is VisualInstance3D:
			c.layers = bits
		_set_layers_rec(c, bits)
