class_name WorldView
extends Node3D
## GameState を読んで 3D の見た目を作る・更新するだけ。
## 状態は書きかえない。

## 自分の体を自分のカメラに映さないためのレイヤー
const SELF_LAYER := 2
## 自分の席からは見えない物(両どなりの後ろに落ちた物)を置くレイヤー
const HIDDEN_LAYER := 3

var _actor_nodes := {} # id -> Node3D
var _seat_cam: Camera3D
var _top_cam: Camera3D
var _handkerchief: Node3D
var _drop_player: AudioStreamPlayer3D
var _step_player: AudioStreamPlayer3D
var _beep_player: AudioStreamPlayer
var _stamp_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer3D
## 床のバナナの皮の見た目(状態の bananas と同じ数だけ出す)
var _banana_nodes: Array[MeshInstance3D] = []
## 頭の上のスタンプ表示(id -> Label3D)
var _stamp_labels := {}
## スタンプを送る相手の目印
var _target_marker: MeshInstance3D

## スタンプの色(仮)
const STAMP_COLORS := {
	Stamps.DROPPED: Color(0.95, 0.35, 0.2),
	Stamps.SAFE: Color(0.2, 0.7, 0.35),
	Stamps.NOW: Color(0.95, 0.7, 0.1),
	Stamps.TRUST: Color(0.6, 0.4, 0.9),
}
## 足音用: 鬼の前回の位置と、前の足音から歩いた距離
var _oni_last_pos := Vector3.ZERO
var _oni_walked := 0.0
## 振り向きの度合い(0=前、1=後ろ)。見た目をなめらかにするためだけの値
var _turn := {} # id -> float
## 表情のための時計と、表情を出しておく期限(id -> 時刻)
var _clock := 0.0
var _oops_until := {}
var _surprise_until := {}
var _was_looking := {}


func build(state: GameState) -> void:
	for c in get_children():
		c.queue_free()
	_actor_nodes.clear()
	_turn.clear()
	_oops_until.clear()
	_surprise_until.clear()
	_was_looking.clear()
	_stamp_labels.clear()
	_banana_nodes.clear()

	_build_environment()
	_build_floor()
	for i in state.seat_positions.size():
		_build_chair(state.seat_positions[i], state.seat_yaws[i])
	for a in state.actors:
		var node := _build_character(a, a.id == state.local_player_id)
		add_child(node)
		_actor_nodes[a.id] = node
	_build_handkerchief(state)
	_build_stamp_labels(state)
	_build_sounds(state)
	_build_cameras(state)
	sync(state, 0.0)


## 毎フレーム、状態に合わせて位置と向きを反映する。
func sync(state: GameState, delta: float) -> void:
	var turn_step := delta / GameConfig.LOOK_BACK_TIME
	for a in state.actors:
		var t: float = move_toward(_turn.get(a.id, 0.0), 1.0 if a.looking_back else 0.0, turn_step)
		_turn[a.id] = t
		var node: Node3D = _actor_nodes.get(a.id)
		if node:
			node.position = a.position
			# 振り向いた姿は全員に見える(体ごと大げさに後ろを向く)
			node.rotation.y = a.yaw + PI * t
			_update_expression(state, a, node as CharacterModel, delta)
	_update_seat_camera(state, delta)
	_update_stamp_labels(state)
	_update_bananas(state)
	_clock += delta

	var holder := state.get_actor(state.chaser_id)
	if holder:
		# 追いかける人が持って(大きい物は頭の上にかついで)走る
		_handkerchief.visible = true
		_handkerchief.position = holder.position + Vector3(0, _item_carry_height, 0)
	else:
		_handkerchief.visible = state.handkerchief_on_floor
		_handkerchief.position = state.handkerchief_position
	_hide_item_if_not_visible_to_me(state)
	_update_footsteps(state)


## 表情と動きを、状態から決める(見た目だけ。状態は変えない)
func _update_expression(state: GameState, a: GameState.Actor, model: CharacterModel, delta: float) -> void:
	if model == null:
		return
	var running := a.role == GameState.Role.CHASER \
			or (a.role == GameState.Role.ONI and state.phase == GameState.Phase.CHASE)
	var expr := CharacterModel.NORMAL
	if state.phase == GameState.Phase.RESULT and not state.result.is_empty():
		if state.result["winner"] == a.id:
			expr = CharacterModel.WIN
		elif state.result["loser"] == a.id:
			expr = CharacterModel.LOSE
	elif running:
		expr = CharacterModel.PANIC
	elif _oops_until.get(a.id, -1.0) > _clock:
		expr = CharacterModel.OOPS
	elif a.looking_back or _surprise_until.get(a.id, -1.0) > _clock:
		expr = CharacterModel.SURPRISED
	model.set_expression(expr)
	# 振り向いた瞬間にピョンと跳ねる
	if a.looking_back and not _was_looking.get(a.id, false):
		model.hop()
	_was_looking[a.id] = a.looking_back
	model.animate(delta, running and state.phase == GameState.Phase.CHASE)


## GameState からのお知らせに合わせて音などを出す。
func on_event(e: Dictionary) -> void:
	match e.get("type"):
		"otetsuki":
			_oops_until[e["actor"]] = _clock + 1.5
		"stamp":
			# スタンプが届いた人は、びっくり顔になる
			_surprise_until[e["target"]] = _clock + 1.0
		"picked_up":
			var m := _actor_nodes.get(e["actor"]) as CharacterModel
			if m:
				m.hop()
		"slip":
			var m := _actor_nodes.get(e["actor"]) as CharacterModel
			if m:
				m.slip()
			_oops_until[e["actor"]] = _clock + GameConfig.SLIP_TIME
		"voice":
			_voice_player.stream = Sfx.voice(e["kind"])
			_voice_player.position = e["pos"]
			_voice_player.pitch_scale = randf_range(0.92, 1.08)
			_voice_player.play()
		"dropped", "rustle":
			# 本物もニセの物音も、まったく同じ音。重い物ほど大きく、低く、遠くまで聞こえる
			var w: float = e.get("weight", 0.0)
			_drop_player.position = e["pos"]
			_drop_player.volume_db = lerpf(GameConfig.DROP_VOLUME_DB, GameConfig.DROP_VOLUME_DB_HEAVY, w)
			if e.get("masked", false):
				# 鬼の声でかき消された
				_drop_player.volume_db += GameConfig.VOICE_MASK_DB
			_drop_player.unit_size = lerpf(GameConfig.DROP_SOUND_RANGE, GameConfig.DROP_SOUND_RANGE_HEAVY, w)
			_drop_player.pitch_scale = lerpf(1.0, 0.5, w) * randf_range(0.9, 1.1)
			_drop_player.play()



func _update_footsteps(state: GameState) -> void:
	var oni := state.get_actor(state.oni_id)
	if oni == null:
		return
	_oni_walked += oni.position.distance_to(_oni_last_pos)
	_oni_last_pos = oni.position
	if _oni_walked >= GameConfig.FOOTSTEP_STRIDE:
		_oni_walked = 0.0
		_step_player.pitch_scale = randf_range(0.85, 1.15)
		_step_player.play()


## 席のカメラ ⇔ 上から見るカメラ(確認用)を切りかえる。
func toggle_top_camera() -> void:
	if _top_cam.current:
		_seat_cam.make_current()
	else:
		_top_cam.make_current()


func is_top_camera() -> bool:
	return _top_cam.current


# --- ここから下は見た目を作る処理 ---

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.9, 0.82) # 教室の壁っぽいクリーム色
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	add_child(_mesh(plane, Color(0.72, 0.55, 0.38))) # 木の床
	# 床板の継ぎ目っぽい線
	for i in range(-7, 8):
		var line := BoxMesh.new()
		line.size = Vector3(16, 0.002, 0.03)
		var mi := _mesh(line, Color(0.6, 0.44, 0.3))
		mi.position = Vector3(0, 0.001, i)
		add_child(mi)


func _build_chair(pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	var wood := Color(0.55, 0.35, 0.2)

	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.5, 0.05, 0.5)
	var seat := _mesh(seat_mesh, wood)
	seat.position = Vector3(0, 0.45, 0)
	chair.add_child(seat)

	# 背もたれは後ろ側(+Z)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.5, 0.5, 0.05)
	var back := _mesh(back_mesh, wood)
	back.position = Vector3(0, 0.72, 0.28)
	chair.add_child(back)

	var metal := Color(0.4, 0.4, 0.42)
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.04, 0.45, 0.04)
			var leg := _mesh(leg_mesh, metal)
			leg.position = Vector3(x, 0.225, z)
			chair.add_child(leg)
	add_child(chair)


## 仮のキャラクター(体・顔・表情は CharacterModel)
func _build_character(a: GameState.Actor, is_self: bool) -> Node3D:
	var model := CharacterModel.new()
	model.name = "Actor%d" % a.id
	model.build(a.color, a.display_name, HudFont.get_font())
	if is_self:
		# 自分の体は、座っているときの自分のカメラには映さない
		model.set_layers(1 << (SELF_LAYER - 1))
	return model


## バナナの皮: 状態の bananas に合わせて、黄色い三日月っぽい形を出す
func _update_bananas(state: GameState) -> void:
	while _banana_nodes.size() < state.bananas.size():
		var m := BoxMesh.new()
		m.size = Vector3(0.32, 0.05, 0.12)
		var mi := _mesh(m, Color(1.0, 0.85, 0.1))
		mi.rotation.y = randf() * TAU
		add_child(mi)
		_banana_nodes.append(mi)
	for i in _banana_nodes.size():
		var shown := i < state.bananas.size()
		_banana_nodes[i].visible = shown
		if shown:
			_banana_nodes[i].position = state.bananas[i]["pos"] + Vector3(0, 0.03, 0)


## 頭の上のスタンプ表示と、送る相手の目印
func _build_stamp_labels(state: GameState) -> void:
	for a in state.actors:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font = HudFont.get_font()
		# ほかの人あてのスタンプは小さめに(自分あては画面の下の吹き出しに出る)
		l.font_size = 44
		l.pixel_size = 0.004
		l.outline_size = 8
		l.no_depth_test = true
		l.position = Vector3(0, 2.25, 0)
		l.visible = false
		(_actor_nodes[a.id] as Node3D).add_child(l)
		_stamp_labels[a.id] = l

	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.0
	cone.height = 0.3
	_target_marker = _mesh(cone, Color(1.0, 0.85, 0.1))
	_target_marker.visible = false
	add_child(_target_marker)


func _update_stamp_labels(state: GameState) -> void:
	for id in _stamp_labels:
		var l: Label3D = _stamp_labels[id]
		var s: Dictionary = state.active_stamps.get(id, {})
		l.visible = not s.is_empty()
		if s.is_empty():
			continue
		var text: String = Stamps.LABELS[s["kind"]]
		if GameConfig.SHOW_STAMP_SENDER:
			var sender := state.get_actor(s["sender"])
			text += "\n(%s)" % sender.display_name
		l.text = text
		l.modulate = STAMP_COLORS[s["kind"]]


## 座っている自分から見えない席(両どなり)の後ろに落ちた物は、自分の席のカメラに映さない。
## (上から見る確認用カメラには映る)
func _hide_item_if_not_visible_to_me(state: GameState) -> void:
	var me := state.get_local_player()
	var hidden := state.handkerchief_on_floor and me.role == GameState.Role.SEATED \
			and state.drop_target_seat != me.seat_index \
			and not GameState.can_see_behind(me.seat_index, state.drop_target_seat)
	var bits := 1 << (HIDDEN_LAYER - 1) if hidden else 1
	for c in _handkerchief.get_children():
		if c is VisualInstance3D:
			c.layers = bits


## 落とし物の仮の形(大きさ・色)。ラウンドごとに重くなる
const ITEM_SHAPES := [
	[Vector3(0.35, 0.02, 0.35), Color(0.97, 0.97, 1.0)], # ハンカチ
	[Vector3(0.14, 0.12, 0.3), Color(0.9, 0.9, 0.95)],   # 上履き
	[Vector3(0.36, 0.4, 0.22), Color(0.8, 0.15, 0.15)],  # ランドセル
	[Vector3(0.6, 0.7, 0.45), Color(0.65, 0.45, 0.25)],  # 机
	[Vector3(0.9, 1.0, 0.5), Color(0.4, 0.25, 0.15)],    # 教卓
]
var _item_carry_height := 1.0


func _build_handkerchief(state: GameState) -> void:
	var shape: Array = ITEM_SHAPES[clampi(state.round_index, 0, ITEM_SHAPES.size() - 1)]
	var size: Vector3 = shape[0]
	var box := BoxMesh.new()
	box.size = size
	var mi := _mesh(box, shape[1])
	# 床に置いたとき、底が床につくように
	mi.position = Vector3(0, size.y / 2.0, 0)
	_handkerchief = Node3D.new()
	_handkerchief.add_child(mi)
	_handkerchief.visible = false
	add_child(_handkerchief)
	# 小さい物は手に持ち、大きい物は頭の上にかつぐ
	_item_carry_height = 0.9 if size.y < 0.3 else 1.75


func _build_sounds(state: GameState) -> void:
	# 足音は鬼の体についていく(左右・遠近で鬼の位置がわかる)
	_step_player = AudioStreamPlayer3D.new()
	_step_player.stream = Sfx.footstep()
	_step_player.volume_db = GameConfig.FOOTSTEP_VOLUME_DB
	_step_player.max_polyphony = 2
	# スマホのブラウザでも鳴るように、PC と同じ方式で再生する
	_step_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	(_actor_nodes[state.oni_id] as Node3D).add_child(_step_player)
	_oni_last_pos = state.get_actor(state.oni_id).position
	_oni_walked = 0.0

	_drop_player = AudioStreamPlayer3D.new()
	_drop_player.stream = Sfx.drop()
	_drop_player.volume_db = GameConfig.DROP_VOLUME_DB
	_drop_player.unit_size = GameConfig.DROP_SOUND_RANGE
	_drop_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_drop_player)

	_stamp_player = AudioStreamPlayer.new()
	_stamp_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_stamp_player.volume_db = -6.0
	add_child(_stamp_player)

	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_voice_player.volume_db = -2.0
	add_child(_voice_player)

	_beep_player = AudioStreamPlayer.new()
	_beep_player.stream = Sfx.beep()
	_beep_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_beep_player)


## 自分に届いたスタンプの音(ほかの人あてのスタンプでは鳴らさない)
func play_stamp_sound(kind: String) -> void:
	_stamp_player.stream = Sfx.stamp(kind)
	_stamp_player.play()


## スタンプを送る相手の目印を出す(-1 で消す)
func set_stamp_target(state: GameState, id: int) -> void:
	var a := state.get_actor(id)
	_target_marker.visible = a != null
	if a:
		_target_marker.position = a.position + Vector3(0, 2.25, 0)


## 画面のこの位置(タップした場所)にいる、座っている人の id(いなければ -1)
func pick_actor_at(state: GameState, screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var best := -1
	var best_dist := 110.0
	for a in state.actors:
		if a.id == state.local_player_id or a.role != GameState.Role.SEATED:
			continue
		var me := state.get_local_player()
		if me.role == GameState.Role.SEATED and not GameState.can_see_behind(me.seat_index, a.seat_index):
			continue # 両どなりはスタンプの相手に選べない
		for h in [0.9, 1.45]:
			var p: Vector3 = a.position + Vector3(0, h, 0)
			if cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen_pos)
			if d < best_dist:
				best_dist = d
				best = a.id
	return best


## 音テスト: 方向や距離に関係なく「ピー」と鳴らす
func play_test_beep() -> void:
	_beep_player.play()


func _build_cameras(state: GameState) -> void:
	var me := state.get_local_player()

	_seat_cam = Camera3D.new()
	# 横の見える幅を固定する(横長の画面でも、両どなりの後ろが見えないように)
	_seat_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_seat_cam.fov = GameConfig.SEAT_CAM_HFOV
	_seat_cam.near = 0.05
	# 自分の体のレイヤーを映さない
	_seat_cam.cull_mask = 0xFFFFF & ~(1 << (SELF_LAYER - 1)) & ~(1 << (HIDDEN_LAYER - 1))
	add_child(_seat_cam)
	_seat_cam.make_current()
	_update_seat_camera(state, 0.0)

	_top_cam = Camera3D.new()
	_top_cam.fov = 60
	add_child(_top_cam)
	_top_cam.look_at_from_position(Vector3(0, 13, 6), Vector3.ZERO)


## 今のカメラの向き(走る向きを画面に合わせるため、入力側が使う)
func get_camera_basis() -> Basis:
	var cam := get_viewport().get_camera_3d()
	return cam.global_basis if cam else Basis.IDENTITY


## 自分のカメラ:
## - 座っているとき: 前は輪の内側、振り向くと足元の後ろを見る
## - 追いかけているとき: 輪の外側・斜め上から自分を見る(画面の右が鬼の走る向き)
func _update_seat_camera(state: GameState, delta: float) -> void:
	var me := state.get_local_player()
	if me == null or _seat_cam == null:
		return
	# 座っているときは自分の体を映さない。立ち上がって追いかけるときは映す
	var self_bit := 1 << (SELF_LAYER - 1)
	if me.role != GameState.Role.SEATED:
		_seat_cam.cull_mask = 0xFFFFF
	else:
		_seat_cam.cull_mask = 0xFFFFF & ~self_bit & ~(1 << (HIDDEN_LAYER - 1))
	if me.role != GameState.Role.SEATED:
		var out := Vector3(me.position.x, 0.0, me.position.z).normalized()
		var want := me.position + out * GameConfig.CHASE_CAM_DISTANCE + Vector3(0, GameConfig.CHASE_CAM_HEIGHT, 0)
		# 立ち上がった直後は一気に、そのあとはなめらかに追う
		var w := 1.0 if delta == 0.0 else clampf(delta * 8.0, 0.0, 1.0)
		var from := _seat_cam.position
		if from.distance_to(want) > 6.0:
			w = 1.0
		_seat_cam.look_at_from_position(from.lerp(want, w), me.position + Vector3(0, 0.8, 0))
		return
	var t: float = _turn.get(me.id, 0.0)
	var back_dir := Vector3(sin(me.yaw), 0.0, cos(me.yaw))
	_seat_cam.position = me.position + Vector3(0, 1.45, 0) + back_dir * GameConfig.LOOK_BACK_LEAN * t
	var pitch := lerpf(GameConfig.SEAT_CAM_PITCH_FRONT, GameConfig.SEAT_CAM_PITCH_BACK, t)
	_seat_cam.rotation = Vector3(deg_to_rad(pitch), me.yaw + PI * t, 0.0)


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi
