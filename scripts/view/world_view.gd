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
## 席のカメラの、ふだんの横の見える幅(お手つきで抜けて上から見ている間は変える)
var _seat_fov := 100.0
var _top_cam: Camera3D
var _handkerchief: Node3D
## 音: 落とし物(本物もフェイクも同じ音)・鬼の足音・追いかける人の足音・場所のある効果音・スタンプ・環境音
var _drop_player: AudioStreamPlayer3D
var _step_player: AudioStreamPlayer3D
var _chaser_step_player: AudioStreamPlayer3D
var _fx3d: Array[AudioStreamPlayer3D] = []
var _fx3d_next := 0
var _beep_player: AudioStreamPlayer
var _stamp_player: AudioStreamPlayer
var _amb_player: AudioStreamPlayer
var _clock_player: AudioStreamPlayer3D
var _curtain_player: AudioStreamPlayer3D
var _curtain_left := 8.0
var _clock_left := 0.0
## 時計とカーテン(環境音を鳴らす場所)
var _clock_node: Node3D
var _curtain_node: Node3D
var _chaser_last_pos := Vector3.ZERO
var _chaser_walked := 0.0
## 牛乳がかかった人の頭の上の白い牛乳(id -> Node3D)
var _milk_nodes := {}
## 鬼が牛乳の相手を選んでいる間、かけられる人の足もとに出す青い点線の丸(人ごと)
var _milk_rings := {}
var _milk_aim := false
## スタンプを送る相手の足もとの、光る丸
var _stamp_ring: Node3D
const STAMP_RING_COLOR := Color("FFC93C")
## 床のバナナの皮の見た目(状態の bananas と同じ数だけ出す)
## 追いかけっこのコースの障害物(とバナナの皮)の見た目(障害物の id -> Node3D)
var _obstacle_nodes := {}
## 鬼が自分の後ろに来たとき、自分の前の床に映る影
var _oni_shadow: MeshInstance3D
var _oni_shadow_mat: StandardMaterial3D
## 頭の上の名札(2D で重ねる)
var _overlay: HeadOverlay
## 停電イベントの暗い幕
var _blackout: BlackoutLayer
## 教室を作っている間だけ使う、背景の箱のまとめ役
var _batch: StaticBatch
## 教室を作るときに見る状態(ラウンドで変わる黒板の落書き・時計・日直)
var _room_state: GameState
## 足もとのぼんやりした丸い影(id -> MeshInstance3D)と、その材質
var _blobs := {}
static var _blob_mat: StandardMaterial3D
## 走る人の土ぼこりを出すまでの時間(id -> 秒)
var _dust_left := {}

## 教室の大きさと色
const ROOM_HALF := 8.0
const ROOM_HEIGHT := 4.4
const COLOR_WAINSCOT := Color("FFF4DC")
const COLOR_WOOD := Color("B67A45")
const COLOR_BOARD := Color("2F6B55")
const COLOR_GLASS := Color("CFF0FA")
const COLOR_CURTAIN := Color("E9B3BE")
const COLOR_CORK := Color("D4A06A")
## 下げた机と椅子(背景なので、キャラより落ち着いた色)
const COLOR_DESK_TOP := Color("E2CDA6")
const COLOR_DESK_BOX := Color("9AA3AD")
const COLOR_METAL := Color("8E8E94")
const COLOR_CHAIR := Color("C9A16E")
## 壁と天井
const COLOR_BASEBOARD := Color("8B6240")
const COLOR_PILLAR := Color("F1E7D3")
const COLOR_CEILING := Color("F3F0E6")
const COLOR_LAMP_FRAME := Color("DADADF")
const COLOR_LAMP := Color("FFFFF4")
## 天井を置くレイヤー(上から見る確認用カメラには映さない)
const CEILING_LAYER := 4
## 窓の外と小物
const COLOR_FIELD := Color("9CC98A")
const COLOR_GROUND := Color("D9C08F")
const COLOR_TRUNK := Color("8B6240")
const COLOR_TREE := Color("6FAE6A")
const COLOR_POT := Color("C9764F")
const COLOR_LEAF := Color("72A866")
const COLOR_FLOWER := Color("F09AB0")
const COLOR_STEEL := Color("A9B2BA")
const COLOR_PAPER_SOFT := Color("FBF8EF")

## スタンプの色: 落ちてる!(赤)・まだへいき!(緑)・信じて!(紫)
const STAMP_COLORS := {
	Stamps.DROPPED: Color("E5483B"),
	Stamps.SAFE: Color("3AAE5C"),
	Stamps.TRUST: Color("9B5DE5"),
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
	_clock_node = null
	_curtain_node = null
	_turn.clear()
	_oops_until.clear()
	_surprise_until.clear()
	_was_looking.clear()
	_dazed.clear()
	_blobs.clear()
	_dust_left.clear()
	_last_pos.clear()
	_still_time.clear()
	_obstacle_nodes.clear()
	_milk_nodes.clear()

	_build_environment()
	_room_state = state
	_build_floor()
	for i in state.seat_positions.size():
		_build_chair(state.seat_positions[i], state.seat_yaws[i])
	for a in state.actors:
		var node := _build_character(a, a.id == state.local_player_id)
		add_child(node)
		_actor_nodes[a.id] = node
		var blob := _make_blob(Vector2(0.95, 0.95))
		add_child(blob)
		_blobs[a.id] = blob
		var milk := _build_milk_splash()
		if a.id == state.local_player_id:
			# 自分の頭の牛乳は、座っているときの自分のカメラには映さない(画面が白くなるので)
			for c in milk.get_children():
				(c as VisualInstance3D).layers = 1 << (SELF_LAYER - 1)
		add_child(milk)
		_milk_nodes[a.id] = milk
	_build_handkerchief(state)
	_build_oni_shadow()
	_milk_rings.clear()
	_stamp_ring = null
	_build_sounds(state)
	_build_cameras(state)
	# 名札(送れない相手は薄く出る)
	_blackout = BlackoutLayer.new()
	add_child(_blackout)
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
			var blob: MeshInstance3D = _blobs.get(a.id)
			if blob:
				blob.position = Vector3(a.position.x, 0.03, a.position.z)
			_update_dust(a, delta)
			var model := node as CharacterModel
			if model:
				# 振り向いた姿は全員に見える(頭→上半身の順に後ろを向く)
				model.set_look(a.looking_back)
				model.set_pose(_pose_of(state, a))
				# 鬼だけが学校の黄色い帽子をかぶる
				model.set_hat(a.id == state.oni_id)
			_update_expression(state, a, model, delta)
			_update_milk(state, a, model)
	_update_seat_camera(state, delta)
	if _overlay:
		_overlay.update(state, get_viewport().get_camera_3d())
	if _blackout:
		# 座っている自分の目は、自分のカメラのすぐ前にあるので描かない
		var me := state.get_local_player()
		var skip := me.id if me != null and me.role == GameState.Role.SEATED else -1
		_blackout.update(state, get_viewport().get_camera_3d(), _actor_nodes, delta, skip)
	_update_obstacles(state)
	_update_oni_shadow(state)
	_update_milk_ring(state, delta)
	_clock += delta

	var holder := state.get_actor(state.chaser_id)
	if holder:
		# 追いかける人が持って走る: ハンカチ・上履きは右手に、大きい物は背中に背負う
		_handkerchief.visible = true
		_carry_item(_actor_nodes.get(holder.id) as CharacterModel)
	else:
		# 停電中は、落とし物はだれにも見えない(誰の後ろに落ちたか、みんなわからなくなる)。落とした鬼だけは見える
		var dark_hide := state.blackout and state.local_player_id != state.oni_id
		_handkerchief.visible = state.handkerchief_on_floor and not dark_hide
		_handkerchief.transform = Transform3D(Basis.IDENTITY, state.handkerchief_position)
	_hide_item_if_not_visible_to_me(state)
	_update_footsteps(state)
	_update_ambience(delta)


## 姿勢: 座っている人は座る、追いかけっこ中は走る、鬼は歩く(止まっていれば立つ)
func _pose_of(state: GameState, a: GameState.Actor) -> String:
	if a.role == GameState.Role.SEATED:
		return "sit"
	if a.role == GameState.Role.OUT:
		# お手つきで抜けた人は、真ん中で体育座り
		return "floor"
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
		# 振り向く「バッ!」(自分は大きく、ほかの人はその場所から小さく)
		_play_at(a, "look", -2.0 if a.id == state.local_player_id else -12.0)
	_was_looking[a.id] = a.looking_back
	model.animate(delta, running and state.phase == GameState.Phase.CHASE)


## 落とし物の部品(箱)を1つ足す。見え方のルールで隠すため、部品は _handkerchief のすぐ下に置く
func _item_part(size: Vector3, pos: Vector3, color: Color, outline: float, bevel: float = 0.0) -> void:
	var mesh: Mesh
	if bevel > 0.0:
		mesh = StaticBatch.chamfer_mesh(size, bevel)
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	var mi := Toon.mesh(mesh, color, outline)
	mi.position = pos
	_handkerchief.add_child(mi)


## 足もとのぼんやりした丸い影(まん中が濃く、外にいくほど薄い)
func _make_blob(size: Vector2) -> MeshInstance3D:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = tex
		_blob_mat.albedo_color = Color(1, 1, 1, 0.3)
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 走っている人の足もとに、ときどき土ぼこり(ふくらんで、しぼんで消える)
func _update_dust(a: GameState.Actor, delta: float) -> void:
	var running: bool = a.role == GameState.Role.CHASER or (a.role == GameState.Role.ONI and _room_state != null \
			and _room_state.phase == GameState.Phase.CHASE)
	if not running or a.slip_left > 0.0:
		return
	_dust_left[a.id] = _dust_left.get(a.id, 0.0) - delta
	if _dust_left[a.id] > 0.0:
		return
	_dust_left[a.id] = 0.12
	var puff := Toon.mesh(_dust_mesh(), Color("EFE5D0"), 0.0)
	puff.position = a.position + Vector3(randf_range(-0.15, 0.15), 0.08, randf_range(-0.15, 0.15))
	puff.scale = Vector3.ONE * 0.4
	add_child(puff)
	var tw := puff.create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * 1.2, 0.18)
	tw.parallel().tween_property(puff, "position:y", puff.position.y + 0.12, 0.4)
	tw.tween_property(puff, "scale", Vector3.ZERO, 0.22)
	tw.tween_callback(puff.queue_free)


static var _dust_sphere: SphereMesh


static func _dust_mesh() -> SphereMesh:
	if _dust_sphere == null:
		_dust_sphere = SphereMesh.new()
		_dust_sphere.radius = 0.08
		_dust_sphere.height = 0.16
		_dust_sphere.radial_segments = 8
		_dust_sphere.rings = 4
	return _dust_sphere


## 頭の上に「!」「?」「★」がポンと出て、上に上がって消える
func _pop(actor_id: int, text: String, color: Color) -> void:
	var m := _actor_nodes.get(actor_id) as CharacterModel
	if m == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font = HudFont.get_font()
	l.font_size = 140
	l.pixel_size = 0.006
	l.outline_size = 24
	l.outline_modulate = GameConfig.COLOR_INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	l.position = m.tag_anchor() + Vector3(0, 0.35, 0)
	l.scale = Vector3.ONE * 0.2
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.25, 0.12)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.tween_property(l, "position:y", l.position.y + 0.25, 0.55)
	tw.tween_property(l, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(l.queue_free)


## GameState からのお知らせに合わせて音などを出す。
func on_event(e: Dictionary) -> void:
	match e.get("type"):
		"otetsuki":
			_oops_until[e["actor"]] = _clock + 1.5
			_play_actor(e["actor"], "oops", -4.0, -14.0)
			_pop(e["actor"], "?", Color("6EA8F0"))
		"stamp":
			# スタンプが届いた人は、びっくり顔になる
			_surprise_until[e["target"]] = _clock + 1.0
		"picked_up":
			var m := _actor_nodes.get(e["actor"]) as CharacterModel
			if m:
				m.hop()
			_pop(e["actor"], "!", GameConfig.COLOR_ACCENT)
			_play_actor(e["actor"], "pickup", -3.0, -8.0)
		"slip":
			var m := _actor_nodes.get(e["actor"]) as CharacterModel
			if m:
				m.slip()
			_pop(e["actor"], "★", Color("F2C14E"))
			_oops_until[e["actor"]] = _clock + GameConfig.SLIP_TIME
			# バナナは「つるっ」、障害物は「ずでーん」
			_play_actor(e["actor"], "banana" if e.get("kind", "") == "banana" else "fall", -2.0, -6.0)
		"blackout":
			AudioDirector.sfx("power_off", -2.0)
		"lights_on":
			AudioDirector.sfx("power_on", -3.0)
		"out":
			_pop(e["actor"], tr("お手つき!"), Color("6EA8F0"))
			# 体育座りに移る「とぼとぼ」(「シーン…」のあと)
			var who: int = e["actor"]
			get_tree().create_timer(1.1).timeout.connect(func() -> void: _play_actor(who, "trudge", -6.0, -16.0))
		"milk":
			_surprise_until[e["target"]] = _clock + 1.2
			_pop(e["target"], tr("ばしゃっ"), Color.WHITE)
		"dropped", "rustle":
			# 本物もフェイクも、まったく同じ音(落とし物ごとの音。同じ大きさ・同じゆらぎ)。
			# 落とした場所から聞こえる(後ろの左右どちらで鳴ったかわかる)。重い物ほど大きく、遠くまで聞こえる
			var w: float = e.get("weight", 0.0)
			_drop_player.position = e["pos"]
			_drop_player.volume_db = lerpf(GameConfig.DROP_VOLUME_DB, GameConfig.DROP_VOLUME_DB_HEAVY, w)
			_drop_player.unit_size = lerpf(GameConfig.DROP_SOUND_RANGE, GameConfig.DROP_SOUND_RANGE_HEAVY, w)
			_drop_player.pitch_scale = randf_range(0.94, 1.06)
			_drop_player.play()



## 足音: 歩く鬼は小さく「トッ、トッ」(鬼の体から聞こえる)。追いかけっこ中は、鬼も追いかける人も速い足音
func _update_footsteps(state: GameState) -> void:
	var oni := state.get_actor(state.oni_id)
	if oni == null:
		return
	var running := state.phase == GameState.Phase.CHASE
	var stride := GameConfig.RUN_STRIDE if running else GameConfig.FOOTSTEP_STRIDE
	var want_stream := Sfx.get_stream("run_step" if running else "step")
	if _step_player.stream != want_stream:
		_step_player.stream = want_stream
		_step_player.volume_db = GameConfig.RUN_STEP_VOLUME_DB if running else GameConfig.FOOTSTEP_VOLUME_DB
	_oni_walked += oni.position.distance_to(_oni_last_pos)
	_oni_last_pos = oni.position
	if _oni_walked >= stride:
		_oni_walked = 0.0
		_step_player.pitch_scale = randf_range(0.88, 1.12)
		_step_player.play()
	var chaser := state.get_actor(state.chaser_id)
	if chaser == null or not running:
		_chaser_walked = 0.0
		return
	_chaser_step_player.global_position = chaser.position + Vector3(0, 0.1, 0)
	_chaser_walked += chaser.position.distance_to(_chaser_last_pos) if _chaser_last_pos != Vector3.ZERO else 0.0
	_chaser_last_pos = chaser.position
	if _chaser_walked >= GameConfig.RUN_STRIDE:
		_chaser_walked = 0.0
		_chaser_step_player.pitch_scale = randf_range(0.95, 1.2)
		_chaser_step_player.play()


## 人のいる場所で効果音を鳴らす(自分なら大きく聞こえるように、自分の頭の位置で)
func _play_actor(actor_id: int, sound_name: String, self_db: float, other_db: float) -> void:
	if _room_state == null:
		return
	var a := _room_state.get_actor(actor_id)
	if a == null:
		return
	_play_at(a, sound_name, self_db if actor_id == _room_state.local_player_id else other_db)


func _play_at(a: GameState.Actor, sound_name: String, vol_db: float) -> void:
	if _fx3d.is_empty():
		return
	var p := _fx3d[_fx3d_next]
	_fx3d_next = (_fx3d_next + 1) % _fx3d.size()
	p.stream = Sfx.get_stream(sound_name)
	p.volume_db = vol_db
	p.pitch_scale = randf_range(0.96, 1.04)
	var cam := get_viewport().get_camera_3d()
	# 自分の音は、カメラ(自分の耳)のすぐそばで鳴らす
	if a.id == _room_state.local_player_id and cam:
		p.global_position = cam.global_position
	else:
		p.global_position = a.position + Vector3(0, 1.0, 0)
	p.play()


## 環境音: 遠くの校庭のざわめき(ずっと小さく)、時計のカチコチ(時計から)、ときどきカーテンの音(窓から)
func _update_ambience(delta: float) -> void:
	if _curtain_player == null:
		return
	# 時計のカチ・コチ(2秒の音を、2秒ごとに鳴らす。ずっと流しっぱなしにしないので軽い)
	_clock_left -= delta
	if _clock_left <= 0.0:
		_clock_left = 2.0
		_clock_player.play()
	_curtain_left -= delta
	if _curtain_left <= 0.0:
		_curtain_left = randf_range(9.0, 20.0)
		_curtain_player.pitch_scale = randf_range(0.9, 1.1)
		_curtain_player.play()


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
	_batch = StaticBatch.new()
	# 床: 下地+少しずつ色のちがう床板(継ぎ目をずらして並べる)
	_part(Vector3(half * 2.0, 0.04, half * 2.0), Vector3(0, -0.02, 0), GameConfig.COLOR_FLOOR.darkened(0.12), 0.0)
	_build_floor_planks(half)
	# 転んだ体が乗る床(物理演算用。見た目はない)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << (CharacterModel.FLOOR_LAYER - 1)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_build_ceiling(half)
	_build_window_light()
	# 4つの壁: 下は腰板(白っぽい)、上は水色。境目は黒い線
	for side in 4:
		var wall := Node3D.new()
		wall.rotation.y = side * PI / 2.0
		add_child(wall)
		_part(Vector3(half * 2.0, 1.1, 0.2), Vector3(0, 0.55, -half), COLOR_WAINSCOT, 0.03, wall)
		_part(Vector3(half * 2.0, ROOM_HEIGHT - 1.1, 0.2), Vector3(0, 1.1 + (ROOM_HEIGHT - 1.1) / 2.0, -half),
				GameConfig.COLOR_SKY, 0.03, wall)
		# 幅木(壁の下の帯)と、腰板の上の手すり
		_part(Vector3(half * 2.0, 0.14, 0.06), Vector3(0, 0.07, -half + 0.13), COLOR_BASEBOARD, 0.02, wall)
		_part(Vector3(half * 2.0, 0.06, 0.07), Vector3(0, 1.12, -half + 0.13), COLOR_WOOD, 0.02, wall)
		# 角の柱
		_part(Vector3(0.32, ROOM_HEIGHT, 0.32), Vector3(-half + 0.14, ROOM_HEIGHT / 2.0, -half + 0.14), COLOR_PILLAR, 0.03, wall)
		match side:
			0:
				_build_front_wall(wall, half)
			1:
				_build_window_wall(wall, half)
			2:
				_build_back_wall(wall, half)
			3:
				_build_door_wall(wall, half)
	_build_stacked_desks()
	for side in [-1.0, 1.0]:
		var db := _make_blob(Vector2(3.4, 2.0))
		db.position = Vector3(side * 6.17, 0.026, 7.05)
		add_child(db)
	# 色ごとにまとめた背景を置く
	_batch.build(self)
	_batch = null


## 床板: 0.4 m 幅の板を、長さと継ぎ目をずらして並べる。色は3段階で少しずつちがう
func _build_floor_planks(half: float) -> void:
	var tones := [GameConfig.COLOR_FLOOR, GameConfig.COLOR_FLOOR.lightened(0.05), GameConfig.COLOR_FLOOR.darkened(0.05)]
	var width := 0.4
	var rows := int(half * 2.0 / width)
	for r in rows:
		var z := -half + width * (r + 0.5)
		var x := -half - float((r * 7) % 5) * 0.55
		var k := r
		while x < half:
			var length := 2.4 + float((k * 13) % 4) * 0.4
			var x0 := maxf(x, -half)
			var x1 := minf(x + length, half)
			if x1 - x0 > 0.05:
				_part(Vector3(x1 - x0 - 0.03, 0.02, width - 0.03), Vector3((x0 + x1) / 2.0, 0.01, z), tones[k % tones.size()], 0.0)
			x += length
			k += 1


## 天井と蛍光灯(上から見る確認用カメラには映さない)
func _build_ceiling(half: float) -> void:
	var ceiling := Node3D.new()
	add_child(ceiling)
	var b := StaticBatch.new()
	b.add_box(Vector3(half * 2.0, 0.1, half * 2.0), Transform3D(Basis.IDENTITY, Vector3(0, ROOM_HEIGHT + 0.05, 0)), COLOR_CEILING, 0.0)
	for x in [-3.6, 0.0, 3.6]:
		for z in [-3.2, 3.2]:
			b.add_box(Vector3(1.6, 0.08, 0.36), Transform3D(Basis.IDENTITY, Vector3(x, ROOM_HEIGHT - 0.04, z)), COLOR_LAMP_FRAME, 0.02)
			b.add_box(Vector3(1.4, 0.05, 0.16), Transform3D(Basis.IDENTITY, Vector3(x, ROOM_HEIGHT - 0.09, z)), COLOR_LAMP, 0.0)
	b.build(ceiling)
	for c in ceiling.get_children():
		(c as VisualInstance3D).layers = 1 << (CEILING_LAYER - 1)


## 窓から床に差しこむ日差し(半透明の帯。光の計算はしない)
func _build_window_light() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.98, 0.82, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for z in [-4.5, 0.0, 4.5]:
		var quad := PlaneMesh.new()
		quad.size = Vector2(3.2, 1.7)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 窓の壁(x = -8)から内側へ、斜めにのびる
		mi.position = Vector3(-ROOM_HALF + 1.7, 0.025, z + 0.5)
		mi.rotation.y = deg_to_rad(-18.0)
		add_child(mi)


## 後ろの壁際に寄せて積んだ机と椅子(ハンカチ落としの場所を作るために机を下げた様子)。
## ロッカーの左右に、机をくっつけて並べ、椅子は机の上に逆さに乗せる
func _build_stacked_desks() -> void:
	for side in [-1.0, 1.0]:
		for col in 5:
			for row in 3:
				var x: float = side * (5.0 + col * 0.58)
				var z := 7.55 - row * 0.5
				var tilt := deg_to_rad(((col * 7 + row * 3) % 5 - 2) * 1.5)
				_school_desk(Vector3(x, 0, z), tilt)


## (下げた机の下のぼんやりした影は _build_floor の最後で置く)


## 学校の机(天板・物入れ・脚)と、その上に逆さに乗せた椅子
func _school_desk(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var put := func(size: Vector3, local: Vector3, color: Color, outline: float) -> void:
		_batch.add_box(size, Transform3D(b, at + b * local), color, outline)
	put.call(Vector3(0.62, 0.035, 0.46), Vector3(0, 0.7, 0), COLOR_DESK_TOP, 0.022)
	put.call(Vector3(0.56, 0.12, 0.36), Vector3(0, 0.61, 0.02), COLOR_DESK_BOX, 0.016)
	for lx in [-0.27, 0.27]:
		for lz in [-0.19, 0.19]:
			put.call(Vector3(0.03, 0.68, 0.03), Vector3(lx, 0.34, lz), COLOR_METAL, 0.0)
	# 逆さの椅子: 座面が机の上、脚は上向き、背もたれは机の奥へ垂れる
	put.call(Vector3(0.4, 0.03, 0.38), Vector3(0, 0.735, -0.02), COLOR_CHAIR, 0.018)
	put.call(Vector3(0.4, 0.28, 0.03), Vector3(0, 0.6, 0.2), COLOR_CHAIR, 0.016)
	for lx in [-0.17, 0.17]:
		for lz in [-0.17, 0.13]:
			put.call(Vector3(0.025, 0.4, 0.025), Vector3(lx, 0.95, lz - 0.02), COLOR_METAL, 0.0)


## 前: 黒板(チョークの文字つき)と時計
func _build_front_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	# 黒板は高めに(手前の人の名札と重なりにくいように)。文字が収まるように横に広く
	_part(Vector3(7.4, 1.9, 0.1), Vector3(0, 2.8, z), COLOR_WOOD, 0.03, wall)
	_part(Vector3(7.0, 1.55, 0.1), Vector3(0, 2.8, z + 0.04), COLOR_BOARD, 0.02, wall)
	_part(Vector3(7.0, 0.06, 0.18), Vector3(0, 2.0, z + 0.1), COLOR_WOOD, 0.02, wall)
	# チョークの文字: 少し黄みがかった白で、少し透けて、手書きっぽく傾ける
	var chalk_color := Color(0.98, 0.97, 0.88, 0.82)
	var chalk := Label3D.new()
	chalk.text = tr("うしろ見ちゃダメ!")
	chalk.font = HudFont.get_chalk_font()
	chalk.font_size = 104
	chalk.pixel_size = 0.0058
	chalk.outline_size = 6
	chalk.outline_modulate = Color(0.98, 0.97, 0.88, 0.18)
	chalk.modulate = chalk_color
	chalk.shaded = false
	chalk.position = Vector3(-0.1, 2.92, z + 0.1)
	chalk.rotation.z = deg_to_rad(2.5)
	wall.add_child(chalk)
	# チョークの落書き: 文字の下の波線と、すみの星
	for i in 9:
		_part(Vector3(0.52, 0.035, 0.01), Vector3(-2.1 + i * 0.5, 2.35 + (0.04 if i % 2 == 0 else -0.04), z + 0.1),
				Color(0.98, 0.97, 0.88), 0.0, wall, Vector3(0, 0, 0.18 if i % 2 == 0 else -0.18))
	for k in 3:
		_part(Vector3(0.42, 0.035, 0.01), Vector3(-3.15, 3.35, z + 0.1), Color(0.98, 0.97, 0.88), 0.0, wall, Vector3(0, 0, k * PI / 3.0))
	# 時計
	var face := CylinderMesh.new()
	face.top_radius = 0.38
	face.bottom_radius = 0.38
	face.height = 0.06
	var clock := Toon.mesh(face, GameConfig.COLOR_PAPER)
	clock.rotation.x = PI / 2.0
	clock.position = Vector3(4.6, 3.35, z + 0.02)
	wall.add_child(clock)
	_clock_node = clock
	_build_front_extras(wall, half, z)


## 前の壁の小物: 時計の針(試合が進むと進む)・日付と日直・黒板の落書き(ラウンドで変わる)・
## 教卓・時間割表・学級目標・スピーカー
func _build_front_extras(wall: Node3D, half: float, z: float) -> void:
	var round_no := _room_state.round_index if _room_state else 0
	# 時計の針: 1ラウンドで10分進む(1時間目の始まりから)
	var minutes := 30.0 + round_no * 10.0
	for hand in [[0.3, 0.03, minutes / 60.0 * TAU], [0.2, 0.045, (9.0 + minutes / 60.0) / 12.0 * TAU]]:
		var box := BoxMesh.new()
		box.size = Vector3(hand[1], hand[0], 0.02)
		var mi := Toon.mesh(box, GameConfig.COLOR_INK, 0.0)
		var pivot := Node3D.new()
		pivot.position = Vector3(4.6, 3.35, z + 0.08)
		pivot.rotation.z = -hand[2]
		wall.add_child(pivot)
		mi.position = Vector3(0, hand[0] / 2.0, 0)
		pivot.add_child(mi)
	# 日付と日直(黒板の右はし、縦書き風に)
	var d := Time.get_date_dict_from_system()
	var days := [tr("日"), tr("月"), tr("火"), tr("水"), tr("木"), tr("金"), tr("土")]
	var duty := "あおい"
	if _room_state and not _room_state.actors.is_empty():
		var a: GameState.Actor = _room_state.actors[(round_no * 3 + 1) % _room_state.actors.size()]
		duty = Locale.actor_name(a.display_name)
	_chalk_text(wall, tr("%d月%d日(%s)") % [d["month"], d["day"], days[d["weekday"]]], Vector3(2.5, 3.42, z + 0.1), 34, 0.0)
	_chalk_text(wall, tr("日直 %s") % duty, Vector3(2.5, 2.15, z + 0.1), 34, 0.0)
	# 黒板の左はしの落書き(ラウンドごとにちがう)
	_chalk_doodle(wall, round_no % 4, Vector3(-3.0, 2.32, z + 0.1))
	# 教卓(黒板の前の床)
	_part(Vector3(1.3, 0.95, 0.6), Vector3(0, 0.48, -half + 1.0), COLOR_WOOD.darkened(0.1), 0.03, wall)
	_part(Vector3(1.4, 0.06, 0.66), Vector3(0, 0.98, -half + 1.0), COLOR_WOOD, 0.02, wall)
	_part(Vector3(0.36, 0.06, 0.26), Vector3(-0.3, 1.04, -half + 1.0), COLOR_PAPER_SOFT, 0.012, wall, Vector3(0, 0.2, 0))
	# 時間割表(黒板の左)
	_part(Vector3(1.0, 1.3, 0.03), Vector3(-4.7, 2.6, z + 0.03), COLOR_PAPER_SOFT, 0.015, wall)
	_part(Vector3(1.0, 0.18, 0.035), Vector3(-4.7, 3.16, z + 0.035), Color("8FB8DE"), 0.0, wall)
	var cell_colors := [Color("F4C7C3"), Color("C9E4C5"), Color("FBE7A1"), Color("CFE0F5"), Color("E8D3F0")]
	for r in 5:
		for c in 5:
			_part(Vector3(0.16, 0.16, 0.01), Vector3(-5.08 + c * 0.19, 2.95 - r * 0.21, z + 0.05),
					cell_colors[(r + c * 2) % cell_colors.size()], 0.0, wall)
	# 学級目標(黒板の上の横長の紙)
	_part(Vector3(4.6, 0.44, 0.03), Vector3(0, 3.98, z + 0.03), COLOR_PAPER_SOFT, 0.015, wall)
	var goal := Label3D.new()
	goal.text = tr("なかよく げんきに がんばろう")
	goal.font = HudFont.get_chalk_font()
	goal.font_size = 54
	goal.pixel_size = 0.0045
	goal.outline_size = 0
	goal.modulate = Color("C2452D")
	goal.shaded = false
	goal.position = Vector3(0, 3.98, z + 0.06)
	wall.add_child(goal)
	# スピーカー(左上のすみ)
	_part(Vector3(0.55, 0.38, 0.2), Vector3(-6.7, 3.95, z + 0.06), COLOR_PILLAR, 0.02, wall)
	for i in 4:
		_part(Vector3(0.4, 0.025, 0.01), Vector3(-6.7, 4.06 - i * 0.07, z + 0.165), COLOR_METAL, 0.0, wall)


## チョークの文字(少し黄みがかった白、少し透ける)
func _chalk_text(parent: Node3D, text: String, pos: Vector3, size: int, tilt_deg: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = HudFont.get_chalk_font()
	l.font_size = size
	l.pixel_size = 0.0055
	l.outline_size = 0
	l.modulate = Color(0.98, 0.97, 0.88, 0.85)
	l.shaded = false
	l.position = pos
	l.rotation.z = deg_to_rad(tilt_deg)
	parent.add_child(l)


## チョークの線(細い箱)
func _chalk_line(parent: Node3D, a: Vector2, b: Vector2, z: float) -> void:
	var d := b - a
	_part(Vector3(d.length() + 0.03, 0.03, 0.01), Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, z), Color(0.98, 0.97, 0.88),
			0.0, parent, Vector3(0, 0, d.angle()))


## 黒板の落書き: 0 にこにこ顔 / 1 ねこ / 2 おうち / 3 かさ
func _chalk_doodle(parent: Node3D, kind: int, at: Vector3) -> void:
	var c := Vector2(at.x, at.y)
	var z := at.z
	var circle := func(center: Vector2, r: float, n: int) -> void:
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			_chalk_line(parent, center + Vector2(cos(a0), sin(a0)) * r, center + Vector2(cos(a1), sin(a1)) * r, z)
	match kind:
		0:
			circle.call(c, 0.3, 12)
			circle.call(c + Vector2(-0.1, 0.08), 0.03, 4)
			circle.call(c + Vector2(0.1, 0.08), 0.03, 4)
			_chalk_line(parent, c + Vector2(-0.14, -0.08), c + Vector2(0, -0.16), z)
			_chalk_line(parent, c + Vector2(0, -0.16), c + Vector2(0.14, -0.08), z)
		1:
			circle.call(c, 0.26, 12)
			_chalk_line(parent, c + Vector2(-0.22, 0.14), c + Vector2(-0.16, 0.38), z)
			_chalk_line(parent, c + Vector2(-0.16, 0.38), c + Vector2(-0.05, 0.25), z)
			_chalk_line(parent, c + Vector2(0.05, 0.25), c + Vector2(0.16, 0.38), z)
			_chalk_line(parent, c + Vector2(0.16, 0.38), c + Vector2(0.22, 0.14), z)
			for s2 in [-1.0, 1.0]:
				_chalk_line(parent, c + Vector2(s2 * 0.12, -0.04), c + Vector2(s2 * 0.4, 0.0), z)
				_chalk_line(parent, c + Vector2(s2 * 0.12, -0.08), c + Vector2(s2 * 0.4, -0.12), z)
		2:
			_chalk_line(parent, c + Vector2(-0.3, -0.3), c + Vector2(0.3, -0.3), z)
			_chalk_line(parent, c + Vector2(-0.3, -0.3), c + Vector2(-0.3, 0.05), z)
			_chalk_line(parent, c + Vector2(0.3, -0.3), c + Vector2(0.3, 0.05), z)
			_chalk_line(parent, c + Vector2(-0.38, 0.05), c + Vector2(0, 0.36), z)
			_chalk_line(parent, c + Vector2(0, 0.36), c + Vector2(0.38, 0.05), z)
			_chalk_line(parent, c + Vector2(-0.08, -0.3), c + Vector2(-0.08, -0.1), z)
			_chalk_line(parent, c + Vector2(0.08, -0.3), c + Vector2(0.08, -0.1), z)
		_:
			for i in 6:
				var a0 := PI * i / 6.0
				var a1 := PI * (i + 1) / 6.0
				_chalk_line(parent, c + Vector2(cos(a0), sin(a0)) * 0.34, c + Vector2(cos(a1), sin(a1)) * 0.34, z)
			_chalk_line(parent, c + Vector2(-0.34, 0), c + Vector2(0.34, 0), z)
			_chalk_line(parent, c + Vector2(0, 0.34), c + Vector2(0, -0.3), z)
			_chalk_line(parent, c + Vector2(0, -0.3), c + Vector2(0.08, -0.36), z)


## 横: 窓が3つ(水色のガラス、白い枠、ピンクのカーテン)
func _build_window_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	for x in [-4.5, 0.0, 4.5]:
		_part(Vector3(2.2, 1.9, 0.08), Vector3(x, 2.3, z), GameConfig.COLOR_PAPER, 0.03, wall)
		_part(Vector3(1.9, 1.6, 0.06), Vector3(x, 2.3, z + 0.03), COLOR_GLASS, 0.0, wall)
		# 窓の外: 校庭(緑の地面と土のグラウンド)と木
		_part(Vector3(1.9, 0.42, 0.01), Vector3(x, 1.71, z + 0.065), COLOR_FIELD, 0.0, wall)
		_part(Vector3(1.9, 0.12, 0.01), Vector3(x, 1.56, z + 0.066), COLOR_GROUND, 0.0, wall)
		var tx: float = x + (0.45 if int(x) % 2 == 0 else -0.5)
		_part(Vector3(0.08, 0.32, 0.01), Vector3(tx, 2.0, z + 0.067), COLOR_TRUNK, 0.0, wall)
		_part(Vector3(0.5, 0.42, 0.01), Vector3(tx, 2.32, z + 0.068), COLOR_TREE, 0.008, wall)
		_part(Vector3(0.34, 0.3, 0.01), Vector3(tx - 0.62, 2.12, z + 0.068), COLOR_TREE.lightened(0.08), 0.008, wall)
		_part(Vector3(0.06, 1.6, 0.08), Vector3(x, 2.3, z + 0.05), GameConfig.COLOR_PAPER, 0.015, wall)
		_part(Vector3(1.9, 0.06, 0.08), Vector3(x, 2.3, z + 0.05), GameConfig.COLOR_PAPER, 0.015, wall)
		for sx in [-1.25, 1.25]:
			_part(Vector3(0.35, 2.1, 0.08), Vector3(x + sx, 2.25, z + 0.08), COLOR_CURTAIN, 0.025, wall)
		if _curtain_node == null:
			# カーテンの音を鳴らす場所の目印
			_curtain_node = Node3D.new()
			_curtain_node.position = Vector3(x, 2.25, z + 0.1)
			wall.add_child(_curtain_node)
		# 窓台と植木鉢
		_part(Vector3(2.3, 0.05, 0.3), Vector3(x, 1.4, z + 0.15), COLOR_PILLAR, 0.02, wall)
		for px in [-0.55, 0.5]:
			_part(Vector3(0.22, 0.2, 0.22), Vector3(x + px, 1.53, z + 0.17), COLOR_POT, 0.018, wall)
			_part(Vector3(0.3, 0.22, 0.26), Vector3(x + px, 1.74, z + 0.17), COLOR_LEAF, 0.018, wall, Vector3(0, 0, 0.12))
			_part(Vector3(0.12, 0.08, 0.12), Vector3(x + px + 0.05, 1.9, z + 0.17), COLOR_FLOWER, 0.012, wall)


## 後ろ: ロッカー(ランドセルが入っている)
func _build_back_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.35
	_part(Vector3(7.2, 1.3, 0.5), Vector3(0, 0.65, z), COLOR_WOOD, 0.03, wall)
	# ランドセル(背景なので、少し落ち着いた色)
	var bags := [Color("C45A4E"), Color("3A3633"), Color("D99AAE"), Color("6A92D0"), Color("86B07E")]
	for row in 2:
		for col in 8:
			var x := -3.15 + col * 0.9
			var y := 0.38 + row * 0.6
			_part(Vector3(0.78, 0.48, 0.05), Vector3(x, y, z + 0.26), COLOR_WOOD.darkened(0.35), 0.0, wall)
			if (row * 8 + col) % 3 != 1:
				_part(Vector3(0.4, 0.34, 0.2), Vector3(x, y - 0.02, z + 0.22),
						bags[(row * 3 + col) % bags.size()], 0.02, wall)
	# 後ろの黒板(おしらせとマグネット)
	var bz := -half + 0.12
	_part(Vector3(4.8, 1.4, 0.08), Vector3(0, 2.45, bz), COLOR_WOOD, 0.03, wall)
	_part(Vector3(4.5, 1.1, 0.08), Vector3(0, 2.45, bz + 0.03), COLOR_BOARD, 0.02, wall)
	_chalk_text(wall, tr("きょうの めあて"), Vector3(-0.9, 2.75, bz + 0.08), 64, 0.0)
	_chalk_text(wall, tr("わすれものを しない"), Vector3(-0.6, 2.3, bz + 0.08), 56, -1.5)
	for i in 4:
		_part(Vector3(0.12, 0.12, 0.04), Vector3(1.1 + i * 0.28, 2.85, bz + 0.09), [Color("E26D5A"), Color("5B8FD9"), Color("F2C14E"), Color("6DB58A")][i], 0.01, wall)
	_part(Vector3(0.7, 0.5, 0.02), Vector3(1.55, 2.3, bz + 0.08), COLOR_PAPER_SOFT, 0.01, wall, Vector3(0, 0, 0.04))
	# 掃除用具入れ(灰色のスチール。戸のすじと、通気の穴)
	var cx := -4.25
	_part(Vector3(0.78, 1.9, 0.5), Vector3(cx, 0.95, -half + 0.35), COLOR_STEEL, 0.03, wall)
	_part(Vector3(0.02, 1.7, 0.02), Vector3(cx, 0.95, -half + 0.61), COLOR_STEEL.darkened(0.3), 0.0, wall)
	for i in 4:
		_part(Vector3(0.26, 0.025, 0.02), Vector3(cx - 0.19, 1.6 - i * 0.07, -half + 0.61), COLOR_STEEL.darkened(0.35), 0.0, wall)
		_part(Vector3(0.26, 0.025, 0.02), Vector3(cx + 0.19, 1.6 - i * 0.07, -half + 0.61), COLOR_STEEL.darkened(0.35), 0.0, wall)
	_part(Vector3(0.04, 0.16, 0.04), Vector3(cx + 0.06, 1.0, -half + 0.63), COLOR_METAL, 0.0, wall)


## もう1つの横: ドアと掲示板(貼り紙つき)
func _build_door_wall(wall: Node3D, half: float) -> void:
	var z := -half + 0.12
	_part(Vector3(1.3, 2.3, 0.08), Vector3(-4.5, 1.15, z), COLOR_WOOD, 0.03, wall)
	_part(Vector3(0.5, 0.6, 0.06), Vector3(-4.5, 1.65, z + 0.04), COLOR_GLASS, 0.015, wall)
	_part(Vector3(3.2, 1.3, 0.08), Vector3(1.5, 2.0, z), COLOR_CORK, 0.03, wall)
	# 習字(白い紙に黒い筆の字)と、絵(色画用紙に、お日さまと家)
	var words := ["友", "夢", "花"]
	for i in 3:
		var px := 0.35 + i * 0.5
		_part(Vector3(0.4, 0.95, 0.02), Vector3(px, 2.05, z + 0.055), COLOR_PAPER_SOFT, 0.01, wall, Vector3(0, 0, (i - 1) * 0.03))
		var brush := Label3D.new()
		brush.text = words[i]
		brush.font = HudFont.get_font()
		brush.font_size = 96
		brush.pixel_size = 0.0028
		brush.outline_size = 0
		brush.modulate = GameConfig.COLOR_INK
		brush.shaded = false
		brush.position = Vector3(px, 2.12, z + 0.07)
		wall.add_child(brush)
	var art_bg := [Color("CFE6F7"), Color("F9E0C7")]
	for i in 2:
		var ax := 2.05 + i * 0.62
		_part(Vector3(0.55, 0.42, 0.02), Vector3(ax, 2.25, z + 0.055), art_bg[i], 0.01, wall, Vector3(0, 0, 0.04 - i * 0.07))
		_part(Vector3(0.12, 0.12, 0.01), Vector3(ax + 0.14, 2.36, z + 0.07), Color("F2B544"), 0.0, wall)
		_part(Vector3(0.18, 0.13, 0.01), Vector3(ax - 0.08, 2.18, z + 0.07), Color("D96B5B"), 0.0, wall)
		_part(Vector3(0.6, 0.04, 0.01), Vector3(ax, 2.08, z + 0.07), Color("7DB86B"), 0.0, wall)
		_part(Vector3(0.55, 0.42, 0.02), Vector3(ax, 1.75, z + 0.055), [Color("FDEBA0"), Color("E1D2F2")][i], 0.01, wall, Vector3(0, 0, -0.03 + i * 0.05))
		_part(Vector3(0.3, 0.05, 0.01), Vector3(ax, 1.8, z + 0.07), Color("6D8FC9"), 0.0, wall)
		_part(Vector3(0.2, 0.05, 0.01), Vector3(ax - 0.04, 1.7, z + 0.07), Color("6D8FC9"), 0.0, wall)


## 箱の部品を1つ置く(outline: 輪郭線の太さ。0 なら線なし/rot: 向き(ラジアン))。
## 教室を作っている間は、色ごとにまとめて描く(StaticBatch。スマホで軽くするため)
func _part(size: Vector3, pos: Vector3, color: Color, outline: float = GameConfig.OUTLINE_WIDTH, parent: Node3D = null,
		rot: Vector3 = Vector3.ZERO) -> void:
	var local := Transform3D(Basis.from_euler(rot), pos)
	if _batch:
		var base := parent.transform if parent else Transform3D.IDENTITY
		_batch.add_box(size, base * local, color, outline)
		return
	var box := BoxMesh.new()
	box.size = size
	var mi := Toon.mesh(box, color, outline)
	mi.transform = local
	(parent if parent else self).add_child(mi)


func _build_chair(pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	var wood := Color(0.55, 0.35, 0.2)
	var metal := Color(0.4, 0.4, 0.42)
	# 座面と背もたれ(背もたれは後ろ側 +Z)は角を丸く
	var parts := [
		[Vector3(0.5, 0.05, 0.5), Vector3(0, 0.45, 0), wood, 0.02],
		[Vector3(0.5, 0.5, 0.05), Vector3(0, 0.72, 0.28), wood, 0.02],
	]
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			parts.append([Vector3(0.04, 0.45, 0.04), Vector3(x, 0.225, z), metal, 0.01])
	for p2 in parts:
		var mi := Toon.mesh(StaticBatch.chamfer_mesh(p2[0], p2[3]), p2[2])
		mi.position = p2[1]
		chair.add_child(mi)
	add_child(chair)


## 仮のキャラクター(体・顔・表情は CharacterModel)
func _build_character(a: GameState.Actor, is_self: bool) -> Node3D:
	var model := CharacterModel.new()
	model.name = "Actor%d" % a.id
	# ボットの性格は、⚙メニューでオンにしたときだけ名前の横に出す
	var shown_name := Locale.actor_name(a.display_name, Profile.show_personality)
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
	_oni_shadow.position = me.position - back * (0.9 + 0.5 * near) + right * rel.dot(right) * 0.5 + Vector3(0, 0.03, 0)
	_oni_shadow.rotation.y = me.yaw
	_oni_shadow.scale = Vector3(0.8 + 0.5 * near, 1.0, 1.6 + 1.4 * near)
	_oni_shadow_mat.albedo_color = Color(0, 0, 0, GameConfig.ONI_SHADOW_ALPHA * near)


## 頭からかぶった牛乳: 白いかたまりと、顔の横にたれるしずく(輪郭線つき)
func _build_milk_splash() -> Node3D:
	var root := Node3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.2
	cap.height = 0.16
	cap.radial_segments = 14
	cap.rings = 6
	var top := Toon.mesh(cap, Color(1.0, 0.99, 0.95), 0.02)
	top.position = Vector3(0, 0.36, 0)
	root.add_child(top)
	for k in 4:
		var drop := SphereMesh.new()
		drop.radius = 0.045
		drop.height = 0.12
		drop.radial_segments = 8
		drop.rings = 4
		var d := Toon.mesh(drop, Color(1.0, 0.99, 0.95), 0.015)
		var ang := TAU * (float(k) + 0.25) / 4.0
		d.position = Vector3(sin(ang) * 0.21, 0.24 - 0.05 * float(k % 2), cos(ang) * 0.21)
		root.add_child(d)
	root.visible = false
	return root


## 牛乳をかけられる人の目印: 足もとに青い点線の丸と、うすい青の丸(ゆっくり回る)
func _build_milk_ring(color: Color = ButtonIcon.MILK_BLUE) -> Node3D:
	var ring := Node3D.new()
	var blue := StandardMaterial3D.new()
	blue.albedo_color = color
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dash := BoxMesh.new()
	dash.size = Vector3(0.16, 0.01, 0.045)
	var n := 18
	var r := 0.62
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = dash
		mi.material_override = blue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / float(n)
		mi.position = Vector3(sin(a) * r, 0.0, cos(a) * r)
		mi.rotation.y = a + PI / 2.0
		ring.add_child(mi)
	var fill := CylinderMesh.new()
	fill.top_radius = r
	fill.bottom_radius = r
	fill.height = 0.004
	fill.radial_segments = 32
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(color, 0.25)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fmi := MeshInstance3D.new()
	fmi.mesh = fill
	fmi.material_override = fill_mat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(fmi)
	ring.visible = false
	add_child(ring)
	return ring


## 鬼が牛乳ボタンを押して、かける相手を選んでいるか(かけられる人みんなの足もとに丸を出す)
func set_milk_aim(on: bool) -> void:
	_milk_aim = on


func _update_milk_ring(state: GameState, delta: float) -> void:
	for a in state.actors:
		var on := _milk_aim and state.can_milk(a.id)
		var ring: Node3D = _milk_rings.get(a.id)
		if ring == null:
			if not on:
				continue
			ring = _build_milk_ring()
			_milk_rings[a.id] = ring
		ring.visible = on
		if on:
			ring.position = Vector3(a.position.x, 0.04, a.position.z)
			ring.rotation.y += delta * 0.6


## 牛乳がかかっている人は、頭の上に牛乳が乗っている(全員から見える)
func _update_milk(state: GameState, a: GameState.Actor, model: CharacterModel) -> void:
	var milk: Node3D = _milk_nodes.get(a.id)
	if milk == null:
		return
	milk.visible = model != null and state.is_milked(a) and state.phase != GameState.Phase.RESULT
	if milk.visible:
		var head := model.bone_world("DEF-head")
		milk.global_transform = Transform3D(model.global_transform.basis.orthonormalized(), head.origin)


## 障害物: 状態の obstacles に合わせて出す/消す。後ろに寄せたバケツ・椅子・机と、投げられたバナナの皮
func _update_obstacles(state: GameState) -> void:
	var alive := {}
	for ob in state.obstacles:
		var id: int = ob["id"]
		alive[id] = true
		if not _obstacle_nodes.has(id):
			var n := _build_obstacle(str(ob["kind"]))
			add_child(n)
			_obstacle_nodes[id] = n
			if ob["kind"] == "banana":
				_pop_at(state.obstacle_position(ob), tr("ぽいっ"), Color(1.0, 0.85, 0.1))
		var node: Node3D = _obstacle_nodes[id]
		var ang: float = ob["angle"]
		node.position = state.obstacle_position(ob)
		# 通り道に横向きに置く(正面がコースの向き)
		node.rotation.y = ang - PI / 2.0
	for id in _obstacle_nodes.keys():
		if not alive.has(id):
			(_obstacle_nodes[id] as Node3D).queue_free()
			_obstacle_nodes.erase(id)


## 障害物の形(教室の物)。低い物: バケツ・バナナ(ジャンプで越えられる)/高い物: 椅子・机(列を変えてよける)
func _build_obstacle(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"bucket":
			var body := CylinderMesh.new()
			body.top_radius = 0.2
			body.bottom_radius = 0.16
			body.height = 0.32
			var b := Toon.mesh(body, Color("4D96FF"), 0.03)
			b.position.y = 0.16
			root.add_child(b)
			var rim := CylinderMesh.new()
			rim.top_radius = 0.215
			rim.bottom_radius = 0.215
			rim.height = 0.03
			var r := Toon.mesh(rim, Color("2F6FD0"), 0.0)
			r.position.y = 0.32
			root.add_child(r)
			# 中の水
			var water := CylinderMesh.new()
			water.top_radius = 0.18
			water.bottom_radius = 0.18
			water.height = 0.01
			var w := Toon.mesh(water, Color("CFE6F7"), 0.0)
			w.position.y = 0.3
			root.add_child(w)
		"chair":
			var seat := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.44, 0.05, 0.42), 0.015), COLOR_CHAIR, 0.025)
			seat.position.y = 0.44
			root.add_child(seat)
			var back := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.44, 0.34, 0.05), 0.015), COLOR_CHAIR, 0.025)
			back.position = Vector3(0, 0.72, 0.19)
			root.add_child(back)
			for x in [-0.19, 0.19]:
				for z in [-0.18, 0.18]:
					var leg := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.035, 0.44, 0.035), 0.008), COLOR_METAL, 0.015)
					leg.position = Vector3(x, 0.22, z)
					root.add_child(leg)
		"desk":
			var top := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.62, 0.05, 0.46), 0.015), COLOR_DESK_TOP, 0.025)
			top.position.y = 0.72
			root.add_child(top)
			var box := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.56, 0.14, 0.4), 0.02), COLOR_DESK_BOX, 0.025)
			box.position.y = 0.62
			root.add_child(box)
			for x in [-0.27, 0.27]:
				for z in [-0.19, 0.19]:
					var leg := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.035, 0.6, 0.035), 0.008), COLOR_METAL, 0.015)
					leg.position = Vector3(x, 0.3, z)
					root.add_child(leg)
		_:
			# バナナの皮: 黄色い皮が3枚ひらいた形
			for k in 3:
				var peel := Toon.mesh(StaticBatch.chamfer_mesh(Vector3(0.09, 0.04, 0.26), 0.015), Color(1.0, 0.85, 0.1), 0.02)
				peel.position = Vector3(0, 0.03, 0)
				peel.rotation.y = TAU * float(k) / 3.0
				peel.position += Vector3(sin(peel.rotation.y), 0, cos(peel.rotation.y)) * 0.08
				root.add_child(peel)
	return root


## 床の上の位置に、ポンと文字を出す(バナナが落ちたときなど)
func _pop_at(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = HudFont.get_font()
	l.font_size = 110
	l.pixel_size = 0.006
	l.outline_size = 20
	l.outline_modulate = GameConfig.COLOR_INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 0.6, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.5, 0.6)
	tw.tween_property(l, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(l.queue_free)


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
	[Vector3(0.24, 0.18, 0.5), Color(1, 1, 1)],         # 上履き(白に青いつま先とバンド)
	[Vector3(0.36, 0.4, 0.22), Color(0.8, 0.15, 0.15)],  # ランドセル
	[Vector3(0.6, 0.7, 0.45), Color(0.65, 0.45, 0.25)],  # 机
	[Vector3(0.9, 1.0, 0.5), Color(0.4, 0.25, 0.15)],    # 教卓
]
## いまの落とし物の番号と大きさ(持ち方を決める)
var _item_index := 0
var _item_size := Vector3.ONE


## 追いかける人が落とし物を持つ: 小さい物(ハンカチ・上履き)は右手に、大きい物は背中に
func _carry_item(m: CharacterModel) -> void:
	if m == null:
		return
	var body := m.global_transform.basis.orthonormalized()
	# キャラの正面は -Z、背中は +Z
	var back := body.z.normalized()
	match _item_index:
		0:
			# ハンカチ: 手からぶら下がる(布を縦にして、少し小さく)
			var hand := m.bone_world("DEF-hand.R").origin
			var b := body * Basis(Vector3.RIGHT, PI / 2.0)
			_handkerchief.transform = Transform3D(b.scaled(Vector3.ONE * 0.6), hand + Vector3(0, -0.17, 0))
		1:
			# 上履き: 手に持つ
			var hand := m.bone_world("DEF-hand.R").origin
			_handkerchief.transform = Transform3D(body.scaled(Vector3.ONE * 0.85), hand + Vector3(0, -0.08, 0))
		2:
			# ランドセル: 背中に背負う(胸の高さの、背中のすぐ後ろ)
			var chest := m.bone_world("DEF-spine.003").origin
			var pos := chest + back * (0.16 + _item_size.z / 2.0) + Vector3(0, -_item_size.y * 0.75, 0)
			_handkerchief.transform = Transform3D(body, pos)
		_:
			# 机・教卓: 頭の上に担ぐ(形の下の端を、頭のてっぺんの少し上に)
			var head := m.bone_world("DEF-head").origin
			# (頭の部品の位置 = 頭の球のまん中)
			var pos := head + Vector3(0, CharacterModel.HEAD_RADIUS + 0.04, 0)
			_handkerchief.transform = Transform3D(body, pos)


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
			# ハンカチ: 白いふち+赤い地+白いチェックの線(スタンプの絵と同じ)。
			# 手に持つと縦になって裏も見えるので、表と裏の両方に赤い地を貼る
			_item_part(Vector3(0.55, 0.03, 0.55), Vector3(0, 0.025, 0), Color.WHITE, ITEM_OUTLINE)
			for face in [1.0, -1.0]:
				var fy: float = 0.025 + face * 0.018
				_item_part(Vector3(0.44, 0.008, 0.44), Vector3(0, fy, 0), COLOR_HANKIE, 0.0)
				for k in [-0.11, 0.11]:
					_item_part(Vector3(0.44, 0.006, 0.05), Vector3(0, fy + face * 0.006, k), Color.WHITE, 0.0)
					_item_part(Vector3(0.05, 0.006, 0.44), Vector3(k, fy + face * 0.007, 0), Color.WHITE, 0.0)
		1:
			# 上履き: 赤い底、丸い白い本体、青いゴムのつま先、甲のゴムバンド、足を入れる口、かかとのつまみ
			# (スタンプの絵と同じ色。つま先は -Z)
			_item_part(Vector3(0.24, 0.035, 0.5), Vector3(0, 0.018, 0), Color("D9483B"), ITEM_OUTLINE, 0.03)
			_item_part(Vector3(0.23, 0.12, 0.48), Vector3(0, 0.09, 0.0), Color.WHITE, ITEM_OUTLINE, 0.055)
			_item_part(Vector3(0.24, 0.115, 0.17), Vector3(0, 0.085, -0.165), COLOR_SHOE_RUBBER, ITEM_OUTLINE, 0.055)
			_item_part(Vector3(0.245, 0.045, 0.07), Vector3(0, 0.13, -0.02), COLOR_SHOE_RUBBER, 0.02, 0.015)
			_item_part(Vector3(0.15, 0.012, 0.2), Vector3(0, 0.152, 0.11), Color("4A4A52"), 0.0, 0.004)
			_item_part(Vector3(0.08, 0.06, 0.03), Vector3(0, 0.16, 0.235), COLOR_SHOE_RUBBER, 0.015, 0.01)
		_:
			_item_part(size, Vector3(0, size.y / 2.0, 0), shape[1], ITEM_OUTLINE)
	_handkerchief.visible = false
	add_child(_handkerchief)
	# 小さい物は手に持ち、大きい物は背負う(_carry_item)
	_item_index = index
	_item_size = size


func _build_sounds(state: GameState) -> void:
	# 足音は鬼の体についていく(左右・遠近で鬼の位置がなんとなくわかる。大きさは GameConfig で変えられる)
	_step_player = Sfx.player_3d(_actor_nodes[state.oni_id] as Node3D, GameConfig.FOOTSTEP_VOLUME_DB, GameConfig.FOOTSTEP_UNIT_SIZE)
	_step_player.stream = Sfx.get_stream("step")
	_step_player.max_polyphony = 2
	_oni_last_pos = state.get_actor(state.oni_id).position
	_oni_walked = 0.0
	_chaser_step_player = Sfx.player_3d(self, GameConfig.RUN_STEP_VOLUME_DB, GameConfig.FOOTSTEP_UNIT_SIZE)
	_chaser_step_player.stream = Sfx.get_stream("run_step")
	_chaser_step_player.max_polyphony = 2
	_chaser_last_pos = Vector3.ZERO
	_chaser_walked = 0.0

	# 落とし物の音は、そのラウンドの落とし物の音(本物もフェイクも同じ)
	_drop_player = Sfx.player_3d(self, GameConfig.DROP_VOLUME_DB, GameConfig.DROP_SOUND_RANGE)
	_drop_player.stream = Sfx.get_stream("drop_%d" % clampi(state.round_index, 0, 4))

	# 場所のある効果音(振り向く・お手つき・拾う・転ぶなど)
	_fx3d.clear()
	for i in 4:
		_fx3d.append(Sfx.player_3d(self, 0.0, 3.0))

	_stamp_player = Sfx.player_2d(self, -4.0)

	_beep_player = Sfx.player_2d(self)
	_beep_player.stream = Sfx.get_stream("ui_click")

	# 環境音(ごく小さく)
	_amb_player = Sfx.player_2d(self, GameConfig.AMBIENT_VOLUME_DB)
	_amb_player.stream = Sfx.get_stream("amb_school")
	_amb_player.play()
	_clock_player = Sfx.player_3d(self, GameConfig.CLOCK_VOLUME_DB, 2.0)
	_clock_player.stream = Sfx.get_stream("clock_tick")
	if _clock_node:
		_clock_player.global_position = _clock_node.global_position
	_clock_left = 0.0
	_curtain_player = Sfx.player_3d(self, GameConfig.CURTAIN_VOLUME_DB, 3.0)
	_curtain_player.stream = Sfx.get_stream("curtain")
	if _curtain_node:
		_curtain_player.global_position = _curtain_node.global_position
	_curtain_left = randf_range(4.0, 10.0)


## 自分に届いたスタンプの音(ほかの人あてのスタンプでは鳴らさない)
func play_stamp_sound(kind: String) -> void:
	_stamp_player.stream = Sfx.get_stream("stamp_" + kind)
	_stamp_player.pitch_scale = randf_range(0.97, 1.03)
	_stamp_player.play()


## スタンプを送る相手の目印を出す(-1 で消す)
## 確認用: 全員を転ばせる(K キー)
func debug_slip_all() -> void:
	for id in _actor_nodes:
		var m := _actor_nodes[id] as CharacterModel
		if m:
			m.slip()


## スタンプを送る相手(いまは頭の上の選択肢で示すので、3D の目印は出さない)
## スタンプを送る相手の足もとを光らせる(-1 で消す)
func set_stamp_target(state: GameState, id: int) -> void:
	if _stamp_ring == null or not is_instance_valid(_stamp_ring):
		_stamp_ring = _build_milk_ring(STAMP_RING_COLOR)
	var a := state.get_actor(id)
	_stamp_ring.visible = a != null
	if a:
		_stamp_ring.position = Vector3(a.position.x, 0.045, a.position.z)
		_stamp_ring.rotation.y += get_process_delta_time() * 0.8
		# ふわっと明るくなったり暗くなったりする
		var k := 1.0 + 0.06 * sin(_clock * 6.0)
		_stamp_ring.scale = Vector3(k, 1.0, k)


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
	_seat_fov = _seat_cam.fov
	_seat_cam.near = 0.05
	# 自分の体のレイヤーを映さない
	_seat_cam.cull_mask = 0xFFFFF & ~(1 << (SELF_LAYER - 1)) & ~(1 << (HIDDEN_LAYER - 1))
	add_child(_seat_cam)
	_seat_cam.make_current()
	_update_seat_camera(state, 0.0)

	_top_cam = Camera3D.new()
	_top_cam.fov = 60
	_top_cam.cull_mask = 0xFFFFF & ~(1 << (CEILING_LAYER - 1))
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
	if me.role == GameState.Role.OUT:
		# お手つきで抜けた: 真ん中の上の高いところから、輪の全員の後ろを見下ろす(天井は映さない)
		_seat_cam.cull_mask = 0xFFFFF & ~(1 << (CEILING_LAYER - 1))
		_seat_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_seat_cam.fov = GameConfig.OUT_CAM_FOV
		var want := GameConfig.OUT_CAM_POS
		var w := 1.0 if delta == 0.0 else clampf(delta * 3.0, 0.0, 1.0)
		_seat_cam.look_at_from_position(_seat_cam.position.lerp(want, w), GameConfig.OUT_CAM_LOOK)
		return
	_seat_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_seat_cam.fov = _seat_fov
	if me.role != GameState.Role.SEATED:
		_seat_cam.cull_mask = 0xFFFFF
	else:
		_seat_cam.cull_mask = 0xFFFFF & ~self_bit & ~(1 << (HIDDEN_LAYER - 1))
	if state.is_runner(me):
		# 追いかけっこで走っている: 走る人のすぐ後ろ・少し上から、走る先を見る(走る向きが画面の奥)
		var ang := state.runner_angle(me)
		var fwd := Vector3(cos(ang), 0.0, -sin(ang))
		var want_r := Vector3(me.position.x, 0.0, me.position.z) - fwd * GameConfig.CHASE_CAM_DISTANCE \
				+ Vector3(0, GameConfig.CHASE_CAM_HEIGHT, 0)
		var wr := 1.0 if delta == 0.0 else clampf(delta * 6.0, 0.0, 1.0)
		if _seat_cam.position.distance_to(want_r) > 6.0:
			wr = 1.0
		var ahead_ang := ang + GameConfig.CHASE_CAM_LOOK_AHEAD / maxf(me.run_r, 1.0)
		var look := Vector3(sin(ahead_ang), 0.0, cos(ahead_ang)) * me.run_r + Vector3(0, 0.6, 0)
		_seat_cam.look_at_from_position(_seat_cam.position.lerp(want_r, wr), look)
		return
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
