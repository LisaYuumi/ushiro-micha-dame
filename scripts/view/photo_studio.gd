class_name PhotoStudio
extends Node3D
## 撮影モード(開発用): Steam のストア画像・スクリーンショット・紹介動画の素材を撮るための画面。
## ゲームの状態にはさわらない(撮影用の状態と教室を、ここで別に作る。ひとりで遊ぶときだけ開け、その間ゲームは止まる)。
## - 場面: 教室 / 海辺(8人。ゲームと同じ教室・海辺を、撮影用に作る)
## - カメラ: 輪の全体 / 教室の全体 / キャラの寄り / 鬼の後ろ / 自由(ドラッグで回す・ホイールやピンチで近づく)
## - キャラを選んで、ポーズ(座る・体育座り・立つ・歩く・走る・振り向く・転ぶ・ひざ崩れ)と
##   表情(ふつう・驚く・勝ち・負け・ニヤニヤ・気まずい・お手つき・必死・困り眉・汗だく・放心)を変える
## - 落とし物: なし / 手に持つ / 背中の後ろに落ちている(選んだキャラ)。種類はラウンドごとの落とし物から
## - 背景: ふつう / キャラだけ(透明。保存すると背景が透明の PNG)
## - 投票: 投票の画面の「証拠」(上の1行・頭の上の言葉・大事な人の足もとの光)を、それらしい中身で出す
## - 「4Kで保存」: 画面の大きさに関係なく 3840×2160 の PNG(Web 版はダウンロード、PC は「ピクチャ」に保存)
## - UI を消す: 操作パネルを隠す(PC は H キーでも)。消している間は、画面を軽くタップすると戻る

signal closed

const STAGES := {"教室": "classroom", "海辺": "beach", "夜の教室": "night"}
const CAMERAS := ["輪の全体", "教室の全体", "キャラの寄り", "鬼の後ろ", "自由"]
const POSES := ["座る", "体育座り", "立つ", "歩く", "走る", "振り向く", "転ぶ", "ひざ崩れ"]
const FACES := ["ふつう", "驚く", "ガーン", "勝ち", "負け", "ニヤニヤ", "気まずい", "お手つき", "必死", "困り眉", "汗だく", "放心"]
const ITEMS := ["なし", "手に持つ", "背中の後ろ"]
## 保存する画像の大きさ(4K)
const SHOT_SIZE := Vector2i(3840, 2160)
## 撮影用の人数(席7つ+鬼1人)
const SEATS := 7
## 立つ・走るなどのポーズでは、椅子と重ならないように、輪の外側(鬼が歩くところ)に立たせる
const STAND_POSES := ["立つ", "歩く", "走る", "転ぶ", "ひざ崩れ"]

var _state: GameState
var _view: WorldView
var _cam: Camera3D
var _env_preview: Environment
var _ui: CanvasLayer
var _panel: PanelContainer
var _buttons: Array[Button] = []
var _sel_label: Label
var _item_label: Label
var _msg: Label

var _stage := "classroom"
var _cam_mode := "輪の全体"
var _sel := 0
var _poses := {}
var _faces := {}
var _item := "なし"
var _item_round := 0
var _transparent := false
var _frozen := false
var _ui_hidden := false
var _saving := false

## 自由カメラ(中心のまわりを回る)
var _orbit_center := Vector3(0, 0.8, 0)
var _yaw := 0.0
var _pitch := 0.5
var _dist := 8.0
## 指・マウスの押しはじめ(短く押して離したら「タップ」)と、指ごとの位置(ピンチ)
var _press_pos := Vector2.ZERO
var _press_time := 0
var _press_on_panel := false
var _dragging := false
var _touches := {}
var _pinch_dist := 0.0


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_cam.make_current()
	# 停電中に開いても、撮影の教室はふつうの明るさで(ゲームに戻ると、ゲームの明るさに戻る)
	Toon.set_darkness(1.0)
	Toon.set_night(0.0)
	_build_ui()
	_rebuild_scene()


func _exit_tree() -> void:
	# 夜の明るさを元に戻す(ゲームが夜の教室なら、ゲームの画面が毎フレームまた夜にする)
	Toon.set_night(0.0)
	Toon.set_darkness(1.0)
	# 撮影用の教室を片づける(ゲームの教室にはさわっていない)
	if _view and is_instance_valid(_view):
		_view.queue_free()


# --- 場面づくり ---

func _rebuild_scene() -> void:
	if _view and is_instance_valid(_view):
		_view.queue_free()
	_state = GameState.new()
	_state.stage = _stage
	_state.custom_bot_names = Profile.active_bot_names()
	_state.start_match(7, false, SEATS, Profile.player_name, Profile.color, Profile.accessories)
	_state.round_index = _item_round
	_state.take_events()
	_view = WorldView.new()
	add_child(_view)
	_view.build(_state)
	_titles_data = {}
	if _titles_mode != "なし":
		_show_titles.call_deferred(false)
	var ov := _view.get_overlay()
	if ov:
		ov.visible = false
	_apply_vote.call_deferred()
	_poses.clear()
	_faces.clear()
	for a in _state.actors:
		_poses[a.id] = "立つ" if a.role == GameState.Role.ONI else "座る"
		_faces[a.id] = "ふつう"
		var m := _model(a.id)
		if m:
			m.set_name_visible(false)
	_sel = clampi(_sel, 0, _state.actors.size() - 1)
	_env_preview = (_view._env as Environment).duplicate()
	_apply_background()
	_cam.make_current()
	_update_ui()


func _model(id: int) -> CharacterModel:
	return _view._actor_nodes.get(id) as CharacterModel


func _selected() -> GameState.Actor:
	return _state.actors[_sel]


func _process(delta: float) -> void:
	if _view == null or not is_instance_valid(_view):
		return
	if _titles_node and is_instance_valid(_titles_node):
		# 称号発表・記念写真: キャラの並びとカメラは、ゲームと同じ動き(WorldView)にまかせる
		_view.sync(_state, delta)
		_view.apply_night_light(_state)
		return
	for a in _state.actors:
		var m := _model(a.id)
		if m == null:
			continue
		_place(a, m)
		_apply_pose(a, m)
		_apply_face(a, m)
		if not _frozen:
			m.animate(delta, _poses[a.id] == "走る")
	_apply_item()
	_apply_wet()
	if _vote_mode == "証拠":
		_view._update_key_rings()
		var ov := _view.get_overlay()
		if ov and not _saving:
			ov.set_label_top((_ev_frame["panel"] as Control).get_global_rect().end.y + 6.0)
			ov.update(_state, _cam)
	# 夜の教室は、ゲームと同じ夜の明るさ(窓側は月の光)
	_view.apply_night_light(_state)
	_apply_camera()


## 立つポーズの人は、輪の外側(鬼が歩くところ)の同じ方向に立たせる(走る・歩くは輪にそって進む向き)
func _place(a: GameState.Actor, m: CharacterModel) -> void:
	var pose: String = _poses[a.id]
	if a.role == GameState.Role.ONI or not (pose in STAND_POSES):
		m.position = a.position
		m.rotation.y = a.yaw
		return
	var ang := atan2(a.position.x, a.position.z)
	m.position = Vector3(sin(ang), 0.0, cos(ang)) * GameConfig.ONI_WALK_RADIUS
	if pose == "歩く" or pose == "走る" or pose == "転ぶ":
		m.rotation.y = atan2(-cos(ang), sin(ang))
	else:
		# 輪の中心を向く
		m.rotation.y = ang


func _apply_pose(a: GameState.Actor, m: CharacterModel) -> void:
	var pose: String = _poses[a.id]
	var seated := "floor" if _stage == "beach" else "sit"
	m.set_look(pose == "振り向く")
	m.set_down(pose == "転ぶ")
	m.set_kneel(pose == "ひざ崩れ")
	match pose:
		"座る", "振り向く":
			m.set_pose(seated if a.role != GameState.Role.ONI else "floor")
		"体育座り":
			m.set_pose("floor")
		"歩く":
			m.set_pose("walk")
		"走る", "転ぶ":
			m.set_pose("run")
		_:
			m.set_pose("idle")


func _apply_face(a: GameState.Actor, m: CharacterModel) -> void:
	var face: String = _faces[a.id]
	var expr := CharacterModel.NORMAL
	var fluster := 0
	match face:
		"驚く":
			expr = CharacterModel.SURPRISED
		"ガーン":
			expr = CharacterModel.SHOCK
		"勝ち":
			expr = CharacterModel.WIN
		"負け":
			expr = CharacterModel.LOSE
		"ニヤニヤ":
			expr = CharacterModel.SMIRK
		"気まずい":
			expr = CharacterModel.AWKWARD
		"お手つき":
			expr = CharacterModel.OOPS
		"必死":
			expr = CharacterModel.PANIC
		"困り眉":
			fluster = 1
		"汗だく":
			fluster = 2
		"放心":
			fluster = CharacterModel.FLUSTER_MAX
	m.set_expression(expr)
	m.set_fluster(fluster)


## 落とし物: 選んだキャラが手に持つ / そのキャラの席の後ろに落ちている
func _apply_item() -> void:
	var h: Node3D = _view._handkerchief
	if h == null:
		return
	var a := _selected()
	if _view._straps and is_instance_valid(_view._straps):
		_view._straps.visible = false
	var tucker: CharacterModel = _view._tucker
	_view._tucker = null
	match _item:
		"手に持つ":
			h.visible = true
			_view._carry_item(_model(a.id))
		"背中の後ろ":
			h.visible = true
			var ang := atan2(a.position.x, a.position.z)
			h.transform = Transform3D(Basis.IDENTITY, Vector3(sin(ang), 0.0, cos(ang)) * GameConfig.DROP_RADIUS)
		_:
			h.visible = false
	if tucker != _view._tucker and tucker and is_instance_valid(tucker):
		tucker.set_tuck(false)


# --- カメラ ---

func _apply_camera() -> void:
	_apply_camera_pose()
	# 天井より高いところから見るときは、天井を映さない(上から見ると天井でかくれるので)
	var no_ceiling := _cam.global_position.y > WorldView.ROOM_HEIGHT - 0.2
	var mask := 0xFFFFF & ~(1 << (WorldView.CEILING_LAYER - 1)) if no_ceiling else 0xFFFFF
	if _cam.cull_mask != mask:
		_cam.cull_mask = mask


func _apply_camera_pose() -> void:
	# 水鉄砲の「本人の画面」: 選んだキャラの目の高さから、輪のまん中を見る
	if _water_mode == "本人の画面":
		var me := _model(_selected().id)
		if me:
			var eye := me.bone_world("DEF-head").origin + Vector3(0, 0.05, 0)
			_cam.fov = 60
			_cam.look_at_from_position(eye, Vector3(0, 0.8, 0))
			return
	# 投票の画面: ゲームの投票と同じカメラ(自由カメラにすると、好きな向きで撮れる)
	if _vote_mode == "証拠" and _cam_mode != "自由":
		_cam.fov = 55
		_cam.global_transform = _view.vote_camera_transform(_state)
		return
	match _cam_mode:
		"輪の全体":
			_cam.fov = 50
			_cam.look_at_from_position(Vector3(0, 5.0, 7.2), Vector3(0, 0.5, 0))
		"教室の全体":
			if _stage == "beach":
				_cam.fov = 60
				_cam.look_at_from_position(Vector3(0, 3.2, 10.5), Vector3(0, 1.0, -3.0))
			else:
				_cam.fov = 64
				_cam.look_at_from_position(Vector3(6.6, 3.5, 7.0), Vector3(-2.0, 1.4, -4.5))
		"キャラの寄り":
			var m := _model(_selected().id)
			if m:
				var f: Array = _view._face_point(m)
				var target: Vector3 = (f[0] as Vector3) + Vector3(0, -0.2, 0)
				_cam.fov = 34
				_cam.look_at_from_position(target + (f[1] as Vector3) * 1.5 + Vector3(0, 0.12, 0), target)
		"鬼の後ろ":
			var oni := _model(_state.oni_id)
			if oni:
				var p := oni.global_position
				var d := Vector3(-p.x, 0.0, -p.z).normalized()
				var side := d.cross(Vector3.UP).normalized()
				_cam.fov = 55
				_cam.look_at_from_position(p - d * 1.5 + side * 0.45 + Vector3(0, 1.8, 0), Vector3(0, 0.7, 0) + d * 0.5)
		"自由":
			_cam.fov = 50
			var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
			_cam.look_at_from_position(_orbit_center + off, _orbit_center)


## 自由カメラにするとき: 今のカメラの位置から始める(中心は輪のまん中。キャラの寄りからなら、そのキャラ)
func _start_free() -> void:
	_orbit_center = Vector3(0, 0.8, 0)
	if _cam_mode == "キャラの寄り":
		var m := _model(_selected().id)
		if m:
			_orbit_center = (_view._face_point(m)[0] as Vector3) + Vector3(0, -0.2, 0)
	var off := _cam.global_position - _orbit_center
	_dist = clampf(off.length(), 0.8, 18.0)
	_pitch = clampf(asin(clampf(off.y / maxf(off.length(), 0.001), -1.0, 1.0)), -0.2, 1.45)
	_yaw = atan2(off.x, off.z)


# --- 背景(ふつう / キャラだけ) ---

func _apply_background() -> void:
	var env := _env_preview
	if _transparent:
		# 画面では灰色の背景で見せる(保存するときだけ透明にする)
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("8C8C8C")
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = (_view._env as Environment).background_color
	_cam.environment = env
	var keep := {}
	for id in _view._actor_nodes:
		keep[_view._actor_nodes[id]] = true
	keep[_view._handkerchief] = true
	for c in _view.get_children():
		if c is CanvasLayer or not (c is Node3D):
			continue
		if c is Light3D or c is WorldEnvironment or keep.has(c):
			continue
		var n := c as Node3D
		# もともと隠れている物(牛乳のしぶきなど)は出さない: 自分で隠した物だけ戻す
		if _transparent and n.visible:
			n.visible = false
			n.set_meta("studio_hid", true)
		elif not _transparent and n.get_meta("studio_hid", false):
			n.visible = true
			n.set_meta("studio_hid", false)


# --- 4K で保存 ---

func _save_shot() -> void:
	if _saving:
		return
	_saving = true
	_show_msg("保存しています…")
	var sv := SubViewport.new()
	sv.size = SHOT_SIZE
	sv.world_3d = get_viewport().world_3d
	sv.transparent_bg = _transparent
	# (スマホは大きな絵を作るだけで重いので、ふちのなめらかさを少し下げる)
	sv.msaa_3d = Viewport.MSAA_2X if Device.is_mobile() else Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Camera3D.new()
	c.fov = _cam.fov
	c.keep_aspect = _cam.keep_aspect
	c.cull_mask = _cam.cull_mask
	var env := _env_preview.duplicate() as Environment
	if _transparent:
		env.background_mode = Environment.BG_CLEAR_COLOR
	c.environment = env
	add_child(sv)
	sv.add_child(c)
	if _water_mode == "本人の画面":
		# 水鉄砲の本人の画面: 水しぶきの絵も入れる
		sv.size_2d_override = Vector2i(get_viewport().get_visible_rect().size)
		sv.size_2d_override_stretch = true
		var wl := CanvasLayer.new()
		wl.add_child(_water_haze())
		var wr := TextureRect.new()
		wr.set_anchors_preset(Control.PRESET_FULL_RECT)
		wr.stretch_mode = TextureRect.STRETCH_SCALE
		wr.texture = MilkArt.texture(get_viewport().get_visible_rect().size, 1.5, true)
		wl.add_child(wr)
		sv.add_child(wl)
	var moved: Array[CanvasLayer] = []
	if _vote_mode == "証拠":
		# 投票の証拠(頭の上の言葉・上の1行)も入れる(2D は今の画面の大きさで作って、4K に引きのばす)
		sv.size_2d_override = Vector2i(get_viewport().get_visible_rect().size)
		sv.size_2d_override_stretch = true
		for l in [_view.get_overlay(), _ev_layer]:
			if l and is_instance_valid(l):
				moved.append(l)
				l.reparent(sv, false)
	if _titles_node and is_instance_valid(_titles_node):
		# 称号の画面も入れる(2D は今の画面の大きさで作って、4K に引きのばす)
		sv.size_2d_override = Vector2i(get_viewport().get_visible_rect().size)
		sv.size_2d_override_stretch = true
		sv.add_child(_new_titles(true, false))
	c.global_transform = _cam.global_transform
	if _titles_node and is_instance_valid(_titles_node):
		# 称号発表・記念写真のときは、そのときのカメラ(WorldView の称号用のカメラ)で撮る
		var live := get_viewport().get_camera_3d()
		if live:
			c.fov = live.fov
			c.global_transform = live.global_transform
	c.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	for l in moved:
		l.reparent(_view if l == _view.get_overlay() else self, false)
	sv.queue_free()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file := "ushiro_%s%s.png" % [stamp, "_alpha" if _transparent else ""]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file, "image/png")
		_show_msg("ダウンロードしました: " + file)
	else:
		var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if dir == "" or not DirAccess.dir_exists_absolute(dir):
			dir = OS.get_user_data_dir()
		var path := dir.path_join(file)
		var err := img.save_png(path)
		_show_msg(("保存しました: " + path) if err == OK else ("保存できませんでした(%d)" % err))
	_saving = false


func _show_msg(text: String) -> void:
	if _msg:
		_msg.text = text


# --- 操作パネル ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	_panel = PanelContainer.new()
	var st := UiStyle.box(Color(1, 1, 1, 0.94), true, 20, 4)
	st.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", st)
	_ui.add_child(_panel)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -UiStyle.SAFE - 620
	_panel.offset_right = -UiStyle.SAFE + 20
	_panel.offset_top = 8
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	col.add_child(UiStyle.label("撮影モード(開発用)", 20, GameConfig.COLOR_INK))
	_row(col, "場面", STAGES.keys(), func(v: String) -> void:
		_stage = STAGES[v]
		_rebuild_scene())
	_row(col, "カメラ", CAMERAS, func(v: String) -> void:
		if v == "自由" and _cam_mode != "自由":
			_start_free()
		_cam_mode = v)
	# キャラを選ぶ(◀ 名前 ▶)
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	col.add_child(sel)
	sel.add_child(_row_label("キャラ"))
	sel.add_child(_button("◀", func() -> void: _pick_actor(-1)))
	_sel_label = UiStyle.label("", 18, GameConfig.COLOR_INK)
	_sel_label.custom_minimum_size = Vector2(190, 0)
	_sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel.add_child(_sel_label)
	sel.add_child(_button("▶", func() -> void: _pick_actor(1)))
	sel.add_child(_button("全員に", _apply_to_all))
	_row(col, "ポーズ", POSES, func(v: String) -> void: _poses[_selected().id] = v)
	_row(col, "表情", FACES, func(v: String) -> void: _faces[_selected().id] = v)
	var item_row := _row(col, "落とし物", ITEMS, func(v: String) -> void: _item = v)
	item_row.add_child(_button("種類 ▶", _next_item_kind))
	_item_label = UiStyle.label("", 16, GameConfig.COLOR_INK)
	item_row.add_child(_item_label)
	_row(col, "背景", ["ふつう", "キャラだけ"], func(v: String) -> void:
		_transparent = v == "キャラだけ"
		_apply_background())
	_row(col, "動き", ["うごく", "止める"], func(v: String) -> void: _frozen = v == "止める")
	# 水鉄砲(海辺): 選んだキャラがびしょぬれ。「まわりから」はまわりから見た姿、「本人の画面」はその人の目から見た水しぶきの画面
	_row(col, "水鉄砲", ["なし", "まわりから", "本人の画面"], func(v: String) -> void:
		_water_mode = v
		_apply_water())
	# 試合の最後の称号の画面(称号はそれらしいものをランダムに。「演出」は1人ずつ出す流れ。4Kで保存にも入る)
	_row(col, "称号", ["なし", "表示", "演出", "選び直す"], func(v: String) -> void:
		if v == "選び直す":
			_titles_data = {}
			if _titles_mode == "なし":
				_titles_mode = "表示"
		else:
			_titles_mode = v
		_show_titles(_titles_mode == "演出"))
	# 投票の画面の証拠(落とされた人=選んだキャラ。ほかにお手つきの人が1人。言葉はランダム。4Kで保存にも入る)
	_row(col, "投票", ["なし", "証拠", "言葉を変える"], func(v: String) -> void:
		if v == "言葉を変える":
			_vote_seed += 1
			if _vote_mode == "なし":
				_vote_mode = "証拠"
		else:
			_vote_mode = v
		_apply_vote())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	col.add_child(bottom)
	bottom.add_child(_button("UIを消す(H)", _set_ui_hidden.bind(true)))
	bottom.add_child(_button("4Kで保存", _save_shot, "", true))
	bottom.add_child(_button("もどる", _close))
	_msg = UiStyle.label("", 15, GameConfig.COLOR_INK)
	_msg.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_msg.custom_minimum_size = Vector2(560, 0)
	col.add_child(_msg)


func _row(parent: VBoxContainer, label: String, values: Array, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	row.add_child(_row_label(label))
	for v in values:
		var value: String = v
		row.add_child(_button(value, _pick.bind(on_pick, value), label + ":" + value))
	return row


func _pick(on_pick: Callable, value: String) -> void:
	on_pick.call(value)
	_update_ui()


func _pick_actor(d: int) -> void:
	_sel = posmod(_sel + d, _state.actors.size())
	_update_ui()


func _apply_to_all() -> void:
	var a := _selected()
	for b in _state.actors:
		_poses[b.id] = _poses[a.id]
		_faces[b.id] = _faces[a.id]


func _next_item_kind() -> void:
	_item_round = (_item_round + 1) % Items.count()
	_rebuild_scene()


func _close() -> void:
	closed.emit()


func _row_label(text: String) -> Label:
	var l := UiStyle.label(text, 18, GameConfig.COLOR_INK)
	l.custom_minimum_size = Vector2(76, 0)
	return l


## 選んでいるものはオレンジにする(key: "ポーズ:座る" など)
func _button(text: String, on_press: Callable, key: String = "", accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_NONE
	UiStyle.button(b, accent, 17)
	b.pressed.connect(on_press)
	b.set_meta("key", key)
	b.set_meta("accent", accent)
	_buttons.append(b)
	return b


func _update_ui() -> void:
	if _state == null:
		return
	var a := _selected()
	var who := Locale.actor_name(a.display_name)
	if a.id == _state.oni_id:
		who += "(鬼)"
	elif a.id == _state.local_player_id:
		who = Profile.player_name + "(自分)"
	_sel_label.text = who
	_item_label.text = _state.item_name()
	var stage_name := "教室"
	for k in STAGES:
		if STAGES[k] == _stage:
			stage_name = k
	var chosen := {
		"場面:" + stage_name: true,
		"カメラ:" + _cam_mode: true,
		"ポーズ:" + str(_poses.get(a.id, "")): true,
		"表情:" + str(_faces.get(a.id, "")): true,
		"落とし物:" + _item: true,
		"背景:" + ("キャラだけ" if _transparent else "ふつう"): true,
		"動き:" + ("止める" if _frozen else "うごく"): true,
		"称号:" + _titles_mode: true,
		"水鉄砲:" + _water_mode: true,
		"投票:" + _vote_mode: true,
	}
	for b in _buttons:
		var key: String = b.get_meta("key", "")
		if key == "":
			continue
		UiStyle.button(b, chosen.get(key, false), 17)


## 水鉄砲(海辺): "なし" / "まわりから" / "本人の画面"
var _water_mode := "なし"
var _water_layer: CanvasLayer
var _water_rect: TextureRect


func _apply_water() -> void:
	if _water_mode == "本人の画面":
		if _water_layer == null:
			_water_layer = CanvasLayer.new()
			_water_layer.layer = 1
			add_child(_water_layer)
			_water_layer.add_child(_water_haze())
			_water_rect = TextureRect.new()
			_water_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_water_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_water_rect.stretch_mode = TextureRect.STRETCH_SCALE
			_water_layer.add_child(_water_rect)
		_water_rect.texture = MilkArt.texture(get_viewport().get_visible_rect().size, 1.5, true)
		_water_layer.visible = true
	elif _water_layer:
		_water_layer.visible = false


## 画面全体の水のにじみ(ゲームの画面と同じ)
func _water_haze() -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Color(MilkArt.WATER_WHITE)
	col.a = 0.9
	c.color = col
	return c


## 選んだキャラのびしょぬれの見た目(頭の水・しずく・「見えない!」のマーク・濡れた色)。本人の画面のときは、その人の体は映さない
func _apply_wet() -> void:
	var a := _selected()
	for b in _state.actors:
		var m := _model(b.id)
		var milk: Node3D = _view._milk_nodes.get(b.id)
		var wet: bool = _water_mode != "なし" and b.id == a.id
		if m:
			m.set_wet(wet and _view._beach)
			m.visible = not (_water_mode == "本人の画面" and b.id == a.id)
		if milk:
			milk.visible = wet and _water_mode == "まわりから"
			if milk.visible and m:
				milk.global_transform = Transform3D(m.global_transform.basis.orthonormalized(), m.bone_world("DEF-head").origin)


## 称号の画面
var _titles_mode := "なし"
var _titles_node: TitleReveal
var _titles_data := {}


func _show_titles(animate: bool) -> void:
	if _titles_node and is_instance_valid(_titles_node):
		_titles_node.queue_free()
	_titles_node = null
	if _view and is_instance_valid(_view):
		_view.ceremony_end()
	_cam.make_current()
	if _titles_mode == "なし" or _state == null:
		return
	if _titles_data.is_empty():
		_titles_data = _make_titles()
	_titles_node = _new_titles(not animate)
	add_child(_titles_node)
	move_child(_titles_node, 0)


func _new_titles(instant: bool, controls := true) -> TitleReveal:
	var t := TitleReveal.new()
	t.controls_view = controls
	t.ready.connect(func() -> void:
		t.setup(_view, _state, _titles_data["rows"], _titles_data["titles"], "", "", instant), CONNECT_ONE_SHOT)
	return t


## それらしい点数と称号(順位の高い順の行と、称号)
func _make_titles() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ids := []
	var sc := {}
	for a in _state.actors:
		ids.append(a.id)
		sc[a.id] = rng.randi_range(0, 14)
	ids.sort_custom(func(x, y): return sc[x] > sc[y])
	var rows := []
	var rank := 0
	var prev := -1
	for i in ids.size():
		var a := _state.get_actor(ids[i])
		if sc[ids[i]] != prev:
			rank = i + 1
			prev = sc[ids[i]]
		rows.append({
			"title_id": a.id,
			"name": Profile.player_name if a.id == _state.local_player_id else Locale.actor_name(a.display_name),
			"color": a.color,
			"score": sc[a.id],
			"mark": "★" if rank == 1 else tr("%d位") % rank,
			"me": false,
		})
	return {"rows": rows, "titles": Titles.sample(ids, _stage, rng)}


func _set_ui_hidden(v: bool) -> void:
	_ui_hidden = v
	_panel.visible = not v


# --- 入力: パネルのボタン(スマホの指)、H キー、自由カメラ(ドラッグ・ホイール・ピンチ)、UI を消している間のタップ ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_H:
			_set_ui_hidden(not _ui_hidden)
			get_viewport().set_input_as_handled()
		elif (event as InputEventKey).keycode == KEY_ESCAPE and _ui_hidden:
			_set_ui_hidden(false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _cam_mode == "自由" and mb.pressed:
				_dist = clampf(_dist * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.8, 18.0)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_on_press(mb.position, mb.pressed)
			if not _ui_hidden and not mb.pressed:
				pass
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_on_drag((event as InputEventMouseMotion).relative)
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch_dist = _touch_spread()
		if _touches.size() <= 1:
			# 指のボタン(マウスなしで動かすので、自分で押す)
			if t.pressed and not _ui_hidden:
				for b in _buttons:
					if b.is_visible_in_tree() and b.get_global_rect().has_point(t.position):
						b.pressed.emit()
						get_viewport().set_input_as_handled()
						_press_on_panel = true
						return
			_on_press(t.position, t.pressed)
		return
	if event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		_touches[dr.index] = dr.position
		if _touches.size() >= 2:
			# ピンチで近づく・離れる
			var spread := _touch_spread()
			if _pinch_dist > 0.0 and _cam_mode == "自由":
				_dist = clampf(_dist * _pinch_dist / maxf(spread, 1.0), 0.8, 18.0)
			_pinch_dist = spread
			_dragging = true
		else:
			_on_drag(dr.relative)


func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _on_press(pos: Vector2, pressed: bool) -> void:
	if pressed:
		_press_pos = pos
		_press_time = Time.get_ticks_msec()
		_dragging = false
		_press_on_panel = _panel.visible and _panel.get_global_rect().has_point(pos)
		return
	# 離した: 短いタップなら、UI を消している間は戻す
	var tap := not _dragging and pos.distance_to(_press_pos) < 12.0 and Time.get_ticks_msec() - _press_time < 350
	if tap and _ui_hidden:
		_set_ui_hidden(false)
		get_viewport().set_input_as_handled()
	_dragging = false


func _on_drag(rel: Vector2) -> void:
	if _press_on_panel:
		return
	if rel.length() > 1.0:
		_dragging = true
	if _cam_mode != "自由":
		return
	_yaw -= rel.x * 0.006
	_pitch = clampf(_pitch + rel.y * 0.005, -0.2, 1.45)


## 投票の画面の証拠: "なし" / "証拠"
var _vote_mode := "なし"
var _vote_seed := 0
var _ev_layer: CanvasLayer
var _ev_frame: Dictionary


func _apply_vote() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var ov := _view.get_overlay()
	if _vote_mode != "証拠":
		_view.set_key_people([])
		if ov:
			ov.set_vote_evidence(false)
			ov.visible = false
		if _ev_layer:
			_ev_layer.visible = false
		return
	_make_evidence()
	# 場面の再現: 落とし物は落とされた人(選んだキャラ)のうしろ、お手つきの人は振り返った姿勢
	_item = "背中の後ろ"
	for id in _state.round_otetsuki:
		_poses[id] = "振り向く"
	_view._vote_cam_at = -100000
	var keys := _state.evidence_key_ids()
	_view.set_key_people(keys)
	if ov:
		ov.set_vote_evidence(true, HeadOverlay.evidence_bubbles(_state))
		ov.visible = true
	if _ev_layer == null:
		# ゲームの投票と同じ、上の1つの枠
		_ev_layer = CanvasLayer.new()
		_ev_layer.layer = 2
		add_child(_ev_layer)
		_ev_frame = Hud.make_vote_frame()
		_ev_layer.add_child(_ev_frame["panel"])
	_ev_layer.visible = true
	var voters := _state.actors.size() - 1
	(_ev_frame["count"] as Label).text = tr("%d/%d人 投票済み") % [voters / 2, voters]


## それらしい証拠: 選んだキャラ(座っている人)のうしろに落ちていて、ほかの1人がお手つき。みんながいくつか言葉を送った
func _make_evidence() -> void:
	var seated := []
	for a in _state.actors:
		if a.role == GameState.Role.SEATED:
			seated.append(a.id)
	if seated.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (_vote_seed + 1)
	var dropped: int = _selected().id if _selected().id in seated else seated[0]
	var others := seated.filter(func(id): return id != dropped)
	var oops: int = others[rng.randi() % others.size()]
	# (時刻: 30秒にお手つき、40秒に落とした。落とされた人は見つけていない)
	_state.round_dropped_on = dropped
	_state.round_otetsuki = [oops]
	_state.round_otetsuki_seen = {}
	_state.round_drop_t = 40.0
	_state.round_found_t = -1.0
	_state.stamp_log.clear()
	var kinds := ["dropped", "safe", "trust"]
	for a in _state.actors:
		for i in rng.randi_range(0, 2):
			var target: int = [dropped, oops][rng.randi() % 2]
			if target == a.id:
				continue
			var t := rng.randf_range(41.0, 60.0) if target == dropped else rng.randf_range(21.0, 30.0)
			_state.stamp_log.append({"sender": a.id, "target": target, "kind": kinds[rng.randi() % kinds.size()], "truthful": true, "t": t})
	_state.stamp_log.sort_custom(func(x, y): return float(x["t"]) < float(y["t"]))
	# (お手つきの人: 振り向いたときに届いていた言葉 = 最後の3つ)
	var seen := []
	for st in _state.stamp_log:
		if int(st["target"]) == oops:
			seen.append({"sender": st["sender"], "kind": st["kind"]})
	_state.round_otetsuki_seen[oops] = seen.slice(maxi(seen.size() - 3, 0))
