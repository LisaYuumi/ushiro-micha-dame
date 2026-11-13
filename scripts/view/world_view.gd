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
## 鬼が自分の後ろに来たとき、自分の前の床に映る影
var _oni_shadow: MeshInstance3D
var _oni_shadow_mat: StandardMaterial3D
## 頭の上の名札(2D で重ねる)
var _overlay: HeadOverlay

## 教室の大きさと色
const ROOM_HALF := 8.0
const ROOM_HEIGHT := 4.4
const COLOR_WAINSCOT := Color("FFF4DC")
const COLOR_WOOD := Color("B67A45")
const COLOR_BOARD := Color("2F6B55")
const COLOR_GLASS := Color("CFF0FA")
const COLOR_CURTAIN := Color("F7A8B8")
const COLOR_CORK := Color("D4A06A")

## スタンプの色(仮)
const STAMP_COLORS := {
	Stamps.DROPPED: Color(0.95, 0.35, 0.2),
	Stamps.SAFE: Color(0.2, 0.7, 0.35),
	Stamps.FAKE: Color(0.95, 0.62, 0.1),
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
## お手つき3回で放心している人(そのラウンドの間)
var _dazed := {}
## 鬼が歩いているか立ち止まっているかを見分けるため(id -> 前の位置/止まっている時間)
var _last_pos := {}
var _still_time := {}


func build(state: GameState) -> void:
	for c in get_children():
		c.queue_free()
	_actor_nodes.clear()
	_turn.clear()
	_oops_until.clear()
	_surprise_until.clear()
	_was_looking.clear()
	_dazed.clear()
	_last_pos.clear()
	_still_time.clear()
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
	_build_oni_shadow()
	_build_sounds(state)
	_build_cameras(state)
	# 名札(送れない相手は薄く出る)
	_overlay = HeadOverlay.new()
	add_child(_overlay)
	_overlay.build(state, _actor_nodes, Profile.show_personality)
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
			node.rotation.y = a.yaw
			var model := node as CharacterModel
			if model:
				# 振り向いた姿は全員に見える(頭→上半身の順に後ろを向く)
				model.set_look(a.looking_back)
				model.set_pose(_pose_of(state, a))
			_update_expression(state, a, model, delta)
	_update_seat_camera(state, delta)
	if _overlay:
		_overlay.update(state, get_viewport().get_camera_3d())
	_update_bananas(state)
	_update_oni_shadow(state)
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


## 姿勢: 座っている人は座る、追いかけっこ中は走る、鬼は歩く(止まっていれば立つ)
func _pose_of(state: GameState, a: GameState.Actor) -> String:
	if a.role == GameState.Role.SEATED:
		return "sit"
	if state.phase == GameState.Phase.RESULT:
		return "idle"
	if state.phase == GameState.Phase.CHASE:
		return "run"
	# 鬼が歩いている: 前のフレームから動いていなければ、立ち止まっている
	var last: Vector3 = _last_pos.get(a.id, a.position)
	_last_pos[a.id] = a.position
	var moving := last.distance_to(a.position) > 0.0005
	if moving:
		_still_time[a.id] = 0.0
	else:
		_still_time[a.id] = _still_time.get(a.id, 0.0) + get_process_delta_time()
	return "walk" if _still_time[a.id] < 0.15 else "idle"


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
	# お手つきの回数で、顔がだんだん崩れていく(3回目は放心)
	var dazed := _dazed.has(a.id) or a.otetsuki_count >= GameConfig.OTETSUKI_DAZED_COUNT
	model.set_fluster(CharacterModel.FLUSTER_MAX if dazed else mini(a.otetsuki_count, 2))
	# 振り向いた瞬間にピョンと跳ねる
	if a.looking_back and not _was_looking.get(a.id, false):
		model.hop()
	_was_looking[a.id] = a.looking_back
	model.animate(delta, running and state.phase == GameState.Phase.CHASE)


## 落とし物の部品(箱)を1つ足す。見え方のルールで隠すため、部品は _handkerchief のすぐ下に置く
func _item_part(size: Vector3, pos: Vector3, color: Color, outline: float) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := Toon.mesh(box, color, outline)
	mi.position = pos
	_handkerchief.add_child(mi)


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
	env.background_color = GameConfig.COLOR_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# アニメ塗りの陰の向きを決める光。リアルな影は落とさない(見た目のためと、スマホで軽くするため)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = false
	add_child(sun)


## 教室: 黄色い床板、下が白っぽく上が水色の壁。黒板・時計・窓・ドア・掲示板・ロッカー。
## 全部アニメ塗り+黒い輪郭線(A案)
func _build_floor() -> void:
	var half := ROOM_HALF
	# 床(床板の継ぎ目つき)
	_part(Vector3(half * 2.0, 0.04, half * 2.0), Vector3(0, -0.02, 0), GameConfig.COLOR_FLOOR, 0.0)
	# 転んだ体が乗る床(物理演算用。見た目はない)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << (CharacterModel.FLOOR_LAYER - 1)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var seam := GameConfig.COLOR_FLOOR.darkened(0.12)
	for i in range(-int(half) + 1, int(half)):
		_part(Vector3(half * 2.0, 0.004, 0.035), Vector3(0, 0.002, i), seam, 0.0)
	# 4つの壁: 下は腰板(白っぽい)、上は水色。境目は黒い線
	for side in 4:
		var wall := Node3D.new()
		wall.rotation.y = side * PI / 2.0
		add_child(wall)
		_part(Vector3(half * 2.0, 1.1, 0.2), Vector3(0, 0.55, -half), COLOR_WAINSCOT, 0.03, wall)
		_part(Vector3(half * 2.0, ROOM_HEIGHT - 1.1, 0.2), Vector3(0, 1.1 + (ROOM_HEIGHT - 1.1) / 2.0, -half),
				GameConfig.COLOR_SKY, 0.03, wall)
		match side:
			0:
				_build_front_wall(wall, half)
			1:
				_build_window_wall(wall, half)
			2:
				_build_back_wall(wall, half)
			3:
				_build_door_wall(wall, half)


## 前: 黒板(チョークの文字つき)と時計
func _build_front_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	# 黒板は高めに(手前の人の名札と重なりにくいように)
	_part(Vector3(5.6, 1.7, 0.1), Vector3(0, 2.75, z), COLOR_WOOD, 0.03, wall)
	_part(Vector3(5.2, 1.35, 0.1), Vector3(0, 2.75, z + 0.04), COLOR_BOARD, 0.02, wall)
	_part(Vector3(5.2, 0.06, 0.18), Vector3(0, 2.05, z + 0.1), COLOR_WOOD, 0.02, wall)
	var chalk := Label3D.new()
	chalk.text = "うしろ見ちゃダメ!"
	chalk.font = HudFont.get_font()
	chalk.font_size = 120
	chalk.pixel_size = 0.006
	chalk.outline_size = 0
	chalk.modulate = Color(0.97, 0.97, 0.92)
	chalk.position = Vector3(0, 2.85, z + 0.1)
	wall.add_child(chalk)
	# 時計
	var face := CylinderMesh.new()
	face.top_radius = 0.38
	face.bottom_radius = 0.38
	face.height = 0.06
	var clock := Toon.mesh(face, GameConfig.COLOR_PAPER)
	clock.rotation.x = PI / 2.0
	clock.position = Vector3(3.6, 3.3, z + 0.02)
	wall.add_child(clock)
	_part(Vector3(0.04, 0.26, 0.02), Vector3(3.6, 3.4, z + 0.07), GameConfig.COLOR_INK, 0.0, wall)
	var minute := _part(Vector3(0.03, 0.32, 0.02), Vector3(3.7, 3.35, z + 0.08), GameConfig.COLOR_INK, 0.0, wall)
	minute.rotation.z = -1.0


## 横: 窓が3つ(水色のガラス、白い枠、ピンクのカーテン)
func _build_window_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	for x in [-4.5, 0.0, 4.5]:
		_part(Vector3(2.2, 1.9, 0.08), Vector3(x, 2.3, z), GameConfig.COLOR_PAPER, 0.03, wall)
		_part(Vector3(1.9, 1.6, 0.06), Vector3(x, 2.3, z + 0.03), COLOR_GLASS, 0.0, wall)
		_part(Vector3(0.06, 1.6, 0.08), Vector3(x, 2.3, z + 0.05), GameConfig.COLOR_PAPER, 0.015, wall)
		_part(Vector3(1.9, 0.06, 0.08), Vector3(x, 2.3, z + 0.05), GameConfig.COLOR_PAPER, 0.015, wall)
		for sx in [-1.25, 1.25]:
			_part(Vector3(0.35, 2.1, 0.08), Vector3(x + sx, 2.25, z + 0.08), COLOR_CURTAIN, 0.025, wall)


## 後ろ: ロッカー(ランドセルが入っている)
func _build_back_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.35
	_part(Vector3(7.2, 1.3, 0.5), Vector3(0, 0.65, z), COLOR_WOOD, 0.03, wall)
	var bags := [Color("D9483B"), Color("2E2B28"), Color("EF8FB0"), Color("4D96FF"), Color("7CC576")]
	for row in 2:
		for col in 8:
			var x := -3.15 + col * 0.9
			var y := 0.38 + row * 0.6
			_part(Vector3(0.78, 0.48, 0.05), Vector3(x, y, z + 0.26), COLOR_WOOD.darkened(0.35), 0.0, wall)
			if (row * 8 + col) % 3 != 1:
				_part(Vector3(0.4, 0.34, 0.2), Vector3(x, y - 0.02, z + 0.22),
						bags[(row * 3 + col) % bags.size()], 0.02, wall)


## もう1つの横: ドアと掲示板(貼り紙つき)
func _build_door_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	_part(Vector3(1.3, 2.3, 0.08), Vector3(-4.5, 1.15, z), COLOR_WOOD, 0.03, wall)
	_part(Vector3(0.5, 0.6, 0.06), Vector3(-4.5, 1.65, z + 0.04), COLOR_GLASS, 0.015, wall)
	_part(Vector3(3.2, 1.3, 0.08), Vector3(1.5, 2.0, z), COLOR_CORK, 0.03, wall)
	var papers := [GameConfig.COLOR_PAPER, Color("FCE7A5"), Color("F7C4CF"), Color("CDEBFF")]
	for i in 5:
		var p := _part(Vector3(0.5, 0.65, 0.03), Vector3(0.3 + i * 0.6, 2.0 + (0.12 if i % 2 == 0 else -0.1), z + 0.06),
				papers[i % papers.size()], 0.012, wall)
		p.rotation.z = 0.06 if i % 2 == 0 else -0.05


## 箱の部品を1つ置く(outline: 輪郭線の太さ。0 なら線なし)
func _part(size: Vector3, pos: Vector3, color: Color, outline: float = GameConfig.OUTLINE_WIDTH, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := Toon.mesh(box, color, outline)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


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
	# ボットの性格は、⚙メニューでオンにしたときだけ名前の横に出す
	var shown_name := a.display_name if Profile.show_personality else a.display_name.get_slice("(", 0)
	model.build(a.color, shown_name, HudFont.get_font())
	if is_self:
		# 自分の体は、座っているときの自分のカメラには映さない。自分の名前は出さない
		model.set_layers(1 << (SELF_LAYER - 1))
		model.set_name_visible(false)
	return model


func _build_oni_shadow() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.35
	disc.height = 0.005
	_oni_shadow_mat = StandardMaterial3D.new()
	_oni_shadow_mat.albedo_color = Color(0, 0, 0, 0)
	_oni_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_oni_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_oni_shadow = MeshInstance3D.new()
	_oni_shadow.mesh = disc
	_oni_shadow.material_override = _oni_shadow_mat
	_oni_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_oni_shadow.visible = false
	add_child(_oni_shadow)


## 鬼の影: 座っている自分の後ろに鬼が近づくと、自分の前の床に影がのびる。
## 近いほど濃く大きい。鬼が立ち止まれば影も止まる(後ろが見えなくても気配がわかる)
func _update_oni_shadow(state: GameState) -> void:
	var me := state.get_local_player()
	var oni := state.get_actor(state.oni_id)
	if me == null or oni == null or me.role != GameState.Role.SEATED or state.phase == GameState.Phase.RESULT:
		_oni_shadow.visible = false
		return
	var back := Vector3(sin(me.yaw), 0.0, cos(me.yaw))
	var right := Vector3(cos(me.yaw), 0.0, -sin(me.yaw))
	var rel := oni.position - me.position
	rel.y = 0.0
	var behind := rel.dot(back)
	var dist := rel.length()
	if behind <= 0.0 or dist > GameConfig.ONI_SHADOW_RANGE:
		_oni_shadow.visible = false
		return
	var near := 1.0 - dist / GameConfig.ONI_SHADOW_RANGE
	_oni_shadow.visible = true
	# 自分の前(輪の内側)の床に、鬼の左右の位置に合わせて映す
	_oni_shadow.position = me.position - back * (0.9 + 0.5 * near) + right * rel.dot(right) * 0.5 + Vector3(0, 0.006, 0)
	_oni_shadow.rotation.y = me.yaw
	_oni_shadow.scale = Vector3(0.8 + 0.5 * near, 1.0, 1.6 + 1.4 * near)
	_oni_shadow_mat.albedo_color = Color(0, 0, 0, GameConfig.ONI_SHADOW_ALPHA * near)


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


## 座っている自分から見えない席(両どなり)の後ろに落ちた物は、自分の席のカメラに映さない。
## (上から見る確認用カメラには映る)
func _hide_item_if_not_visible_to_me(state: GameState) -> void:
	var me := state.get_local_player()
	# 手下は両どなりの後ろも見える(GameState.sees_behind)
	var hidden := state.handkerchief_on_floor and me.role == GameState.Role.SEATED \
			and state.drop_target_seat != me.seat_index \
			and not state.sees_behind(me.id, state.drop_target_seat)
	var bits := 1 << (HIDDEN_LAYER - 1) if hidden else 1
	for c in _handkerchief.get_children():
		if c is VisualInstance3D:
			c.layers = bits


## 落とし物の仮の形(大きさ・色)。ラウンドごとに重くなる
const ITEM_SHAPES := [
	[Vector3(0.55, 0.04, 0.55), Color("EE5A4B")],       # ハンカチ(赤いチェックに白いふち。_build_item_parts)
	[Vector3(0.2, 0.16, 0.42), Color(1, 1, 1)],         # 上履き(白に青いつま先とバンド)
	[Vector3(0.36, 0.4, 0.22), Color(0.8, 0.15, 0.15)],  # ランドセル
	[Vector3(0.6, 0.7, 0.45), Color(0.65, 0.45, 0.25)],  # 机
	[Vector3(0.9, 1.0, 0.5), Color(0.4, 0.25, 0.15)],    # 教卓
]
var _item_carry_height := 1.0


## 落とし物の輪郭線(床の上で目立つように、ふつうより太く)
const ITEM_OUTLINE := 0.04
const COLOR_HANKIE := Color("EE5A4B")
const COLOR_SHOE_RUBBER := Color("3F86F0")


func _build_handkerchief(state: GameState) -> void:
	var index := clampi(state.round_index, 0, ITEM_SHAPES.size() - 1)
	var shape: Array = ITEM_SHAPES[index]
	var size: Vector3 = shape[0]
	_handkerchief = Node3D.new()
	# 床に置いたとき、底が床につくように。ハンカチと上履きは小さいので、色と形で目立たせる
	match index:
		0:
			# ハンカチ: 白いふち+赤い地+白いチェックの線(スタンプの絵と同じ)
			_item_part(Vector3(0.55, 0.03, 0.55), Vector3(0, 0.015, 0), Color.WHITE, ITEM_OUTLINE)
			_item_part(Vector3(0.44, 0.01, 0.44), Vector3(0, 0.033, 0), COLOR_HANKIE, 0.0)
			for k in [-0.11, 0.11]:
				_item_part(Vector3(0.44, 0.006, 0.05), Vector3(0, 0.04, k), Color.WHITE, 0.0)
				_item_part(Vector3(0.05, 0.006, 0.44), Vector3(k, 0.041, 0), Color.WHITE, 0.0)
		1:
			# 上履き: 白い本体、赤い底、青いつま先のゴムと甲のバンド(スタンプの絵と同じ)
			_item_part(Vector3(0.21, 0.03, 0.43), Vector3(0, 0.015, 0), Color("D9483B"), ITEM_OUTLINE)
			_item_part(Vector3(0.2, 0.13, 0.42), Vector3(0, 0.095, 0), Color.WHITE, ITEM_OUTLINE)
			_item_part(Vector3(0.215, 0.11, 0.14), Vector3(0, 0.085, -0.15), COLOR_SHOE_RUBBER, 0.0)
			_item_part(Vector3(0.215, 0.04, 0.07), Vector3(0, 0.15, 0.02), COLOR_SHOE_RUBBER, 0.0)
		_:
			_item_part(size, Vector3(0, size.y / 2.0, 0), shape[1], ITEM_OUTLINE)
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
## 確認用: 全員を転ばせる(K キー)
func debug_slip_all() -> void:
	for id in _actor_nodes:
		var m := _actor_nodes[id] as CharacterModel
		if m:
			m.slip()


## スタンプを送る相手(いまは頭の上の選択肢で示すので、3D の目印は出さない)
func set_stamp_target(_state: GameState, _id: int) -> void:
	pass


## 頭の上の名札とスタンプ(2D)
func get_overlay() -> HeadOverlay:
	return _overlay


## 撮影モードから戻ったとき: 席のカメラに戻し、名札をまた出す
func set_shown(v: bool) -> void:
	visible = v
	if _overlay:
		_overlay.visible = v
	if v and _seat_cam:
		_seat_cam.make_current()


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
	_seat_cam.fov = GameConfig.SEAT_CAM_HFOV if state.seat_count > 5 else GameConfig.SEAT_CAM_HFOV_SMALL
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
		var is_oni := me.role == GameState.Role.ONI
		var dist := GameConfig.ONI_CAM_DISTANCE if is_oni else GameConfig.CHASE_CAM_DISTANCE
		var height := GameConfig.ONI_CAM_HEIGHT if is_oni else GameConfig.CHASE_CAM_HEIGHT
		var want := me.position + out * dist + Vector3(0, height, 0)
		# 立ち上がった直後は一気に、そのあとはなめらかに追う
		var w := 1.0 if delta == 0.0 else clampf(delta * 8.0, 0.0, 1.0)
		var from := _seat_cam.position
		if from.distance_to(want) > 6.0:
			w = 1.0
		var look_h := GameConfig.ONI_CAM_LOOK_HEIGHT if is_oni else 0.8
		_seat_cam.look_at_from_position(from.lerp(want, w), me.position + Vector3(0, look_h, 0))
		return
	var t: float = _turn.get(me.id, 0.0)
	var back_dir := Vector3(sin(me.yaw), 0.0, cos(me.yaw))
	# 前を向いているときは少し後ろ・上から、振り向くと頭の位置から後ろをのぞきこむ
	var back := lerpf(GameConfig.SEAT_CAM_BACK, GameConfig.LOOK_BACK_LEAN, t)
	var height := lerpf(GameConfig.SEAT_CAM_HEIGHT, GameConfig.SEAT_CAM_HEIGHT_BACK, t)
	_seat_cam.position = me.position + Vector3(0, height, 0) + back_dir * back
	var pitch := lerpf(GameConfig.SEAT_CAM_PITCH_FRONT, GameConfig.SEAT_CAM_PITCH_BACK, t)
	_seat_cam.rotation = Vector3(deg_to_rad(pitch), me.yaw + PI * t, 0.0)


## アニメ塗り+黒い輪郭線(Toon)の見た目
func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	return Toon.mesh(mesh, color)
