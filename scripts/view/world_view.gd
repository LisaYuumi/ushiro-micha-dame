class_name WorldView
extends Node3D
## 見逃しの演出: 答え合わせ(上からの巻き戻し)が始まった/終わった・演出がおわった(結果カードを出してよい)
signal missed_scene_done
## GameState を読んで 3D の見た目を作る・更新するだけ。
## 状態は書きかえない。

## 自分の体を自分のカメラに映さないためのレイヤー
const SELF_LAYER := 2
## 自分の席からは見えない物(両どなりの後ろに落ちた物)を置くレイヤー
const HIDDEN_LAYER := 3

var _actor_nodes := {} # id -> Node3D
## 教室の椅子(席の番号の順)。お手つきの顔のアップの間は、自分の椅子を隠す(背もたれが顔にかぶらないように)
var _chairs: Array[Node3D] = []
var _hidden_chair := -1
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
## 鬼が自分のうしろにいる近さ(0〜1。影と同じ範囲)と、なめらかにしたドキドキの強さ、心臓の音
var _oni_near := 0.0
var _heart_level := 0.0
## 頭の上の名札(2D で重ねる)
var _overlay: HeadOverlay
## 停電イベントの暗い幕
var _blackout: BlackoutLayer
## 教室を作っている間だけ使う、背景の箱のまとめ役
var _batch: StaticBatch
## 教室を作るときに見る状態(ラウンドで変わる黒板の落書き・時計・日直)
var _room_state: GameState
## 海辺の舞台か(座る人は砂に体育座り・鬼は麦わら帽子・牛乳のかわりに水鉄砲)
var _beach := false
## 夜の教室(昼の教室と同じ部屋の夜。暗めの青、窓の外は月と星、窓側は月の光で明るい)
var _night := false
## 窓の外の稲光(雷のときだけ出す)と、夜の壁の文字の明るさ
var _bolts: Array[Node3D] = []
var _night_label_bright := -1.0
## 夜の落とし物の動く部品(NightStage.build_item)と、メトロノームの音・時計
var _night_item := {}
var _tick_player: AudioStreamPlayer3D
var _night_t := 0.0
var _tick_side := 0
const COLOR_NIGHT_SKY := Color("16204A")
const COLOR_NIGHT_GLASS := Color("1E2C63")
const COLOR_MOON := Color("FFF3B8")
## 砂に座るので、座っている人のカメラを下げる高さ
const BEACH_CAM_DROP := 0.3
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

## スタンプの色は言葉の意味でそろえる: 見ろ系(落ちてる・信じて)は赤、見るな系(平気)は青
const STAMP_COLORS := {
	Stamps.DROPPED: HeadOverlay.COLOR_LOOK,
	Stamps.SAFE: HeadOverlay.COLOR_DONT,
	Stamps.TRUST: HeadOverlay.COLOR_LOOK,
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
## お手つきの演出: ズッコケてから、とぼとぼ真ん中まで歩く(id -> {"t", "from", "to"})
var _out_anim := {}
## 見逃しの演出(鬼が1周しても気づかなかった): {"t", "loser", "oni", "result", "done", "walk_from", "walk_to", "oni_from"}
var _ms := {}
## 見逃しの演出: トントン → 振り向く → 顔のアップ(鬼の画面は相手の気まずい顔、気づかなかった人の画面は鬼のニヤニヤ、
## ほかの人は2人を横から)→ 放心(魂が抜ける・チーン。2人を横から)→ とぼとぼ
## 段階: 0 トントン・振り向く / 1 顔のアップ / 2 チーン / 4 とぼとぼ。秒数は GameConfig の MISSED_*
const MS_LOOK := GameConfig.MISSED_LOOK_TIME
const MS_FACE := GameConfig.MISSED_LOOK_TIME + GameConfig.MISSED_TURN_TIME
const MS_CHIIN := MS_FACE + GameConfig.MISSED_FACE_TIME
const MS_WALK := MS_CHIIN + GameConfig.MISSED_CHIIN_TIME
## トントンされて振り向くとき、椅子と重ならないように後ろ(鬼の側)へ出る距離(メートル)
const MS_TURN_STEP_OUT := 0.55
## 頭に落とし物をのせている人(見逃した人。次のラウンドで消える)と、真ん中に座った位置
var _item_head_id := -1
var _missed_sit := {}
const OUT_FALL_TIME := 1.1
const OUT_RISE_TIME := 0.35
const OUT_WALK_SPEED := 1.1
## お手つきの本人の画面: まず自分の顔を大きく映す時間(そのあと、崩れ落ちるところまで寄ったまま見せる)
const OUT_FACE_TIME := 0.6
## 画面のゆれ(お手つきの本人の画面。⚙メニューでオフにできる)
var _shake_left := 0.0
const SHAKE_TIME := 0.4
const SHAKE_PIXELS := 0.08


## ラウンドが変わっても同じ人のキャラは使い回す(作り直すと重く、ラウンドの始まりにガタッと止まるので)
## 名前・色・小物・自分かどうか が同じなら同じキャラ
var _model_cache := {}


func _model_key(a: GameState.Actor, is_self: bool) -> String:
	return "%d|%s|%s|%s|%s" % [a.id, a.color.to_html(), a.display_name, JSON.stringify(a.accessories), is_self]


func build(state: GameState) -> void:
	# 前のラウンドのキャラは取っておく(鬼の体についていた足音のプレイヤーは外す)
	if is_instance_valid(_step_player):
		_step_player.get_parent().remove_child(_step_player)
		_step_player.queue_free()
	_step_player = null
	_model_cache.clear()
	for id in _actor_nodes:
		var old: Node3D = _actor_nodes[id]
		if is_instance_valid(old) and old.get_meta("model_key", "") != "":
			remove_child(old)
			_model_cache[old.get_meta("model_key")] = old
	for c in get_children():
		c.queue_free()
	_actor_nodes.clear()
	_window_lights.clear()
	_wall_labels.clear()
	_wall_bright = 1.0
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
	_out_anim.clear()
	# (見逃しの顔のアップの途中でラウンドが終わっても、隠していた鬼・気づかなかった人の体を元にもどす)
	_set_viewer_hidden(false, false)
	_ms.clear()
	_item_head_id = -1
	_missed_sit.clear()
	_reveal_faces.clear()
	if _vote_view:
		_vote_view = false
	_mirage_nodes.clear()
	_mirage_fade = -1.0
	_mirage_oni_faded = false
	# (投票の場面の再現も消す。残すと、次のラウンドでも前のラウンドの席にみんなを置いてしまう)
	_vote_scene.clear()
	_vote_item_pos = Vector3.INF
	_vote_item_top = Vector3.INF
	_vote_focus = -1
	_shake_left = 0.0
	_obstacle_nodes.clear()
	_milk_nodes.clear()

	_beach = state.stage == "beach"
	_night = state.stage == "night"
	# (昼の舞台では、夜の青っぽさをなくす)
	Toon.set_night(0.0)
	_bolts.clear()
	_night_label_bright = -1.0
	_build_environment()
	_room_state = state
	if _beach:
		_build_beach()
		# 砂浜には椅子がないので、座る場所に丸いあとをつける
		for i in state.seat_positions.size():
			BeachStage.seat_mark(self, state.seat_positions[i])
	_chairs.clear()
	_hidden_chair = -1
	if not _beach:
		_build_floor()
		for i in state.seat_positions.size():
			_chairs.append(_build_chair(state.seat_positions[i], state.seat_yaws[i]))
	for a in state.actors:
		var is_self: bool = a.id == state.local_player_id
		var key: String = _model_key(a, is_self)
		var node: Node3D
		if _model_cache.has(key):
			node = _model_cache[key]
			_model_cache.erase(key)
			(node as CharacterModel).stop_ragdoll()
			# (前のラウンドで一時的に隠したまま(見逃しの顔のアップ・カメラのすぐ前)にならないように、必ず見えるようにもどす。
			# 前は、隠したまま次のラウンドになると、鬼が足音だけして見えなかった)
			node.visible = true
			node.set_meta("cam_hid", false)
			# (蜃気楼で透けさせたまま次のラウンドにならないように)
			_set_transparency(node, 0.0)
			node.rotation.z = 0.0
		else:
			node = _build_character(a, is_self)
			node.set_meta("model_key", key)
		add_child(node)
		_actor_nodes[a.id] = node
		var blob := _make_blob(Vector2(0.95, 0.95))
		add_child(blob)
		_blobs[a.id] = blob
		var milk := _build_milk_splash()
		if a.id == state.local_player_id:
			# 自分の頭の牛乳は、座っているときの自分のカメラには映さない(画面が白くなるので)
			for c in milk.find_children("*", "VisualInstance3D", true, false):
				(c as VisualInstance3D).layers = 1 << (SELF_LAYER - 1)
		add_child(milk)
		_milk_nodes[a.id] = milk
	# 使わなかったキャラ(抜けた人など)は消す
	for k in _model_cache:
		(_model_cache[k] as Node).queue_free()
	_model_cache.clear()
	# 壁の文字を覚えておく(このあとで出す「ぽいっ」などの文字は入れない)
	for n in find_children("*", "Label3D", true, false):
		var l := n as Label3D
		_wall_labels.append([l, l.modulate, l.outline_modulate])
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
		# 見逃しの演出で、ゆっくり振り向く(見た目だけ)
		var forced := _ms_forced_look(a.id)
		var t: float = move_toward(_turn.get(a.id, 0.0), 1.0 if a.looking_back or forced else 0.0, turn_step * (0.6 if forced else 1.0))
		_turn[a.id] = t
		var node: Node3D = _actor_nodes.get(a.id)
		# 称号発表(寄る人は立つ)と記念写真(全員が横に並ぶ)
		var cer := _cer_override(a.id)
		if node:
			node.position = a.position
			node.rotation.y = a.yaw
			_apply_out_anim(a, node, delta)
			_apply_missed_pos(a, node)
			if cer.has("pos"):
				node.position = cer["pos"]
				node.rotation.y = cer["yaw"]
			if forced:
				# 見逃しでトントンされた人: 頭だけひねると、鬼の側から見て後頭部に顔があるように見えるので、
				# 立ち上がって、体ごとくるっと鬼の方へ振り向く(椅子と重ならないように、少し後ろへ出ながら)
				var out := Vector3(a.position.x, 0.0, a.position.z).normalized()
				node.position = a.position + out * MS_TURN_STEP_OUT * t
				node.rotation.y = a.yaw + PI * t
			var blob: MeshInstance3D = _blobs.get(a.id)
			if blob:
				blob.position = Vector3(node.position.x, 0.03, node.position.z)
			_update_dust(a, delta)
			var model := node as CharacterModel
			# (投票の場面を再現している人は、姿勢・表情を _apply_vote_scene_actors が決める。ここで毎フレーム別の姿勢にすると、
			# 座る動きが毎回やり直しになって、変な姿勢のまま止まってしまう)
			var in_scene := _vote_scene.has(a.id)
			if model and in_scene:
				if not _vote_scene[a.id]["look"]:
					_update_expression(state, a, model, delta)
				else:
					model.animate(delta, false)
				_update_milk(state, a, model)
				continue
			if model:
				# 振り向いた姿は全員に見える(頭→上半身の順に後ろを向く)
				# (見逃しの人は体ごと振り向くので、頭はひねらない)
				model.set_look(a.looking_back and not forced and cer.is_empty())
				model.set_pose(("walk" if cer.get("walk", false) else "idle") if not cer.is_empty() else _pose_of(state, a))
				# 転んで止まっている間は、前にばったり倒れている(お手つきの演出中は、後ろへズッコケる)
				if not cer.is_empty():
					model.set_kneel(bool(cer.get("kneel", false)))
					model.set_down(false)
				elif _out_anim.has(a.id):
					# お手つき: ひざから崩れ落ちる
					var ot: float = float(_out_anim[a.id]["t"]) - float(_out_anim[a.id].get("d", 0.0))
					model.set_kneel(ot >= 0.0 and ot < OUT_FALL_TIME)
					model.set_down(false)
				else:
					model.set_kneel(false)
					model.set_down(a.slip_left > 0.0)
				# 鬼だけが学校の黄色い帽子をかぶる
				model.set_hat(a.id == state.oni_id, _beach)
				# 称号発表・記念写真のポーズ
				# 砂のお城を抱えて走る人は、両腕でかかえる
				var hug: bool = _beach and _item_index == 3 and a.id == state.chaser_id and state.phase == GameState.Phase.CHASE \
						and a.slip_left <= 0.0
				model.set_gesture(str(_cer_gestures.get(a.id, "")) if _cer_mode != "" else ("hug" if hug else ""))
			_update_expression(state, a, model, delta)
			_update_milk(state, a, model)
	# (投票の場面の再現は、名札・足もとの光・カメラより先に)
	_apply_vote_scene_actors()
	_update_missed_scene(state, delta)
	_update_seat_camera(state, delta)
	_update_vote_view(state, delta)
	_update_ceremony(delta)
	_update_events(state, delta)
	_hide_near_camera(state)
	_update_mirage(state, delta)
	if _overlay:
		_overlay.update(state, get_viewport().get_camera_3d())
	if _blackout:
		# 座っている自分の目は、自分のカメラのすぐ前にあるので描かない
		var me := state.get_local_player()
		var skip := me.id if me != null and me.role == GameState.Role.SEATED else -1
		_blackout.update(state, get_viewport().get_camera_3d(), _actor_nodes, delta, skip)
		if _env:
			var bc := _sky_color.lerp(DARK_SKY, 1.0 - _blackout.brightness())
			if _env.background_color != bc:
				_env.background_color = bc
		for wl in _window_lights:
			wl.visible = _blackout.brightness() > 0.5
		# 壁の文字も同じ暗さに(停電中だけ。変わったときだけ色をかえる)
		var wb := _blackout.brightness()
		if not is_equal_approx(wb, _wall_bright):
			_wall_bright = wb
			for wl in _wall_labels:
				# (ラウンドのあいだに消えた文字もあるので、型をつける前に確かめる)
				if not is_instance_valid(wl[0]):
					continue
				var lab: Label3D = wl[0]
				if lab:
					var m: Color = wl[1]
					var o: Color = wl[2]
					lab.modulate = Color(m.r * wb, m.g * wb, m.b * wb, m.a)
					lab.outline_modulate = Color(o.r * wb, o.g * wb, o.b * wb, o.a)
	apply_night_light(state)
	_update_obstacles(state)
	_update_oni_shadow(state)
	_update_heart(state, delta)
	_update_milk_ring(state, delta)
	_clock += delta

	var holder := state.get_actor(state.chaser_id)
	# (背負う紐は、背負っている間だけ。_carry_item が出す)
	if _straps and is_instance_valid(_straps):
		_straps.visible = false
	if _sand_fx and is_instance_valid(_sand_fx):
		_sand_fx.emitting = false
	var tucker := _tucker
	_tucker = null
	if _item_head_id >= 0 and _actor_nodes.has(_item_head_id):
		# 見逃した人は、落とし物を頭にのせたまま(次のラウンドで消える)
		var hm := _actor_nodes[_item_head_id] as CharacterModel
		var head := hm.bone_world("DEF-head").origin
		_handkerchief.visible = true
		_handkerchief.transform = Transform3D(hm.global_transform.basis.orthonormalized().scaled(Vector3.ONE * 0.8),
				head + Vector3(0, CharacterModel.HEAD_RADIUS + 0.06, 0))
	elif holder:
		# 追いかける人が持って走る: ハンカチ・上履きは右手に、大きい物は背中に背負う
		_handkerchief.visible = true
		_castle_size = state.castle_size
		_castle_down = holder.slip_left > 0.0
		_carry_item(_actor_nodes.get(holder.id) as CharacterModel)
	else:
		# 停電中は、落とし物はだれにも見えない(誰の後ろに落ちたか、みんなわからなくなる)。落とした鬼だけは見える
		var dark_hide := state.blackout and state.local_player_id != state.oni_id
		_handkerchief.visible = state.handkerchief_on_floor and not dark_hide
		_handkerchief.transform = Transform3D(Basis.IDENTITY, state.handkerchief_position)
	if tucker != _tucker and tucker and is_instance_valid(tucker):
		tucker.set_tuck(false)
	_hide_item_if_not_visible_to_me(state)
	_update_night_item(state, delta, holder != null and _item_head_id < 0)
	_apply_vote_scene_item()
	_update_footsteps(state)
	_update_ambience(delta)


## 見逃しの演出を始める(鬼が1周しても気づかなかった)。終わったら(結果カードを出してよくなったら)missed_scene_done。
## みんなの画面で同じ動き。気づかなかった本人の画面は、ゆっくり後ろを向く
func play_missed_scene(state: GameState, result: Dictionary) -> void:
	var loser: int = result.get("loser", -1)
	var ln: Node3D = _actor_nodes.get(loser)
	if ln == null:
		missed_scene_done.emit()
		return
	var oni_node: Node3D = _actor_nodes.get(state.oni_id)
	var home := ln.position
	var center := home.normalized() * GameConfig.OUT_SIT_RADIUS if home.length() > 0.01 else Vector3.ZERO
	_ms = {"t": 0.0, "loser": loser, "oni": state.oni_id, "result": result, "done": false,
			"walk_from": home, "walk_to": Vector3(center.x, 0.0, center.z),
			"oni_from": oni_node.position if oni_node else Vector3.ZERO, "stage": 0}
	# 1. トントン(鬼が後ろから肩をたたく)
	_play_actor(loser, "tonton", -2.0, -8.0)
	_pop(loser, tr("トントン"), Color.WHITE)


func is_missed_scene_playing() -> bool:
	return not _ms.is_empty() and not _ms.get("done", false)


## タップでとばす: すぐに終わりの形(真ん中で体育座り・頭に落とし物)にする
func skip_missed_scene() -> void:
	if _ms.is_empty():
		return
	if int(_ms["stage"]) >= 1 and int(_ms["stage"]) < 4:
		_end_close_up()
	var loser: int = _ms["loser"]
	_missed_sit[loser] = _ms["walk_to"]
	_item_head_id = loser
	_ms_finish()
	_ms.clear()


func _ms_forced_look(id: int) -> bool:
	return not _ms.is_empty() and _ms["loser"] == id and float(_ms["t"]) >= MS_LOOK and int(_ms["stage"]) < 4


func _ms_dazed(id: int) -> bool:
	return (not _ms.is_empty() and _ms["loser"] == id and float(_ms["t"]) >= MS_CHIIN) or _missed_sit.has(id)


## 見逃しの演出での表情(""なら、ふだんどおり): 振り向いてから、鬼はニヤニヤ、気づかなかった人はガーン!(あごが外れたような顔。チーンからは放心)
func _ms_expression(id: int) -> String:
	if _ms.is_empty():
		return ""
	var t: float = _ms["t"]
	if id == _ms["oni"] and t >= MS_LOOK:
		return CharacterModel.SMIRK
	if id == _ms["loser"] and t >= MS_FACE:
		return CharacterModel.SHOCK if t < MS_CHIIN else CharacterModel.NORMAL
	return ""


func _ms_finish() -> void:
	if not _ms.get("done", false):
		_ms["done"] = true
		missed_scene_done.emit()


func _update_missed_scene(state: GameState, delta: float) -> void:
	if _ms.is_empty():
		return
	_ms["t"] = float(_ms["t"]) + delta
	var t: float = _ms["t"]
	var loser: int = _ms["loser"]
	var stage: int = _ms["stage"]
	var oni_node: Node3D = _actor_nodes.get(_ms["oni"])
	var ln := _actor_nodes.get(loser) as CharacterModel
	if stage < 3 and oni_node and ln:
		# 鬼は、気づかなかった人の方を向いて立つ
		var d := ln.global_position - oni_node.global_position
		oni_node.rotation.y = atan2(-d.x, -d.z)
	if stage == 0 and t >= MS_FACE:
		# 1. 振り向いた: 顔のアップ
		_ms["stage"] = 1
		if _overlay:
			_overlay.visible = false
		_top_cam.make_current()
	elif stage == 1 and t >= MS_CHIIN:
		# 2. 放心して、頭から魂がふわっと抜ける。間の抜けたラッパ「チーン」(みんな2人を横から見る)
		_ms["stage"] = 2
		_play_actor(loser, "chiin", -2.0, -8.0)
		# (2人を横から近くで映すので、文字は小さめ)
		_pop(loser, tr("チーン…"), Color("C9C2B6"), 0.3)
		_spawn_soul(loser)
	elif stage == 2 and t >= MS_WALK:
		# 3. 落とし物を頭にのせて、とぼとぼ真ん中へ(ここで結果カードを出してよい)
		_end_close_up()
		# (振り向いて少し後ろへ出た場所から、とぼとぼ歩きだす)
		if ln:
			_ms["walk_from"] = ln.position
		_ms["stage"] = 4
		_ms["walking"] = true
		_ms["walk_t"] = 0.0
		_item_head_id = loser
		_missed_sit[loser] = _ms["walk_from"]
		_play_actor(loser, "trudge", -6.0, -16.0)
		_ms_finish()
	elif stage == 4:
		_ms["walk_t"] = float(_ms["walk_t"]) + delta
		var from: Vector3 = _ms["walk_from"]
		var to: Vector3 = _ms["walk_to"]
		var k := clampf(float(_ms["walk_t"]) * OUT_WALK_SPEED / maxf(from.distance_to(to), 0.01), 0.0, 1.0)
		_missed_sit[loser] = from.lerp(to, k)
		if k >= 1.0:
			_missed_sit[loser] = to
			_ms.clear()
	if int(_ms.get("stage", 4)) in [1, 2]:
		_update_ms_camera(state)


## 顔のアップと、2人を横から見るカメラ
func _update_ms_camera(state: GameState) -> void:
	var oni := _actor_nodes.get(_ms["oni"]) as CharacterModel
	var ln := _actor_nodes.get(_ms["loser"]) as CharacterModel
	if oni == null or ln == null:
		return
	var me := state.local_player_id
	var lf := _face_point(ln)
	var of := _face_point(oni)
	if int(_ms["stage"]) == 1 and (me == _ms["oni"] or me == _ms["loser"]):
		# 鬼の画面: 気づかなかった人の気まずい顔 / 気づかなかった人の画面: 鬼のニヤニヤ顔
		# (2人は近くで向かい合うので、見ている本人の体はカメラの前をさえぎらないように映さない)
		_set_viewer_hidden(me == _ms["oni"], me == _ms["loser"])
		var f: Array = lf if me == _ms["oni"] else of
		var target: Vector3 = f[0]
		var dir: Vector3 = f[1]
		_top_cam.fov = 40.0
		# (少し下から見上げる: 鬼の帽子のつばで目がかくれないように)
		_top_cam.look_at_from_position(target + dir * 0.85 + Vector3(0, -0.14, 0), target + Vector3(0, 0.02, 0))
		return
	_set_viewer_hidden(false, false)
	# 2人を横から: 2人を結ぶ線の真横から、2人とも入る距離で(部屋の内側になる向きから)
	var mid: Vector3 = ((lf[0] as Vector3) + (of[0] as Vector3)) / 2.0
	var d: Vector3 = (of[0] as Vector3) - (lf[0] as Vector3)
	d.y = 0.0
	if d.length() < 0.05:
		d = Vector3(mid.x, 0.0, mid.z)
	var side := d.cross(Vector3.UP).normalized()
	var dist := clampf(d.length() * 1.3 + 1.1, 2.0, 4.5)
	# どちら側から映すかは、はじめに1回だけ決める(途中で反対側へ飛ばないように)
	if not _ms.has("cam_side"):
		_ms["cam_side"] = -1.0 if (mid + side * dist).length() > (mid - side * dist).length() else 1.0
	side *= float(_ms["cam_side"])
	_top_cam.fov = 45.0
	_top_cam.look_at_from_position(mid + side * dist + Vector3(0, 0.35, 0), mid + Vector3(0, -0.15, 0))


## 顔の位置(両目のまん中)と、顔の向き(水平)
func _face_point(m: CharacterModel) -> Array:
	var head := m.bone_world("DEF-head").origin
	var target := head + Vector3(0, CharacterModel.HEAD_LIFT, 0)
	var face := -m.global_transform.basis.z
	var eyes := m.eye_points()
	if eyes.size() > 0:
		var c := Vector3.ZERO
		for e in eyes:
			c += e
		target = c / float(eyes.size())
		face = target - head
	face.y = 0.0
	face = face.normalized() if face.length() > 0.001 else Vector3.FORWARD
	return [target, face]


## 顔のアップの間だけ、見ている本人(鬼か、気づかなかった人)の体を隠す
func _set_viewer_hidden(oni_hidden: bool, loser_hidden: bool) -> void:
	if _ms.is_empty():
		return
	var oni := _actor_nodes.get(_ms["oni"]) as Node3D
	var ln := _actor_nodes.get(_ms["loser"]) as Node3D
	if oni and oni.visible == oni_hidden:
		oni.visible = not oni_hidden
	if ln and ln.visible == loser_hidden:
		ln.visible = not loser_hidden


## 顔のアップ・2人を横から見るのをやめて、席のカメラと名札に戻す
func _end_close_up() -> void:
	_set_viewer_hidden(false, false)
	if _seat_cam:
		_seat_cam.make_current()
	if _overlay:
		_overlay.visible = visible


## 見逃した人の位置(とぼとぼ歩く途中・真ん中に座ったあと)と向き
func _apply_missed_pos(a: GameState.Actor, node: Node3D) -> void:
	if not _missed_sit.has(a.id):
		return
	var p: Vector3 = _missed_sit[a.id]
	if _ms.has("walking") and _ms["loser"] == a.id:
		var dir: Vector3 = (_ms["walk_to"] as Vector3) - (_ms["walk_from"] as Vector3)
		node.rotation.y = atan2(-dir.x, -dir.z)
	else:
		# 真ん中で、もとの席の方を向いて座る
		node.rotation.y = atan2(p.x, p.z) + PI
	node.position = p


## 頭から魂がふわっと抜ける(白いおばけの形が、ゆれながら上へのぼって消える)
func _spawn_soul(id: int) -> void:
	var m := _actor_nodes.get(id) as CharacterModel
	if m == null:
		return
	var soul := Node3D.new()
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	var hm := Toon.mesh(head, Color(1, 1, 1), 0.02)
	soul.add_child(hm)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.12
	tail.bottom_radius = 0.0
	tail.height = 0.28
	var tm := Toon.mesh(tail, Color(1, 1, 1), 0.02)
	tm.position = Vector3(0, -0.16, 0)
	tm.rotation.z = 0.3
	soul.add_child(tm)
	add_child(soul)
	var start := m.bone_world("DEF-head").origin + Vector3(0, 0.3, 0)
	soul.position = start
	var tw := soul.create_tween()
	tw.set_parallel(true)
	tw.tween_property(soul, "position", start + Vector3(0.15, 1.1, 0), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(soul, "rotation:z", 0.4, 0.8).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(soul, "scale", Vector3.ZERO, 0.3)
	tw.chain().tween_callback(soul.queue_free)


## お手つきの演出: ズッコケている間はもとの席の場所、そのあと真ん中まで歩く(状態の位置は、もう真ん中)
func _apply_out_anim(a: GameState.Actor, node: Node3D, delta: float) -> void:
	if not _out_anim.has(a.id):
		return
	if a.role != GameState.Role.OUT:
		_out_anim.erase(a.id)
		return
	var an: Dictionary = _out_anim[a.id]
	an["t"] = float(an["t"]) + delta
	var t: float = an["t"]
	var from: Vector3 = an["from"]
	var to: Vector3 = an["to"]
	var walk_start := OUT_FALL_TIME + OUT_RISE_TIME + float(an.get("d", 0.0))
	if t < walk_start:
		node.position = from
		return
	var dist := from.distance_to(to)
	var k := clampf((t - walk_start) * OUT_WALK_SPEED / maxf(dist, 0.01), 0.0, 1.0)
	if k >= 1.0:
		_out_anim.erase(a.id)
		return
	node.position = from.lerp(to, k)
	# 歩く向きを向く
	var dir := to - from
	node.rotation.y = atan2(-dir.x, -dir.z)


## 姿勢: 座っている人は座る、追いかけっこ中は走る、鬼は歩く(止まっていれば立つ)
func _pose_of(state: GameState, a: GameState.Actor) -> String:
	# 見逃しでトントンされた人: 立ち上がって振り向く
	if _ms_forced_look(a.id):
		return "idle"
	# 見逃した人: 演出の終わりにとぼとぼ歩いて、真ん中で体育座り
	if _missed_sit.has(a.id):
		return "walk" if _ms.has("walking") and _ms["loser"] == a.id else "floor"
	if a.role == GameState.Role.SEATED:
		# 海辺では、砂に直接体育座り
		return "floor" if _beach else "sit"
	if a.role == GameState.Role.OUT:
		# お手つきの演出中: ズッコケている間は立った姿、そのあと真ん中まで歩く
		if _out_anim.has(a.id):
			var t: float = _out_anim[a.id]["t"]
			if t < OUT_FALL_TIME + OUT_RISE_TIME + float(_out_anim[a.id].get("d", 0.0)):
				return "idle"
			return "walk"
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
	# 見逃しの演出: 鬼はニヤニヤ、気づかなかった人は気まずい顔
	var ms_expr := _ms_expression(a.id)
	if ms_expr != "":
		expr = ms_expr
	# 手下の発表: 手下はニヤッ、バレバレなら放心
	var rf: String = _reveal_faces.get(a.id, "")
	if rf == "smirk":
		expr = CharacterModel.SMIRK
	elif rf == "dazed":
		expr = CharacterModel.NORMAL
	# 称号発表・記念写真の顔
	var cf := _ceremony_face(a.id)
	if cf != "":
		expr = cf
		rf = ""
	model.set_expression(expr)
	# お手つきの回数で、顔がだんだん崩れていく(3回目は放心)
	# お手つきで抜けた人は放心の顔(ズッコケてから、体育座りしている間も)
	var dazed := (_dazed.has(a.id) or a.otetsuki_count >= GameConfig.OTETSUKI_DAZED_COUNT or a.role == GameState.Role.OUT \
			or _ms_dazed(a.id) or rf == "dazed") and cf == ""
	model.set_fluster(CharacterModel.FLUSTER_MAX if dazed else mini(a.otetsuki_count, 2))
	# 振り向いた瞬間にピョンと跳ねる
	if a.looking_back and not _was_looking.get(a.id, false):
		model.hop()
		# 振り向く「バッ!」(ほかの人は、その場所から小さく聞こえる。自分は押した瞬間に main が「ザッ…」を鳴らす)
		if a.id != state.local_player_id:
			_play_at(a, "look", -12.0)
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


## 落とし物の部品(好きな形)を置く
func _item_mesh(mesh: Mesh, pos: Vector3, color: Color, outline: float, rot: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := Toon.mesh(mesh, color, outline)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale_v
	_handkerchief.add_child(mi)
	return mi


## 上履き: 赤いゴム底、白い布の本体、丸い青いゴムのつま先、甲のゴムバンド、足を入れる口、かかとのつまみと名前の布
## (スタンプの絵と同じ色。つま先は -Z)
func _build_shoe() -> void:
	# (小さいので、ふちどりは細めにする。角のある形はふちどりにすき間ができるので、丸い形で作る)
	var line := 0.018
	# 赤いゴム底(平たくつぶした長い丸)
	var sole := CapsuleMesh.new()
	sole.radius = 0.125
	sole.height = 0.52
	sole.radial_segments = 16
	sole.rings = 4
	_item_mesh(sole, Vector3(0, 0.022, 0), Color("D9483B"), line, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.18))
	# 白い布の本体(かかと側。ぽってりした長い丸)
	var body := CapsuleMesh.new()
	body.radius = 0.112
	body.height = 0.36
	body.radial_segments = 16
	body.rings = 4
	_item_mesh(body, Vector3(0, 0.085, 0.07), Color.WHITE, line, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.55))
	# 丸い青いゴムのつま先
	var toe := SphereMesh.new()
	toe.radius = 0.12
	toe.height = 0.24
	toe.radial_segments = 16
	toe.rings = 8
	_item_mesh(toe, Vector3(0, 0.075, -0.13), COLOR_SHOE_RUBBER, line, Vector3.ZERO, Vector3(0.96, 0.5, 1.05))
	# 甲のゴムバンド(本体をぐるっと巻く青い帯)
	var band := CylinderMesh.new()
	band.top_radius = 0.118
	band.bottom_radius = 0.118
	band.height = 0.05
	band.radial_segments = 16
	_item_mesh(band, Vector3(0, 0.085, -0.005), COLOR_SHOE_RUBBER, 0.01, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.57))
	# 足を入れる口(内側は灰色)
	var mouth := CylinderMesh.new()
	mouth.top_radius = 0.085
	mouth.bottom_radius = 0.085
	mouth.height = 0.008
	mouth.radial_segments = 16
	_item_mesh(mouth, Vector3(0, 0.146, 0.1), Color("6A6A74"), 0.0, Vector3.ZERO, Vector3(0.78, 1.0, 1.15))
	# かかとのつまみ(青)と、名前を書く白い布(黒い線)
	var tab := CapsuleMesh.new()
	tab.radius = 0.02
	tab.height = 0.07
	_item_mesh(tab, Vector3(0, 0.14, 0.235), COLOR_SHOE_RUBBER, 0.01)
	_item_part(Vector3(0.1, 0.045, 0.006), Vector3(0, 0.085, 0.245), Color("FFFDF5"), 0.006)
	_item_part(Vector3(0.07, 0.006, 0.004), Vector3(0, 0.085, 0.25), Color("3A3633"), 0.0)


## 学校の机: うすい木目色の天板(ふちは濃い木)、灰色の金属の脚と横の棒、天板の下の物入れ、横のかばんのフック
func _build_desk() -> void:
	var metal := Color("8E989F")
	# 天板
	_item_part(Vector3(0.6, 0.03, 0.45), Vector3(0, 0.685, 0), Color("EBD7AE"), ITEM_OUTLINE, 0.01)
	_item_part(Vector3(0.61, 0.02, 0.46), Vector3(0, 0.662, 0), Color("B07A4A"), 0.02, 0.006)
	# 物入れ(天板の下の、前があいた箱)
	_item_part(Vector3(0.52, 0.012, 0.36), Vector3(0, 0.57, 0.02), metal, 0.02)
	_item_part(Vector3(0.52, 0.09, 0.012), Vector3(0, 0.615, 0.2), metal, 0.02)
	for sx in [-0.255, 0.255]:
		_item_part(Vector3(0.012, 0.09, 0.36), Vector3(sx, 0.615, 0.02), metal, 0.02)
	# 中に入っている教科書(すこし見える)
	_item_part(Vector3(0.2, 0.04, 0.26), Vector3(-0.1, 0.6, 0.03), Color("6A92D0"), 0.012, 0.005)
	_item_part(Vector3(0.18, 0.03, 0.24), Vector3(0.12, 0.592, 0.04), Color("E5B94E"), 0.012, 0.005)
	# 脚(四すみ)と、下の横の棒、ゴムの足
	for sx in [-0.27, 0.27]:
		for sz in [-0.19, 0.19]:
			_item_part(Vector3(0.03, 0.64, 0.03), Vector3(sx, 0.33, sz), metal, 0.02, 0.006)
			_item_part(Vector3(0.04, 0.02, 0.04), Vector3(sx, 0.01, sz), Color("3A3633"), 0.012, 0.006)
		_item_part(Vector3(0.025, 0.025, 0.38), Vector3(sx, 0.14, 0), metal, 0.015)
	_item_part(Vector3(0.54, 0.025, 0.025), Vector3(0, 0.14, 0.19), metal, 0.015)
	# かばんのフック(横)
	_item_part(Vector3(0.012, 0.05, 0.012), Vector3(0.29, 0.6, 0.0), Color("C9CED6"), 0.008)
	_item_part(Vector3(0.03, 0.012, 0.012), Vector3(0.302, 0.58, 0.0), Color("C9CED6"), 0.008)


## 教卓: 木の箱(前の板は一段明るい色で、ふちどりの飾り)、少しはみ出す天板、下の台。
## 上に出席簿と、チョークの箱
func _build_podium() -> void:
	var wood := Color("8B5A33")
	_item_part(Vector3(0.9, 0.08, 0.5), Vector3(0, 0.04, 0), wood.darkened(0.25), ITEM_OUTLINE, 0.015)
	_item_part(Vector3(0.84, 0.86, 0.44), Vector3(0, 0.5, 0), wood, ITEM_OUTLINE, 0.02)
	# 前の板(-Z)と、ふちどり
	_item_part(Vector3(0.68, 0.62, 0.02), Vector3(0, 0.5, -0.225), wood.lightened(0.15), 0.02, 0.008)
	_item_part(Vector3(0.56, 0.5, 0.02), Vector3(0, 0.5, -0.232), wood.lightened(0.05), 0.015, 0.006)
	# 前の板の、学校のマーク(丸い金の飾り)
	var badge := CylinderMesh.new()
	badge.top_radius = 0.07
	badge.bottom_radius = 0.07
	badge.height = 0.012
	badge.radial_segments = 16
	_item_mesh(badge, Vector3(0, 0.58, -0.245), Color("E9B949"), 0.012, Vector3(PI / 2.0, 0, 0))
	# 天板(少しはみ出す)
	_item_part(Vector3(0.98, 0.05, 0.58), Vector3(0, 0.955, 0), Color("B67A45"), ITEM_OUTLINE, 0.015)
	# 出席簿(青い表紙)と、チョークの箱(白いチョーク)
	_item_part(Vector3(0.26, 0.03, 0.34), Vector3(-0.2, 0.995, 0.02), Color("3F6FD0"), 0.015, 0.006)
	_item_part(Vector3(0.24, 0.022, 0.32), Vector3(-0.2, 0.99, 0.02), Color("FFFDF5"), 0.0)
	_item_part(Vector3(0.16, 0.05, 0.08), Vector3(0.22, 1.005, -0.08), Color("F2C14E"), 0.015, 0.006)
	for k in 3:
		_item_part(Vector3(0.025, 0.025, 0.07), Vector3(0.18 + k * 0.035, 1.04, -0.08), Color.WHITE, 0.008)


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
## size: 文字の大きさの倍率(近くから映すときは小さく)
func _pop(actor_id: int, text: String, color: Color, size: float = 1.0) -> void:
	var m := _actor_nodes.get(actor_id) as CharacterModel
	if m == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font = HudFont.get_font()
	l.font_size = 140
	l.pixel_size = 0.006 * size
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
	# (本人だけのお知らせ・蜃気楼のニセは、ほかの人の画面では何もしない。ホストの画面にも全部届くので)
	if _room_state and e.get("type") in ["pranked", "mirage_fake"]:
		var me := _room_state.local_player_id
		if e.get("private_to", me) != me or me in e.get("not_for", []):
			return
	match e.get("type"):
		"otetsuki":
			# (音と文字は、すぐあとの「out」で「ガーン!」を出す)
			_oops_until[e["actor"]] = _clock + 1.5
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
		"event":
			# 1試合に1回のイベント
			match str(e.get("kind", "")):
				"teacher":
					AudioDirector.sfx("shh", -2.0)
				"gust":
					AudioDirector.sfx("wind_gust", -2.0)
				"chime":
					AudioDirector.sfx("chime", 0.0)
				"gull":
					AudioDirector.sfx("gull", -3.0)
					_start_gull(e.get("pos", Vector3.ZERO))
		"lightning":
			# 雷: ピシャッ、ゴロゴロ…(夜の教室)
			AudioDirector.sfx("thunder", -3.0)
		"lights_on":
			AudioDirector.sfx("power_on", -3.0)
		"castle_crumble":
			_castle_crumble(e.get("pos", Vector3.ZERO), float(e.get("size", 1.0)))
		"out":
			# ハズレ: 「ガーン!」。ズッコケてから、とぼとぼ真ん中まで歩いて体育座り(みんなの画面で見える)
			var who: int = e["actor"]
			_pop(who, tr("ガーン!"), Color("6EA8F0"))
			_play_actor(who, "gaan", -2.0, -10.0)
			var node: Node3D = _actor_nodes.get(who)
			var a := _room_state.get_actor(who) if _room_state else null
			if node and a:
				# 本人の画面では、まず顔を大きく映してから崩れ落ちる(そのぶん遅らせる)
				var d := OUT_FACE_TIME if who == _room_state.local_player_id else 0.0
				_out_anim[who] = {"t": 0.0, "from": node.position, "to": a.position, "d": d}
			if who == _room_state.local_player_id and Profile.screen_shake:
				_shake_left = SHAKE_TIME
			get_tree().create_timer(OUT_FALL_TIME + OUT_RISE_TIME).timeout.connect(func() -> void: _play_actor(who, "trudge", -6.0, -16.0))
		"found":
			# 当たり: 短いファンファーレ。ほかの人の画面では、その人の頭の上に「あったー!!」
			var who: int = e["actor"]
			_play_actor(who, "found", -3.0, -12.0)
			if _room_state and who != _room_state.local_player_id:
				_pop(who, tr("あったー!!"), Color("FFB020"))
		"milk":
			_surprise_until[e["target"]] = _clock + 1.2
			if _beach:
				# 水鉄砲: かけた瞬間に「ピューッ!」、かけられた人に「バシャッ」。頭の上には「見えない!」のマーク(_build_milk_splash)
				_play_actor(e.get("sender", -1), "water_pyuu", -2.0, -5.0)
				var victim: int = e["target"]
				get_tree().create_timer(0.35).timeout.connect(func() -> void:
					_play_actor(victim, "bashaa", -2.0, -5.0)
					_pop(victim, tr("バシャッ!"), Color("BFE6FF")))
				var wet := _actor_nodes.get(e["target"]) as CharacterModel
				if wet:
					wet.shiver(0.9)
				_shiver_next[e["target"]] = _clock + 2.2
			elif _night:
				# 夜の教室: カメラのフラッシュ「パシャッ!」
				_pop(e["target"], tr("パシャッ!"), Color("FFE58A"))
				_play_actor(e["target"], "flash_pasha", -2.0, -5.0)
			else:
				# 教室: 黒板消しでポンポンポン(チョークの粉の煙)
				_pop(e["target"], tr("ポンポン!"), Color.WHITE)
				_play_actor(e["target"], "eraser_pon", -2.0, -5.0)
		"dropped", "rustle", "mirage_fake":
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
	var sand := "_sand" if _beach else ""
	var want_stream := Sfx.get_stream(("run_step" if running else "step") + sand)
	if _step_player.stream != want_stream:
		_step_player.stream = want_stream
	# 鬼がうしろに近いほど、歩く足音を少し大きく(ドキドキと同じ強さ)
	_step_player.volume_db = GameConfig.RUN_STEP_VOLUME_DB if running \
			else GameConfig.FOOTSTEP_VOLUME_DB + GameConfig.ONI_NEAR_STEP_BOOST_DB * _heart_level
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
	if _curtain_player == null or _beach:
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

## 空の色(停電のときは暗くする)
var _env: Environment
## 窓から差しこむ日差し(停電のときは消す)
var _window_lights: Array[MeshInstance3D] = []
## 壁の文字(黒板・学級目標など。停電のときは同じ暗さにする)と、もとの色 [Label3D, modulate, outline_modulate]
var _wall_labels: Array = []
var _wall_bright := 1.0
var _sky_color := Color.WHITE
const DARK_SKY := Color(0.02, 0.03, 0.08)


func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = BeachStage.COLOR_SKY if _beach else (COLOR_NIGHT_SKY if _night else GameConfig.COLOR_SKY)
	_sky_color = env.background_color
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


## 海辺: 砂浜・海・飾り(BeachStage)。転んだ体が乗る床(物理演算用)も置く
func _build_beach() -> void:
	_batch = StaticBatch.new()
	BeachStage.build_world(self)
	_batch.build(self)
	_batch = null
	BeachStage.build_props(self)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << (CharacterModel.FLOOR_LAYER - 1)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)


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
	# (夜は、青白い月の光の帯)
	mat.albedo_color = Color(0.72, 0.82, 1.0, 0.3) if _night else Color(1.0, 0.98, 0.82, 0.28)
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
		_window_lights.append(mi)


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
	# 時計の針: 1ラウンドで10分進む(1時間目の始まりから。夜の教室は夜の8時から)
	var minutes := (0.0 if _night else 30.0) + round_no * 10.0
	var hour := 8.0 if _night else 9.0
	for hand in [[0.3, 0.03, minutes / 60.0 * TAU], [0.2, 0.045, (hour + minutes / 60.0) / 12.0 * TAU]]:
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
		_part(Vector3(1.9, 1.6, 0.06), Vector3(x, 2.3, z + 0.03), COLOR_NIGHT_GLASS if _night else COLOR_GLASS, 0.0, wall)
		# 窓の外: 校庭(緑の地面と土のグラウンド)と木。夜は、暗い校庭と木の影に、月と星
		var field := COLOR_FIELD.darkened(0.6) if _night else COLOR_FIELD
		var tree := COLOR_TREE.darkened(0.65) if _night else COLOR_TREE
		_part(Vector3(1.9, 0.42, 0.01), Vector3(x, 1.71, z + 0.065), field, 0.0, wall)
		_part(Vector3(1.9, 0.12, 0.01), Vector3(x, 1.56, z + 0.066), COLOR_GROUND.darkened(0.6) if _night else COLOR_GROUND, 0.0, wall)
		var tx: float = x + (0.45 if int(x) % 2 == 0 else -0.5)
		_part(Vector3(0.08, 0.32, 0.01), Vector3(tx, 2.0, z + 0.067), COLOR_TRUNK.darkened(0.6) if _night else COLOR_TRUNK, 0.0, wall)
		_part(Vector3(0.5, 0.42, 0.01), Vector3(tx, 2.32, z + 0.068), tree, 0.008, wall)
		_part(Vector3(0.34, 0.3, 0.01), Vector3(tx - 0.62, 2.12, z + 0.068), tree.lightened(0.08), 0.008, wall)
		if _night:
			_build_night_window(wall, x, z)
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


## 夜の窓の外: 星(小さな光る点)、まん中の窓には丸い月(にっこり顔)、雷のときだけ出る稲光。
## 月と星は暗くならないように、光る材質(明るさの計算をしない)
func _build_night_window(wall: Node3D, x: float, z: float) -> void:
	var star_mat := _glow_material(Color("FFF7CF"))
	var stars := [Vector2(-0.7, 2.95), Vector2(-0.35, 2.75), Vector2(0.15, 3.0), Vector2(0.62, 2.8), Vector2(-0.1, 2.55), Vector2(0.8, 2.5)]
	for i in stars.size():
		var st: Vector2 = stars[i]
		var sz := 0.035 if i % 2 == 0 else 0.025
		var q := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz, sz, 0.01)
		q.mesh = bm
		q.material_override = star_mat
		q.position = Vector3(x + st.x + fmod(x * 0.37, 0.2), st.y, z + 0.07)
		q.rotation.z = PI / 4.0
		wall.add_child(q)
	if is_zero_approx(x):
		# 月: 丸い黄色(まわりにぼんやり光る輪)と、目を閉じたにっこり顔
		var halo := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.36
		hm.bottom_radius = 0.36
		hm.height = 0.005
		hm.radial_segments = 24
		halo.mesh = hm
		var hmat := _glow_material(Color(1.0, 0.95, 0.7, 0.25))
		hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.material_override = hmat
		halo.rotation.x = PI / 2.0
		halo.position = Vector3(0.45, 2.75, z + 0.069)
		wall.add_child(halo)
		var moon := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.24
		mm.bottom_radius = 0.24
		mm.height = 0.01
		mm.radial_segments = 24
		moon.mesh = mm
		moon.material_override = _glow_material(COLOR_MOON)
		moon.rotation.x = PI / 2.0
		moon.position = Vector3(0.45, 2.75, z + 0.072)
		wall.add_child(moon)
		var face_mat := _glow_material(Color("C9A84A"))
		for ex in [-0.08, 0.08]:
			var eye := MeshInstance3D.new()
			var em := BoxMesh.new()
			em.size = Vector3(0.07, 0.015, 0.01)
			eye.mesh = em
			eye.material_override = face_mat
			eye.position = Vector3(0.45 + ex, 2.79, z + 0.08)
			wall.add_child(eye)
		var smile := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.09, 0.015, 0.01)
		smile.mesh = sm
		smile.material_override = face_mat
		smile.position = Vector3(0.45, 2.68, z + 0.08)
		wall.add_child(smile)
	# 稲光(ギザギザの光の線。雷のときだけ出す)
	var bolt := Node3D.new()
	var bolt_mat := _glow_material(Color("FFFBE0"))
	var pts := [Vector2(-0.3, 3.05), Vector2(-0.1, 2.7), Vector2(-0.28, 2.55), Vector2(0.05, 2.1), Vector2(-0.12, 1.95), Vector2(0.15, 1.6)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.045, a.distance_to(b) + 0.03, 0.01)
		seg.mesh = bm2
		seg.material_override = bolt_mat
		seg.position = Vector3(x + (a.x + b.x) / 2.0 + (0.3 if x < 0.0 else -0.2), (a.y + b.y) / 2.0, z + 0.075)
		seg.rotation.z = atan2(b.x - a.x, a.y - b.y)
		bolt.add_child(seg)
	bolt.visible = false
	wall.add_child(bolt)
	_bolts.append(bolt)


## 明るさの計算をしない光る材質(夜でも暗くならない)
func _glow_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## 夜の教室の明るさ(毎フレーム): 全体は暗めの青、窓側は月の光で明るい。雷の一瞬だけ、部屋全体が明るくなる。
## 撮影モードからも呼ぶ
func apply_night_light(state: GameState) -> void:
	if not _night:
		return
	var flash := 0.0
	var since := GameConfig.LIGHTNING_TIME - state.lightning_left
	if state.lightning_left > 0.0:
		# ピカッ・ピカッ(2回光って、そのあと少しずつ暗くなる)
		if since < 0.1 or (since > 0.2 and since < 0.45):
			flash = 1.0
		elif since >= 0.45:
			flash = clampf(state.lightning_left / (GameConfig.LIGHTNING_TIME - 0.45), 0.0, 1.0)
	# 称号発表・記念写真は、夜の教室でも撮影用のライトがついた明るさ
	if _cer_mode != "":
		flash = 1.0
	var bright := lerpf(GameConfig.NIGHT_BRIGHTNESS, 1.0, flash)
	Toon.set_night(lerpf(GameConfig.NIGHT_TINT, GameConfig.NIGHT_TINT * 0.4, flash))
	Toon.set_darkness(bright, GameConfig.NIGHT_MOON_CENTER, GameConfig.NIGHT_MOON_RADIUS,
			lerpf(GameConfig.NIGHT_MOON_BRIGHTNESS, 1.0, flash))
	if _env:
		var sky := COLOR_NIGHT_SKY.lerp(Color(0.78, 0.84, 1.0), flash * 0.7)
		if _env.background_color != sky:
			_env.background_color = sky
	for b in _bolts:
		var show := state.lightning_left > 0.0 and since < 0.5 and flash > 0.5
		if b.visible != show:
			b.visible = show
	# 壁の文字(黒板の日付など)も少し暗く(雷のときは明るく)
	var wb := lerpf(0.7, 1.0, flash)
	if not is_equal_approx(wb, _night_label_bright):
		_night_label_bright = wb
		for wl in _wall_labels:
			# (ラウンドのあいだに消えた文字もあるので、型をつける前に確かめる)
			if not is_instance_valid(wl[0]):
				continue
			var lab: Label3D = wl[0]
			var m: Color = wl[1]
			var o: Color = wl[2]
			lab.modulate = Color(m.r * wb, m.g * wb, m.b * wb, m.a)
			lab.outline_modulate = Color(o.r * wb, o.g * wb, o.b * wb, o.a)


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


func _set_hidden_chair(idx: int) -> void:
	if idx == _hidden_chair:
		return
	if _hidden_chair >= 0 and _hidden_chair < _chairs.size() and is_instance_valid(_chairs[_hidden_chair]):
		_chairs[_hidden_chair].visible = true
	_hidden_chair = idx
	if idx >= 0 and idx < _chairs.size() and is_instance_valid(_chairs[idx]):
		_chairs[idx].visible = false


func _build_chair(pos: Vector3, yaw: float) -> Node3D:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation.y = yaw
	var wood := Color(0.55, 0.35, 0.2)
	var metal := Color(0.4, 0.4, 0.42)
	# 座面と背もたれ(背もたれは後ろ側 +Z)と、4本の脚。
	# 部品ごとに描くと椅子1つで12回描くので、色ごとに1つの形にまとめる(木と金属で、塗りと輪郭線の4回)
	var batch := StaticBatch.new()
	batch.add_box(Vector3(0.5, 0.05, 0.5), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), wood, GameConfig.OUTLINE_WIDTH)
	batch.add_box(Vector3(0.5, 0.5, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0.28)), wood, GameConfig.OUTLINE_WIDTH)
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			batch.add_box(Vector3(0.04, 0.45, 0.04), Transform3D(Basis.IDENTITY, Vector3(x, 0.225, z)), metal, GameConfig.OUTLINE_WIDTH)
	batch.build(chair)
	add_child(chair)
	return chair


## 仮のキャラクター(体・顔・表情は CharacterModel)
func _build_character(a: GameState.Actor, is_self: bool) -> Node3D:
	var model := CharacterModel.new()
	model.name = "Actor%d" % a.id
	# ボットの性格は、⚙メニューでオンにしたときだけ名前の横に出す
	var shown_name := Locale.actor_name(a.display_name, Profile.show_personality)
	model.build(a.color, shown_name, HudFont.get_font())
	model.set_accessories(a.accessories)
	if is_self:
		# 自分の体は、座っているときの自分のカメラには映さない。自分の名前は出さない
		model.set_layers(1 << (SELF_LAYER - 1))
		model.set_name_visible(false)
	return model


func _build_oni_shadow() -> void:
	# 人の形の影(胴と頭。ふちはぼんやり)を、床に置いた板に貼る。頭は板の -Z の側
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.8)
	_oni_shadow_mat = StandardMaterial3D.new()
	_oni_shadow_mat.albedo_color = Color(0, 0, 0, 0)
	_oni_shadow_mat.albedo_texture = _shadow_texture()
	_oni_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_oni_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_oni_shadow = MeshInstance3D.new()
	_oni_shadow.mesh = plane
	_oni_shadow.material_override = _oni_shadow_mat
	_oni_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_oni_shadow.visible = false
	add_child(_oni_shadow)


## 人の形の影の絵: 上(v = 0)が頭、下が足もと。肩のある胴と丸い頭、ふちはやわらかくぼかす。足もとはうすく消える
static var _shadow_tex: Texture2D


func _shadow_texture() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var w := 64
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		for x in w:
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0
			# 頭(丸)
			var dh := Vector2(u * 1.0, (v - 0.13) * 2.6).length() - 0.3
			# 胴(肩が広く、足もとへ細くなる)
			var half := lerpf(0.62, 0.36, clampf((v - 0.3) / 0.7, 0.0, 1.0))
			if v < 0.3:
				half = lerpf(0.3, 0.62, clampf((v - 0.22) / 0.08, 0.0, 1.0))
			var db := absf(u) - half
			if v < 0.22:
				db = 1.0
			var d := minf(dh, db)
			var a := 1.0 - smoothstep(-0.12, 0.08, d)
			# 足もと(自分に近い側)は、うすく消える
			a *= 1.0 - smoothstep(0.75, 1.0, v)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


## 鬼の影: 座っている自分の後ろに鬼が近づくと、自分の前の床に影がのびる(人の形。鬼のいる左右に合わせて少しななめ)。
## 近いほど濃く大きい。鬼が立ち止まれば影も止まる(後ろが見えなくても気配がわかる)
func _update_oni_shadow(state: GameState) -> void:
	var me := state.get_local_player()
	var oni := state.get_actor(state.oni_id)
	_oni_near = 0.0
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
	_oni_near = near
	_oni_shadow.visible = true
	# 鬼から自分の前へのびる向き(板の +Z が鬼の側、頭は前)
	var toward := atan2(rel.x, rel.z)
	var side := clampf(rel.dot(right) / maxf(dist, 0.01), -1.0, 1.0)
	_oni_shadow.rotation.y = lerp_angle(me.yaw, toward, 0.5)
	# (近いほど、自分の席にかかるように大きく・長く。はっきり分かるように)
	var length := 0.95 + 0.6 * near
	_oni_shadow.scale = Vector3(0.8 + 0.45 * near, 1.0, length)
	# 自分の前(輪の内側)の床に、頭が前・足もとが自分の側になるように置く
	_oni_shadow.position = me.position - back * (0.5 + 0.9 * length) + right * side * 0.35 + Vector3(0, 0.03, 0)
	_oni_shadow_mat.albedo_color = Color(0, 0, 0, GameConfig.ONI_SHADOW_ALPHA * (0.4 + 0.6 * near))


## 鬼がうしろに来たときのドキドキ(影がのびるのと同じとき): BGM の下に心臓の「ドクン、ドクン」。
## 近いほど速く・大きく。離れたら少しずつ消える。鬼が歩いて回っている間だけ(追いかけっこ・結果では鳴らさない)
func _update_heart(state: GameState, delta: float) -> void:
	# (座っている本人の画面だけ。鬼のとき・追いかけっこ中・お手つきで真ん中にいるときは 0。_oni_near は座っている人だけ)
	var walking := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	var target := _oni_near if walking else 0.0
	var rate := GameConfig.HEART_RISE if target > _heart_level else GameConfig.HEART_FALL
	_heart_level = move_toward(_heart_level, target, rate * delta)
	# 心臓の音そのもの(速さ・大きさ・BGM を下げる)は AudioDirector が鳴らす
	if AudioDirector.instance:
		AudioDirector.instance.set_heart(_heart_level)


## 鬼がうしろにいるドキドキの強さ(0〜1。画面のふちを暗くするのに使う)
func oni_near_level() -> float:
	return _heart_level


## 頭からかぶった牛乳: 白いかたまりと、顔の横にたれるしずく(輪郭線つき)
func _build_milk_splash() -> Node3D:
	var root := Node3D.new()
	if _night:
		# 夜の教室: フラッシュでまぶしい人の頭のまわりを、黄色い星がくるくる回る
		var star_mat := _glow_material(Color("FFE066"))
		for k in 3:
			var star := Node3D.new()
			var ang := TAU * float(k) / 3.0
			star.position = Vector3(sin(ang) * 0.26, 0.42, cos(ang) * 0.26)
			for r in [0.0, PI / 2.0]:
				var bar := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.11, 0.035, 0.035)
				bar.mesh = bm
				bar.material_override = star_mat
				bar.rotation.z = r + PI / 4.0
				star.add_child(bar)
			root.add_child(star)
		root.set_meta("spin", true)
		root.visible = false
		return root
	if _beach:
		# 海辺: 水鉄砲の水(水色。画面にかかる水と同じ色)が頭にかかる
		var col := Color(MilkArt.WATER_WHITE)
		var cap := SphereMesh.new()
		cap.radius = 0.2
		cap.height = 0.16
		cap.radial_segments = 14
		cap.rings = 6
		var top := Toon.mesh(cap, col, 0.02)
		top.position = Vector3(0, 0.36, 0)
		root.add_child(top)
		for k in 4:
			var drop := SphereMesh.new()
			drop.radius = 0.045
			drop.height = 0.12
			drop.radial_segments = 8
			drop.rings = 4
			var d := Toon.mesh(drop, col, 0.015)
			var ang := TAU * (float(k) + 0.25) / 4.0
			d.position = Vector3(sin(ang) * 0.21, 0.24 - 0.05 * float(k % 2), cos(ang) * 0.21)
			root.add_child(d)
		# 頭の上に「見えない!」のマーク(まわりの人は、その人がいま見えていないと分かる)
		var mark := Label3D.new()
		mark.text = tr("見えない!")
		mark.font = HudFont.get_font()
		mark.font_size = 64
		mark.pixel_size = 0.0055
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.modulate = Color("2F7FD0")
		mark.outline_size = 12
		mark.outline_modulate = Color.WHITE
		mark.no_depth_test = true
		mark.position = Vector3(0, 0.66, 0)
		root.add_child(mark)
		# びしょぬれ: 頭と体から、しずくがぽたぽた落ち続ける
		var drip := CPUParticles3D.new()
		drip.amount = 14
		drip.lifetime = 0.9
		drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		drip.emission_sphere_radius = 0.24
		drip.direction = Vector3(0, -1, 0)
		drip.spread = 15.0
		drip.gravity = Vector3(0, -6.0, 0)
		drip.initial_velocity_min = 0.2
		drip.initial_velocity_max = 0.6
		var dm := SphereMesh.new()
		dm.radius = 0.025
		dm.height = 0.06
		dm.radial_segments = 6
		dm.rings = 3
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.55, 0.8, 1.0)
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.material = dmat
		drip.mesh = dm
		drip.position = Vector3(0, 0.1, 0)
		root.add_child(drip)
	else:
		# 教室: 黒板消しのチョークの粉が、頭のまわりでもくもく(白と灰色の丸いかたまり)
		for k in 6:
			var puff := SphereMesh.new()
			var r := 0.1 + 0.03 * float(k % 3)
			puff.radius = r
			puff.height = r * 1.7
			puff.radial_segments = 10
			puff.rings = 5
			var col := Color("FBFAF7") if k % 2 == 0 else Color("E3DED6")
			var p := Toon.mesh(puff, col, 0.02)
			var ang := TAU * float(k) / 6.0
			p.position = Vector3(sin(ang) * 0.2, 0.3 + 0.08 * float(k % 2), cos(ang) * 0.2)
			root.add_child(p)
		var top_puff := SphereMesh.new()
		top_puff.radius = 0.15
		top_puff.height = 0.24
		top_puff.radial_segments = 10
		top_puff.rings = 5
		var tp := Toon.mesh(top_puff, Color("FBFAF7"), 0.02)
		tp.position = Vector3(0, 0.45, 0)
		root.add_child(tp)
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
	var r := MILK_RING_RADIUS
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


## 足もとの青い丸の大きさと高さ(タップの当たり判定にも使う)
const MILK_RING_RADIUS := 0.62
const MILK_RING_Y := 0.04


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
			ring.position = Vector3(a.position.x, MILK_RING_Y, a.position.z)
			ring.rotation.y += delta * 0.6


## 牛乳がかかっている人は、頭の上に牛乳が乗っている(全員から見える)
## 水鉄砲でぬれている人が、次にぶるぶるする時刻(id -> _clock)
var _shiver_next := {}


func _update_milk(state: GameState, a: GameState.Actor, model: CharacterModel) -> void:
	# 海辺: びしょぬれの間は、ときどきぶるぶる体をふるう(まわりから見ても分かる)
	if _beach and model and state.is_milked(a) and state.phase != GameState.Phase.RESULT \
			and _clock >= float(_shiver_next.get(a.id, 0.0)):
		model.shiver(0.7)
		_shiver_next[a.id] = _clock + randf_range(1.8, 2.8)
	var milk: Node3D = _milk_nodes.get(a.id)
	if milk == null:
		return
	milk.visible = model != null and state.is_milked(a) and state.phase != GameState.Phase.RESULT
	# 海辺: びしょぬれの間は、体が少し濡れた色
	if _beach and model:
		model.set_wet(milk.visible)
	if milk.visible:
		var head := model.bone_world("DEF-head")
		var basis := model.global_transform.basis.orthonormalized()
		if milk.get_meta("spin", false):
			# フラッシュの星は、頭のまわりをくるくる回る
			basis = Basis(Vector3.UP, _clock * 3.0)
		milk.global_transform = Transform3D(basis, head.origin)


## 障害物: 状態の obstacles に合わせて出す/消す。後ろに寄せたバケツ・椅子・机と、投げられたバナナの皮
func _update_obstacles(state: GameState) -> void:
	var alive := {}
	for ob in state.obstacles:
		var id: int = ob["id"]
		alive[id] = true
		if not _obstacle_nodes.has(id):
			var n: Node3D = BeachStage.build_obstacle(str(ob["kind"])) if _beach else null
			if n == null:
				n = _build_obstacle(str(ob["kind"]))
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
	var hidden := state.phase != GameState.Phase.RESULT and state.handkerchief_on_floor and me.role == GameState.Role.SEATED \
			and state.drop_target_seat != me.seat_index \
			and not state.sees_behind(me.id, state.drop_target_seat)
	# 蜃気楼の間、蜃気楼チームには本物は見えない(終わったら全員に見える)
	if state.handkerchief_on_floor and not state.mirage_sees_real(me.id) and state.phase != GameState.Phase.RESULT:
		hidden = true
	var bits := 1 << (HIDDEN_LAYER - 1) if hidden else 1
	_set_item_layers(_handkerchief, bits)


## 落とし物の部品の見え方(中の部品まで。モナリザの目の光のように、いつも見せる部品はそのまま)
func _set_item_layers(node: Node, bits: int) -> void:
	for c in node.get_children():
		if c.get_meta("always_visible", false):
			continue
		if c is VisualInstance3D:
			c.layers = bits
		_set_item_layers(c, bits)


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
	# 砂のお城は、前で両腕にかかえる(顔が少し隠れる)
	if _beach and _item_index == 3:
		_carry_castle(m, body, back)
		return
	# 大きな物(机・教卓・バナナボート)は、紐で背中にくくりつける
	if _item_index >= 3 and not _night:
		_carry_on_back(m, body, back)
		return
	if _beach:
		_carry_beach_item(m, body, back)
		return
	if _night and _item_index > 0:
		_carry_night_item(m, body, back)
		return
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


## 大きな物を紐で背中にくくりつける: 物は背中のうしろに立てて(バナナボートは横向き)、
## 体の前には、肩から腰へのたすきがけの紐と、腰ひもが見える
func _carry_on_back(m: CharacterModel, body: Basis, back: Vector3) -> void:
	var chest := m.bone_world("DEF-spine.003").origin
	var b := body
	var depth := _item_size.z
	var height := _item_size.y
	if _beach and _item_index == 4:
		# バナナボートは長いので、横にして背負う
		b = body * Basis(Vector3.UP, PI / 2.0)
		depth = _item_size.x
	var scale_k := 0.8 if height > 0.9 else 0.9
	_handkerchief.transform = Transform3D(b.scaled(Vector3.ONE * scale_k), chest + back * (0.17 + depth * scale_k / 2.0) + Vector3(0, -height * scale_k * 0.55, 0))
	_update_straps(m, body, true)


## モナリザを脇にはさんでいる人(腕の形を変える)。運んでいないときは null
var _tucker: CharacterModel


func _set_tucker(m: CharacterModel) -> void:
	if _tucker == m:
		return
	if _tucker and is_instance_valid(_tucker):
		_tucker.set_tuck(false)
	_tucker = m
	if m:
		m.set_tuck(true)


## 背負うときの紐(体の前のたすきがけと腰ひも)。背負っていないときは隠す
var _straps: Node3D


func _update_straps(m: CharacterModel, body: Basis, show: bool) -> void:
	if _straps == null or not is_instance_valid(_straps):
		_straps = Node3D.new()
		add_child(_straps)
		var rope := Color("8B6A4A")
		for side in [-1.0, 1.0]:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.62, 0.035)
			var mi := Toon.mesh(bm, rope, 0.012)
			mi.position = Vector3(side * 0.05, -0.18, -0.2)
			mi.rotation = Vector3(0.12, 0, side * 0.55)
			_straps.add_child(mi)
		var belt := TorusMesh.new()
		belt.inner_radius = 0.2
		belt.outer_radius = 0.24
		belt.rings = 18
		belt.ring_segments = 6
		var bt := Toon.mesh(belt, rope, 0.012)
		bt.position = Vector3(0, -0.42, 0.02)
		bt.scale = Vector3(1.0, 0.6, 0.85)
		_straps.add_child(bt)
	_straps.visible = show
	if show and m:
		_straps.global_transform = Transform3D(body, m.bone_world("DEF-spine.003").origin)


## 夜の落とし物の持ち方: 懐中電灯は手に(前を照らす)、メトロノームとガイコツは胸の前に抱え、モナリザは頭の上に担ぐ
func _carry_night_item(m: CharacterModel, body: Basis, back: Vector3) -> void:
	# (落とし物の正面は +Z、キャラの正面は -Z なので、半回転して前に向ける)
	var front := body * Basis(Vector3.UP, PI)
	match _item_index:
		1:
			var hand := m.bone_world("DEF-hand.R").origin
			_handkerchief.transform = Transform3D(front, hand + Vector3(0, -0.12, 0))
		2:
			var chest := m.bone_world("DEF-spine.003").origin
			_handkerchief.transform = Transform3D(front, chest - back * 0.28 + Vector3(0, -0.32, 0))
		_:
			# モナリザとガイコツは、右の脇に抱える(モナリザは絵を外に向けて縦に、ガイコツは横にして前向きに)
			var chest := m.bone_world("DEF-spine.003").origin
			var right := body.x.normalized()
			if _item_index == 3:
				# 絵は体と腕のあいだ(脇の下にはさむ)。腕は絵の外側に下ろす(CharacterModel.set_tuck)
				_set_tucker(m)
				var shoulder := m.bone_world("DEF-upper_arm.R").origin
				# 絵は横にする(額縁の面のまわりに90度)。落とし物の原点は下の端なので、真ん中を脇の下に合わせる
				var b := (body * Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.BACK, PI / 2.0)).scaled(Vector3.ONE * 0.85)
				var center := shoulder + Vector3(0, -0.22, 0)
				_handkerchief.transform = Transform3D(b, center - b * Vector3(0, NightStage.ITEM_SIZES[3].y / 2.0, 0))
			else:
				var b2 := body * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI / 2.0)
				_handkerchief.transform = Transform3D(b2.scaled(Vector3.ONE * 0.85), chest + right * 0.25 - back * 0.3 + Vector3(0, -0.2, 0))


## 夜の落とし物の動き(毎フレーム): 懐中電灯の光(暗い席で目立ち、明るい席では弱い)、メトロノームの振り子と音、
## モナリザの目(こっちを見る・キラッ)、ガイコツ(床ではバラバラ、持つと元の形)。床にあるときは輪の中心を向く
func _update_night_item(state: GameState, delta: float, carried: bool) -> void:
	if not _night or _night_item.is_empty():
		return
	_night_t += delta
	var on_floor := state.handkerchief_on_floor and not carried and _item_head_id < 0
	if on_floor:
		var p := state.handkerchief_position
		_handkerchief.rotation.y = atan2(-p.x, -p.z)
	match _item_index:
		1:
			var glow: Node3D = _night_item["glow"]
			glow.visible = on_floor or carried
			var dark := state.is_dark_seat(state.drop_target_seat)
			var mat: StandardMaterial3D = _night_item["glow_mat"]
			var a := 0.55 if (dark or carried) else 0.16
			if not is_equal_approx(mat.albedo_color.a, a):
				mat.albedo_color.a = a
		2:
			var arm: Node3D = _night_item["arm"]
			var moving := on_floor or carried
			var phase := sin(_night_t * PI * 2.0 * GameConfig.METRONOME_HZ / 2.0)
			arm.rotation.z = phase * 0.45 if moving else 0.0
			# 振り子がはしに来るたびに「カチ」(床にあるときだけ。小さく)
			var side := 1 if phase > 0.0 else -1
			if on_floor and side != _tick_side and _tick_player:
				_tick_player.play()
			_tick_side = side
		3:
			var cam := get_viewport().get_camera_3d()
			var pupils: Array = _night_item["pupils"]
			var bases: Array = _night_item["eyes_base"]
			for i in pupils.size():
				var pm: MeshInstance3D = pupils[i]
				var base: Vector3 = bases[i]
				var want := base
				if on_floor and cam:
					# 目がゆっくり、こっち(カメラ)を見る
					var parent3d := pm.get_parent() as Node3D
					var local: Vector3 = parent3d.global_transform.affine_inverse() * cam.global_position
					var d: Vector3 = local - base
					want = base + Vector3(clampf(d.x, -1.0, 1.0) * 0.008, clampf(d.y, -1.0, 1.0) * 0.004, 0)
				pm.position = pm.position.lerp(want, clampf(delta * 1.5, 0.0, 1.0))
			for g in _night_item["glints"]:
				var gl: Node3D = g
				gl.visible = on_floor
				var k := 1.0 + 0.5 * maxf(sin(_night_t * 3.0), 0.0)
				gl.scale = Vector3(k, k, 1.0)
		4:
			(_night_item["pile"] as Node3D).visible = on_floor
			(_night_item["body"] as Node3D).visible = not on_floor


## 海辺の落とし物の持ち方: 貝殻は手に、ビーチボールは胸の前に抱え、浮き輪は腰に通し、
## 砂の城とバナナボートは頭の上に担ぐ
## 砂のお城(海辺の4ラウンド目)の大きさと、抱えている人が転んでいるか(update で状態からうつす)
var _castle_size := 1.0
var _castle_down := false
var _sand_fx: CPUParticles3D
var _sand_piles: Array = []


## 砂のお城を前で抱える。大きさは state.castle_size(走ると砂がこぼれて小さくなる)。
## 転んでいる間はお城を隠す(崩れて砂山になっている。起き上がったら、小さくなったお城を拾い直したように抱える)
func _carry_castle(m: CharacterModel, body: Basis, back: Vector3) -> void:
	var s := _castle_size
	if _castle_down:
		_handkerchief.visible = false
		_set_sand_fx(Vector3.ZERO, false)
		return
	var chest := m.bone_world("DEF-spine.003").origin
	var head := m.bone_world("DEF-head").origin
	var h: float = BeachStage.ITEM_SIZES[3].y * s
	var front := -back
	var pos := Vector3(chest.x, 0.0, chest.z) + front * (BeachStage.ITEM_SIZES[3].x * 0.5 * s + 0.12)
	# お城のてっぺんが頭より少し上(顔が少し隠れる)
	pos.y = maxf(0.05, head.y + 0.28 - h)
	_handkerchief.transform = Transform3D(body.scaled(Vector3.ONE * s), pos)
	# 走ると、上のほうから砂がぽろぽろこぼれる
	_set_sand_fx(pos + Vector3(0, h * 0.9, 0), true)


func _set_sand_fx(at: Vector3, on: bool) -> void:
	if _sand_fx == null or not is_instance_valid(_sand_fx):
		if not on:
			return
		_sand_fx = CPUParticles3D.new()
		_sand_fx.amount = 24
		_sand_fx.lifetime = 0.8
		_sand_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_sand_fx.emission_sphere_radius = 0.2
		_sand_fx.direction = Vector3(0, 1, 0)
		_sand_fx.spread = 70.0
		_sand_fx.gravity = Vector3(0, -7.0, 0)
		_sand_fx.initial_velocity_min = 0.3
		_sand_fx.initial_velocity_max = 1.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.04, 0.04, 0.04)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BeachStage.COLOR_SAND_DARK
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mat
		_sand_fx.mesh = mesh
		add_child(_sand_fx)
	_sand_fx.emitting = on
	if on:
		_sand_fx.global_position = at


## お城がザザーッと崩れて砂山になる(転んだ場所。この試合の残りのあいだ残る)
func _castle_crumble(pos: Vector3, size: float) -> void:
	var pile := Node3D.new()
	add_child(pile)
	pile.position = Vector3(pos.x, 0.0, pos.z)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.5 * maxf(size, 0.5)
	cone.height = 0.4 * maxf(size, 0.5)
	cone.radial_segments = 12
	var cm := Toon.mesh(cone, BeachStage.COLOR_SAND_DARK, 0.02)
	cm.position.y = cone.height / 2.0
	pile.add_child(cm)
	pile.scale = Vector3(1.0, 0.2, 1.0)
	pile.create_tween().tween_property(pile, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sand_piles.append(pile)
	# 砂ぼこり
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 40
	burst.lifetime = 0.9
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 80.0
	burst.gravity = Vector3(0, -6.0, 0)
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.6
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BeachStage.COLOR_SAND_DARK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	burst.mesh = mesh
	add_child(burst)
	burst.position = pile.position + Vector3(0, 0.4, 0)
	burst.emitting = true
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)
	AudioDirector.sfx("zazaa", -2.0)


func _carry_beach_item(m: CharacterModel, body: Basis, back: Vector3) -> void:
	match _item_index:
		0:
			var hand := m.bone_world("DEF-hand.R").origin
			_handkerchief.transform = Transform3D(body, hand + Vector3(0, -0.06, 0))
		1:
			var chest := m.bone_world("DEF-spine.003").origin
			_handkerchief.transform = Transform3D(body, chest - back * 0.3 + Vector3(0, -0.35, 0))
		2:
			var hips := m.bone_world("DEF-spine.001").origin
			_handkerchief.transform = Transform3D(body, hips + Vector3(0, -0.06, 0))
		_:
			var head := m.bone_world("DEF-head").origin
			_handkerchief.transform = Transform3D(body, head + Vector3(0, CharacterModel.HEAD_RADIUS + 0.04, 0))


## 落とし物の輪郭線(床の上で目立つように、ふつうより太く)
const ITEM_OUTLINE := 0.04
const COLOR_HANKIE := Color("EE5A4B")
const COLOR_SHOE_RUBBER := Color("3F86F0")


func _build_handkerchief(state: GameState) -> void:
	var index := clampi(state.round_index, 0, ITEM_SHAPES.size() - 1)
	var shape: Array = ITEM_SHAPES[index]
	var size: Vector3 = shape[0]
	_handkerchief = Node3D.new()
	_night_item = {}
	if _night and index > 0:
		# 夜の教室の落とし物: 懐中電灯・メトロノーム・モナリザ・ガイコツ(ハンカチは教室と同じ)
		_night_item = NightStage.build_item(_handkerchief, index)
		_handkerchief.visible = false
		add_child(_handkerchief)
		_item_index = index
		_item_size = NightStage.ITEM_SIZES[index]
		_tick_player = Sfx.player_3d(_handkerchief, GameConfig.METRONOME_VOLUME_DB, 1.2)
		_tick_player.stream = Sfx.get_stream("metronome_tick")
		return
	if _beach:
		# 海辺の落とし物: 貝殻・ビーチボール・浮き輪・砂の城・バナナボート
		BeachStage.build_item(_handkerchief, index)
		_handkerchief.visible = false
		add_child(_handkerchief)
		_item_index = index
		_item_size = BeachStage.ITEM_SIZES[index]
		return
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
			_build_shoe()
		3:
			_build_desk()
		4:
			_build_podium()
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
	_step_player.stream = Sfx.get_stream("step_sand" if _beach else "step")
	_step_player.max_polyphony = 2
	_oni_last_pos = state.get_actor(state.oni_id).position
	_oni_walked = 0.0
	_chaser_step_player = Sfx.player_3d(self, GameConfig.RUN_STEP_VOLUME_DB, GameConfig.FOOTSTEP_UNIT_SIZE)
	_chaser_step_player.stream = Sfx.get_stream("run_step_sand" if _beach else "run_step")
	_chaser_step_player.max_polyphony = 2
	_chaser_last_pos = Vector3.ZERO
	_chaser_walked = 0.0

	# 落とし物の音は、そのラウンドの落とし物の音(本物もフェイクも同じ)
	_drop_player = Sfx.player_3d(self, GameConfig.DROP_VOLUME_DB, GameConfig.DROP_SOUND_RANGE)
	var drop_name := ("drop_beach_%d" if _beach else ("drop_night_%d" if _night else "drop_%d")) % clampi(state.round_index, 0, 4)
	_drop_player.stream = Sfx.get_stream(drop_name)

	# 場所のある効果音(振り向く・お手つき・拾う・転ぶなど)
	_fx3d.clear()
	for i in 4:
		_fx3d.append(Sfx.player_3d(self, 0.0, 3.0))

	_stamp_player = Sfx.player_2d(self, -4.0)

	_beep_player = Sfx.player_2d(self)
	_beep_player.stream = Sfx.get_stream("ui_click")

	# 環境音(ごく小さく)
	_amb_player = Sfx.player_2d(self, GameConfig.AMBIENT_VOLUME_DB)
	_amb_player.stream = Sfx.get_stream("amb_beach" if _beach else ("amb_night" if _night else "amb_school"))
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


# --- 手下を当てる投票(教室のまま) ---
## 投票と発表の間は、自分の席のうしろの少し高いところから、輪の全員が見えるように映す(なめらかに動く)
var _vote_view := false
var _vote_view_t := 0.0
var _vote_from := Transform3D.IDENTITY
## 発表で変える表情(id -> "smirk" / "dazed")
var _reveal_faces := {}


func set_vote_view(on: bool, state: GameState = null) -> void:
	if on == _vote_view:
		return
	_vote_view = on
	_vote_view_t = 0.0
	_vote_cam_at = -100000
	_vote_focus = -1
	_set_vote_scene(state if on else null)
	if on:
		var cam := get_viewport().get_camera_3d()
		_vote_from = cam.global_transform if cam else _seat_cam.global_transform
		_top_cam.fov = 55.0
		_top_cam.global_transform = _vote_from
		_top_cam.make_current()
	else:
		_reveal_faces.clear()
		if _seat_cam:
			_seat_cam.make_current()


## 振り返りの演出: カメラをその人に寄せる(-1 で全員が見える位置にもどす)
var _vote_focus := -1


func set_vote_focus(id: int) -> void:
	_vote_focus = id


## その人の頭と、頭の上の言葉がよく見える、少し上からのカメラ(全体のカメラと同じ向きから寄る)
func _vote_focus_transform(id: int, wide: Transform3D) -> Transform3D:
	var m := _actor_nodes.get(id) as CharacterModel
	if m == null:
		return wide
	var foot: Vector3 = (_vote_scene[id]["pos"] as Vector3) if _vote_scene.has(id) else m.global_position
	var look := foot + Vector3(0, 1.7, 0)
	var dir := wide.origin - look
	# (お手つきの人は振り返っているので、輪の外側から寄って顔を見せる)
	if _vote_scene.has(id) and _vote_scene[id]["look"]:
		dir = foot
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var pos := look + dir * 3.3 + Vector3(0, 1.5, 0)
	return Transform3D.IDENTITY.translated(pos).looking_at(look, Vector3.UP)


func is_vote_view() -> bool:
	return _vote_view


func _update_vote_view(state: GameState, delta: float) -> void:
	if not _vote_view:
		return
	_vote_view_t += delta
	var want := vote_camera_transform(state)
	if _vote_focus >= 0:
		want = _vote_focus_transform(_vote_focus, want)
	# (なめらかに近づく。振り返りの演出で、寄ったり引いたりする)
	var k := 1.0 - exp(-delta * 3.2)
	_top_cam.global_transform = _top_cam.global_transform.interpolate_with(want, k)


## 投票の画面は、ラウンドの場面を再現する(見た目だけ): 全員を自分の席(ラウンドの始めの並び)に戻して座らせ、
## 落とされた人のうしろに落とし物をそのまま置き、お手つきの人は自分の席で振り返った姿勢のまま。
## 鬼は、落とした席の少し先の、歩く道に立つ。id -> {"pos", "yaw", "look", "stand"}
var _vote_scene := {}
var _vote_item_pos := Vector3.INF
## 投票の場面の落とし物の大きさ(少しだけ大きく)
const VOTE_ITEM_SCALE := 1.25


func _set_vote_scene(state: GameState) -> void:
	_vote_scene.clear()
	_vote_item_pos = Vector3.INF
	_vote_item_top = Vector3.INF
	if state == null or state.round_lineup.is_empty():
		return
	var n: int = state.seat_positions.size()
	for seat in mini(state.round_lineup.size(), n):
		var id: int = int(state.round_lineup[seat])
		if id < 0 or not _actor_nodes.has(id):
			continue
		_vote_scene[id] = {"pos": state.seat_positions[seat], "yaw": state.seat_yaws[seat],
				"look": id in state.round_otetsuki, "stand": false}
		if id == state.round_dropped_on:
			var p: Vector3 = state.seat_positions[seat]
			_vote_item_pos = Vector3(p.x, 0.0, p.z).normalized() * GameConfig.DROP_RADIUS
	if _actor_nodes.has(state.oni_id) and not _vote_scene.has(state.oni_id):
		# 鬼: 落とした席(なければ自分の席の反対側)から、歩く向きに少し進んだところ
		var ang := PI
		if _vote_item_pos != Vector3.INF:
			ang = atan2(_vote_item_pos.x, _vote_item_pos.z)
		ang += TAU / float(maxi(n, 1)) * 0.6
		var pos := Vector3(sin(ang), 0.0, cos(ang)) * GameConfig.ONI_WALK_RADIUS
		_vote_scene[state.oni_id] = {"pos": pos, "yaw": atan2(-cos(ang), sin(ang)), "look": false, "stand": true}
	# (追いかけっこで転んで倒れたままの人も、起こして座らせる)
	for id in _vote_scene:
		var m := _actor_nodes.get(id) as CharacterModel
		if m:
			m.stop_ragdoll()


func _apply_vote_scene_actors() -> void:
	for id in _vote_scene:
		var sc: Dictionary = _vote_scene[id]
		var model := _actor_nodes.get(id) as CharacterModel
		if model == null:
			continue
		model.position = sc["pos"]
		model.rotation.y = sc["yaw"]
		model.set_pose("idle" if sc["stand"] else ("floor" if _beach else "sit"))
		model.set_look(sc["look"])
		# (お手つきの人は、お手つきのときと同じガーン顔のまま)
		if sc["look"]:
			model.set_expression(CharacterModel.SHOCK)
		model.set_kneel(false)
		model.set_down(false)
		model.set_gesture("")
		var blob: MeshInstance3D = _blobs.get(id)
		if blob:
			blob.position = Vector3(model.position.x, 0.03, model.position.z)


func _apply_vote_scene_item() -> void:
	if _vote_item_pos != Vector3.INF:
		# 落とし物は、落とされた人のうしろの床に、落とされたまま
		if _tucker and is_instance_valid(_tucker):
			_tucker.set_tuck(false)
		_tucker = null
		if _straps and is_instance_valid(_straps):
			_straps.visible = false
		_handkerchief.visible = true
		# (遠くの席でも分かるように、少しだけ大きく)
		_handkerchief.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * VOTE_ITEM_SCALE), _vote_item_pos)
		if _vote_item_top == Vector3.INF:
			_vote_item_top = _item_top()


## 投票の画面のカメラ(自分の席の後ろの高いところから、輪を見る。撮影モードでも使う)。
## 全員の頭と足もと(名札)が画面に入る範囲で、できるだけ近づく。大事な人は頭の上の吹き出しの分も入れ、その人たちがよく見える角度を選ぶ。
## 投票の画面になったときに1回だけ計算する(撮影モードは、証拠を作り直したとき)
## 見下ろす角度の候補(ラジアン)。いちばんキャラが大きく(近く)映る角度を選ぶ
## (低すぎると、手前の人のラベルが奥の人の顔にかぶるので、ある程度は見下ろす)
## (手前の人も背中だけにならないよう、少し上から見下ろす)
const VOTE_CAM_PITCHES := [0.82, 0.92, 1.02, 1.12]
## 画面の上の枠の分、頭を置かない上の帯(px)と、左右のよゆう(px)
const VOTE_CAM_TOP_PX := 150.0
## 大事な人の頭の上に、吹き出しを1つ積むための高さ(m)
const VOTE_CAM_BUBBLE_ROOM := 0.3
const VOTE_CAM_SIDE_PX := 110.0
var _vote_cam_cache := Transform3D.IDENTITY
var _vote_cam_at := -100000


func vote_camera_transform(state: GameState) -> Transform3D:
	# (投票の画面に入ったときに1回だけ決める。とちゅうで変えると、発表の間にカメラが動いてしまう)
	var now := Time.get_ticks_msec()
	if _vote_cam_at >= 0:
		return _vote_cam_cache
	_vote_cam_at = now
	_vote_cam_cache = _fit_vote_camera(state)
	return _vote_cam_cache


func _fit_vote_camera(state: GameState) -> Transform3D:
	var me := state.get_local_player()
	var base := Vector3(0, 0, 1)
	if me:
		var p := me.position
		if me.role == GameState.Role.OUT and me.home_seat >= 0 and me.home_seat < state.seat_positions.size():
			p = state.seat_positions[me.home_seat]
		elif me.role == GameState.Role.SEATED and me.seat_index >= 0:
			p = state.seat_positions[me.seat_index]
		if Vector2(p.x, p.z).length() > 0.3:
			base = Vector3(p.x, 0.0, p.z).normalized()
	var keys := state.evidence_key_ids()
	# 大事な人がいれば、その人たちの反対側から見る(大事な人が奥に来て、顔と頭の上の吹き出しと、うしろの落とし物が見える)
	var key_sum := Vector3.ZERO
	for id in keys:
		if _vote_scene.has(id):
			key_sum += _vote_scene[id]["pos"] as Vector3
		elif _actor_nodes.has(id):
			key_sum += (_actor_nodes[id] as Node3D).global_position
	key_sum.y = 0.0
	if key_sum.length() > 0.5:
		base = -key_sum.normalized()
	elif keys.size() >= 2 and _vote_scene.has(keys[0]):
		# (2人が向かい合わせ: 2人とも横に見える向き)
		var kp: Vector3 = _vote_scene[keys[0]]["pos"]
		base = Vector3(kp.z, 0.0, -kp.x).normalized()
	# 映したい点: 全員の頭の上と足もと(名札)。大事な人(落とされた人・お手つきの人)は、頭の上の吹き出しの分も
	var heads: Array[Vector3] = []
	var chests: Array[Vector3] = []
	var key_feet: Array[Vector3] = []
	var bubbles := HeadOverlay.evidence_bubbles(state)
	for id in _actor_nodes:
		var m := _actor_nodes[id] as CharacterModel
		if m == null or not is_instance_valid(m):
			continue
		# (場面を再現しているときは、再現した位置で数える)
		var foot: Vector3 = (_vote_scene[id]["pos"] as Vector3) if _vote_scene.has(id) else m.global_position
		var head: Vector3 = foot + (m.tag_anchor() - m.global_position)
		# (輪の外のカメラ側に立っている人は数えない。その人の札は画面の下のふちに寄せて出る)
		if foot.dot(base) > GameConfig.RING_RADIUS * 1.1:
			continue
		heads.append(head)
		# (足もとの名札も入るように、足もと)
		chests.append(foot)
		if id in keys:
			# (頭の上に積む吹き出しの数だけ、上によゆう)
			var lines: int = (bubbles.get(id, []) as Array).size() + (1 if id in state.round_otetsuki else 0)
			heads.append(head + Vector3(0, VOTE_CAM_BUBBLE_ROOM * float(lines), 0))
			key_feet.append(foot)
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var aspect := vp.x / maxf(vp.y, 1.0)
	var tan_v := tan(deg_to_rad(55.0) / 2.0)
	var y_top := 1.0 - 2.0 * VOTE_CAM_TOP_PX / vp.y
	var x_lim := 1.0 - 2.0 * VOTE_CAM_SIDE_PX / vp.x
	var fallback := Transform3D.IDENTITY.translated(base * (GameConfig.RING_RADIUS + 3.9) + Vector3(0, 4.2, 0)) \
			.looking_at(Vector3(0, 1.9, 0) - base * 2.6, Vector3.UP)
	if heads.is_empty():
		return fallback
	var best := fallback
	var best_depth := INF
	# (全員が入る角度がなければ、教室の中でいちばん遠く・いちばん上から見る)
	var partial := Transform3D.IDENTITY
	for pitch in VOTE_CAM_PITCHES:
		var dir := (base * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
		var t := _fit_vote_distance(dir, base, heads, chests, tan_v, aspect, y_top, x_lim)
		if t == Transform3D.IDENTITY:
			partial = _vote_cam_at_dist(Vector3(0, 0.6, 0), dir, _vote_cam_max_dist(Vector3(0, 0.6, 0), dir))
			continue
		# キャラの大きさ = 近さの平均(近いほど大きく映る)。大事な人がいれば、その人たちがよく見える角度
		var inv := t.affine_inverse()
		var pts: Array[Vector3] = key_feet if not key_feet.is_empty() else chests
		var depth := 0.0
		for p in pts:
			depth += -(inv * p).z
		depth /= maxf(float(pts.size()), 1.0)
		if depth < best_depth:
			best_depth = depth
			best = t
	if best_depth == INF and partial != Transform3D.IDENTITY:
		return partial
	return best


## カメラが教室の壁の外に出ない、いちばん遠い距離(海辺は壁がないので、少しゆるく)
func _vote_cam_max_dist(target: Vector3, dir: Vector3) -> float:
	var lim := (ROOM_HALF - 0.4) if not _beach else 14.0
	var d := 20.0
	for axis in [0, 2]:
		var v: float = dir[axis]
		if absf(v) > 0.001:
			d = minf(d, (lim * signf(v) - target[axis]) / v)
	if not _beach:
		d = minf(d, (ROOM_HEIGHT * 2.2 - target.y) / maxf(dir.y, 0.05))
	return maxf(d, 2.5)


## その向きで、全員が入るいちばん近いカメラ(入らなければ IDENTITY)
func _fit_vote_distance(dir: Vector3, base: Vector3, heads: Array[Vector3], chests: Array[Vector3], tan_v: float,
		aspect: float, y_top: float, x_lim: float) -> Transform3D:
	# ねらう場所を前後にずらしながら、入るいちばん近い距離を二分探索でさがす(遠いほど入りやすい)
	var best := Transform3D.IDENTITY
	var best_d := INF
	for shift in [0.0, -0.6, 0.6, -1.2, 1.2]:
		var target: Vector3 = Vector3(0, 0.6, 0) + base * float(shift)
		var lo := 2.5
		var hi := _vote_cam_max_dist(target, dir)
		if not _vote_cam_fits(_vote_cam_at_dist(target, dir, hi), heads, chests, tan_v, aspect, y_top, x_lim):
			continue
		for k in 9:
			var mid := (lo + hi) * 0.5
			if _vote_cam_fits(_vote_cam_at_dist(target, dir, mid), heads, chests, tan_v, aspect, y_top, x_lim):
				hi = mid
			else:
				lo = mid
		if hi < best_d:
			best_d = hi
			best = _vote_cam_at_dist(target, dir, hi)
	return best


func _vote_cam_at_dist(target: Vector3, dir: Vector3, d: float) -> Transform3D:
	return Transform3D.IDENTITY.translated(target + dir * d).looking_at(target, Vector3.UP)


func _vote_cam_fits(t: Transform3D, heads: Array[Vector3], chests: Array[Vector3], tan_v: float, aspect: float,
		y_top: float, x_lim: float) -> bool:
	var inv := t.affine_inverse()
	for p in heads:
		var l := inv * p
		if l.z >= -0.3:
			return false
		var depth := -l.z
		var nx := l.x / (depth * tan_v * aspect)
		var ny := l.y / (depth * tan_v)
		if absf(nx) > x_lim or ny > y_top or ny < -0.95:
			return false
	for p in chests:
		var l := inv * p
		if l.z >= -0.3:
			return false
		var depth := -l.z
		var nx := l.x / (depth * tan_v * aspect)
		var ny := l.y / (depth * tan_v)
		# (足もとの下に名札が入るだけのよゆう)
		if absf(nx) > 0.95 or ny < -0.88:
			return false
	return true


# --- 蜃気楼!(海辺): 蜃気楼チームの画面には、ニセの落とし物(本物とまったく同じ見た目)。鬼はゆらゆら揺らぐ ---
## 席 -> ニセの落とし物の Node3D / 終わったあと薄くなっていく残り時間
var _mirage_nodes := {}
var _mirage_fade := -1.0
var _mirage_oni_faded := false


func _update_mirage(state: GameState, delta: float) -> void:
	var me := state.get_local_player()
	var active := state.mirage_on and not state.mirage_done and state.phase != GameState.Phase.RESULT
	# ニセ: 蜃気楼チームの画面にだけ。現れた席のうしろに、本物と同じ見え方(見えない席のうしろは見えない)
	if me and active and not state.mirage_sees_real(me.id):
		_mirage_fade = -1.0
		for seat in state.mirage_fakes_shown:
			if not _mirage_nodes.has(seat):
				var n := _handkerchief.duplicate() as Node3D
				add_child(n)
				var p: Vector3 = Vector3(sin(state.seat_angle(seat)), 0.0, cos(state.seat_angle(seat))) * GameConfig.DROP_RADIUS
				n.transform = Transform3D(Basis.IDENTITY, p)
				n.visible = true
				_mirage_nodes[seat] = n
			var node: Node3D = _mirage_nodes[seat]
			var can_see: bool = me.role != GameState.Role.SEATED or (me.seat_index != int(seat) and state.sees_behind(me.id, int(seat)))
			_set_item_layers(node, 1 if can_see else 1 << (HIDDEN_LAYER - 1))
	elif not _mirage_nodes.is_empty():
		# 終わったら、すっと薄くなって消える
		if _mirage_fade < 0.0:
			_mirage_fade = GameConfig.MIRAGE_FADE
		_mirage_fade -= delta
		var a := clampf(_mirage_fade / GameConfig.MIRAGE_FADE, 0.0, 1.0)
		for seat in _mirage_nodes:
			_set_transparency(_mirage_nodes[seat] as Node3D, 1.0 - a)
		if _mirage_fade <= 0.0:
			for seat in _mirage_nodes:
				(_mirage_nodes[seat] as Node3D).queue_free()
			_mirage_nodes.clear()
	# 鬼: 蜃気楼の間は少し透けて、ゆらゆら揺らぐ(落とす手元が見えないように)
	var oni := _actor_nodes.get(state.oni_id) as Node3D
	if oni:
		if active:
			oni.position += Vector3(sin(_clock * 7.0) * 0.06, 0.0, cos(_clock * 5.3) * 0.05)
			oni.rotation.z = sin(_clock * 6.1) * 0.05
			if not _mirage_oni_faded:
				_mirage_oni_faded = true
				_set_transparency(oni, 0.45)
		elif _mirage_oni_faded:
			_mirage_oni_faded = false
			oni.rotation.z = 0.0
			_set_transparency(oni, 0.0)


func _set_transparency(n: Node, t: float) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).transparency = t


# --- カメラが人や障害物の中に入ったときに、黒い輪郭線(裏返した外側の面)が画面いっぱいに映らないように ---
## (追いかけっこで逃げる側のとき、うしろから迫る人の体の中にカメラが入ると、画面いっぱいに黒い斜めの線が出ていた)
const CAM_CLEAR_RADIUS := 0.95


func _hide_near_camera(state: GameState) -> void:
	var cam := get_viewport().get_camera_3d()
	# (追いかけっこの間だけ。見逃しの顔のアップなど、わざと近くから映す場面では隠さない)
	if cam == null or state.phase != GameState.Phase.CHASE:
		_restore_cam_hidden()
		return
	var eye := cam.global_position
	for id in _actor_nodes:
		if id == state.local_player_id:
			continue
		_cam_clear(_actor_nodes[id] as Node3D, eye, Vector3(0, 0.8, 0), CAM_CLEAR_RADIUS)
	for id in _obstacle_nodes:
		_cam_clear(_obstacle_nodes[id] as Node3D, eye, Vector3(0, 0.35, 0), CAM_CLEAR_RADIUS * 0.8)


func _restore_cam_hidden() -> void:
	for id in _actor_nodes:
		_cam_clear(_actor_nodes[id] as Node3D, Vector3.INF, Vector3.ZERO, 0.0)
	for id in _obstacle_nodes:
		_cam_clear(_obstacle_nodes[id] as Node3D, Vector3.INF, Vector3.ZERO, 0.0)


func _cam_clear(n: Node3D, eye: Vector3, center: Vector3, radius: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var near := eye != Vector3.INF and (n.global_position + center).distance_to(eye) < radius
	if near and n.visible:
		n.visible = false
		n.set_meta("cam_hid", true)
	elif not near and n.get_meta("cam_hid", false):
		n.visible = true
		n.set_meta("cam_hid", false)


# --- 投票の証拠: 落とし物のてっぺんの位置(2D の「▼」の矢印を出すため) ---

## 投票の場面で置いた落とし物のてっぺん(なければ Vector3.INF。置いたあとに1回だけ計算する)
var _vote_item_top := Vector3.INF


func vote_item_top() -> Vector3:
	return _vote_item_top


## 落とし物の見た目のてっぺん(撮影モードでも使う)
func _item_top() -> Vector3:
	var top := _handkerchief.global_position.y
	for c in _handkerchief.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if vi.visible:
			var box := vi.global_transform * vi.get_aabb()
			top = maxf(top, box.end.y)
	return Vector3(_handkerchief.global_position.x, top, _handkerchief.global_position.z)


# --- 1試合に1回のイベントの見た目(先生の見回り・カモメの貝がら) ---
var _teacher: CharacterModel
var _teacher_say: Label3D
var _shell: Node3D
var _gull: Node3D
var _gull_t := 0.0
var _gull_to := Vector3.ZERO
var _shell_show_at := 0.0
## カモメが飛んでくる時間・飛んでいく時間(秒)
const GULL_IN := 1.6
const GULL_OUT := 1.4


func _update_events(state: GameState, delta: float) -> void:
	# 先生の見回り: 黒板の前に先生が立って「しーっ!」
	var teacher_on := state.teacher_left > 0.0 and state.phase != GameState.Phase.RESULT
	if teacher_on and (_teacher == null or not is_instance_valid(_teacher)):
		_teacher = CharacterModel.new()
		add_child(_teacher)
		_teacher.build(Color("5A6478"), "", HudFont.get_font())
		_teacher.set_name_visible(false)
		_teacher.scale = Vector3.ONE * 1.15
		_teacher.position = Vector3(-2.6, 0.0, PHOTO_Z - 1.2)
		_teacher.rotation.y = PI + 0.35
		_teacher.set_pose("idle")
		_teacher.set_gesture("chin")
		_teacher_say = Label3D.new()
		_teacher_say.text = tr("しーっ!")
		_teacher_say.font = HudFont.get_font()
		_teacher_say.font_size = 72
		_teacher_say.pixel_size = 0.004
		_teacher_say.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_teacher_say.outline_size = 14
		_teacher_say.outline_modulate = GameConfig.COLOR_INK
		_teacher_say.position = Vector3(0, 2.25, 0)
		_teacher.add_child(_teacher_say)
	if _teacher and is_instance_valid(_teacher):
		_teacher.visible = teacher_on
		if teacher_on:
			_teacher.set_expression(CharacterModel.SMIRK)
			_teacher.animate(delta, false)
	# カモメの貝がら(落とし物ではない)。見え方は落とし物と同じ(自分と両どなりのうしろは見えない)
	if state.shell_seat >= 0 and state.phase != GameState.Phase.RESULT:
		if _shell == null or not is_instance_valid(_shell):
			_shell = _build_shell()
			add_child(_shell)
		_shell.position = _ring_point_v(state.seat_angle(state.shell_seat), GameConfig.DROP_RADIUS)
		_shell.visible = _clock >= _shell_show_at
		var me := state.get_local_player()
		var hidden := me != null and me.role == GameState.Role.SEATED and state.shell_seat != me.seat_index \
				and not state.sees_behind(me.id, state.shell_seat)
		_set_item_layers(_shell, 1 << (HIDDEN_LAYER - 1) if hidden else 1)
	elif _shell and is_instance_valid(_shell):
		_shell.visible = false
	# カモメが飛んでくる → 貝がらを置く → 飛んでいく
	if _gull and is_instance_valid(_gull):
		_gull_t += delta
		var from := _gull_to + Vector3(7.0, 4.5, -3.0)
		var away := _gull_to + Vector3(-7.0, 5.5, 4.0)
		var above := _gull_to + Vector3(0, 1.1, 0)
		if _gull_t < GULL_IN:
			var k := _gull_t / GULL_IN
			_gull.position = from.lerp(above, k * (2.0 - k))
		else:
			var k := clampf((_gull_t - GULL_IN) / GULL_OUT, 0.0, 1.0)
			_gull.position = above.lerp(away, k * k)
		var dir := (above - from) if _gull_t < GULL_IN else (away - above)
		_gull.rotation.y = atan2(-dir.x, -dir.z)
		var flap := sin(_gull_t * 18.0) * 0.6
		for w in _gull.get_children():
			if w.has_meta("wing"):
				(w as Node3D).rotation.z = flap * float(w.get_meta("wing"))
		if _gull_t >= GULL_IN + GULL_OUT:
			_gull.queue_free()
			_gull = null


func _ring_point_v(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle)) * radius


func _start_gull(to: Vector3) -> void:
	if _gull and is_instance_valid(_gull):
		_gull.queue_free()
	_gull = Node3D.new()
	add_child(_gull)
	_gull_to = to
	_gull_t = 0.0
	_shell_show_at = _clock + GULL_IN
	var white := Color("F4F6F8")
	var body := CapsuleMesh.new()
	body.radius = 0.12
	body.height = 0.5
	var bm := Toon.mesh(body, white, 0.02)
	bm.rotation.x = PI / 2.0
	_gull.add_child(bm)
	var head := SphereMesh.new()
	head.radius = 0.1
	head.height = 0.2
	var hm := Toon.mesh(head, white, 0.02)
	hm.position = Vector3(0, 0.06, -0.26)
	_gull.add_child(hm)
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.035
	beak.height = 0.12
	var km := Toon.mesh(beak, Color("F2A33A"), 0.01)
	km.position = Vector3(0, 0.05, -0.38)
	km.rotation.x = -PI / 2.0
	_gull.add_child(km)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.set_meta("wing", side)
		_gull.add_child(wing)
		var wb := BoxMesh.new()
		wb.size = Vector3(0.55, 0.03, 0.22)
		var wm := Toon.mesh(wb, white, 0.015)
		wm.position = Vector3(side * 0.3, 0, 0)
		wing.add_child(wm)
		var tip := BoxMesh.new()
		tip.size = Vector3(0.18, 0.031, 0.2)
		var tm := Toon.mesh(tip, Color("5A6270"), 0.01)
		tm.position = Vector3(side * 0.5, 0, 0)
		wing.add_child(tm)


## 貝がら: 白とうすいピンクの扇の形(遠くからは落とし物と見分けにくい大きさ)
func _build_shell() -> Node3D:
	var root := Node3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.2
	sp.height = 0.4
	var m := Toon.mesh(sp, Color("FBE3E0"), 0.015)
	m.scale = Vector3(1.0, 0.28, 0.85)
	m.position = Vector3(0, 0.05, 0)
	root.add_child(m)
	for i in 5:
		var rb := BoxMesh.new()
		rb.size = Vector3(0.025, 0.02, 0.3)
		var rm := Toon.mesh(rb, Color("E8B4B0"), 0.0)
		rm.position = Vector3(0, 0.1, 0.0)
		rm.rotation.y = (float(i) - 2.0) * 0.32
		root.add_child(rm)
	return root


# --- 試合の終わりの演出(TitleReveal から。見た目だけ) ---
## 同じ教室の中で、カメラが動いてつなぐ:
##   ceremony_gather: 全員が立ち上がって表彰台のまわりへ歩いて集まる(1〜3位は台の前、ほかは台の左右)
##   ceremony_step_up: その人が台に上がる / ceremony_view("podium" / "wide"): 表彰台を映す・少し引く
##   ceremony_focus: 称号の人にカメラが寄る / ceremony_photo: 全員が横に並んで記念写真
var _cer_mode := ""
var _cer_cam := ""
var _cer_focus_id := -1
var _cer_t := 0.0
var _cer_from := Transform3D.IDENTITY
## 人の動き id -> {"from", "to", "t", "time", "hop"}(歩いて集まる・台に上がる)と、止まったときの位置
var _cer_moves := {}
var _cer_faces := {}
var _cer_gestures := {}
var _cer_center := Vector3.ZERO
var _cer_dist := 4.0
var _cer_props: Node3D
## 表彰台と記念写真の場所(黒板の前、輪と教卓のあいだ)
const PHOTO_Z := -4.6
const PHOTO_SPACING_MIN := 0.62
const PHOTO_SPACING_MAX := 0.9
## 表彰台: 1位・2位・3位の台の高さと横の位置(メートル)。4位からは台の左右に立つ
const PODIUM_HEIGHTS := [0.6, 0.42, 0.28]
const PODIUM_XS := [0.0, -0.9, 0.9]
const PODIUM_SIDE_X := 1.85
const PODIUM_SIDE_SPACING := 0.62
## 記念写真の1位の台
const PHOTO_PODIUM_HEIGHT := 0.32
const PHOTO_PODIUM_FRONT := 0.4
## 歩いて集まる時間・台に上がる時間・カメラが動く時間(秒)
const GATHER_TIME := 1.4
const STEP_UP_TIME := 0.4
const CAM_MOVE_TIME := 0.9
## 称号の人に寄るカメラ: 顔の前の距離
const FOCUS_DIST := 2.5


func in_ceremony() -> bool:
	return _cer_mode != ""


## 全員が立ち上がって、表彰台のまわりへ歩いて集まる。ranked は順位の高い順
func ceremony_gather(ranked: Array) -> void:
	_cer_start()
	_cer_mode = "podium"
	_build_award_podium(3)
	var targets := {}
	var side := 0
	for i in ranked.size():
		var id := int(ranked[i])
		if i < 3:
			# 台の前の床(順番に台に上がる)
			targets[id] = Vector3(PODIUM_XS[i], 0.0, PHOTO_Z + 0.75)
		else:
			var k := side
			side += 1
			var dir := -1.0 if k % 2 == 0 else 1.0
			# (台より少しうしろ。台の前に入らないように)
			targets[id] = Vector3(dir * (PODIUM_SIDE_X + float(k / 2) * PODIUM_SIDE_SPACING), 0.0, PHOTO_Z - 0.25)
	_cer_move_all(targets, GATHER_TIME)
	ceremony_view("podium")


## その人が台に上がる(rank: 0 = 1位)
func ceremony_step_up(id: int, rank: int) -> void:
	if rank < 0 or rank >= PODIUM_HEIGHTS.size():
		return
	_cer_move(id, Vector3(PODIUM_XS[rank], PODIUM_HEIGHTS[rank], PHOTO_Z), STEP_UP_TIME, true)


## カメラ: "podium"(表彰台)/"wide"(少し引いて全体)
func ceremony_view(kind: String) -> void:
	_cer_cam_to(kind)


## 表情とポーズ(id -> CharacterModel の表情 / set_gesture の名前)。足していく
func ceremony_set_face(id: int, face: String, gesture: String = "") -> void:
	_cer_faces[id] = face
	_cer_gestures[id] = gesture


## 称号の人にカメラを寄せる(人はその場のまま)。face: 表情、gesture: ポーズ
func ceremony_focus(id: int, face: String, kneel: bool = false, gesture: String = "") -> void:
	if _cer_mode == "":
		_cer_start()
		_cer_mode = "podium"
	_cer_focus_id = id
	ceremony_set_face(id, face, gesture)
	var m := _actor_nodes.get(id) as CharacterModel
	if m and not kneel:
		m.hop()
	_cer_cam_to("focus")


## 記念写真: ranked は順位の高い順。1位はまん中の台の上、そのあと左右に交互に並べ、上位ほど少し前。
## 全員が歩いて並ぶ(instant = true ならすぐ並ぶ)。faces: id -> 表情、gestures: id -> ポーズ
func ceremony_photo(ranked: Array, faces: Dictionary, gestures: Dictionary = {}, instant: bool = false) -> void:
	if _cer_mode == "":
		_cer_start()
	_cer_mode = "photo"
	_cer_faces = faces.duplicate()
	_cer_gestures = gestures.duplicate()
	var n := ranked.size()
	var sp := clampf(6.4 / maxf(n - 1, 1), PHOTO_SPACING_MIN, PHOTO_SPACING_MAX)
	var targets := {}
	for i in n:
		# まん中から: 0, -1, +1, -2, +2 ...(席の番号 × 間隔)
		var slot := 0 if i == 0 else (int((i + 1) / 2) * (-1 if i % 2 == 1 else 1))
		var x := float(slot) * sp
		var z := PHOTO_Z + (PHOTO_PODIUM_FRONT if i == 0 else (0.18 if i <= 2 else 0.0))
		var y := PHOTO_PODIUM_HEIGHT if i == 0 else 0.0
		targets[int(ranked[i])] = Vector3(x, y, z)
	_build_award_podium(1, targets[int(ranked[0])] if n > 0 else Vector3.ZERO)
	_cer_move_all(targets, 0.0 if instant else GATHER_TIME * 0.8)
	# 全員(と頭の上のバッジ)が入る距離。並びのまん中をねらう(左右の数がちがうことがあるので)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var vfov := deg_to_rad(42.0)
	var hfov := 2.0 * atan(tan(vfov / 2.0) * aspect)
	var min_x := INF
	var max_x := -INF
	for id in targets:
		min_x = minf(min_x, (targets[id] as Vector3).x)
		max_x = maxf(max_x, (targets[id] as Vector3).x)
	var width := (max_x - min_x) + 1.4
	_cer_dist = maxf(3.4, width / 2.0 / tan(hfov / 2.0))
	_cer_center = Vector3((min_x + max_x) / 2.0, 1.15, PHOTO_Z)
	_cer_cam_to("photo")
	if instant:
		_cer_t = CAM_MOVE_TIME


## 試合の終わりの演出をやめて、ふだんのカメラに戻す
func ceremony_end() -> void:
	if _cer_mode == "":
		return
	_cer_mode = ""
	_cer_cam = ""
	_cer_moves.clear()
	_cer_faces.clear()
	_cer_gestures.clear()
	_cer_focus_id = -1
	if _cer_props and is_instance_valid(_cer_props):
		_cer_props.queue_free()
	_cer_props = null
	for id in _actor_nodes:
		var m := _actor_nodes[id] as CharacterModel
		if m:
			m.set_gesture("")
	for i in _chairs.size():
		if is_instance_valid(_chairs[i]):
			_chairs[i].visible = i != _hidden_chair
	if _seat_cam:
		_seat_cam.make_current()


func _cer_start() -> void:
	var cam := get_viewport().get_camera_3d()
	_top_cam.fov = 42.0
	_top_cam.global_transform = cam.global_transform if cam else _top_cam.global_transform
	_top_cam.make_current()
	# 椅子は隠す(集まる人や台の前に入らないように)
	for c in _chairs:
		if is_instance_valid(c):
			c.visible = false


## カメラを、今の位置から次のねらいへ、なめらかに動かす
func _cer_cam_to(kind: String) -> void:
	_cer_from = _top_cam.global_transform
	_cer_cam = kind
	_cer_t = 0.0


## みんなを targets(id -> 位置)へ歩かせる(time 秒。0 ならすぐ)
func _cer_move_all(targets: Dictionary, time: float) -> void:
	for id in targets:
		_cer_move(int(id), targets[id], time, false)


func _cer_move(id: int, to: Vector3, time: float, hop: bool) -> void:
	var node: Node3D = _actor_nodes.get(id)
	var from := node.position if node else to
	_cer_moves[id] = {"from": from, "to": to, "t": 0.0 if time > 0.0 else 1.0, "time": maxf(time, 0.001), "hop": hop}
	var m := node as CharacterModel
	if hop and m:
		m.hop()


## この人の、試合の終わりの演出での置き方({} ならふだんどおり)
func _cer_override(id: int) -> Dictionary:
	if _cer_mode == "" or not _cer_moves.has(id):
		return {}
	var mv: Dictionary = _cer_moves[id]
	var k := clampf(float(mv["t"]), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector3 = mv["from"]
	var to: Vector3 = mv["to"]
	var pos := from.lerp(to, e)
	if bool(mv["hop"]):
		pos.y += sin(k * PI) * 0.25
	var walking := k < 1.0 and not bool(mv["hop"]) and from.distance_to(to) > 0.3
	var yaw := PI
	if walking:
		var d := to - from
		yaw = atan2(-d.x, -d.z)
	return {"pos": pos, "yaw": yaw, "walk": walking}


## 台(白い箱に金・銀・銅の数字)。count = 3 なら表彰台、1 なら記念写真の1位の台(at の場所)
func _build_award_podium(count: int, at: Vector3 = Vector3.ZERO) -> void:
	if _cer_props and is_instance_valid(_cer_props):
		_cer_props.queue_free()
	_cer_props = Node3D.new()
	add_child(_cer_props)
	var colors := [Color("E0A820"), Color("A8B4C0"), Color("C0794A")]
	for i in count:
		var h: float = PHOTO_PODIUM_HEIGHT if count == 1 else PODIUM_HEIGHTS[i]
		var pos := Vector3(at.x, 0.0, at.z) if count == 1 else Vector3(PODIUM_XS[i], 0.0, PHOTO_Z)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.84, h, 0.7)
		var box := Toon.mesh(bm, Color("FFF6E4"), 0.02)
		box.position = pos + Vector3(0, h / 2.0, 0)
		_cer_props.add_child(box)
		var lab := Label3D.new()
		lab.text = str(i + 1)
		lab.font = HudFont.get_font()
		lab.font_size = 96
		lab.pixel_size = 0.0032
		lab.modulate = colors[i]
		lab.outline_size = 14
		lab.outline_modulate = GameConfig.COLOR_INK
		lab.position = pos + Vector3(0, h / 2.0, 0.36)
		_cer_props.add_child(lab)


func _ceremony_face(id: int) -> String:
	if _cer_mode == "":
		return ""
	return str(_cer_faces.get(id, ""))


func _update_ceremony(delta: float) -> void:
	if _cer_mode == "":
		return
	_cer_t += delta
	for id in _cer_moves:
		var mv: Dictionary = _cer_moves[id]
		mv["t"] = float(mv["t"]) + delta / float(mv["time"])
	if get_viewport().get_camera_3d() != _top_cam:
		_top_cam.make_current()
	var want := _top_cam.global_transform
	match _cer_cam:
		"podium":
			var c := Vector3(0, 1.0, PHOTO_Z)
			want = Transform3D.IDENTITY.translated(c + Vector3(0, 0.8, 6.0)).looking_at(c + Vector3(0, 0.15, 0), Vector3.UP)
		"wide":
			var c := Vector3(0, 1.0, PHOTO_Z)
			want = Transform3D.IDENTITY.translated(c + Vector3(0, 1.1, 6.6)).looking_at(c, Vector3.UP)
		"focus":
			var node: Node3D = _actor_nodes.get(_cer_focus_id)
			if node:
				var m := node as CharacterModel
				var head := node.global_position + Vector3(0, 1.3, 0)
				if m:
					head = m.bone_world("DEF-head").origin
				var facing := -node.global_transform.basis.z
				facing.y = 0.0
				facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
				var right := (-facing).cross(Vector3.UP).normalized()
				var pos := head + facing * FOCUS_DIST + Vector3(0, 0.05, 0)
				# 人は画面の左寄り(右半分に称号のカード)。上半身が入るように、少し下をねらう
				want = Transform3D.IDENTITY.translated(pos).looking_at(head + right * 0.85 + Vector3(0, -0.35, 0), Vector3.UP)
		"photo":
			var pos := _cer_center + Vector3(0, 0.35, _cer_dist)
			want = Transform3D.IDENTITY.translated(pos).looking_at(_cer_center + Vector3(0, 0.05, 0), Vector3.UP)
	var k := clampf(_cer_t / CAM_MOVE_TIME, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_top_cam.global_transform = _cer_from.interpolate_with(want, k)


## 画面のこの位置にいる人の id(自分以外。だれでも。いなければ -1)。投票でタップした人
func pick_any_actor(state: GameState, screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var best := -1
	var best_dist := 80.0
	for a in state.actors:
		if a.id == state.local_player_id:
			continue
		var node: Node3D = _actor_nodes.get(a.id)
		if node == null:
			continue
		for h in [0.5, 0.9, 1.35]:
			var p: Vector3 = node.global_position + Vector3(0, h, 0)
			if cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen_pos)
			if d < best_dist:
				best_dist = d
				best = a.id
	return best


## 発表の表情: 手下はニヤッと笑う(smirk)、バレバレの手下は放心(dazed)。空で元に戻す
func set_reveal_faces(faces: Dictionary) -> void:
	_reveal_faces = faces.duplicate()


## 画面の上の位置(人の頭の上・体のまん中)。発表の矢印や指マークに使う
func actor_point(id: int, height: float) -> Vector3:
	var node: Node3D = _actor_nodes.get(id)
	return (node.global_position if node else Vector3.ZERO) + Vector3(0, height, 0)


## 頭の上の名札とスタンプ(2D)
func get_overlay() -> HeadOverlay:
	return _overlay


## 撮影モードから戻ったとき: 席のカメラに戻し、名札をまた出す
func set_shown(v: bool) -> void:
	visible = v
	if _overlay:
		_overlay.visible = v
	if _blackout:
		_blackout.visible = v and _blackout._on
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
	if best >= 0:
		return best
	# 牛乳・水鉄砲の相手を選んでいる間は、足もとの青い丸をタップしても選べる
	# (タップした場所を床の上に移して、丸の中に入っているか)
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return -1
	var t := (MILK_RING_Y - from.y) / dir.y
	if t <= 0.0:
		return -1
	var hit := from + dir * t
	var best_r := MILK_RING_RADIUS + 0.15
	for id in _milk_rings:
		var ring: Node3D = _milk_rings[id]
		if not ring.visible:
			continue
		var dr := Vector2(hit.x - ring.position.x, hit.z - ring.position.z).length()
		if dr < best_r:
			best_r = dr
			best = id
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
## お手つきの本人の画面で、自分の顔を大きく映している間か(名札が顔にかぶらないように、main が名札を隠す)
var self_close_up := false


func _update_seat_camera(state: GameState, delta: float) -> void:
	var me := state.get_local_player()
	self_close_up = false
	if me == null or _seat_cam == null:
		return
	# 画面のゆれ(お手つきの本人。だんだん小さく)
	_shake_left = maxf(_shake_left - delta, 0.0)
	var amp := SHAKE_PIXELS * (_shake_left / SHAKE_TIME)
	_seat_cam.h_offset = randf_range(-amp, amp)
	_seat_cam.v_offset = randf_range(-amp, amp)
	# 座っているときは自分の体を映さない。立ち上がって追いかけるときは映す
	var self_bit := 1 << (SELF_LAYER - 1)
	var close_up := me.role == GameState.Role.OUT and _out_anim.has(me.id) \
			and float(_out_anim[me.id]["t"]) < OUT_FACE_TIME + OUT_FALL_TIME * 0.9
	# 顔のアップの間は、自分の椅子を隠す(カメラと顔の間に背もたれが入って、顔にかぶるので)
	_set_hidden_chair(me.home_seat if close_up else -1)
	self_close_up = close_up
	if close_up:
		# お手つき直後: 自分の顔の正面にカメラを寄せて、放心の顔を大きく映す。そのまま崩れ落ちるところを見せる
		var model := _actor_nodes.get(me.id) as CharacterModel
		if model:
			_seat_cam.cull_mask = 0xFFFFF & ~(1 << (CEILING_LAYER - 1))
			_seat_cam.keep_aspect = Camera3D.KEEP_HEIGHT
			_seat_cam.fov = 40.0
			var head := model.bone_world("DEF-head").origin
			# 顔の向き: 頭のまん中から目へ向かう向き(体の向きの決まりにたよらない)。ねらうのは両目のまん中
			var face := -model.global_transform.basis.z
			var eyes := model.eye_points()
			var target := head + Vector3(0, CharacterModel.HEAD_LIFT, 0)
			if eyes.size() > 0:
				var c := Vector3.ZERO
				for e in eyes:
					c += e
				target = c / float(eyes.size())
				face = target - head
			face.y = 0.0
			face = face.normalized() if face.length() > 0.001 else Vector3.FORWARD
			var t_face: float = _out_anim[me.id]["t"]
			# 顔のアップから、崩れ落ちるときは少し引いて、下がる体を追う
			var pull := clampf((t_face - OUT_FACE_TIME) / OUT_FALL_TIME, 0.0, 1.0)
			# (崩れ落ちるときは頭が前にたれるので、カメラを下げて、下から顔を見上げる)
			var eye := target + face * lerpf(0.85, 1.2, pull) + Vector3(0, lerpf(0.0, -0.35, pull), 0)
			_seat_cam.look_at_from_position(eye, target + Vector3(0, -0.1 * pull, 0))
			return
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
		# 砂のお城を抱えて走るときは、カメラを少し寄せて、お城がよく見えるように
		var near := 0.72 if _beach and _item_index == 3 and me.id == state.chaser_id else 1.0
		var want_r := Vector3(me.position.x, 0.0, me.position.z) - fwd * GameConfig.CHASE_CAM_DISTANCE * near \
				+ Vector3(0, GameConfig.CHASE_CAM_HEIGHT * lerpf(1.0, near, 0.6), 0)
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
	if _beach:
		height -= BEACH_CAM_DROP
	_seat_cam.position = me.position + Vector3(0, height, 0) + back_dir * back
	var pitch := lerpf(GameConfig.SEAT_CAM_PITCH_FRONT, GameConfig.SEAT_CAM_PITCH_BACK, t)
	_seat_cam.rotation = Vector3(deg_to_rad(pitch), me.yaw + PI * t, 0.0)


## アニメ塗り+黒い輪郭線(Toon)の見た目
func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	return Toon.mesh(mesh, color)
