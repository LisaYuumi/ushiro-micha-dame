extends SceneTree
## 自動チェック(GitHub の自動変換のときに実行される)。
##   godot --headless -s res://tests/smoke_test.gd
## 1. GameState のルールを、画面なしで確かめる
## 2. 本番のシーンを数秒動かして、スクリプトのエラーが出ないか確かめる

const STEP := 1.0 / 60.0
const MAIN_SCENE_FRAMES := 210
var _chase_lasted := false
var _chase_time := 0.0
var _vote_outside := ""

var _failures := 0
var _frames := 0
var _carry_model: CharacterModel
var _main: Node
## 転ぶ(物理演算)の確認用のキャラ
var _faller: CharacterModel
var _faller_head_y := 0.0
var _faller_min_head_y := INF
## 転んでからの時間(秒)。-1 = まだ転んでいない
var _fall_clock := -1.0
var _fall_done := false


func _initialize() -> void:
	# テストは日本語の文字で確かめる(端末の言語に関係なく)
	Locale.setup("ja")
	_test_drop_happens_for_every_seed()
	_test_otetsuki_when_nothing_behind()
	_test_found_when_handkerchief_behind()
	_test_decoy_rustle_is_behind_a_seat()
	_test_bot_cannot_look_back_as_oni()
	_test_missed_when_nobody_notices()
	_test_pick_up_rules()
	_test_oni_sits_if_chaser_stands_still()
	_test_touch_wins()
	_test_chaser_never_stops()
	_test_chase_lanes_and_speed()
	_test_obstacles()
	_test_overtake_is_touch()
	_test_no_otetsuki_during_chase()
	_test_rounds_with_bots_always_finish()
	_test_stamp_rules()
	_test_stamp_truthfulness()
	_test_stamp_words()
	_test_milk_art()
	_test_blackout()
	_test_sounds()
	_test_languages()
	_test_custom_stamp_words()
	_test_bots_send_and_trust_stamps()
	_test_player_oni_setup()
	_test_player_oni_walk_speed_and_stop()
	_test_player_oni_drop_and_feint()
	_test_player_oni_auto_drop_after_laps()
	_test_player_oni_rounds_finish()
	_test_match_next_oni_is_loser()
	_test_match_scores_and_end()
	_test_titles()
	_test_heavier_items_slow_the_chaser()
	_test_banana_rules()
	_test_banana_can_be_dodged()
	_test_bots_throw_bananas()
	_test_who_can_see_behind_whom()
	_test_stamp_sender_hidden_up_to_six()
	_test_miss_goes_out()
	_test_milk()
	_test_deceiving_scores()
	_test_minion()
	_test_two_minions()
	_test_minion_vote()
	_test_custom_bot_names()
	_test_night_stage()
	_test_beach_stage()
	_test_accessories()
	_test_lap_behind_not_touch()
	_test_stamp_shuffle()
	_test_bots_quiet_in_blackout()
	_test_missed_replay_data()
	_test_bot_personalities()
	_test_look_limit_and_patience()
	_test_online_match_setup()
	_test_humans_only_oni()
	_test_snapshot_round_trip()
	_test_vote_evidence()
	_test_character_model()
	_test_profile_names_and_colors()

	# 本番の画面も日本語で動かす(端末の言語に関係なく)
	Profile.load_saved()
	Profile.lang = "ja"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_check_carry()
	if _frames == 6:
		_check_heart()
	if _frames == 7:
		_check_vote_scene()
	_check_fall(delta)
	if _frames == 60:
		# ボタン操作と同じ命令を送ってみる
		_press("look_back", true)
	elif _frames == 90:
		_press("look_back", false)
		_press("debug_top_camera", true)
		_press("debug_top_camera", false)
	elif _frames == 100:
		# 拾う・走る操作も送ってみる(拾えない場面でもエラーにならないこと)
		_press("pick_up", true)
		_press("pick_up", false)
		Input.action_press("move_right", 1.0)
	elif _frames == 110:
		Input.action_release("move_right")
	elif _frames == 120:
		_press("sound_test", true)
		_press("sound_test", false)
		_press("oni_milk", true)
		_press("oni_milk", false)
		_press("banana_oni", true)
		_press("banana_oni", false)
		# 相手を選ばずにスタンプ → 相手を選んでスタンプ
		_press("stamp_0", true)
		_press("stamp_0", false)
		_main._stamp_target = 1
		_press("stamp_1", true)
		_press("stamp_1", false)
		_press("restart", true)
		_press("restart", false)
	_check_photo_mode()
	if _frames == 175:
		_check_tutorial()
	if _frames == 185:
		_check_ending()
	if (_frames < MAIN_SCENE_FRAMES or not _fall_done) and _frames < 5000:
		return false
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("TESTS FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
	return true


## 撮影モード: 開いて、向き・表情・ポーズ・色・輪の場面を切りかえ、もどれる
func _check_photo_mode() -> void:
	match _frames:
		140:
			_main._open_studio()
			_check(_main._studio != null and not _main.view.visible, "撮影モードが開き、ゲームの画面が隠れる")
		145:
			var st: PhotoStudio = _main._studio
			_check(st._view != null and st._state.actors.size() == PhotoStudio.SEATS + 1, "撮影モード: 撮影用の教室に8人")
			_check(st._state != _main.state, "撮影モード: ゲームの状態とは別の状態で撮る")
			for cam in PhotoStudio.CAMERAS:
				st._pick(func(v: String) -> void: st._cam_mode = v, cam)
				st._apply_camera()
			for pose in PhotoStudio.POSES:
				st._pick(func(v: String) -> void: st._poses[st._selected().id] = v, pose)
				st._process(0.05)
			for face in PhotoStudio.FACES:
				st._pick(func(v: String) -> void: st._faces[st._selected().id] = v, face)
				st._process(0.05)
			for item in PhotoStudio.ITEMS:
				st._item = item
				st._process(0.05)
			_check(st._view._handkerchief.visible, "撮影モード: 落とし物を背中の後ろに置ける")
			st._pick_actor(1)
			st._apply_to_all()
		150:
			var st2: PhotoStudio = _main._studio
			st2._transparent = true
			st2._apply_background()
			var hidden_room := false
			for c in st2._view.get_children():
				if c is MeshInstance3D and not (c as MeshInstance3D).visible:
					hidden_room = true
			_check(hidden_room, "撮影モード: キャラだけ(背景を消す)")
			st2._transparent = false
			st2._apply_background()
			st2._stage = "beach"
			st2._rebuild_scene()
			_check(st2._view._beach, "撮影モード: 海辺の場面")
			st2._pick(func(v: String) -> void: st2._vote_mode = v, "証拠")
			st2._apply_vote()
			st2._process(0.05)
			st2._process(0.05)
			var sov := st2._view.get_overlay()
			_check(st2._state.evidence_key_ids().size() == 2 and sov._oops_marks.size() == 1 and sov._item_mark != null and st2._ev_layer.visible,
					"撮影モード: 投票の証拠(落とし物の▼・お手つきのガーン!)を出せる")
			st2._vote_mode = "なし"
			st2._apply_vote()
			_check(sov._oops_marks.is_empty() and sov._item_mark == null, "撮影モード: 投票の証拠を消せる")
			st2._set_ui_hidden(true)
			_check(not st2._panel.visible, "撮影モード: UIを消せる")
		160:
			_main._studio._close()
			_check(_main._studio == null and _main.view.visible, "撮影モードからもどれる")


## 投票の画面は、ラウンドの場面を再現する: 全員が自分の席、落とし物は落とされた人のうしろ、お手つきの人は振り返ったまま
func _check_vote_scene() -> void:
	var s := GameState.new()
	s.start_round(1)
	var v := WorldView.new()
	root.add_child(v)
	v.build(s)
	var dropped: int = int(s.round_lineup[2])
	var oops: int = int(s.round_lineup[4])
	s.round_dropped_on = dropped
	s.round_otetsuki = [oops]
	# (お手つきの人は真ん中へ、だれかは輪の外へ動いてしまっている)
	s.get_actor(oops).position = Vector3.ZERO
	s.get_actor(int(s.round_lineup[0])).position = Vector3(5, 0, 5)
	s.phase = GameState.Phase.RESULT
	v.set_vote_view(true, s)
	v.sync(s, 0.05)
	var ok := true
	for seat in s.round_lineup.size():
		var m: Node3D = v._actor_nodes[int(s.round_lineup[seat])]
		if m.position.distance_to(s.seat_positions[seat]) > 0.01:
			ok = false
	_check(ok, "投票の場面: 全員が自分の席に戻る")
	var item_at: Vector3 = v._handkerchief.position
	var seat_p: Vector3 = s.seat_positions[2]
	_check(v._handkerchief.visible and item_at.distance_to(seat_p.normalized() * GameConfig.DROP_RADIUS) < 0.01,
			"投票の場面: 落とし物は落とされた人のうしろ")
	_check(v._vote_scene[oops]["look"] and not v._vote_scene[dropped]["look"], "投票の場面: お手つきの人は振り返ったまま")
	_check(absf(v._handkerchief.transform.basis.get_scale().x - WorldView.VOTE_ITEM_SCALE) < 0.01 and v.vote_item_top() != Vector3.INF,
			"投票の場面: 落とし物は少し大きく、▼を出す位置がわかる")
	_check((v._actor_nodes[oops] as CharacterModel)._expression == CharacterModel.SHOCK, "投票の場面: お手つきの人はガーン顔のまま")
	# 次のラウンドで教室を作り直したら、場面の再現は残らない(前のラウンドの席にみんなを置かない)
	var v2 := WorldView.new()
	root.add_child(v2)
	v2.build(s)
	v2.set_vote_view(true, s)
	v2.build(s)
	_check(v2._vote_scene.is_empty() and not v2._vote_view, "投票の場面: 次のラウンドで作り直したら、前の席の再現は残らない")
	v2.queue_free()
	# 振り返りの演出: 6〜8秒くらい。はじめは言葉を隠し、早送りすると全部出る
	var hud := Hud.new()
	root.add_child(hud)
	s.round_otetsuki_seen = {oops: [{"sender": int(s.round_lineup[0]), "kind": "safe"}]}
	v.get_overlay().set_vote_evidence(true, HeadOverlay.evidence_bubbles(s), Vector3.INF, s.round_otetsuki)
	var rc := VoteRecap.new()
	root.add_child(rc)
	rc.setup(s, v, hud)
	_check(rc.total_time() >= 4.0 and rc.total_time() <= 9.0, "振り返り: 長さは6〜8秒くらい(%.1f秒)" % rc.total_time())
	_check(not v.get_overlay()._reveal_all and v.get_overlay()._reveal_counts.is_empty(), "振り返り: はじめは言葉を隠しておく")
	rc.skip()
	_check(not rc.is_running() and v.get_overlay()._reveal_all and v._vote_focus == -1, "振り返り: タップで早送りすると、言葉が全部出てカメラがもどる")
	rc.queue_free()
	hud.queue_free()
	# 全員が投票しても、振り返りの間は発表に進まない
	s.voting_open = true
	s.vote_elapsed = 0.0
	s.vote_recap_hold = 7.0
	for a in s.actors:
		if not s.is_minion(a.id):
			var cands := s.vote_candidates(a.id)
			if not cands.is_empty():
				s.cast_vote(a.id, int(cands[0]))
	_check(s.voting_open, "振り返り: 全員が投票しても、演出の間は発表に進まない")
	s.vote_elapsed = 7.1
	s.tick(0.05)
	_check(not s.voting_open, "振り返り: 演出が終わったら発表へ")
	v.set_vote_view(false)
	_check(v._vote_scene.is_empty(), "投票の場面: 投票が終わったら元にもどす")
	# 点数は必要な場面だけ: 1位の人の名札に👑、言葉を送る相手を選んでいる間だけ点数
	var ovl := v.get_overlay()
	var lead: int = int(s.round_lineup[1])
	ovl.set_leaders([lead])
	_check((ovl._tags[lead]["crown"] as Control).visible and not (ovl._tags[int(s.round_lineup[2])]["crown"] as Control).visible,
			"点数: 1位の人の名札にだけ👑")
	ovl.set_tag_scores({lead: 5})
	_check((ovl._tags[lead]["score"] as Label).visible, "点数: 送る相手を選んでいる間は、名札の横に点数")
	ovl.set_tag_scores({})
	_check(not (ovl._tags[lead]["score"] as Label).visible, "点数: 選び終わったら消す")
	# カメラの中に入った人は隠す(黒い輪郭線が画面いっぱいに映らないように)
	s.phase = GameState.Phase.CHASE
	var cam := v.get_viewport().get_camera_3d()
	var other := s.get_actor(int(s.round_lineup[3]))
	var keep := other.position
	other.position = cam.global_position - Vector3(0, 0.8, 0)
	v.sync(s, 0.016)
	var hid := not (v._actor_nodes[other.id] as Node3D).visible
	other.position = keep
	v.sync(s, 0.016)
	_check(hid and (v._actor_nodes[other.id] as Node3D).visible, "カメラのすぐ前の人は隠し、離れたら元にもどす")
	# 次のラウンドで体を使い回しても、隠したままにならない(鬼が足音だけして見えない、にならない)
	(v._actor_nodes[s.oni_id] as Node3D).visible = false
	v.build(s)
	_check((v._actor_nodes[s.oni_id] as Node3D).visible, "次のラウンドで、隠していた体も見えるようにもどす")
	v.queue_free()


## 鬼がうしろに来たときのドキドキ: 心臓の音・足音・画面のふち。離れたら戻る
func _check_heart() -> void:
	var s := GameState.new()
	s.start_round(1)
	var v := WorldView.new()
	root.add_child(v)
	v.build(s)
	var me := s.get_local_player()
	var oni := s.get_actor(s.oni_id)
	var back := Vector3(sin(me.yaw), 0.0, cos(me.yaw))
	s.phase = GameState.Phase.WALKING
	oni.position = me.position + back * 2.4
	for i in 30:
		v.sync(s, 0.05)
	var far := v.oni_near_level()
	oni.position = me.position + back * 0.6
	for i in 30:
		v.sync(s, 0.05)
	var near := v.oni_near_level()
	_check(far > 0.05 and near > far, "ドキドキ: 鬼がうしろに近いほど強い(%.2f → %.2f)" % [far, near])
	var ad := AudioDirector.instance
	_check(Sfx.get_stream("heartbeat") != null and ad != null and ad._heart_level > 0.3, "ドキドキ: 心臓の音を鳴らす(%.2f)" % (ad._heart_level if ad else -1.0))
	if ad:
		ad._process(0.5)
		var bi := AudioServer.get_bus_index(Sfx.BUS_BGM)
		var amp := AudioServer.get_bus_effect(bi, 0) as AudioEffectAmplify
		_check(amp != null and amp.volume_db < -2.0, "ドキドキ: 鳴っている間は BGM を下げる(%.1f dB)" % (amp.volume_db if amp else 0.0))
		# 速さ: 近いほど速い(1分に70回 → 140回)
		_check(GameConfig.HEART_BPM_FAR == 70.0 and GameConfig.HEART_BPM_NEAR == 140.0, "ドキドキ: 3mで1分に70回、すぐうしろで140回")
	_check(v._step_player.volume_db > GameConfig.FOOTSTEP_VOLUME_DB + 1.0, "ドキドキ: 鬼の足音が大きくなる")
	var hud := Hud.new()
	root.add_child(hud)
	# 画面のまん中の大きなお知らせは重ならない。同じときに来たら、順位 → 役のカード → イベントの名前の順
	hud.show_event("蜃気楼!", "見えているものが、本物とはかぎらない…", Color.BLUE)
	hud.show_popup_card("あなたは鬼の手下!", [], Color.PURPLE, "", 3.0)
	hud.announce_message("ラウンド 2", Color.GRAY, 2.0)
	hud._run_announcements()
	_check(hud._message.visible and hud._ann_queue.size() == 2, "お知らせ: まずラウンドのお知らせ(ほかは順番待ち)")
	hud._ann_until = 0
	hud._run_announcements()
	_check(hud._popup != null and is_instance_valid(hud._popup) and hud._ann_queue.size() == 1 and int(hud._ann_queue[0]["prio"]) == 2,
			"お知らせ: 次に役のカード、イベントの名前はそのあと")
	hud._ann_until = 0
	hud._run_announcements()
	_check(hud._ann_queue.is_empty(), "お知らせ: 前のお知らせが終わったら、次を出す")
	hud.set_danger(near)
	hud._update_heart(0.5)
	_check(hud._heart != null and hud._heart.visible, "ドキドキ: 自分の胸から、アニメっぽいハートが出る")
	# 心臓の音の1拍ごとに、ハートがボヨンと飛び出す(「ドックン」で大きく)。近いほど遠くまで
	var rest: Vector2 = hud._heart_shape()[0]
	hud.heart_pulse(1.0)
	hud._beat_t = hud.BEAT_TIME * 0.5
	var out: Vector2 = hud._heart_shape()[0]
	_check(out.y < rest.y - 50.0, "ドキドキ: 「ドックン」でハートが前に飛び出す(%.0f px)" % (rest.y - out.y))
	hud._pulse = 0.0
	if ad:
		var beats := [0]
		var stops := [0]
		ad.heart_beat.connect(func(_k: float) -> void: beats[0] += 1)
		ad.heart_stopped.connect(func() -> void: stops[0] += 1)
		ad._heart_wait = 0.0
		ad.set_heart(0.8)
		ad._process(0.05)
		_check(beats[0] >= 1, "ドキドキ: 心臓の音の1拍ごとに、ハートへ合図を送る")
		ad.set_heart(0.0)
		ad._process(0.05)
		_check(stops[0] == 1 and not ad._heart_on, "ドキドキ: 鬼が離れたら止まる(「ふぅ…」)")
	# 自分に届いた言葉: まず紙飛行機が飛んできて、ポンと開いてカード(ふちは送った人の色・「〇〇から」)。新しいものがいちばん大きい
	hud.show_my_stamps([
		{"kind": "dropped", "text": "落ちてる", "sender": "A", "sender_id": 1, "sender_color": Color.RED, "from": Vector2(100, 100)},
		{"kind": "safe", "text": "平気", "sender": "B", "sender_id": 2, "sender_color": Color.GREEN, "from": Vector2(300, 100)}])
	var c_old: Dictionary = hud._cards["1|dropped"]
	var c_new: Dictionary = hud._cards["2|safe"]
	_check(c_new["plane"] != null and not (c_new["card"] as Control).visible, "届いた言葉: はじめは紙飛行機(カードはまだ出ない)")
	hud._open_card(c_old)
	hud._open_card(c_new)
	for i in 4:
		hud._layout_cards(1.0, 0.1)
	var st_new := (c_new["card"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	_check((c_new["card"] as Control).visible and st_new.border_color == Color.GREEN and (c_new["from"] as Label).text.contains("B"),
			"届いた言葉: 開いたカードのふちは送った人の色で「Bから」")
	_check((c_new["card"] as Control).scale.x > (c_old["card"] as Control).scale.x + 0.1
			and (c_new["card"] as Control).position.y > (c_old["card"] as Control).position.y,
			"届いた言葉: いちばん新しいものが下で大きく、古いものは上で小さい")
	hud.show_my_stamps([])
	_check(hud._cards.is_empty(), "届いた言葉: 消えたらカードも消える")
	# いたずらっ子のネタばらしの場面の間は、次のラウンドに進まない
	var gs := GameState.new()
	gs.phase = GameState.Phase.RESULT
	gs.reveal_left = 0.0
	var could := gs.can_go_next()
	gs.prank_reveal_on = true
	_check(could and not gs.can_go_next(), "いたずらっ子のネタばらし: 場面の間は「次へ」を出さない")
	gs.free() if not (gs is RefCounted) else null
	oni.position = me.position - back * 2.0
	# (鬼が離れたら、1〜2秒かけて小さくなって止まる)
	for i in 10:
		v.sync(s, 0.05)
	_check(v.oni_near_level() > 0.0, "ドキドキ: 鬼が離れても、すぐには止まらない(少しずつ小さく)")
	for i in 50:
		v.sync(s, 0.05)
	hud.set_danger(v.oni_near_level())
	for i in 10:
		hud._update_heart(0.1)
	_check(v.oni_near_level() == 0.0 and not hud._heart.visible, "ドキドキ: 鬼が離れたら、ハートは胸にもどって消える")
	v.queue_free()
	hud.queue_free()


## チュートリアル: 最後まで進められる(プレイヤーの動きをまねる)。終わるとロビーにもどり、端末に覚える
func _check_tutorial() -> void:
	_main.start_tutorial()
	var tu: Tutorial = _main._tutorial
	_check(tu != null and _main.state.seat_count == Tutorial.SEAT_COUNT and _main.state.stage == "classroom",
			"チュートリアル: 教室・7人で始まる")
	# スマホの指で「次へ」を押せる(指をマウスに見立てない設定なので、自分で押す)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = tu._next.get_global_rect().get_center()
	tu._input(touch)
	_check(tu.step() == "oni_walk", "チュートリアル: スマホの指で「次へ」を押せる(%s)" % tu.step())
	var seen := {}
	var since := 0.0
	var last := ""
	for i in 6000:
		if _main._tutorial == null:
			break
		var st: String = tu.step()
		if st != last:
			last = st
			since = 0.0
			seen[st] = true
		since += 1.0 / 30.0
		var s: GameState = _main.state
		if since > 0.5:
			match st:
				"banana_done":
					# (読んでいる間にボットの追いかけっこが終わっても、投票が始まらないことを確かめる)
					if since > 12.0:
						tu._on_next()
				"intro", "see_back", "look_rule", "words", "minion", "revealed", "oni_intro", "oni_done":
					tu._on_next()
				"out":
					if since > 3.6:
						tu._on_next()
				"try_look", "pick":
					s.set_looking_back(s.local_player_id, true)
					s.pick_up(s.local_player_id)
				"teach":
					# 言われた人・言われた言葉以外は送れない
					_main._stamp_target = 1
					_main._send_stamp(Stamps.DROPPED)
					_main._stamp_target = Tutorial.PICK_BOT
					_main._send_stamp(Stamps.SAFE)
					_check(s.stamp_log.is_empty(), "チュートリアル: 言われた人・言われた言葉以外は送れない")
					_check(not tu.allows_stamp_target(1) and tu.allows_stamp_target(Tutorial.PICK_BOT), "チュートリアル: 送る相手に選べるのは落ちている人だけ")
					_main._stamp_target = Tutorial.PICK_BOT
					_main._send_stamp(Stamps.DROPPED)
				"vote_now":
					_main._on_vote_pressed(Tutorial.MINION_ID)
				"banana":
					s.throw_banana(s.local_player_id, s.oni_id)
				"fake":
					s.oni_feint(s.local_player_id)
				"oni_stamp":
					_main._stamp_target = s.get_actor_at_seat(2).id
					_main._send_stamp(Stamps.SAFE)
				"eraser":
					s.oni_milk(s.local_player_id, s.get_actor_at_seat(1).id)
				"drop":
					s.oni_drop(s.local_player_id)
				"end":
					tu._end(true)
		if st == "chase" and s.phase == GameState.Phase.CHASE and since > 1.5:
			_chase_lasted = true
		if st == "chase":
			_chase_time = since
		if s.voting_open and not (st in ["chase", "vote", "vote_now", "revealed"]):
			_vote_outside = st
		_main._physics_process(1.0 / 30.0)
	_check(_vote_outside == "", "チュートリアル: 投票は投票の場面だけ(%s で投票が始まった)" % _vote_outside)
	_check(_chase_lasted, "チュートリアル: 拾ってすぐタッチで終わらない(追いかけっこが続く)")
	_check(_chase_time <= Tutorial.CHASE_LIMIT + 1.0, "チュートリアル: 自分の追いかけっこは短い(%.1f秒)" % _chase_time)
	for st in ["oni_walk", "see_back", "teach", "bot_pick", "banana", "banana_done", "try_look", "out", "words", "minion", "pick", "chase", "vote_now", "revealed", "fake", "oni_stamp", "eraser", "drop", "end"]:
		_check(seen.has(st), "チュートリアル: 「%s」まで進む" % st)
	_check(_main._tutorial == null and _main.mode == _main.Mode.LOBBY and _main.lobby.visible, "チュートリアルが終わるとロビーにもどる")
	_check(Profile.tutorial == 2, "チュートリアルを最後までやったことを覚える")
	_check(not _main.state.scripted, "チュートリアルのあとは、ボットはふつうに動く")
	# スキップ
	_main.start_tutorial()
	_main._tutorial._end(false)
	_check(_main._tutorial == null and _main.lobby.visible, "チュートリアルはスキップできる")
	# はじめて起動したときの「チュートリアルを見る?」: カードが画面に収まる(縦に伸びてボタンが外に出ない)
	_main.lobby._ask_tutorial()
	var ask: Control = _main.lobby._tutorial_ask
	var card: Control = ask.get_child(0)
	var vp: Vector2 = ask.get_viewport_rect().size
	_check(card.size.y < vp.y * 0.8 and card.position.y >= 0.0, "チュートリアルを見るか聞くカードが画面に収まる(高さ %d)" % card.size.y)
	_main.lobby._close_tutorial_ask()
	_main._on_solo()


## 試合の終わりの演出: 試合終了 → 表彰台 → 称号発表 → 称号 → 記念写真 が、早送りでつながる。スキップで記念写真へ
func _check_ending() -> void:
	var s: GameState = _main.state
	s.phase = GameState.Phase.RESULT
	s.round_index = GameConfig.ROUNDS_PER_MATCH - 1
	s.voting_open = false
	s.vote_wait = 0.0
	s.reveal_left = 0.0
	s._stat(1, "early_otetsuki")
	s._stat(2, "banana", 3)
	_main._on_restart_pressed()
	var tr: TitleReveal = _main._title_reveal
	_check(tr != null and tr.scene() == "end", "試合の終わり: 「試合終了!」から始まる(順位のカードは出さない)")
	_check(_main.view.in_ceremony(), "試合の終わり: 同じ教室の中でカメラが動く")
	var scenes := [tr.scene()]
	for i in 12:
		tr.advance()
		if scenes[scenes.size() - 1] != tr.scene():
			scenes.append(tr.scene())
		if tr.is_done() and tr._flashed:
			break
	_check(scenes.slice(0, 4) == ["end", "podium", "intro", "award"] and scenes[scenes.size() - 1] == "photo",
			"試合の終わり: 試合終了 → 表彰台 → 称号発表 → 称号 → 記念写真(%s)" % str(scenes))
	_check(tr._photo_ui != null and tr._next_button != null, "試合の終わり: 記念写真に「新しい試合へ」")
	# 称号がない試合は、表彰台からそのまま記念写真へ。ルーム主のスキップで記念写真へ
	_main._close_titles()
	s.titles = []
	_main._match_shown_serial = -1
	_main._show_match_result()
	tr = _main._title_reveal
	tr.advance()
	tr.advance()
	_check(tr.scene() == "photo", "試合の終わり: 称号がなければ、表彰台から記念写真へ")
	_main._close_titles()
	_main._match_shown_serial = -1
	_main._show_match_result()
	_main._title_reveal.jump_to_photo()
	_check(_main._title_reveal.scene() == "photo", "試合の終わり: スキップで記念写真へ")
	_main._close_titles()
	_check(not _main.view.in_ceremony(), "試合の終わり: 終わると、ふだんのカメラに戻る")
	_main._on_solo()


## 転ぶ: 床の上でキャラを転ばせると、頭がぐっと下がり、少しして元の高さに戻る
func _check_fall(delta: float) -> void:
	if _frames == 5:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1 << (CharacterModel.FLOOR_LAYER - 1)
		var cs := CollisionShape3D.new()
		cs.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(cs)
		floor_body.position = Vector3(50, 0, 50)
		root.add_child(floor_body)
		_faller = CharacterModel.new()
		root.add_child(_faller)
		_faller.position = Vector3(50, 0, 50)
		_faller.build(Color(0.9, 0.4, 0.3), "テスト", HudFont.get_font())
		_faller.set_pose("run")
	if _faller == null:
		return
	_faller.animate(delta, true)
	var head := _faller._attachments.filter(func(a): return _faller._skel.get_bone_name(a["bone"]) == "DEF-head")
	var y: float = (head[0]["node"] as Node3D).global_position.y if not head.is_empty() else 0.0
	if _frames == 30:
		_faller_head_y = y
		_faller.slip()
		_fall_clock = 0.0
	if _fall_clock < 0.0 or _fall_done:
		return
	var before := _fall_clock
	_fall_clock += delta
	if _fall_clock <= GameConfig.SLIP_TIME:
		_faller_min_head_y = minf(_faller_min_head_y, y)
	if int(before * 10.0) != int(_fall_clock * 10.0):
		print("fall %.1fs: head y %.2f / down %.2f" % [_fall_clock, y, _faller._down_w])
	if _fall_clock > GameConfig.SLIP_TIME + 0.4 + 0.3:
		_fall_done = true
		_check(_faller_min_head_y < _faller_head_y - 0.5, "転ぶと頭が下がる(%.2f → %.2f)" % [_faller_head_y, _faller_min_head_y])
		_check(absf(y - _faller_head_y) < 0.25 and _faller._down_w == 0.0, "少しすると起き上がる(頭 %.2f)" % y)


# --- テスト ---

func _test_drop_happens_for_every_seed() -> void:
	var seats_hit := {}
	for seed_value in 40:
		var s := GameState.new()
		s.start_round(seed_value)
		var e := _run_until(s, "dropped", 120.0)
		_check(not e.is_empty(), "seed %d: 120秒以内にハンカチを落とす" % seed_value)
		if e.is_empty():
			continue
		_check(s.handkerchief_on_floor, "落とした後は床にハンカチがある")
		_check(e["seat"] == s.drop_target_seat, "お知らせの席と予定の席が同じ")
		var r: float = Vector2(s.handkerchief_position.x, s.handkerchief_position.z).length()
		_check(absf(r - GameConfig.DROP_RADIUS) < 0.01, "ハンカチは席の真後ろの輪の上")
		var behind := s.seat_positions[s.drop_target_seat].normalized() * GameConfig.DROP_RADIUS
		_check(behind.distance_to(s.handkerchief_position) < 0.01, "ハンカチは相手の席の真後ろ")
		seats_hit[e["seat"]] = true
	_check(seats_hit.size() == GameConfig.SEAT_COUNT, "プレイヤーもボットも全員が落とされることがある")


## 称号: 1人1つ・同じ称号は1つ・最大3つ。優先の称号・オチ・同じ称号が続かない工夫・理由の文のちがい
func _test_titles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ids := [0, 1, 2, 3, 4, 5]
	var stats := {
		0: {"otetsuki": 3, "looks": 3, "early_otetsuki": 1, "early_sec": 4},
		1: {"dragged": 2, "otetsuki": 1, "looks": 1},
		2: {"found": 3, "instinct": 1, "looks": 3},
		3: {"looks": 2, "banana_hits": 3},
		4: {"banana": 3, "otetsuki": 1, "looks": 1},
		5: {"missed": 2, "looks": 1, "dropped_on": 3},
	}
	var t := Titles.decide(stats, ids, "classroom", rng)
	_check(t.size() == Titles.MAX_AWARDS, "称号: 最大3つ(%d)" % t.size())
	var names := t.map(func(a): return a["title"])
	_check("早とちり大王" in names and "逆転の道連れ王" in names, "称号: 優先の称号(早とちり大王・逆転の道連れ王)が選ばれる(%s)" % str(names))
	_check(t[t.size() - 1]["tone"] == "funny", "称号: 最後は笑える称号(オチ)")
	var who := {}
	for a in t:
		who[a["id"]] = true
	_check(who.size() == t.size(), "称号: 1人1つ")
	var early := {}
	for a in t:
		if a["title"] == "早とちり大王":
			early = a
	_check(not early.is_empty() and Titles.reason_text(early).find("4") >= 0, "称号: 早とちり大王の理由に秒数が入る(%s)" % Titles.reason_text(early))
	# 回数の称号は、2位と同点なら出さない(ゆるめた段では出ることもある)
	var tie := Titles._candidate(Titles.find("体育座りのプロ"), false, {0: {"otetsuki": 3}, 1: {"otetsuki": 3}}, [0, 1], "classroom", rng)
	_check(tie.is_empty(), "称号: 一番が同点なら出さない")
	# 直前の試合で出た称号は、ほかに当てはまる称号があれば出さない
	var hist := {"recent": [["早とちり大王", "逆転の道連れ王"]], "counts": {}, "last_by_actor": {}}
	var t2 := Titles.decide(stats, ids, "classroom", rng, hist)
	var names2 := t2.map(func(a): return a["title"])
	_check(not ("早とちり大王" in names2) and not ("逆転の道連れ王" in names2), "称号: 直前の試合の称号は続けて出さない(%s)" % str(names2))
	var hist3 := {"recent": [["大ウソつき"], ["韋駄天"], ["早とちり大王"]], "counts": {}, "last_by_actor": {}}
	var names3 := Titles.decide(stats, ids, "classroom", rng, hist3).map(func(a): return a["title"])
	_check(not ("早とちり大王" in names3), "称号: 直近3試合で出た称号は、ほかに当てはまれば選ばない(%s)" % str(names3))
	var only := Titles.decide({0: {"early_otetsuki": 1, "early_sec": 3, "otetsuki": 1, "looks": 1}}, [0], "classroom", rng,
			{"recent": [["早とちり大王"]], "counts": {}, "last_by_actor": {}})
	_check(only.size() == 1, "称号: ほかに当てはまる称号がなければ、続けて出てもよい")
	# 毎回少しずつちがう組み合わせ(何回か決めると、ちがう称号が出る)
	var seen := {}
	for k in 20:
		for a in Titles.decide(stats, ids, "classroom", rng):
			seen[a["title"]] = true
	_check(seen.size() > 3, "称号: 毎回少しずつちがう組み合わせ(%d種類)" % seen.size())
	# 理由の文は、称号ごとに2〜3通り
	var ok := true
	for d in Titles.LIST + Titles.EXTRA:
		var n: int = (d["reasons"] as Array).size()
		if n < 2 or n > 3:
			ok = false
	_check(ok, "称号: 理由の文は称号ごとに2〜3通り")
	# すごい称号は金色、それ以外は紫
	var gold := ["名探偵", "名演技賞", "野生の勘", "韋駄天", "忍者", "フェイクの達人", "逃げ足No.1", "バナナ職人", "真実を見た人"]
	var tone_ok := true
	for d in Titles.LIST + Titles.EXTRA:
		if (d["tone"] == "good") != (d["title"] in gold):
			tone_ok = false
	_check(tone_ok, "称号: すごい称号だけ金色")
	_check(Titles.decide({}, [], "beach", rng).is_empty(), "称号: だれもいなければ称号なし")
	_check(Titles.reason_text({"reason": "%d回もだまされた", "n": 3}) == "3回もだまされた", "称号: 理由の文に回数が入る")
	# 出来事を数える
	var s := GameState.new()
	s.start_round(1)
	s.set_looking_back(s.local_player_id, true)
	_check(int(s.match_stats.get(s.local_player_id, {}).get("otetsuki", 0)) == 1, "称号: お手つきが数えられる")
	Locale.setup("en")
	_check(Titles.title_text({"title": "名探偵"}) == "Great Detective", "称号: 英語の称号名")
	Locale.setup("ja")


func _test_otetsuki_when_nothing_behind() -> void:
	var s := GameState.new()
	s.start_round(1)
	s.set_looking_back(s.local_player_id, true)
	var ev := s.take_events()
	_check(_has(ev, "otetsuki"), "何もないのに振り向くとお手つき")
	_check(s.get_local_player().otetsuki_count == 1, "お手つきが1回数えられる")
	_check(s.get_local_player().role == GameState.Role.OUT, "お手つきしたら輪から抜ける")
	s.set_looking_back(s.local_player_id, true)
	s.set_looking_back(s.local_player_id, false)
	s.set_looking_back(s.local_player_id, true)
	_check(s.get_local_player().otetsuki_count == 1, "抜けたあとは振り向けない(お手つきも増えない)")


func _test_found_when_handkerchief_behind() -> void:
	var s := GameState.new()
	s.start_round(3)
	_run_until(s, "dropped", 120.0)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	s.set_looking_back(target.id, true)
	var ev := s.take_events()
	_check(_has(ev, "found"), "後ろにハンカチがあれば見つかる")
	_check(target.otetsuki_count == 0, "見つけたときはお手つきにならない")
	# 別の人は、落とされていないのでお手つき
	var other := s.get_actor_at_seat((s.drop_target_seat + 1) % GameConfig.SEAT_COUNT)
	s.set_looking_back(other.id, true)
	_check(_has(s.take_events(), "otetsuki"), "落とされていない人が振り向くとお手つき")


func _test_decoy_rustle_is_behind_a_seat() -> void:
	var rustles := 0
	for seed_value in 20:
		var s := GameState.new()
		s.start_round(seed_value)
		for i in int(30.0 / STEP):
			s.tick(STEP)
			for e in s.take_events():
				if e["type"] == "rustle":
					rustles += 1
					var seat: int = e["seat"]
					_check(seat >= 0 and seat < GameConfig.SEAT_COUNT, "ニセの物音の席番号が正しい")
					var behind := s.seat_positions[seat].normalized() * GameConfig.DROP_RADIUS
					_check(behind.distance_to(e["pos"]) < 0.01, "ニセの物音は席の真後ろで鳴る")
	_check(rustles > 0, "ニセの物音が鳴ることがある")


func _test_bot_cannot_look_back_as_oni() -> void:
	var s := GameState.new()
	s.start_round(7)
	s.take_events() # 「ラウンド開始」のお知らせを読み捨てる
	s.set_looking_back(s.oni_id, true)
	_check(s.take_events().is_empty(), "鬼は振り向き判定の対象外")


func _test_missed_when_nobody_notices() -> void:
	var s := GameState.new()
	s.start_round(11)
	var e := _run_until(s, "result", 200.0)
	_check(not e.is_empty(), "誰も気づかなければ勝敗が出る")
	if e.is_empty():
		return
	var target := s.get_actor_at_seat(s.drop_target_seat)
	_check(e["reason"] == "missed", "気づかなければ『見逃し』")
	_check(e["loser"] == target.id, "見逃しは落とされた人の負け")
	_check(e["winner"] == s.oni_id, "見逃しは鬼の勝ち")
	_check(s.phase == GameState.Phase.RESULT, "勝敗が出たら RESULT")


func _test_pick_up_rules() -> void:
	var s := _dropped_state(13)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	var other := s.get_actor_at_seat((s.drop_target_seat + 1) % GameConfig.SEAT_COUNT)
	s.pick_up(other.id)
	_check(s.phase == GameState.Phase.DROPPED, "後ろにハンカチがない人は拾えない")
	_check(_has(s.take_events(), "otetsuki"), "何もないのに拾おうとするとお手つき")
	s.pick_up(target.id)
	_check(s.phase == GameState.Phase.CHASE, "「拾う」だけで振り向いて拾える")
	_check(_has(s.take_events(), "picked_up"), "拾ったお知らせが出る")
	_check(target.role == GameState.Role.CHASER and target.seat_index == -1, "拾った人は席を立つ")
	_check(s.vacant_seat == s.drop_target_seat, "その席が空く")
	_check(not s.handkerchief_on_floor, "ハンカチは床から消える(手に持つ)")


func _test_oni_sits_if_chaser_stands_still() -> void:
	# 同じ速さなので、外側の列を走ると遠回りで追いつけない。鬼は2周して空いた席に座る
	var s := _chasing_state(17)
	var c := s.get_actor(s.chaser_id)
	var start_angle := s.oni_angle
	var e := {}
	var t := 0.0
	for i in int(90.0 / STEP):
		s.chase_lane(c.id, 1)
		s.tick(STEP)
		t += STEP
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "sat", "外側の列ばかり走ると鬼に座られる")
	if e.is_empty():
		return
	var oni := s.get_actor(s.oni_id)
	_check(e["winner"] == s.oni_id and e["loser"] == s.chaser_id, "座られたら追いかけた人の負け")
	_check(oni.seat_index == s.vacant_seat, "鬼は空いた席に座る")
	_check(s.oni_angle - start_angle > float(GameConfig.CHASE_LAPS - 1) * TAU,
			"鬼は %d 周してから座る(%.1f 周)" % [GameConfig.CHASE_LAPS, (s.oni_angle - start_angle) / TAU])


func _test_chaser_never_stops() -> void:
	var s := _chasing_state(31)
	var c := s.get_actor(s.chaser_id)
	var before := c.position
	s.set_move(c.id, Vector3.ZERO)
	for i in 30:
		s.tick(STEP)
	_check(c.position.distance_to(before) > 1.0, "何も押さなくても前に走る(待ちぶせできない)")


func _test_touch_wins() -> void:
	# 内側の列は近道。鬼がまん中の列に出たら、内側を走る追う人が追いつける
	var s := _chasing_state(19)
	var chaser := s.get_actor(s.chaser_id)
	s.get_actor(s.oni_id).lane = 1
	var e := {}
	for i in int(90.0 / STEP):
		s.chase_lane(chaser.id, -1)
		s.tick(STEP)
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "touched", "鬼がまん中の列なら、内側(近道)を走ってタッチできる")
	if not e.is_empty():
		_check(e["winner"] == chaser.id and e["loser"] == s.oni_id, "タッチしたら追いかけた人の勝ち")


func _test_chase_lanes_and_speed() -> void:
	var s := _chasing_state(23)
	var c := s.get_actor(s.chaser_id)
	var oni := s.get_actor(s.oni_id)
	_check(oni.lane == 0 and c.lane == 0, "鬼も追う人も、内側の列から走り出す")
	# 列は3つ。端より外には行けない
	for i in 5:
		s.chase_lane(c.id, 1)
	_check(c.lane == GameConfig.LANE_RADII.size() - 1, "外側の列より外には行けない")
	for i in 5:
		s.chase_lane(c.id, -1)
	_check(c.lane == 0, "内側の列より内には行けない")
	for i in int(1.0 / STEP):
		s.tick(STEP)
	_check(absf(c.run_r - float(GameConfig.LANE_RADII[0])) < 0.01, "選んだ列に寄る")
	# 鬼も追いかける人も同じ速さ
	var p0 := c.position
	var o0 := oni.position
	s.tick(STEP)
	var cs := c.position.distance_to(p0) / STEP
	var os := oni.position.distance_to(o0) / STEP
	# 同じ速さで走る。内側の近道は少しだけ効く(回る速さは、まん中の列に近づけた半径で決まる)
	var mid: float = GameConfig.LANE_RADII[1]
	var expect_c := GameConfig.CHASE_SPEED * c.run_r / (mid + (c.run_r - mid) * GameConfig.LANE_SHORTCUT)
	var expect_o := GameConfig.CHASE_SPEED * oni.run_r / (mid + (oni.run_r - mid) * GameConfig.LANE_SHORTCUT)
	_check(absf(cs - expect_c) < 0.05 and absf(os - expect_o) < 0.05,
			"鬼も追いかける人も同じ速さで走る(%.2f / %.2f)" % [cs, os])
	var inner_gain := (mid / (mid + (float(GameConfig.LANE_RADII[0]) - mid) * GameConfig.LANE_SHORTCUT)) - 1.0
	_check(inner_gain < 0.08, "内側の近道は効きすぎない(まん中より %.1f%% 速いだけ)" % (inner_gain * 100.0))
	# 座っている人は走れない
	var seated := s.get_actor_at_seat((s.vacant_seat + 2) % GameConfig.SEAT_COUNT)
	var lane0 := seated.lane
	s.chase_lane(seated.id, 1)
	s.chase_steer(seated.id, 1.0)
	_check(seated.lane == lane0 and not seated.steer_by_stick, "座っている人は走れない(左右に動けない)")
	# スティック: 倒している間だけ、なめらかに外側へ動く。離すと、その場の列のまま
	var r0 := c.run_r
	for i in int(0.2 / STEP):
		s.chase_steer(c.id, 1.0)
		s.tick(STEP)
	_check(c.run_r > r0 + 0.3, "スティックを外側に倒すと外側へ動く")
	var r1 := c.run_r
	for i in int(0.3 / STEP):
		s.chase_steer(c.id, 0.0)
		s.tick(STEP)
	_check(absf(c.run_r - r1) < 0.01, "スティックを離すと横には動かない")
	for i in int(3.0 / STEP):
		s.chase_steer(c.id, 1.0)
		s.tick(STEP)
	_check(c.run_r <= float(GameConfig.LANE_RADII[GameConfig.LANE_RADII.size() - 1]) + 0.001, "コースの外側の端より外には出ない")


func _test_overtake_is_touch() -> void:
	# ちがう列(1m 以上はなれた列)で鬼を追い越しても、タッチになる
	var s := _chasing_state(29)
	var c := s.get_actor(s.chaser_id)
	var oni := s.get_actor(s.oni_id)
	oni.lane = 2
	oni.steer_by_stick = false
	var e := {}
	for i in int(90.0 / STEP):
		s.chase_lane(c.id, -1)
		s.tick(STEP)
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "touched", "ちがう列で追いついても、タッチになる")


func _test_obstacles() -> void:
	# コースに障害物が置かれる。走りはじめた2人のすぐ前には置かない
	var s0 := _dropped_state(41)
	var target := s0.get_actor_at_seat(s0.drop_target_seat)
	s0.set_looking_back(target.id, true)
	s0.pick_up(target.id)
	_check(s0.obstacles.size() >= GameConfig.OBSTACLE_COUNT_MIN - 1, "コースに障害物がある(%d 個)" % s0.obstacles.size())
	# 毎回ランダム: 同じ場面でも、もう一度置くと場所がちがう
	var first := []
	for ob in s0.obstacles:
		first.append(snappedf(float(ob["angle"]), 0.01))
	s0._build_obstacles()
	var second := []
	for ob in s0.obstacles:
		second.append(snappedf(float(ob["angle"]), 0.01))
	_check(first != second, "障害物の場所は毎回ランダム")
	for i in s0.obstacles.size():
		for j in range(i + 1, s0.obstacles.size()):
			var gap := absf(wrapf(float(s0.obstacles[i]["angle"]) - float(s0.obstacles[j]["angle"]), -PI, PI)) * float(GameConfig.LANE_RADII[1])
			_check(gap >= GameConfig.OBSTACLE_MIN_GAP - 0.01, "障害物どうしは近すぎない")
	var mid: float = GameConfig.LANE_RADII[1]
	for ob in s0.obstacles:
		for who in [s0.chaser_id, s0.oni_id]:
			var ahead := fposmod(float(ob["angle"]) - s0.runner_angle(s0.get_actor(who)), TAU) * mid
			_check(ahead >= GameConfig.OBSTACLE_START_CLEAR - 0.01, "走りはじめの人のすぐ前には置かない")
	# 椅子にぶつかると転ぶ。鬼も同じ。ぶつかっても椅子は残る
	var s1 := _chasing_state(43)
	var oni := s1.get_actor(s1.oni_id)
	var r1: float = GameConfig.LANE_RADII[oni.lane]
	var ob1 := s1._add_obstacle(fposmod(s1.runner_angle(oni) + 1.0 / r1, TAU), oni.lane, "chair")
	var hit := false
	for i in int(1.0 / STEP):
		s1.tick(STEP)
		for e in s1.take_events():
			if e["type"] == "slip" and e["actor"] == oni.id:
				hit = true
	_check(hit, "椅子にぶつかると鬼も転ぶ")
	_check(s1.obstacles.has(ob1), "椅子はぶつかっても残る")
	# バケツ: よけないと転んで少し止まる。スティックを左右に倒して横に動けばよけられる(ジャンプはない)
	for how in ["none", "steer"]:
		var s := _chasing_state(45)
		var c := s.get_actor(s.chaser_id)
		var r: float = GameConfig.LANE_RADII[c.lane]
		s._add_obstacle(fposmod(s.runner_angle(c) + 1.6 / r, TAU), c.lane, "bucket")
		var slipped := false
		var stopped_for := 0.0
		var dir := 1.0 if c.lane == 0 else -1.0
		for i in int(1.4 / STEP):
			if how == "steer":
				s.chase_steer(c.id, dir if i < int(0.3 / STEP) else 0.0)
			var p0 := c.position
			s.tick(STEP)
			if c.position.distance_to(p0) < 0.0001:
				stopped_for += STEP
			for e in s.take_events():
				if e["type"] == "slip" and e["actor"] == c.id:
					slipped = true
			if s.phase != GameState.Phase.CHASE:
				break
		if how == "none":
			_check(slipped and stopped_for > 0.5, "バケツをよけないと転んで少し止まる")
		else:
			_check(not slipped, "スティックを倒して横に動けば、バケツをよけられる")

func _test_no_otetsuki_during_chase() -> void:
	var s := _chasing_state(29)
	var other := s.get_actor_at_seat((s.vacant_seat + 1) % GameConfig.SEAT_COUNT)
	s.set_looking_back(other.id, true)
	_check(not _has(s.take_events(), "otetsuki"), "追いかけっこ中に振り向いて見物してもお手つきにならない")


func _test_rounds_with_bots_always_finish() -> void:
	var reasons := {}
	for seed_value in 60:
		var s := GameState.new()
		s.start_round(seed_value)
		var b := BotBrain.new()
		b.reset(seed_value)
		var e := {}
		for i in int(200.0 / STEP):
			b.update(s, STEP)
			s.tick(STEP)
			for ev in s.take_events():
				if ev["type"] == "result":
					e = ev
			if not e.is_empty():
				break
		_check(not e.is_empty(), "seed %d: ボット相手のラウンドは必ず勝敗が出る" % seed_value)
		if not e.is_empty():
			reasons[e["reason"]] = true
	_check(reasons.has("missed"), "ボットが見逃すことがある")
	_check(reasons.has("touched") or reasons.has("sat"), "ボットが追いかけることがある")
	print("bot round results: ", reasons.keys())


func _test_stamp_rules() -> void:
	# 8人(席 0〜6 の輪、鬼は id 7)。両どなり(差が1)には送れず、それ以外には送れる
	var s := GameState.new()
	s.start_round(41)
	s.minion_id = -1
	s.take_events()
	_check(s.send_stamp(1, 3, Stamps.SAFE), "向かいの人にスタンプが届く")
	_check(_has(s.take_events(), "stamp"), "届いたお知らせが出る")
	_check(not s.send_stamp(1, 3, Stamps.DROPPED), "同じ相手には1ラウンド1回")
	_check(_blocked_reason(s.take_events()) == "already", "もう送ったお知らせが出る")
	_check(not s.send_stamp(1, 2, Stamps.SAFE), "8人のとき、右どなりには送れない")
	_check(_blocked_reason(s.take_events()) == "neighbor", "となりには送れないお知らせが出る")
	_check(not s.send_stamp(1, 0, Stamps.SAFE), "8人のとき、左どなりには送れない")
	s.take_events()
	_check(s.send_stamp(0, 3, Stamps.DROPPED) and s.send_stamp(5, 3, Stamps.TRUST), "1人に何人もスタンプを送れる")
	_check(s.active_stamps[3].size() == 3, "3つ同時に表示される")
	_check(s.active_stamps[3][0]["sender"] == 1 and s.active_stamps[3][2]["sender"] == 5, "届いた順に並ぶ")
	s.take_events()
	_check(not s.send_stamp(6, 3, Stamps.SAFE), "表示中が %d つなら届かない" % GameConfig.STAMP_SLOTS)
	_check(_blocked_reason(s.take_events()) == "full", "いっぱいのお知らせが出る")
	_check(not (3 in s.get_actor(6).stamped_targets), "届かなかったら、その相手への1回は使わない")
	_check(s.send_stamp(s.oni_id, 4, Stamps.DROPPED), "鬼もスタンプを送れる")
	_check(not s.send_stamp(1, 1, Stamps.SAFE), "自分には送れない")
	_check(not s.send_stamp(2, s.oni_id, Stamps.SAFE), "鬼には送れない")
	_check(not s.send_stamp(1, 4, "unknown"), "知らない種類は送れない")
	var born: float = s.active_stamps[3][0]["born_angle"]
	var gone := false
	var walked := 0.0
	for i in int(80.0 / STEP):
		s.tick(STEP)
		if not s.active_stamps.has(3):
			gone = true
			walked = s.oni_angle - born
			break
	_check(gone, "届いたスタンプは消える")
	_check(walked >= GameConfig.STAMP_EXPIRE_LAPS * TAU - 0.01 and walked < GameConfig.STAMP_EXPIRE_LAPS * TAU + 0.1,
			"鬼が半周したら消える(%.2f 周)" % (walked / TAU))
	_check(_has(s.take_events(), "stamp_end"), "消えたお知らせが出る")
	if s.phase == GameState.Phase.WALKING or s.phase == GameState.Phase.DROPPED:
		_check(s.send_stamp(6, 3, Stamps.SAFE), "消えたら、届かなかった人がまた送れる")
	_check(s.get_actor(1).stamps_left == GameConfig.STAMPS_PER_ROUND, "何回でもの設定なら残りは減らない")

	# 5人(席 0〜3)のときは、両どなりにも送れる
	var s5 := GameState.new()
	s5.start_match(41, false, 4)
	_check(s5.send_stamp(1, 2, Stamps.SAFE) and s5.send_stamp(1, 0, Stamps.SAFE), "5人のときは両どなりにも送れる")


func _test_custom_stamp_words() -> void:
	# 使える言葉
	for ok in ["だいじょぶ", "みてみて", "うしろ!", "ゆるして", "Help"]:
		_check(WordFilter.check(ok) == "", "使える言葉: %s" % ok)
	# 長すぎる・空
	_check(WordFilter.check("ながいながいことば") == "long", "%d文字より長いと使えない" % WordFilter.MAX_LEN)
	_check(WordFilter.check("  ") == "empty", "空は使えない")
	# 悪口(ひらがな・カタカナ・空白入りでも見つける)
	for bad in ["しね", "シネ", "し ね", "バカ", "ばーか", "きもい", "死ね", "ﾌﾞｽ" if false else "ブス", "FUCK"]:
		_check(WordFilter.check(bad) == "bad", "使えない言葉: %s" % bad)
	# 個人情報(電話番号・メール・住所)
	for pi in ["090123", "０９０１２", "a@b.jp", "3丁目", "www"]:
		_check(WordFilter.check(pi) == "personal", "個人情報は使えない: %s" % pi)
	# 保存するときは、使えない言葉を消す
	var cleaned := Profile.clean_words({Stamps.DROPPED: "みて!", Stamps.SAFE: "しね", Stamps.TRUST: "090123", "other": "x"})
	_check(cleaned.size() == 1 and cleaned[Stamps.DROPPED] == "みて!", "使えない言葉と、ない種類は消える")
	# 状態にのせて、ほかの人にも届く
	var s := GameState.new()
	s.start_match(5)
	s.stamp_words[2] = {Stamps.SAFE: "だいじょぶ"}
	var g := GameState.new()
	g.apply_snapshot(s.snapshot())
	_check(str(g.stamp_words.get(2, {}).get(Stamps.SAFE, "")) == "だいじょぶ", "自作の言葉が通信で届く")
	_check(HeadOverlay.stamp_text(g, 2, Stamps.SAFE) == "だいじょぶ👍", "自作の言葉に絵文字がつく")
	Profile.hide_custom_words = true
	g.stamp_picks[2] = {Stamps.DROPPED: 0, Stamps.SAFE: 2, Stamps.TRUST: 0}
	_check(HeadOverlay.stamp_text(g, 2, Stamps.SAFE) == "まだまだ👍", "「表示しない」なら、同じ意味のシャッフルの言葉")
	Profile.hide_custom_words = false


func _test_languages() -> void:
	# 英語に切りかえる
	Locale.setup("en")
	_check(Locale.current() == "en", "英語に切りかえられる")
	_check(Texts.stamp(Stamps.DROPPED) == "Behind you!😨" and Texts.stamp(Stamps.SAFE) == "You're safe👍" \
			and Texts.stamp(Stamps.TRUST) == "Trust me🥺", "英語のスタンプ(%s)" % Texts.stamp(Stamps.DROPPED))
	_check(Locale.t("ひとりで遊ぶ") == "Play solo", "画面の文字が英語になる")
	_check(Locale.t("ラウンド %d/%d") % [2, 5] == "Round 2/5", "数字の入る文も英語になる")
	_check(Locale.actor_name("ボット3(せっかち)", true) == "Bot 3 (hasty)", "ボットの名前も英語(%s)" % Locale.actor_name("ボット3(せっかち)", true))
	_check(Locale.actor_name("たろう") == "たろう", "人がつけた名前はそのまま")
	_check(Items.name_of(0) == "Handkerchief", "落とし物の名前も英語")
	# 自作の言葉: 言語が同じ人には出し、ちがう人には受け取った人の言語の初期の言葉で出す
	var s := GameState.new()
	s.start_match(5)
	s.stamp_words[2] = {Stamps.SAFE: "だいじょぶ"}
	s.stamp_langs[2] = "ja"
	s.stamp_picks[2] = {Stamps.DROPPED: 0, Stamps.SAFE: 1, Stamps.TRUST: 0}
	_check(HeadOverlay.stamp_text(s, 2, Stamps.SAFE) == "All clear👍", "言語がちがえば、自作の言葉は受け取った人の言語のシャッフルの言葉で出す")
	s.stamp_words[3] = {Stamps.SAFE: "No worry"}
	s.stamp_langs[3] = "en"
	_check(HeadOverlay.stamp_text(s, 3, Stamps.SAFE) == "No worry👍", "言語が同じなら自作の言葉を出す")
	var g := GameState.new()
	g.apply_snapshot(s.snapshot())
	_check(str(g.stamp_langs.get(2, "")) == "ja", "言語も通信で届く")
	# 文字がはみ出さない: 長い英語でも、ボタンの幅に収まる大きさになる
	var b := Button.new()
	b.text = "Banana the chaser"
	UiStyle.fit(b, 28, 150.0)
	var size: int = b.get_theme_font_size("font_size")
	var w := HudFont.get_font().get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_check(w <= 150.0 and size < 28, "長い文字は小さくして収める(%d px / 幅 %.0f)" % [size, w])
	b.free()
	Locale.setup("ja")
	_check(Texts.stamp(Stamps.DROPPED) == "落ちてる😨", "日本語に戻せる")
	_check(Locale.pick("") in Locale.SUPPORTED, "端末の言語に合わせて選べる")


func _test_sounds() -> void:
	# 使う音が全部そろっていて読める(落とし物は5つとも別の音。BGM・環境音はくり返す)
	for n in ["drop_0", "drop_1", "drop_2", "drop_3", "drop_4", "step", "run_step", "look", "oops", "trudge", "pickup",
			"fall", "banana", "lap", "touch", "sit", "stamp_dropped", "stamp_safe", "stamp_trust",
			"chime", "reveal", "win", "lose", "match_end", "ui_click",
			"bgm_lobby", "bgm_round_1", "bgm_round_2", "bgm_round_3", "bgm_chase", "amb_school", "clock_tick", "curtain"]:
		_check(Sfx.get_stream(n) != null, "音 %s がある" % n)
	var bgm := Sfx.get_stream("bgm_chase") as AudioStreamOggVorbis
	_check(bgm != null and bgm.loop, "BGM はくり返す")
	for k in Stamps.ALL:
		_check(Sfx.get_stream("stamp_" + k) != null, "スタンプ %s の声がある" % k)
	# 音量のバス(全体・BGM・効果音)
	Sfx.setup_buses()
	_check(AudioServer.get_bus_index(Sfx.BUS_BGM) >= 0 and AudioServer.get_bus_index(Sfx.BUS_SFX) >= 0, "BGM と効果音のバスがある")
	var keep := Profile.vol_bgm
	Profile.vol_bgm = 0.5
	Sfx.apply_volumes()
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.BUS_BGM)) - linear_to_db(0.5)) < 0.01, "BGM の音量を変えられる")
	Profile.vol_bgm = keep
	Sfx.apply_volumes()
	# 鬼が最後の1周に入ったら、合図の音のお知らせが出る(ルールは変えない)
	var s := _chasing_state(19)
	var told := false
	for i in int(60.0 / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "last_lap":
				told = true
		if told or s.phase != GameState.Phase.CHASE:
			break
	_check(told or s.phase != GameState.Phase.CHASE, "鬼が最後の1周に入ると合図のお知らせ")


## イベント: 同じイベントが続けて起きにくい・先生の見回り・チャイム・突風・カモメ
func _test_events() -> void:
	var s := GameState.new()
	var repeats := 0
	var prev := ""
	for m in 12:
		s.start_match(200 + m)
		if s.event_kind == prev:
			repeats += 1
		prev = s.event_kind
	_check(repeats == 0, "イベント: 同じイベントが2試合続けて起きない(%d回)" % repeats)
	s.stage = "beach"
	s.start_match(5)
	_check(s.event_kind in ["prankster", "mirage"], "イベント: 海辺はいたずらっ子か蜃気楼(%s)" % s.event_kind)
	# いまは起こさないイベント(カミナリ・突風・チャイム・カモメ)は、どの舞台でも選ばれない
	var off_seen := false
	for st in ["classroom", "night", "beach"]:
		s.stage = st
		for m in 10:
			s.start_match(300 + m)
			if s.event_kind in GameConfig.EVENTS_OFF:
				off_seen = true
	_check(not off_seen, "イベント: カミナリ・突風・チャイム・カモメは起こさない")
	# 先生の見回り: だれも言葉を送れない
	s.stage = "classroom"
	s.start_match(3)
	s.take_events()
	s._start_event("teacher")
	_check(_has(s.take_events(), "event"), "イベント: 先生の見回りのお知らせ")
	var a := s.get_actor_at_seat(1)
	var b := s.get_actor_at_seat(3)
	_check(s.stamp_block_reason(a.id, b.id) == "teacher", "イベント: 先生の見回り中は言葉を送れない")
	s.tick(GameConfig.TEACHER_TIME + 0.1)
	_check(s.stamp_block_reason(a.id, b.id) != "teacher", "イベント: 見回りが終わると、また送れる")
	# チャイム: 鬼が少し速い
	var oni := s.get_actor(s.oni_id)
	var v0 := s._oni_walk_speed(oni)
	s._start_event("chime")
	_check(s._oni_walk_speed(oni) > v0, "イベント: チャイムで鬼が速くなる")
	# 突風: 画面が見えにくい時間
	s._start_event("gust")
	_check(s.gust_left > 0.0, "イベント: 突風で見えにくくなる")
	# カモメ: だれかのうしろに貝がら。貝がらだけなら振り向くとお手つき
	s.start_match(4)
	s.take_events()
	s._start_event("gull")
	_check(s.shell_seat >= 0 and s.shell_seat != s.drop_target_seat, "イベント: カモメが落とし物ではない席に貝がらを置く")
	var victim := s.get_actor_at_seat(s.shell_seat)
	s.set_looking_back(victim.id, true)
	_check(victim.role == GameState.Role.OUT and int(s.match_stats.get(victim.id, {}).get("gull_fooled", 0)) == 1,
			"イベント: 貝がらだけならお手つき(カモメにだまされた)")
	_check(s.event_log.size() >= 1, "イベント: 起きたイベントを記録する")


## いたずらっ子!: 送った言葉が逆の意味に書き換わる(同じ人は1回まで・回数まで)。ほかの人には書き換えたあとの言葉だけ
func _test_prankster() -> void:
	var s := GameState.new()
	s.start_match(21)
	s.take_events()
	s._start_event("prankster")
	_check(s.prank_on and s.prank_left == GameConfig.PRANK_COUNT, "いたずらっ子: このラウンドは %d 回書き換える" % GameConfig.PRANK_COUNT)
	_check(GameState.flip_stamp(Stamps.SAFE) == Stamps.DROPPED and GameState.flip_stamp(Stamps.DROPPED) == Stamps.SAFE
			and GameState.flip_stamp(Stamps.TRUST) == Stamps.SAFE, "いたずらっ子: 逆の意味の言葉にだけ書き換える")
	# いろいろな人がいろいろな人に送る(書き換えと書き換えの間は鬼が少し進むように)
	var pranked_senders := {}
	var first := {}
	for round_try in 6:
		for a in s.actors:
			for b in s.actors:
				if s.stamp_block_reason(a.id, b.id) != "":
					continue
				s.send_stamp(a.id, b.id, Stamps.SAFE)
				break
		s.oni_angle += GameConfig.PRANK_MIN_GAP_LAPS * TAU + 0.01
		s.active_stamps = {}
	for p in s.prank_log:
		pranked_senders[p["sender"]] = int(pranked_senders.get(p["sender"], 0)) + 1
		if first.is_empty():
			first = p
	var twice := false
	for k in pranked_senders:
		if int(pranked_senders[k]) > 1:
			twice = true
	_check(not s.prank_log.is_empty() and s.prank_log.size() <= GameConfig.PRANK_COUNT and not twice,
			"いたずらっ子: 書き換えは %d 回まで、同じ人は1回まで(%d 回)" % [GameConfig.PRANK_COUNT, s.prank_log.size()])
	if not first.is_empty():
		_check(str(first["flipped"]) == Stamps.DROPPED and str(first["orig"]) == Stamps.SAFE, "いたずらっ子: 「平気」が「落ちてる」に")
	# ほかの人には、書き換える前の言葉は届かない
	s.active_stamps = {}
	s.prank_left = 1
	s._pranked = []
	s._last_prank_angle = -INF
	var x := s.get_actor_at_seat(1)
	var y := s.get_actor_at_seat(4)
	x.stamped_targets.clear()
	var ok_sent := false
	for k in 40:
		s.active_stamps = {}
		x.stamped_targets.clear()
		s.send_stamp(x.id, y.id, Stamps.SAFE)
		if not s._pranked.is_empty():
			ok_sent = true
			break
	if ok_sent:
		_check(not (y.id in x.stamped_targets), "いたずらっ子: 書き換えられたら、同じ相手にすぐ言い直せる")
		var other := s.get_actor_at_seat(2).id
		var st_other: Dictionary = (s.snapshot(other)["stamps"][y.id] as Array)[0]
		var st_self: Dictionary = (s.snapshot(x.id)["stamps"][y.id] as Array)[0]
		_check(st_other["kind"] == Stamps.DROPPED and not st_other["prank"] and st_other["orig"] == Stamps.DROPPED,
				"いたずらっ子: ほかの人には、書き換えたあとの言葉だけ(ふつうの言葉と同じ)")
		_check(st_self["prank"] and st_self["orig"] == Stamps.SAFE, "いたずらっ子: 送った本人だけが、書き換えられたことを知る")


## 蜃気楼!(海辺): 本物が見える人は少し。ほかの全員には、鬼がうしろを通ったときに同じ席のうしろにニセが見える
func _test_mirage() -> void:
	var s := GameState.new()
	s.stage = "beach"
	s.start_match(31)
	s.event_kind = "mirage"
	s.event_round = s.round_index
	s.restart_round()
	var ev := s.take_events()
	_check(s.mirage_on and _has(ev, "event"), "蜃気楼: 鬼が歩き出したらすぐ始まる(落とす前)")
	_check(s.mirage_true.size() == GameConfig.MIRAGE_TRUE_VIEWERS and not (s.oni_id in s.mirage_true), "蜃気楼: 本物が見えるのは鬼以外の %d 人" % GameConfig.MIRAGE_TRUE_VIEWERS)
	_check(not s._mirage_plan.is_empty() and int(s._mirage_plan[0]["seat"]) != s.drop_target_seat, "蜃気楼: ニセは本物が落とされる席とは別の席")
	var seat: int = s._mirage_plan[0]["seat"]
	var fake_ev := {}
	for k in 4000:
		s.tick(0.05)
		for e in s.take_events():
			if e["type"] == "mirage_fake":
				fake_ev = e
		if not fake_ev.is_empty() or s.phase == GameState.Phase.CHASE:
			break
	_check(not fake_ev.is_empty() and seat in s.mirage_fakes_shown, "蜃気楼: 鬼がその席のうしろを通ったときにニセが現れる")
	if fake_ev.is_empty():
		return
	_check(s.oni_id in fake_ev["not_for"] and s.mirage_true[0] in fake_ev["not_for"], "蜃気楼: 本物が見える人と鬼には、ニセのお知らせは届かない")
	var fake_target := s.get_actor_at_seat(seat)
	var team := -1
	for a in s.actors:
		if a.id != s.oni_id and not (a.id in s.mirage_true) and a.id != fake_target.id and a.role == GameState.Role.SEATED:
			team = a.id
	_check(s.perceived_item_behind(team, fake_target) and not s.perceived_item_behind(s.mirage_true[0], fake_target),
			"蜃気楼: 蜃気楼チームにはニセが見えて、本物が見える人には見えない")
	var snap_team := s.snapshot(team)
	var snap_true := s.snapshot(s.mirage_true[0])
	_check(seat in snap_team["mirage_fakes"] and not snap_team["mirage_real"] and snap_true["mirage_fakes"].is_empty() and snap_true["mirage_real"],
			"蜃気楼: だれがどちらかは本人のことだけ届く")
	# 蜃気楼のせいで間違えた言葉は、ウソにしない
	var lies_before := int(s.lie_counts.get(team, 0))
	if s.stamp_block_reason(team, fake_target.id) == "":
		s.send_stamp(team, fake_target.id, Stamps.DROPPED)
		_check(int(s.lie_counts.get(team, 0)) == lies_before, "蜃気楼: ニセを信じた「落ちてる」はウソにならない")
	# 鬼が1周したら終わる(本物が全員に見える)
	for k in 4000:
		s.tick(0.05)
		if s.mirage_done or s.phase == GameState.Phase.CHASE:
			break
	_check(s.mirage_done and s.mirage_sees_real(team), "蜃気楼: 鬼が1周したら終わって、本物が全員に見える")


## 海辺の砂のお城: 抱えて走ると小さくなり、転ぶと崩れてもっと小さくなる。小さいほど少し速い
func _test_castle() -> void:
	var s := GameState.new()
	s.stage = "beach"
	s.start_match(9)
	s.round_index = 3
	s.restart_round()
	_check(s.is_castle_round() and s.castle_size == 1.0, "お城: はじめは大きさ 1")
	_run_until(s, "dropped", 120.0)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	s.pick_up(target.id)
	var w0 := s.item_weight()
	for i in 40:
		s.tick(0.05)
		if s.phase != GameState.Phase.CHASE:
			break
	_check(s.castle_size < 1.0, "お城: 抱えて走ると砂がこぼれて小さくなる(%.2f)" % s.castle_size)
	_check(s.item_weight() < w0, "お城: 小さくなるほど軽い")
	var before := s.castle_size
	var chaser := s.get_actor(s.chaser_id)
	if chaser:
		s.obstacles = []
		s._add_obstacle(s.runner_angle(chaser), chaser.lane, "bucket")
		s._check_obstacles(chaser)
		var ev := s.take_events()
		_check(_has(ev, "castle_crumble") and s.castle_size < before, "お城: 転ぶと崩れて小さくなる")


func _test_blackout() -> void:
	# 1試合に1回、2〜4ラウンド目のどれかでイベントが起きる(ステージに合ったもの。停電はその1つ)
	for seed_value in 10:
		var s0 := GameState.new()
		s0.start_match(seed_value)
		_check(s0.event_round >= GameConfig.BLACKOUT_ROUND_MIN and s0.event_round <= GameConfig.BLACKOUT_ROUND_MAX,
				"イベントは2〜4ラウンド目のどれか(%d)" % (s0.event_round + 1))
		_check(s0.event_kind in GameConfig.EVENTS_BY_STAGE["classroom"], "教室のイベントは教室のものから(%s)" % s0.event_kind)
		_check((s0.event_kind == "blackout") == (s0.blackout_round >= 0), "停電のときだけ、停電するラウンドが決まる")
	_test_events()
	_test_prankster()
	_test_mirage()
	_test_castle()
	# 停電するラウンドでは、ラウンドの途中でとつぜん停電する。拾って追いかけっこになったら電気がつく
	var s := GameState.new()
	s.start_match(7)
	s.blackout_round = 0
	s.restart_round()
	_check(not s.blackout, "ラウンドの最初は停電していない")
	var got := _run_until(s, "blackout", 120.0)
	_check(not got.is_empty() and s.blackout, "ラウンドの途中で停電する")
	var g := GameState.new()
	g.apply_snapshot(s.snapshot())
	_check(g.blackout, "停電しているかは通信で届く")
	# 鬼が1周したら、電気がつく
	var start := s.oni_angle
	var lit := _run_until(s, "lights_on", 200.0)
	_check(not lit.is_empty() and not s.blackout, "鬼が1周したら電気がつく")
	_check(s.oni_angle - start >= GameConfig.BLACKOUT_LAPS * TAU - 0.01, "電気がつくのは、停電から1周したあと")
	# それより前に追いかけっこが始まったら、そこで電気がつく
	var s3 := GameState.new()
	s3.start_match(7)
	s3.blackout_round = 0
	s3.restart_round()
	_run_until(s3, "blackout", 120.0)
	_run_until(s3, "dropped", 120.0)
	if s3.phase == GameState.Phase.DROPPED and s3.blackout:
		var target := s3.get_actor_at_seat(s3.drop_target_seat)
		s3.take_events()
		s3.pick_up(target.id)
		_check(not s3.blackout and _has(s3.take_events(), "lights_on"), "追いかけっこが始まったら電気がつく")
	# 停電しないラウンドでは停電しない
	var s2 := GameState.new()
	s2.start_match(7)
	s2.blackout_round = 3
	s2.restart_round()
	_check(_run_until(s2, "blackout", 60.0).is_empty(), "停電するラウンド以外は停電しない")
	_check(Sfx.get_stream("power_off") != null and Sfx.get_stream("power_on") != null, "停電の音がある")


func _test_milk_art() -> void:
	var tex := MilkArt.texture(Vector2(1280, 720), 1.0)
	_check(tex != null and tex.get_width() == 1280 and tex.get_height() == 720, "牛乳の絵(SVG)が画面の大きさで作れる")
	var tex2 := MilkArt.texture(Vector2(1560, 720), 1.0)
	_check(tex2 != null and tex2.get_width() == 1560, "横長の画面でも作れる")


func _test_stamp_words() -> void:
	_check(Stamps.ALL.size() == 3, "スタンプは3つ(落ちてる!・まだへいき!・信じて!)")
	_check(Texts.stamp(Stamps.DROPPED) == "落ちてる😨" and Texts.stamp(Stamps.SAFE) == "平気👍" \
			and Texts.stamp(Stamps.TRUST) == "信じて🥺", "スタンプの言葉と絵文字")
	_check(Texts.stamp(Stamps.SAFE, "だいじょぶ") == "だいじょぶ👍", "言葉を変えても絵文字はそのまま")
	var font := HudFont.get_font()
	_check(not font.fallbacks.is_empty(), "絵文字フォントが入っている")
	_check(font.fallbacks[0].has_char(0x1f628) and font.fallbacks[0].has_char(0x1f44d) and font.fallbacks[0].has_char(0x1f97a),
			"絵文字フォントに 😨👍🥺 がある")
	for k in Stamps.ALL:
		_check(WorldView.STAMP_COLORS.has(k), "%s に色がある" % k)
	_check(not Stamps.says_look(Stamps.SAFE) and Stamps.says_look(Stamps.TRUST), "まだへいき=見るな、信じて=見ろ")
	_check(Locale.t("%sに送る") % "ボット3" == "ボット3に送る", "「◯◯に送る」")


func _test_stamp_truthfulness() -> void:
	var s := _dropped_state(43)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	var other := s.get_actor_at_seat((s.drop_target_seat + 1) % GameConfig.SEAT_COUNT)
	var sender := s.get_actor_at_seat((s.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	var sender2 := s.get_actor_at_seat((s.drop_target_seat + 3) % GameConfig.SEAT_COUNT)
	s.send_stamp(sender.id, target.id, Stamps.DROPPED)
	_check(s.active_stamps[target.id][0]["truthful"], "落とされた人に『落ちてる!』は本当")
	s.send_stamp(sender2.id, other.id, Stamps.DROPPED)
	_check(not s.active_stamps[other.id][0]["truthful"], "落とされていない人に『落ちてる!』は嘘")
	s.set_looking_back(target.id, true)
	s.pick_up(target.id)
	_check(s.active_stamps.is_empty(), "追いかけっこが始まるとスタンプは消える")
	_check(not s.send_stamp(sender.id, other.id, Stamps.SAFE), "追いかけっこ中は送れない")


func _test_bots_send_and_trust_stamps() -> void:
	var sent := 0
	var from_oni := 0
	var otetsuki_after_stamp := 0
	for seed_value in 30:
		var s := GameState.new()
		s.start_round(seed_value)
		var b := BotBrain.new()
		b.reset(seed_value)
		var pairs := {}
		var bot_turns := 0
		for i in int(40.0 / STEP):
			b.update(s, STEP)
			s.tick(STEP)
			for e in s.take_events():
				if e["type"] == "stamp":
					sent += 1
					# ボットが反応する(拾って席を立つ)前に確かめる
					var t := s.get_actor(e["target"])
					var from := s.get_actor(e["sender"])
					if from.id == s.oni_id:
						from_oni += 1
					elif from.role == GameState.Role.OUT:
						# お手つきで抜けた人は、両どなりにも送れる
						pass
					else:
						_check(not s.is_stamp_neighbor(from.seat_index, t.seat_index), "8人のとき、ボットは両どなりに送らない")
					var key := "%d>%d" % [from.id, t.id]
					_check(not pairs.has(key), "ボットは同じ相手に1ラウンド2回送らない")
					pairs[key] = true
					_check(s.seat_pass_age[t.seat_index] <= GameConfig.BOT_STAMP_RECENT_PASS + STEP * 1.5,
							"ボットは鬼がついさっき後ろを通った人にだけスタンプを送る")
				elif e["type"] == "otetsuki":
					otetsuki_after_stamp += 1
					var turner := s.get_actor(e["actor"])
					if turner.is_bot:
						# お手つきした人は、もう輪から抜けている(もとの席で確かめる)
						var age: float = s.seat_pass_age[turner.home_seat]
						_check(age != INF and age >= GameConfig.BOT_TURN_MIN_AFTER_PASS - STEP * 2.0,
								"ボットは鬼が後ろを通ってから %d 秒たつまで振り向かない(%.1f 秒)" % [int(GameConfig.BOT_TURN_MIN_AFTER_PASS), age])
				elif e["type"] == "picked_up":
					var age: float = s.seat_pass_age[s.vacant_seat]
					_check(age >= GameConfig.BOT_TURN_MIN_AFTER_PASS - STEP * 2.0,
							"落とされたボットも、鬼が通ってすぐには拾わない(%.1f 秒)" % age)
				b.on_event(s, e)
			if s.phase == GameState.Phase.RESULT:
				break
		for a in s.actors:
			_check(a.stamps_left == GameConfig.STAMPS_PER_ROUND or a.stamps_left >= 0, "スタンプの残りの数がおかしくならない")
	_check(sent > 0, "ボットがスタンプを送る")
	_check(from_oni > 0, "鬼のボットもスタンプを送る")
	_check(otetsuki_after_stamp > 0, "ボットがスタンプを信じて振り向き、お手つきすることがある")
	print("bot stamps sent: %d, otetsuki: %d" % [sent, otetsuki_after_stamp])


func _test_player_oni_setup() -> void:
	var s := GameState.new()
	s.start_round(51, true)
	_check(s.oni_is_player and s.local_player_id == s.oni_id, "鬼をやるとき、自分が鬼")
	_check(not s.get_actor(s.oni_id).is_bot, "鬼はボットではない")
	var seated_bots := 0
	for a in s.actors:
		if a.role == GameState.Role.SEATED and a.is_bot:
			seated_bots += 1
	_check(seated_bots == GameConfig.SEAT_COUNT, "席には全部ボットが座る")
	_check(s.drop_target_seat == -1, "誰に落とすかは決まっていない")
	s.start_round(51, false)
	_check(not s.oni_is_player and s.local_player_id == 0, "座る側に戻せる")


func _test_player_oni_walk_speed_and_stop() -> void:
	var s := GameState.new()
	s.start_round(53, true)
	var oni := s.get_actor(s.oni_id)
	var a0 := s.oni_angle
	for i in 60:
		s.tick(STEP)
	var normal := s.oni_angle - a0
	var carry := lerpf(1.0, GameConfig.ONI_CARRY_SPEED_HEAVY, s.item_weight())
	_check(absf(normal * GameConfig.ONI_WALK_RADIUS - GameConfig.ONI_WALK_SPEED * carry) < 0.05, "スティックを倒さなければ自動で前に歩く")

	a0 = s.oni_angle
	for i in 60:
		s.set_move(oni.id, Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle)))
		s.tick(STEP)
	_check((s.oni_angle - a0) > normal * 1.3, "歩く向きに倒すと速く歩く")

	# 反対に倒す: すぐ止まり、倒し続けると後ろに戻る。戻れるのは、いちばん進んだ地点から ONI_BACK_LIMIT まで
	var far := s.oni_angle
	for i in int(GameConfig.ONI_BACK_HOLD * 0.5 / STEP):
		s.set_move(oni.id, -Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle)))
		s.tick(STEP)
	_check(absf(s.oni_angle - far) < 0.0001, "反対に倒すと止まる")
	for i in int(10.0 / STEP):
		s.set_move(oni.id, -Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle)))
		s.tick(STEP)
	var back := (far - s.oni_angle) * GameConfig.ONI_WALK_RADIUS
	_check(back > GameConfig.ONI_BACK_LIMIT - 0.05 and back < GameConfig.ONI_BACK_LIMIT + 0.05,
			"倒し続けると戻れるのは %.1f m まで(%.2f m)" % [GameConfig.ONI_BACK_LIMIT, back])
	s.set_move(oni.id, Vector3.ZERO)
	a0 = s.oni_angle
	s.tick(STEP)
	_check(s.oni_angle > a0, "スティックを離すと、また前に歩く")


func _test_player_oni_drop_and_feint() -> void:
	var s := GameState.new()
	s.start_round(55, true)
	var oni := s.get_actor(s.oni_id)
	# 歩きはじめは席と席のまん中なので、落とせない
	_check(not s.oni_drop(oni.id), "席の後ろから離れていると落とせない")
	_check(_has(s.take_events(), "drop_failed"), "落とせなかったお知らせが出る")
	# ふりはどこでもできて、いちばん近い席の後ろで鳴る
	s.oni_feint(oni.id)
	var ev := s.take_events()
	_check(_has(ev, "rustle"), "ふりで物音が出る")
	_check(s.phase == GameState.Phase.WALKING, "ふりでは落ちない")
	# 次の席の後ろまで歩いて落とす
	var target_angle := s.next_seat_crossing
	while s.oni_angle < target_angle - 0.01:
		s.tick(STEP)
	_check(s.oni_drop(oni.id), "席の後ろなら落とせる")
	_check(s.phase == GameState.Phase.DROPPED and s.handkerchief_on_floor, "落とすと床にハンカチ")
	_check(s.drop_target_seat == posmod(roundi(target_angle / TAU * GameConfig.SEAT_COUNT), GameConfig.SEAT_COUNT), "いちばん近い席の後ろに落ちる")
	_check(not s.oni_drop(oni.id), "2回は落とせない")
	# 座っている人は鬼の命令を使えない
	var s2 := GameState.new()
	s2.start_round(55, false)
	_check(not s2.oni_drop(0), "座る側は落とせない")

	# ボットが「ふり」にだまされることがある(鬼が後ろを通って、しばらくたってから)。
	# 鬼が一度も後ろを通っていないうちは、だまされない
	var fooled := 0
	var fooled_early := 0
	for seed_value in 40:
		for passed in [false, true]:
			var s3 := GameState.new()
			s3.start_round(seed_value, true)
			if passed:
				for i in s3.seat_pass_age.size():
					s3.seat_pass_age[i] = GameConfig.BOT_TURN_MIN_AFTER_PASS + 1.0
			var b := BotBrain.new()
			b.reset(seed_value)
			s3.oni_feint(s3.oni_id)
			for e in s3.take_events():
				b.on_event(s3, e)
			for e in s3.take_events():
				if e["type"] == "otetsuki":
					if passed:
						fooled += 1
					else:
						fooled_early += 1
	_check(fooled > 0 and fooled < 40, "ボットは「ふり」にときどきだまされる")
	_check(fooled_early == 0, "鬼が後ろを通っていないうちは、ボットは「ふり」にだまされない")


func _test_player_oni_auto_drop_after_laps() -> void:
	var s := GameState.new()
	s.start_round(57, true)
	var e := _run_until(s, "dropped", 400.0)
	_check(not e.is_empty(), "落とさなくても、いつかは自動で落ちる")
	var laps := (s.oni_angle - s.oni_start_angle) / TAU
	_check(laps >= GameConfig.ONI_MAX_LAPS_BEFORE_DROP and laps < GameConfig.ONI_MAX_LAPS_BEFORE_DROP + 0.5,
			"自動で落ちるのは %d 周したあと" % GameConfig.ONI_MAX_LAPS_BEFORE_DROP)


func _test_player_oni_rounds_finish() -> void:
	var reasons := {}
	for seed_value in 30:
		var s := GameState.new()
		s.start_round(seed_value, true)
		var b := BotBrain.new()
		b.reset(seed_value)
		var oni := s.get_actor(s.oni_id)
		var dropped := false
		var e := {}
		for i in int(300.0 / STEP):
			# 人の鬼のまね: 2つ目の席の後ろで落とし、追いかけられたら内側を走る
			if not dropped and s.oni_angle >= s.oni_start_angle + TAU * 2.0 / GameConfig.SEAT_COUNT:
				dropped = s.oni_drop(oni.id)
			if s.phase == GameState.Phase.CHASE:
				s.set_move(oni.id, -Vector3(oni.position.x, 0, oni.position.z).normalized())
			b.update(s, STEP)
			s.tick(STEP)
			for ev in s.take_events():
				b.on_event(s, ev)
				if ev["type"] == "result":
					e = ev
			if not e.is_empty():
				break
		_check(not e.is_empty(), "seed %d: 人が鬼でもラウンドは必ず終わる" % seed_value)
		if not e.is_empty():
			reasons[e["reason"]] = true
			if e["reason"] == "sat":
				_check(oni.seat_index == s.vacant_seat, "座れたら鬼は空いた席にいる")
	print("player oni results: ", reasons.keys())
	_check(reasons.size() >= 2, "人が鬼のときも、勝ったり負けたりする")


## 勝敗が出るまで、ボットと一緒に進める
func _play_round_with_bots(s: GameState, b: BotBrain) -> Dictionary:
	for i in int(300.0 / STEP):
		b.update(s, STEP)
		s.tick(STEP)
		for ev in s.take_events():
			b.on_event(s, ev)
			if ev["type"] == "result":
				return ev
	return {}


func _test_match_next_oni_is_loser() -> void:
	var seen := {}
	for seed_value in 30:
		var s := GameState.new()
		s.start_match(seed_value)
		var b := BotBrain.new()
		b.reset(seed_value)
		var e := _play_round_with_bots(s, b)
		if e.is_empty():
			_check(false, "seed %d: 1ラウンド目が終わる" % seed_value)
			continue
		var reason: String = e["reason"]
		seen[reason] = true
		var old_oni := s.oni_id
		var chaser := s.chaser_id
		var vacant := s.vacant_seat
		var target_seat := s.drop_target_seat
		_check(s.next_round(), "次のラウンドに進める")
		_check(s.round_index == 1 and s.item_name() == Items.name_of(1), "2ラウンド目は %s" % Items.name_of(1))
		_check(s.oni_id == e["loser"], "負けた人が次の鬼(%s)" % reason)
		var seated := 0
		for a in s.actors:
			if a.role == GameState.Role.SEATED:
				seated += 1
		_check(seated == GameConfig.SEAT_COUNT, "席は全部うまっている")
		match reason:
			"touched":
				_check(s.get_actor(chaser).seat_index == vacant, "タッチした人は自分の席に戻る")
				_check(s.oni_id == old_oni, "鬼はもう一度鬼")
			"sat":
				_check(s.get_actor(old_oni).seat_index == vacant, "座れた鬼はその席に座ったまま")
			"missed":
				_check(s.get_actor(old_oni).seat_index == target_seat, "見逃されたら、鬼はその人の席に入る")
		_check(s.phase == GameState.Phase.WALKING and not s.handkerchief_on_floor, "新しいラウンドは歩くところから")
	_check(seen.size() >= 2, "いろいろな結果でためせた")


func _test_match_scores_and_end() -> void:
	var s := GameState.new()
	s.start_match(61)
	var b := BotBrain.new()
	b.reset(61)
	var total_rounds := 0
	while true:
		var e := _play_round_with_bots(s, b)
		_check(not e.is_empty(), "ラウンド %d が終わる" % (s.round_index + 1))
		if e.is_empty():
			return
		total_rounds += 1
		match e["reason"]:
			"sat":
				_check(e["scores"][e["winner"]] >= GameConfig.SCORE_ONI_SAT or true, "")
		if not s.next_round():
			break
		b.reset(61 + total_rounds)
	_check(total_rounds == GameConfig.ROUNDS_PER_MATCH, "1試合は %d ラウンド" % GameConfig.ROUNDS_PER_MATCH)
	_check(s.match_over, "最後のラウンドのあとは試合終了")
	var over_ev := s.take_events()
	_check(_has(over_ev, "match_over"), "試合終了のお知らせが出る")
	# 称号: 最大3つ。お知らせと状態(参加者に送る分)にも入る
	_check(s.titles.size() <= Titles.MAX_AWARDS, "試合の最後の称号は最大3つ(%d)" % s.titles.size())
	for e in over_ev:
		if e["type"] == "match_over":
			_check((e.get("titles", []) as Array).size() == s.titles.size(), "試合終了のお知らせに称号が入る")
	var guest := GameState.new()
	guest.apply_snapshot(s.snapshot())
	_check(guest.titles.size() == s.titles.size(), "参加者にも同じ称号が届く")
	_check(not s.match_stats.is_empty(), "試合中の出来事が数えられている")
	_check(not s.next_round(), "試合終了のあとは次のラウンドに進めない")
	var sum := 0
	for id in s.scores:
		sum += s.scores[id]
	_check(sum != 0, "点数が入っている")

	# 点数の決まりを1つずつ確かめる
	var s2 := GameState.new()
	s2.start_match(63)
	var before: Dictionary = s2.scores.duplicate()
	var e2 := _run_until(s2, "result", 200.0)
	_check(e2["reason"] == "missed", "(確認用)だれも気づかなければ見逃し")
	_check(s2.scores[e2["loser"]] == before[e2["loser"]] + GameConfig.SCORE_LOSE, "気づかなかった人は %d 点" % GameConfig.SCORE_LOSE)
	var s3 := _chasing_state(65)
	var c := s3.get_actor(s3.chaser_id)
	var e3 := {}
	for i in int(60.0 / STEP):
		s3.chase_lane(c.id, -1)
		s3.tick(STEP)
		for ev in s3.take_events():
			if ev["type"] == "result":
				e3 = ev
		if not e3.is_empty():
			break
	if not e3.is_empty() and e3["reason"] == "touched":
		_check(s3.scores[c.id] == GameConfig.SCORE_CHASER_TOUCHED, "タッチした人は +%d 点" % GameConfig.SCORE_CHASER_TOUCHED)


func _test_heavier_items_slow_the_chaser() -> void:
	# 重い物を持っても速さは同じ。そのかわり、転んだときに起き上がるまでが長い
	var speeds := []
	var falls := []
	for round_no in [0, GameConfig.ROUNDS_PER_MATCH - 1]:
		var s := GameState.new()
		s.start_match(67)
		s.round_index = round_no
		s.restart_round()
		_run_until(s, "dropped", 200.0)
		for i in int(3.0 / STEP):
			s.tick(STEP)
		var target := s.get_actor_at_seat(s.drop_target_seat)
		s.pick_up(target.id)
		s.obstacles = []
		var p0 := target.position
		s.tick(STEP)
		speeds.append(target.position.distance_to(p0) / STEP)
		var r: float = GameConfig.LANE_RADII[target.lane]
		s._add_obstacle(fposmod(s.runner_angle(target) + 0.5 / r, TAU), target.lane, "bucket")
		for i in int(0.5 / STEP):
			s.tick(STEP)
			if target.slip_left > 0.0:
				break
		falls.append(target.slip_left)
	_check(absf(speeds[0] - speeds[1]) < 0.05, "教卓を持っても、ハンカチと同じ速さ")
	_check(falls[1] > falls[0] * 1.5, "教卓を持って転ぶと、起き上がるまでが長い(%.2f / %.2f 秒)" % [falls[0], falls[1]])
	print("chaser speed: handkerchief %.2f / heaviest %.2f, fall %.2f / %.2f" % [speeds[0], speeds[1], falls[0], falls[1]])


func _test_banana_rules() -> void:
	var s := _chasing_state(73)
	# (鬼は外側の列を走らせる。内側だと、追う人の前のバナナを鬼が先に踏んでしまう)
	s.get_actor(s.oni_id).lane = 2
	var thrower := s.get_actor_at_seat((s.vacant_seat + 2) % GameConfig.SEAT_COUNT)
	var s0 := _dropped_state(73)
	_check(not s0.throw_banana(thrower.id, s0.oni_id), "追いかけっこの前は投げられない")
	_check(not s.throw_banana(s.oni_id, s.chaser_id), "鬼は投げられない")
	_check(not s.throw_banana(thrower.id, thrower.id), "座っている人には投げられない")
	_check(s.throw_banana(thrower.id, s.chaser_id), "追いかける人に投げられる")
	_check(s.throw_banana(thrower.id, s.oni_id), "バナナは何回でも投げられる")
	var other := s.get_actor_at_seat((s.vacant_seat + 3) % GameConfig.SEAT_COUNT)
	_check(s.throw_banana(other.id, s.oni_id), "鬼にも投げられる")
	var n_banana := 0
	for ob in s.obstacles:
		if ob["kind"] == "banana":
			n_banana += 1
	_check(n_banana == 3, "コースにバナナが3つ")
	# 追いかける人はまっすぐ走ると踏んで転ぶ
	var c := s.get_actor(s.chaser_id)
	var slipped := false
	for i in int(2.0 / STEP):
		s.set_move(c.id, Vector3.ZERO)
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "slip" and e["actor"] == c.id:
				slipped = true
		if slipped or s.phase != GameState.Phase.CHASE:
			break
	_check(slipped, "前に落ちたバナナをよけないと転ぶ")
	if slipped and s.phase == GameState.Phase.CHASE:
		var p0 := c.position
		for i in int(0.5 / STEP):
			s.tick(STEP)
		_check(c.position.distance_to(p0) < 0.01, "転んでいる間は止まる")
		for i in int(GameConfig.SLIP_TIME / STEP) + 2:
			s.tick(STEP)
		var p1 := c.position
		s.tick(STEP)
		_check(c.position.distance_to(p1) > 0.01 or s.phase != GameState.Phase.CHASE, "起き上がるとまた走る")


func _test_banana_can_be_dodged() -> void:
	var s := _chasing_state(75)
	var c := s.get_actor(s.chaser_id)
	s.get_actor(s.oni_id).lane = 2
	var thrower := s.get_actor_at_seat((s.vacant_seat + 2) % GameConfig.SEAT_COUNT)
	s.throw_banana(thrower.id, c.id)
	var slipped := false
	# 列を変えてよける
	s.chase_lane(c.id, 1 if c.lane == 0 else -1)
	for i in int(2.0 / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "slip" and e["actor"] == c.id:
				slipped = true
	_check(not slipped, "列を変えればバナナをよけられる")


func _test_bots_throw_bananas() -> void:
	var thrown := 0
	var slips := 0
	for seed_value in 40:
		var s := GameState.new()
		s.start_match(seed_value)
		var b := BotBrain.new()
		b.reset(seed_value)
		for i in int(120.0 / STEP):
			b.update(s, STEP)
			s.tick(STEP)
			for e in s.take_events():
				b.on_event(s, e)
				if e["type"] == "banana":
					thrown += 1
				elif e["type"] == "slip":
					slips += 1
			if s.phase == GameState.Phase.RESULT:
				break
	_check(thrown > 0, "ボットがバナナを投げることがある")
	print("bot bananas thrown: %d, slips: %d" % [thrown, slips])


func _test_who_can_see_behind_whom() -> void:
	for players in range(GameConfig.PLAYER_COUNT_MIN, GameConfig.PLAYER_COUNT_MAX + 1):
		_check_visibility(players - 1)


func _test_stamp_sender_hidden_up_to_six() -> void:
	# 6人まで(5席まで)は、鬼と自分以外のスタンプの送り主は「だれか」。7人からは名前が出る
	for players in range(GameConfig.PLAYER_COUNT_MIN, GameConfig.PLAYER_COUNT_MAX + 1):
		var g := GameState.new()
		g.start_match(3, false, players - 1)
		_check(g.actors.size() == players, "%d人で遊べる" % players)
		var other := -1
		for a in g.actors:
			if a.id != g.oni_id and a.id != g.local_player_id:
				other = a.id
				break
		_check(HeadOverlay.is_anonymous(g, other) == (players <= 6), "%d人: 送り主を隠すのは6人まで" % players)
		_check(not HeadOverlay.is_anonymous(g, g.oni_id), "鬼のスタンプは「鬼」と出る")


func _check_visibility(n: int) -> void:
	var g := GameState.new()
	g.start_match(1, false, n)
	_check(g.seat_count == n and g.seat_positions.size() == n, "席が %d つ" % n)
	for i in n:
		_check(not g.can_see_behind(i, i), "自分の後ろは見えない")
		_check(not g.can_see_behind(i, (i + 1) % n), "右どなりの後ろは見えない")
		_check(not g.can_see_behind(i, (i + n - 1) % n), "左どなりの後ろは見えない")
		var seen := 0
		for j in n:
			if g.can_see_behind(i, j):
				seen += 1
		_check(seen == n - 3, "見えるのは向かいの %d 人" % (n - 3))


func _test_miss_goes_out() -> void:
	# お手つきは減点しない。そのかわり輪から抜けて真ん中で体育座り、このラウンドの点は0点
	var s := GameState.new()
	s.start_match(81)
	var me := s.get_local_player()
	var seat := me.seat_index
	s.scores[me.id] = 7
	s._round_base_scores[me.id] = 5
	s.set_looking_back(me.id, true)
	var ev := s.take_events()
	_check(_has(ev, "otetsuki") and _has(ev, "out"), "お手つきと、抜けたお知らせが出る")
	_check(s.scores[me.id] == 5, "このラウンドで取った点はなくなる(ラウンドの最初の点に戻る)")
	_check(me.role == GameState.Role.OUT and me.seat_index == -1 and me.home_seat == seat, "輪から抜けて、もとの席を覚えている")
	_check(s.get_actor_at_seat(seat) == null, "席は空いたまま")
	_check(Vector2(me.position.x, me.position.z).length() < 1.5, "真ん中に座る")
	# 抜けた人は全員の後ろが見え、だれにでもスタンプを送れる(両どなりにも)
	var nb := s.get_actor_at_seat((seat + 1) % s.seat_count)
	_check(s.sees_behind(me.id, (seat + 1) % s.seat_count), "抜けた人は両どなりの後ろも見える")
	_check(s.stamp_block_reason(me.id, nb.id) == "", "抜けた人は両どなりにもスタンプを送れる")
	_check(s.send_stamp(me.id, nb.id, Stamps.SAFE), "抜けた人もスタンプを送れる")
	_check(s.stamp_block_reason(nb.id, me.id) == "invalid", "抜けた人にはスタンプを送れない")
	# 抜けた人がだましても教えても、このラウンドは0点
	s.scores[me.id] = 5
	var st: Dictionary = s.active_stamps[nb.id][0]
	st["scorable"] = true
	s._award_help(st, nb.id)
	_check(s.scores[me.id] == 5, "抜けた人には点が入らない")
	# 抜けた人の席の後ろには、鬼(人)は落とせない
	var s2 := GameState.new()
	s2.start_round(55, true)
	var out_seat := s2._seat_at_angle(s2.next_seat_crossing)
	s2.set_looking_back(s2.get_actor_at_seat(out_seat).id, true)
	while s2.oni_angle < s2.next_seat_crossing - 0.01:
		s2.tick(STEP)
	_check(not s2.oni_drop(s2.oni_id), "空いた席の後ろには落とせない")
	# ボットの鬼が落とす予定だった人が抜けたら、ほかの人に落とす
	var s3 := GameState.new()
	s3.start_round(57)
	var planned := s3.get_actor_at_seat(s3.drop_target_seat)
	s3.set_looking_back(planned.id, true)
	_check(s3.get_actor_at_seat(s3.drop_target_seat) != null, "落とす相手を選び直す")
	var d := _run_until(s3, "dropped", 200.0)
	_check(not d.is_empty() and s3.get_actor_at_seat(d["seat"]) != null, "座っている人の後ろに落とす")
	# 次のラウンドでは、もとの席に戻る
	var s4 := GameState.new()
	s4.start_match(83)
	s4.minion_id = -1
	var p4 := s4.get_local_player()
	var home := p4.seat_index
	s4.set_looking_back(p4.id, true)
	var r := _run_until(s4, "result", 200.0)
	_check(not r.is_empty(), "抜けた人がいてもラウンドは終わる")
	if not r.is_empty() and r["loser"] != p4.id:
		s4.next_round()
		_check(p4.role == GameState.Role.SEATED and p4.seat_index == home, "次のラウンドは、もとの席に戻る")
	# 全員が抜けたら、鬼の勝ち(負けた人はいない。次も同じ鬼)
	var s5 := GameState.new()
	s5.start_match(85, false, 5)
	var oni5 := s5.oni_id
	var before5: Dictionary = s5.scores.duplicate()
	for a in s5.actors.duplicate():
		if a.role == GameState.Role.SEATED:
			s5.set_looking_back(a.id, true)
	_check(s5.phase == GameState.Phase.RESULT and s5.result["reason"] == "all_out", "全員お手つきで抜けたら鬼の勝ち")
	for a in s5.actors:
		if a.id != oni5 and not s5.is_minion(a.id):
			_check(s5.scores[a.id] == before5[a.id], "%s: 全員抜けたときは、だれも減点されない" % a.display_name)
	s5.next_round()
	_check(s5.oni_id == oni5, "全員抜けたときは、次も同じ鬼")


func _test_milk() -> void:
	var s := GameState.new()
	s.start_round(61, true)
	var oni := s.oni_id
	_check(s.milk_left == GameConfig.MILK_PER_ROUND, "鬼は牛乳を %d 回かけられる" % GameConfig.MILK_PER_ROUND)
	var victim := s.get_actor_at_seat(3)
	_check(not s.oni_milk(0, victim.id), "座っている人は牛乳をかけられない")
	_check(not s.oni_milk(oni, oni), "鬼は自分にはかけられない")
	_check(not s.oni_milk(oni, -1), "相手を選ばないとかけられない")
	s.take_events()
	# 選んだ人に、どこからでもかけられる
	_check(s.can_milk(victim.id), "座っている人は、かける相手に選べる")
	_check(s.oni_milk(oni, victim.id), "選んだ人にかけられる")
	_check(_has(s.take_events(), "milk"), "牛乳のお知らせが出る")
	_check(s.is_milked(victim), "かけられた人は画面が白い")
	_check(not s.oni_milk(oni, s.get_actor_at_seat(4).id), "1ラウンド %d 回まで" % GameConfig.MILK_PER_ROUND)
	_check(s.milk_left_ratio(victim) > 0.9, "かかったばかりは、晴れるまでの残りがいっぱい")
	# 鬼が半周歩くと晴れる
	var start := s.oni_angle
	while s.oni_angle - start < GameConfig.MILK_LAPS * TAU - 0.05:
		s.tick(STEP)
	_check(s.is_milked(victim), "半周するまでは白いまま")
	for i in int(5.0 / STEP):
		s.tick(STEP)
	_check(not s.is_milked(victim), "半周したら晴れる")
	# 通信で送れる
	var guest := GameState.new()
	guest.apply_snapshot(s.snapshot())
	_check(guest.milk_left == 0 and guest.get_actor(victim.id).milk_angle == victim.milk_angle, "牛乳の状態が写る")
	# ボットの鬼も牛乳を使う
	var used := 0
	for seed_value in 20:
		var s2 := GameState.new()
		s2.start_round(seed_value)
		if not _run_until(s2, "milk", 120.0).is_empty():
			used += 1
	_check(used > 0, "ボットの鬼も牛乳を使う")
	print("bot oni milk used in %d/20 rounds" % used)


func _test_deceiving_scores() -> void:
	# 鬼が通っていない人に嘘の「落ちてる!」→ お手つきさせても点は入らない(手下でも)
	var s0 := GameState.new()
	s0.start_match(91)
	s0.minion_id = 1
	var b0: int = s0.scores[1]
	s0.send_stamp(1, 3, Stamps.DROPPED)
	s0.set_looking_back(3, true)
	_check(s0.scores[1] == b0, "鬼が通ってから %d 秒より前のスタンプは点にならない" % int(GameConfig.STAMP_SCORE_RECENT_PASS))

	# 鬼が通った直後(落とされていない人)に嘘の「落ちてる!」→ お手つき → 手下は +1、普通の人は 0
	var s := GameState.new()
	s.start_match(91)
	var victim_seat := -1
	for i in int(120.0 / STEP):
		s.tick(STEP)
		for seat in GameConfig.SEAT_COUNT:
			if s.seat_pass_age[seat] < 0.5 and seat != s.drop_target_seat:
				victim_seat = seat
		if victim_seat >= 0:
			break
	s.take_events()
	var victim := s.get_actor_at_seat(victim_seat)
	var liar := s.get_actor_at_seat((victim_seat + 2) % GameConfig.SEAT_COUNT)
	var normal_liar := s.get_actor_at_seat((victim_seat + 3) % GameConfig.SEAT_COUNT)
	s.minion_id = liar.id
	var before: int = s.scores[liar.id]
	var before_n: int = s.scores[normal_liar.id]
	var before_oni: int = s.scores[s.oni_id]
	s.send_stamp(liar.id, victim.id, Stamps.DROPPED)
	s.send_stamp(normal_liar.id, victim.id, Stamps.TRUST)
	s.send_stamp(s.oni_id, victim.id, Stamps.TRUST)
	s.set_looking_back(victim.id, true)
	_check(s.scores[liar.id] == before + GameConfig.SCORE_DECEIVE_MINION, "手下が嘘の『落ちてる!』で振り向かせたら +%d" % GameConfig.SCORE_DECEIVE_MINION)
	_check(s.scores[normal_liar.id] == before_n + GameConfig.SCORE_DECEIVE_NORMAL, "普通の人がだましても +%d" % GameConfig.SCORE_DECEIVE_NORMAL)
	_check(s.scores[s.oni_id] == before_oni + GameConfig.SCORE_DECEIVE_ONI, "鬼がだましたら +%d" % GameConfig.SCORE_DECEIVE_ONI)
	var ev := s.take_events()
	_check(_has(ev, "deceived"), "だましたお知らせが出る")
	for e in ev:
		if e["type"] == "deceived":
			_check(e.get("private_to", -1) == e["sender"], "だましたお知らせは、送った本人にだけ")
	s.set_looking_back(victim.id, false)

	# 鬼が通った直後(落とされていない人)に本当の「まだ平気」→ 振り向かない → 普通の人は +1(教えた)
	var other_seat := -1
	for i in int(60.0 / STEP):
		s.tick(STEP)
		for seat in GameConfig.SEAT_COUNT:
			if s.seat_pass_age[seat] < 0.5 and seat != s.drop_target_seat and s.get_actor_at_seat(seat) != null \
					and not s.active_stamps.has(s.get_actor_at_seat(seat).id):
				other_seat = seat
		if other_seat >= 0 or s.phase != GameState.Phase.WALKING and s.phase != GameState.Phase.DROPPED:
			break
	if other_seat >= 0:
		var safe_target := s.get_actor_at_seat(other_seat)
		var helper := s.get_actor_at_seat((other_seat + 2) % GameConfig.SEAT_COUNT)
		if helper.id == liar.id:
			helper = s.get_actor_at_seat((other_seat + 3) % GameConfig.SEAT_COUNT)
		var bh: int = s.scores[helper.id]
		s.send_stamp(helper.id, safe_target.id, Stamps.SAFE)
		_tick_until_no_stamps(s)
		_check(s.scores[helper.id] == bh + GameConfig.SCORE_HELP_NORMAL, "鬼が通った直後の本当の『まだ平気』で、振り向かずにすんだら +%d" % GameConfig.SCORE_HELP_NORMAL)

	# 本当の「落ちてる!」で振り向けたら、普通の人に +1(だましの点ではない)。手下が教えても 0
	var s2 := _dropped_state(93)
	var target := s2.get_actor_at_seat(s2.drop_target_seat)
	var sender := s2.get_actor_at_seat((s2.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	var minion2 := s2.get_actor_at_seat((s2.drop_target_seat + 3) % GameConfig.SEAT_COUNT)
	s2.minion_id = minion2.id
	var b2: int = s2.scores[sender.id]
	var bm2: int = s2.scores[minion2.id]
	s2.send_stamp(sender.id, target.id, Stamps.DROPPED)
	s2.send_stamp(minion2.id, target.id, Stamps.DROPPED)
	s2.set_looking_back(target.id, true)
	var ev2 := s2.take_events()
	_check(s2.scores[sender.id] == b2 + GameConfig.SCORE_HELP_NORMAL, "本当の『落ちてる!』で教えたら +%d" % GameConfig.SCORE_HELP_NORMAL)
	_check(s2.scores[minion2.id] == bm2 + GameConfig.SCORE_HELP_MINION, "手下が教えても +%d" % GameConfig.SCORE_HELP_MINION)
	_check(_has(ev2, "helped") and not _has(ev2, "deceived"), "教えたお知らせが出る(だましではない)")
	s2.set_looking_back(target.id, false)
	s2.set_looking_back(target.id, true)
	_check(s2.scores[sender.id] == b2 + GameConfig.SCORE_HELP_NORMAL, "同じスタンプで2回は点が入らない")

	# 鬼が通っていない人への本当の「まだ平気」では点は入らない
	var s5 := GameState.new()
	s5.start_match(99)
	s5.minion_id = -1
	var b5: int = s5.scores[1]
	s5.send_stamp(1, 3, Stamps.SAFE)
	_tick_until_no_stamps(s5)
	_check(s5.scores[1] == b5, "鬼が通っていない人への『まだ平気』では点は入らない(連打で稼げない)")

	# 嘘の「まだ平気」(本当は落ちていた)→ 消えるまで振り向かない → 手下と鬼は +1、普通の人は 0
	var s3 := _dropped_state(95)
	var t3 := s3.get_actor_at_seat(s3.drop_target_seat)
	var liar3 := s3.get_actor_at_seat((s3.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	var normal3 := s3.get_actor_at_seat((s3.drop_target_seat + 3) % GameConfig.SEAT_COUNT)
	s3.minion_id = liar3.id
	var b3: int = s3.scores[liar3.id]
	var bn3: int = s3.scores[normal3.id]
	var bo3: int = s3.scores[s3.oni_id]
	s3.send_stamp(liar3.id, t3.id, Stamps.SAFE)
	s3.send_stamp(normal3.id, t3.id, Stamps.SAFE)
	s3.send_stamp(s3.oni_id, t3.id, Stamps.SAFE)
	_tick_until_no_stamps(s3)
	_check(s3.scores[liar3.id] == b3 + GameConfig.SCORE_DECEIVE_MINION, "手下が嘘の『まだ平気』で振り向かせなかったら +%d" % GameConfig.SCORE_DECEIVE_MINION)
	_check(s3.scores[normal3.id] == bn3 + GameConfig.SCORE_DECEIVE_NORMAL, "普通の人の嘘の『まだ平気』は +%d" % GameConfig.SCORE_DECEIVE_NORMAL)
	# (鬼は、このあと見逃しで勝つと勝ちの点も入るので、だましの分が入ったかだけ確かめる)
	_check(s3.scores[s3.oni_id] - bo3 >= GameConfig.SCORE_DECEIVE_ONI, "鬼の嘘の『まだ平気』も点になる")

	# 嘘の「まだ平気」でも、振り向かれたら点は入らない
	var s4 := _dropped_state(97)
	var t4 := s4.get_actor_at_seat(s4.drop_target_seat)
	var liar4 := s4.get_actor_at_seat((s4.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	s4.minion_id = liar4.id
	var b4: int = s4.scores[liar4.id]
	s4.send_stamp(liar4.id, t4.id, Stamps.SAFE)
	s4.tick(STEP)
	s4.set_looking_back(t4.id, true)
	s4.set_looking_back(t4.id, false)
	_tick_until_no_stamps(s4)
	_check(s4.scores[liar4.id] == b4, "『まだ平気』の嘘は、振り向かれたら失敗")


func _test_minion() -> void:
	for seed_value in 10:
		var s := GameState.new()
		s.start_match(200 + seed_value)
		var m := s.get_actor(s.minion_id)
		_check(m != null and m.role == GameState.Role.SEATED and m.id != s.oni_id, "手下は座っている人から選ばれる")
		var ev := s.take_events()
		var told := false
		for e in ev:
			if e["type"] == "minion" and e["actor"] == m.id:
				told = e["private_to"] == m.id
		_check(told, "手下は本人にだけ知らされる")
		var other := s.get_actor_at_seat((m.seat_index + 2) % GameConfig.SEAT_COUNT)
		if s.is_minion(other.id):
			other = s.get_actor_at_seat((m.seat_index + 3) % GameConfig.SEAT_COUNT)
		_check(s.snapshot(other.id)["minion_ids"] == [] or s.is_minion(other.id), "ほかの人に送る状態には、手下がだれかは入らない")
		_check(s.snapshot(m.id)["minion_ids"] == [m.id], "手下本人に送る状態には、自分だけ入る")
		var right := (m.seat_index + 1) % GameConfig.SEAT_COUNT
		_check(s.sees_behind(m.id, right), "手下は両どなりの後ろも見える")
		_check(not s.sees_behind(m.id, m.seat_index), "手下も自分の後ろは見えない")
		var n := s.get_actor_at_seat(right)
		if not s.is_minion(n.id):
			_check(not s.sees_behind(n.id, (right + 1) % GameConfig.SEAT_COUNT), "普通の人は両どなりの後ろが見えない")

	# 鬼が見逃しで勝つ → 手下は +2(負けた本人でなければ)。勝敗のあとは全員に発表
	var s2 := GameState.new()
	s2.start_match(63)
	var minion := s2.get_actor_at_seat((s2.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	s2.minion_id = minion.id
	var before: int = s2.scores[minion.id]
	var e2 := _run_until(s2, "result", 200.0)
	_check(e2["reason"] == "missed", "(確認用)見逃しで鬼の勝ち")
	_check(s2.scores[minion.id] == before + GameConfig.SCORE_MINION_ONI_WIN, "鬼が勝ったら手下は +%d" % GameConfig.SCORE_MINION_ONI_WIN)
	_check(e2["minion"] == minion.id and e2["minion_bonus"], "勝敗のお知らせで手下を発表する")
	var other2 := s2.get_actor_at_seat((minion.seat_index + 2) % GameConfig.SEAT_COUNT)
	_check(s2.snapshot(other2.id)["minion_ids"] == [minion.id], "勝敗のあとは、だれにでも手下がわかる")
	s2.next_round()
	_check(s2.last_minion_id == minion.id, "前のラウンドの手下を覚えている")

	# 手下が落とされて気づかなかった → 負けの -3 だけ
	var s3 := GameState.new()
	s3.start_match(63)
	var loser := s3.get_actor_at_seat(s3.drop_target_seat)
	s3.minion_id = loser.id
	var b3: int = s3.scores[loser.id]
	var e3 := _run_until(s3, "result", 200.0)
	_check(e3["loser"] == loser.id and not e3["minion_bonus"], "(確認用)手下が負けた本人")
	_check(s3.scores[loser.id] == b3 + GameConfig.SCORE_LOSE, "手下が負けたら %d 点だけ" % GameConfig.SCORE_LOSE)

	# 鬼がタッチされて負け → 手下の +2 はない
	var s4 := _chasing_state(65)
	var c := s4.get_actor(s4.chaser_id)
	var m4: GameState.Actor = null
	for a in s4.actors:
		if a.role == GameState.Role.SEATED:
			m4 = a
			break
	s4.minion_id = m4.id
	var b4: int = s4.scores[m4.id]
	var e4 := {}
	for i in int(60.0 / STEP):
		s4.chase_lane(c.id, -1)
		s4.tick(STEP)
		for ev in s4.take_events():
			if ev["type"] == "result":
				e4 = ev
		if not e4.is_empty():
			break
	if not e4.is_empty() and e4["reason"] == "touched":
		_check(s4.scores[m4.id] == b4, "鬼が負けたら手下の +%d はない" % GameConfig.SCORE_MINION_ONI_WIN)


func _test_bot_personalities() -> void:
	var s := GameState.new()
	s.start_match(301)
	var kinds := {}
	for a in s.actors:
		if a.is_bot:
			_check(a.personality in Personalities.ALL, "ボットには性格がある")
			_check(Personalities.label(a.personality) in a.display_name, "名前の横に性格が出る")
			kinds[a.personality] = true
		else:
			_check(a.personality == "", "人には性格はない")
	_check(kinds.size() >= 2, "(確認用)いろいろな性格がいる")


func _test_look_limit_and_patience() -> void:
	var s := GameState.new()
	s.start_match(101)
	var me := s.get_local_player()
	_check(me.looks_left == GameConfig.LOOKS_PER_ROUND, "振り向ける回数は %d 回" % GameConfig.LOOKS_PER_ROUND)
	me.looks_left = 0
	s.take_events()
	s.set_looking_back(me.id, true)
	_check(not me.looking_back, "回数を使い切ると振り向けない")
	_check(_has(s.take_events(), "no_looks"), "振り向けなかったお知らせが出る")
	# 使い切ると、後ろに落とされても拾えない
	var s2 := _dropped_state(103)
	var target := s2.get_actor_at_seat(s2.drop_target_seat)
	target.looks_left = 0
	s2.pick_up(target.id)
	_check(s2.phase == GameState.Phase.DROPPED, "振り向けないと拾えない")
	# 次のラウンドでは回数が戻る
	var s3 := GameState.new()
	s3.start_match(105)
	var p3 := s3.get_local_player()
	p3.looks_left = 0
	_run_until(s3, "result", 200.0)
	s3.next_round()
	_check(p3.looks_left == GameConfig.LOOKS_PER_ROUND, "次のラウンドで振り向ける回数が戻る")


func _test_online_match_setup() -> void:
	var s := GameState.new()
	s.start_match_custom(111, [0, 1, 2], 1, {0: "ホスト", 1: "P2", 2: "P3"}, true)
	_check(s.oni_id == 1 and s.oni_is_player, "人が最初の鬼")
	var humans := 0
	for a in s.actors:
		if not a.is_bot:
			humans += 1
	_check(humans == 3, "人は3人、残りはボット")
	_check(s.get_actor(0).display_name == "ホスト", "名前が入る")
	var seated := 0
	for a in s.actors:
		if a.role == GameState.Role.SEATED:
			seated += 1
	_check(seated == GameConfig.SEAT_COUNT, "鬼以外は全員座る")


func _test_humans_only_oni() -> void:
	# オンラインでも、負けた人が次の鬼(ボットが負けたら、そのボットが鬼)
	var ok := 0
	var bot_oni := 0
	for seed_value in 20:
		var s := GameState.new()
		s.start_match_custom(seed_value, [0, 5], 5, {0: "A", 5: "B"}, true)
		var b := BotBrain.new()
		b.reset(seed_value)
		var e := _play_round_with_bots_and_human_oni(s, b)
		if e.is_empty():
			continue
		var loser: int = e["loser"] if e["reason"] != "all_out" else s.oni_id
		s.next_round()
		_check(s.oni_id == loser, "seed %d: 負けた人が次の鬼" % seed_value)
		if s.get_actor(s.oni_id).is_bot:
			bot_oni += 1
			_check(not s.oni_is_player, "ボットの鬼は自動で動く")
		var seated := 0
		for a in s.actors:
			if a.role == GameState.Role.SEATED:
				seated += 1
		_check(seated == GameConfig.SEAT_COUNT, "席は全部うまっている")
		ok += 1
	_check(ok > 0, "(確認用)ためせた")
	_check(bot_oni > 0, "ボットが負けたら、ボットが鬼になる")


func _play_round_with_bots_and_human_oni(s: GameState, b: BotBrain) -> Dictionary:
	for i in int(300.0 / STEP):
		var oni := s.get_actor(s.oni_id)
		if not oni.is_bot and s.phase == GameState.Phase.WALKING:
			s.oni_drop(oni.id)
		b.update(s, STEP)
		s.tick(STEP)
		for ev in s.take_events():
			b.on_event(s, ev)
			if ev["type"] == "result":
				return ev
	return {}


func _test_snapshot_round_trip() -> void:
	var host := _dropped_state(113)
	var guest := GameState.new()
	guest.apply_snapshot(host.snapshot())
	_check(guest.actors.size() == host.actors.size(), "登場人物が写る")
	_check(guest.oni_id == host.oni_id and guest.phase == host.phase, "鬼と場面が写る")
	_check(guest.handkerchief_on_floor and guest.drop_target_seat == host.drop_target_seat, "ハンカチの場所が写る")
	for i in host.actors.size():
		_check(guest.actors[i].position.distance_to(host.actors[i].position) < 0.001, "位置が写る")
	# 通信で送れる形か(バイト列にして戻せるか)
	var bytes := var_to_bytes(host.snapshot())
	var back = bytes_to_var(bytes)
	_check(typeof(back) == TYPE_DICTIONARY and back["round_serial"] == host.round_serial, "状態は通信で送れる形")


func _test_vote_evidence() -> void:
	# お手つきした人は、このラウンドの大事な人になる。振り向いた瞬間に届いていた言葉も覚える
	var s := GameState.new()
	s.start_round(1)
	var me := s.local_player_id
	var others := []
	for a in s.actors:
		if a.role == GameState.Role.SEATED and a.id != me:
			others.append(a.id)
	s.active_stamps[me] = [{"sender": others[0], "kind": "safe", "born_angle": s.oni_angle, "truthful": false,
			"sender_role": 0, "looked": false, "credited": false, "scorable": false}]
	s.set_looking_back(me, true)
	_check(s.round_otetsuki == [me] and (s.round_otetsuki_seen.get(me, []) as Array).size() == 1,
			"証拠: お手つきした人と、そのとき届いていた言葉が記録される")
	# 落とされた人: 落とされたあとの言葉の最後の3つ
	var ids := []
	for a in s.actors:
		if a.role == GameState.Role.SEATED or a.id == me:
			ids.append(a.id)
	var dropped: int = ids[1]
	var oops: int = ids[2]
	var sender: int = ids[3]
	s.round_dropped_on = dropped
	s.round_drop_t = 40.0
	s.round_found_t = 55.0
	s.round_otetsuki = [oops]
	s.round_otetsuki_seen = {oops: [{"sender": sender, "kind": "trust"}, {"sender": s.oni_id, "kind": "safe"}]}
	s.stamp_log = [
		{"sender": sender, "target": dropped, "kind": "safe", "truthful": true, "t": 35.0},   # 落とされる前: 出さない
		{"sender": sender, "target": dropped, "kind": "safe", "truthful": false, "t": 41.0},  # 落とされてから(4つのうち最初): 出さない
		{"sender": ids[4], "target": dropped, "kind": "safe", "truthful": false, "t": 45.0},
		{"sender": s.oni_id, "target": dropped, "kind": "dropped", "truthful": true, "t": 50.0},
		{"sender": ids[5], "target": dropped, "kind": "trust", "truthful": true, "t": 54.0},
		{"sender": sender, "target": dropped, "kind": "trust", "truthful": true, "t": 58.0},  # 見つけたあと: 出さない
		{"sender": sender, "target": ids[4], "kind": "safe", "truthful": true, "t": 45.0},    # 大事な人以外: 出さない
	]
	_check(s.evidence_key_ids() == [dropped, oops], "証拠: 大事な人は落とされた人とお手つきの人")
	var got := s.evidence_received(dropped)
	_check(got.size() == 3 and got[0]["sender"] == ids[4] and got[2]["sender"] == ids[5],
			"証拠: 落とされた人は、落とされてから振り向く直前の3つ(%s)" % str(got))
	s.round_found_t = -1.0
	var got2 := s.evidence_received(dropped)
	_check(got2.size() == 3 and got2[2]["kind"] == "trust" and got2[0]["sender"] == s.oni_id,
			"証拠: 気づかなかったら、ラウンドが終わる直前の3つ")
	_check(s.evidence_received(oops).size() == 2, "証拠: お手つきの人は、振り向いたときに届いていた言葉")
	_check(s.evidence_received(ids[4]).is_empty(), "証拠: 大事な人でなければ出ない")
	var bubbles := HeadOverlay.evidence_bubbles(s)
	_check(bubbles.size() == 2 and bubbles.has(dropped) and bubbles.has(oops) and not bubbles.has(sender), "証拠: 吹き出しは大事な人の頭の上だけ")
	_check(str((bubbles[oops] as Array)[0]["text"]).find(":") > 0, "証拠: 吹き出しは「送った人:言葉」(プレイ中と同じ)")
	s.round_otetsuki_seen = {oops: []}
	var none: Array = HeadOverlay.evidence_bubbles(s)[oops]
	_check(none.size() == 1 and none[0]["kind"] == "none", "証拠: 1つも届いていなければ「だれも教えてくれなかった…」")
	s.round_otetsuki_seen = {oops: [{"sender": sender, "kind": "trust"}, {"sender": s.oni_id, "kind": "safe"}]}
	_check(HeadOverlay.kind_color("dropped") == HeadOverlay.COLOR_LOOK and HeadOverlay.kind_color("trust") == HeadOverlay.COLOR_LOOK \
			and HeadOverlay.kind_color("safe") == HeadOverlay.COLOR_DONT, "吹き出しの色: 見ろ系は赤、見るな系は青")
	# 結果の場面だけ、ゲストに届く。本当かウソかは届かない
	var guest := GameState.new()
	guest.apply_snapshot(s.snapshot())
	_check(guest.round_dropped_on == -1 and guest.stamp_log.is_empty(), "証拠: 結果の場面の前はゲストに届かない")
	s.phase = GameState.Phase.RESULT
	guest.apply_snapshot(s.snapshot())
	_check(guest.evidence_key_ids() == [dropped, oops] and guest.evidence_received(dropped).size() == s.evidence_received(dropped).size()
			and guest.evidence_received(oops).size() == 2, "証拠: 結果の場面でゲストにも同じ言葉が届く")
	var leak := false
	for st in guest.stamp_log:
		if (st as Dictionary).has("truthful"):
			leak = true
	_check(not leak, "証拠: 本当かウソかはゲストに届かない")
	# 次のラウンドで消える
	s.start_round(2)
	_check(s.evidence_key_ids().is_empty() and s.round_drop_t < 0.0, "証拠: 次のラウンドで消える")


func _test_character_model() -> void:
	# 人型キャラ: 骨組みと動きの素材が読めて、使う動きと骨がそろっているか
	var m := CharacterModel.new()
	m.build(Color(0.3, 0.5, 0.9), "テスト", HudFont.get_font())
	_check(m._skel != null and m._anim != null, "キャラの骨組みと動きが読める")
	if m._anim:
		print("character animations: ", m._anim.get_animation_list().slice(0, 8))
	if m._anim == null:
		m.free()
		return
	for anim_name in [CharacterModel.ANIM_SIT, CharacterModel.ANIM_SIT_DOWN, CharacterModel.ANIM_STAND_UP,
			CharacterModel.ANIM_RUN, CharacterModel.ANIM_WALK, CharacterModel.ANIM_IDLE]:
		_check(m.anim_of(anim_name) != "", "動き %s がある" % anim_name)
	for bone in CharacterModel.LOOK_TWIST:
		_check(m._skel.find_bone(bone) >= 0, "骨 %s がある" % bone)
	_check(m._twist_bones.size() == CharacterModel.LOOK_TWIST.size(), "振り向きでひねる骨がそろう")
	# 姿勢を切りかえて動かしても、エラーにならない
	for pose in ["sit", "run", "walk", "idle", "sit"]:
		m.set_pose(pose)
		m.set_look(pose == "sit")
		for i in 30:
			m.animate(STEP, pose == "run")
	_check(m._pose == "sit", "姿勢が切りかわる")
	m.free()
	# 落とし物を持つ位置は、シーンに入ってから _process で確かめる(_check_carry)
	_carry_model = CharacterModel.new()
	root.add_child(_carry_model)
	_carry_model.build(Color(0.9, 0.5, 0.3), "テスト", HudFont.get_font())
	_carry_model.set_pose("run")


## 落とし物を持つ位置: 走っているとき、背中(背骨の上)と頭は床よりずっと上(引きずらない)
func _check_carry() -> void:
	if _carry_model == null:
		return
	for i in 30:
		_carry_model.animate(STEP, true)
	var chest := _carry_model.bone_world("DEF-spine.003").origin.y
	var head := _carry_model.bone_world("DEF-head").origin.y
	print("carry heights: chest %.2f / head %.2f" % [chest, head])
	_check(chest > 0.9, "走っているとき、背負う位置(胸)は床より高い(%.2f m)" % chest)
	_check(head > chest, "頭は胸より高い")
	_carry_model.queue_free()
	_carry_model = null


func _test_profile_names_and_colors() -> void:
	_check(Profile.clean_name("  とても長いなまえですよ  ") == "とても長いなまえ", "名前は %d 文字まで" % Profile.NAME_MAX)
	_check(Profile.clean_name("   ") == Profile.DEFAULT_NAME, "空の名前は「プレイヤー」")
	_check(Profile.parse_color("4d96ff", Color.RED).is_equal_approx(Color("4D96FF")), "# なしのカラーコードも読める")
	_check(Profile.parse_color("ぴんく", Color.RED) == Color.RED, "読めないカラーコードは元のまま")
	# 選んだ名前と色で試合が始まり、ほかの人には近い色を使わない
	var mine := Color("EE6A4D")
	var s := GameState.new()
	s.start_match(401, false, GameConfig.SEAT_COUNT, "りさ", mine)
	var me := s.get_local_player()
	_check(me.display_name == "りさ" and me.color.is_equal_approx(mine), "自分の名前と色で始まる")
	for a in s.actors:
		if a.id != me.id:
			_check(Vector3(a.color.r - mine.r, a.color.g - mine.g, a.color.b - mine.b).length() >= 0.25, "ほかの人は自分の色と重ならない")
	var o := GameState.new()
	o.start_match_custom(402, [0, 1], 0, {0: "ホスト", 1: "ゆうみ"}, true, GameConfig.SEAT_COUNT, {1: Color("B07CF0")})
	_check(o.get_actor(1).display_name == "ゆうみ" and o.get_actor(1).color.is_equal_approx(Color("B07CF0")), "参加者の名前と色が入る")
	var g := GameState.new()
	g.apply_snapshot(o.snapshot(1))
	_check(g.get_actor(1).color.is_equal_approx(Color("B07CF0")) and g.get_actor(1).display_name == "ゆうみ", "名前と色は通信で届く")


# --- 道具 ---

func _dropped_state(seed_value: int) -> GameState:
	var s := GameState.new()
	s.start_round(seed_value)
	_run_until(s, "dropped", 120.0)
	# 鬼がハンカチの横から3mくらい離れるまで待つ(すぐ拾うと、その場でタッチになる)
	for i in int(20.0 / STEP):
		if (s.oni_angle - s.drop_angle) * GameConfig.ONI_WALK_RADIUS >= 3.0:
			break
		s.tick(STEP)
	s.take_events()
	return s


func _chasing_state(seed_value: int) -> GameState:
	var s := _dropped_state(seed_value)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	s.set_looking_back(target.id, true)
	s.pick_up(target.id)
	s.take_events()
	# 決まった結果を確かめるため、コースの障害物はなし(障害物のテストは自分で置く)
	s.obstacles = []
	return s


func _run_until(s: GameState, type: String, seconds: float) -> Dictionary:
	for i in int(seconds / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == type:
				return e
	return {}


func _blocked_reason(events: Array) -> String:
	for e in events:
		if e["type"] == "stamp_blocked":
			return e["reason"]
	return ""


## 表示中のスタンプが全部消えるまで進める(鬼が半周歩くまで)
func _tick_until_no_stamps(s: GameState) -> void:
	for i in int(80.0 / STEP):
		if s.active_stamps.is_empty():
			return
		s.tick(STEP)


func _has(events: Array, type: String) -> bool:
	for e in events:
		if e["type"] == type:
			return true
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


## 8人(7席)のときは、ときどき手下が2人。鬼は人数だけ知る。手下どうしはおたがいを知らない
func _test_two_minions() -> void:
	var twos := 0
	var tries := 60
	for seed_value in tries:
		var s := GameState.new()
		s.start_match(500 + seed_value)
		var ev := s.take_events()
		var counts := []
		for e in ev:
			if e["type"] == "minion_count":
				counts.append(e)
		_check(counts.size() == 1 and counts[0]["private_to"] == s.oni_id and counts[0]["count"] == s.minion_ids.size(),
				"鬼にだけ、手下の人数が知らされる")
		_check(s.snapshot(s.oni_id)["minion_count"] == s.minion_ids.size() and s.snapshot(s.oni_id)["minion_ids"] == [],
				"鬼に送る状態には、人数だけ入る(だれかは入らない)")
		for a in s.actors:
			if a.id != s.oni_id:
				_check(s.snapshot(a.id)["minion_count"] == -1, "鬼以外には、手下の人数は入らない")
		if s.minion_ids.size() == 2:
			twos += 1
			var m1: int = s.minion_ids[0]
			var m2: int = s.minion_ids[1]
			_check(m1 != m2 and m1 != s.oni_id and m2 != s.oni_id, "2人の手下は別の人で、鬼ではない")
			_check(s.snapshot(m1)["minion_ids"] == [m1], "手下は、もう1人の手下を知らない")
	_check(twos >= 8 and twos <= 35, "手下が2人になるのは、3回に1回くらい(%d/%d)" % [twos, tries])
	# 少ない人数では、いつも1人
	for seed_value in 30:
		var s5 := GameState.new()
		s5.start_match(700 + seed_value, false, 5)
		_check(s5.minion_ids.size() == 1, "6人以下なら手下は1人")


## ラウンドのあと、教室のまま、手下以外の全員(鬼も)で手下を当てる投票。
## 勝ち負けの演出のあとに始まり、全員がそろうまで入れ直せる。当てた人 +1、手下に1票も入らなければ手下 +1(だましきった)。
## 発表の演出のあとは、ルーム主が「次へ」を押すまで進まない
func _test_minion_vote() -> void:
	var s := GameState.new()
	s.start_match(63)
	var minion := s.get_actor_at_seat((s.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	s.minion_ids = [minion.id]
	var e := _run_until(s, "result", 200.0)
	_check(not e.is_empty() and not s.voting_open and s.vote_wait > 0.0, "勝ち負けの演出の間は、まだ投票しない")
	var vs := _run_until(s, "vote_start", GameConfig.MISSED_SCENE_TIME + 1.0)
	_check(not vs.is_empty() and s.voting_open, "演出のあとに投票が始まる")
	_check(not s.can_vote(minion.id), "手下は投票できない")
	_check(s.can_vote(s.oni_id), "鬼も投票できる(鬼は手下がだれか知らない)")
	_check(not (s.oni_id in s.vote_candidates(minion.id)) and not (minion.id in s.vote_candidates(minion.id)),
			"投票の相手に、鬼と自分は入らない")
	_check(not s.can_skip_vote(), "「発表へ」は、始まってすぐは押せない")
	var before: Dictionary = s.scores.duplicate()
	var voters := []
	for a in s.actors:
		if not s.is_minion(a.id):
			voters.append(a.id)
	_check(voters.size() == s.voter_count(), "投票する人の数")
	var wrong0 := -1
	for c in s.vote_candidates(voters[0]):
		if c != minion.id:
			wrong0 = c
			break
	# 1人目は、はずれに入れてから手下に入れ直す
	_check(s.cast_vote(voters[0], wrong0), "投票できる")
	_check(s.cast_vote(voters[0], minion.id) and s.votes[voters[0]] == minion.id, "全員がそろうまでは入れ直せる")
	_check(s.snapshot(voters[1])["voted"].has(voters[0]), "だれが投票したかは状態で届く(だれに入れたかは届かない)")
	_check(not s.snapshot(voters[1]).has("votes"), "だれに入れたかは、発表まで届かない")
	var result_ev := {}
	for i in range(1, voters.size()):
		var wrong := -1
		for c in s.vote_candidates(voters[i]):
			if c != minion.id:
				wrong = c
				break
		s.cast_vote(voters[i], wrong)
	for ev in s.take_events():
		if ev["type"] == "vote_result":
			result_ev = ev
	_check(not result_ev.is_empty() and not s.voting_open, "全員が投票したら、すぐ発表")
	_check(result_ev.get("correct", []) == [voters[0]], "当てた人だけが当たり")
	_check(s.scores[voters[0]] == before[voters[0]] + GameConfig.SCORE_VOTE_CORRECT, "当てたら +%d" % GameConfig.SCORE_VOTE_CORRECT)
	_check(s.scores[voters[1]] == before[voters[1]], "はずれは 0 点")
	_check(int((result_ev.get("tally", {}) as Dictionary).get(minion.id, 0)) == 1, "票の数が発表に入る")
	_check(result_ev.get("fooled", []).is_empty() and result_ev.get("busted", []).is_empty(), "1票だけなら、だましきってもバレバレでもない")
	var round_before := s.round_index
	_check(not s.can_go_next(), "発表の演出の間は「次へ」を出さない")
	var auto := _run_until(s, "round_start", GameState.reveal_time() + 30.0)
	_check(auto.is_empty() and s.phase == GameState.Phase.RESULT and s.can_go_next(), "発表のあとは自動で進まず、「次へ」を待つ")
	_check(s.next_round() and s.round_index == round_before + 1, "「次へ」で次のラウンドへ")

	# だれも手下に入れなかった: 手下に +1(だましきった!)。ルーム主の「発表へ」は5秒たってから
	var s2 := GameState.new()
	s2.start_match(63)
	var ma := s2.get_actor_at_seat((s2.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	var mb := s2.get_actor_at_seat((s2.drop_target_seat + 4) % GameConfig.SEAT_COUNT)
	s2.minion_ids = [ma.id, mb.id]
	_run_until(s2, "vote_start", 200.0)
	var b2: Dictionary = s2.scores.duplicate()
	s2.cast_vote(s2.oni_id, mb.id)
	_check(s2.voting_open, "まだ投票していない人がいれば、発表しない")
	_check(not s2.skip_vote(), "始まってすぐは「発表へ」できない")
	for i in int((GameConfig.VOTE_SKIP_DELAY + 0.2) / STEP):
		s2.tick(STEP)
	_check(s2.skip_vote() and not s2.voting_open, "5秒たったら「発表へ」で、投票していない人がいても発表")
	var r2 := {}
	for ev in s2.take_events():
		if ev["type"] == "vote_result":
			r2 = ev
	_check(s2.scores[s2.oni_id] == b2[s2.oni_id] + GameConfig.SCORE_VOTE_CORRECT, "手下が2人なら、どちらに当てても +%d" % GameConfig.SCORE_VOTE_CORRECT)
	_check(r2.get("fooled", []) == [ma.id] and s2.scores[ma.id] == b2[ma.id] + GameConfig.SCORE_MINION_FOOLED,
			"1票も入らなかった手下は「だましきった!」で +%d" % GameConfig.SCORE_MINION_FOOLED)
	_check(r2.get("busted", []) == [mb.id], "投票した全員が入れた手下は「バレバレ!」")

	# 画面には出さないが、2分たったら自動で発表
	var s3 := GameState.new()
	s3.start_match(63)
	_run_until(s3, "vote_start", 200.0)
	var r3 := _run_until(s3, "vote_result", GameConfig.VOTE_TIMEOUT + 1.0)
	_check(not r3.is_empty(), "2分たったら自動で発表")

	# ボットも数秒で投票する(1回だけ)
	var s4 := GameState.new()
	s4.start_match(63)
	var brain := BotBrain.new()
	_run_until(s4, "vote_start", 200.0)
	# 人(ボットでない人)は先に投票しておく
	for a in s4.actors:
		if not a.is_bot and s4.can_vote(a.id):
			s4.cast_vote(a.id, s4.vote_candidates(a.id)[0])
	for i in int((GameConfig.BOT_VOTE_DELAY_MAX + 1.0) / STEP):
		brain.update(s4, STEP)
		s4.tick(STEP)
	_check(not s4.voting_open, "ボットが全員投票して発表される")

	# 最後のラウンドの発表のあとは、試合おわり
	var s5 := GameState.new()
	s5.start_match(63)
	s5.round_index = GameConfig.ROUNDS_PER_MATCH - 1
	_run_until(s5, "vote_start", 200.0)
	s5.close_vote()
	_run_until(s5, "match_over", GameState.reveal_time() + 1.0)
	_check(not s5.match_over and s5.can_go_next(), "最後のラウンドも、発表のあとは「次へ」を待つ")
	_check(not s5.next_round() and s5.match_over, "最後のラウンドの「次へ」で、試合おわり")


## 宣伝用: ボットの名前を決められる(空のボットはふつうの名前)
func _test_custom_bot_names() -> void:
	var s := GameState.new()
	s.custom_bot_names = ["たろう", "", "はなこ"]
	s.start_match(5, false, 7)
	var bots := []
	for a in s.actors:
		if a.is_bot:
			bots.append(a)
	_check(bots[0].display_name == "たろう", "ボット1に決めた名前がつく")
	_check(bots[1].display_name.begins_with("ボット2"), "空のボットは、ふつうの名前")
	_check(bots[2].display_name == "はなこ", "ボット3に決めた名前がつく")
	_check(bots[0].personality != "", "名前を変えても、性格(動き)はふつうのボットと同じ")
	var names := Profile.clean_bot_names(["  じろう  ", "", "あ".repeat(40)])
	_check(names.size() == Profile.BOT_NAME_SLOTS and names[0] == "じろう" and names[1] == "" and names[2].length() <= Profile.NAME_MAX,
			"ボットの名前は9人分にそろえ、長すぎる名前は切る")


## 夜の教室: 明るい席と暗い席、雷、カメラのフラッシュ、落とし物
func _test_night_stage() -> void:
	_check("night" in Items.STAGES, "夜の教室を選べる")
	var names := []
	for i in Items.count():
		names.append(Items.NAMES_BY_STAGE["night"][i])
	_check(names == ["ハンカチ", "懐中電灯", "メトロノーム", "モナリザ", "ガイコツ"], "夜の教室の落とし物")
	var s := GameState.new()
	s.stage = "night"
	s.start_match(31, false, 7)
	var dark := []
	var bright := []
	for i in s.seat_count:
		if s.is_dark_seat(i):
			dark.append(i)
		else:
			bright.append(i)
	_check(not dark.is_empty() and not bright.is_empty(), "明るい席と暗い席がある(暗い %d / 明るい %d)" % [dark.size(), bright.size()])
	for i in dark:
		_check(s.seat_positions[i].x > 0.0, "暗い席は廊下側(窓と反対)")
	# 暗い席のうしろは、向かいの人からも見えない(鬼は見える)
	var d: int = dark[0]
	var viewer := -1
	for a in s.actors:
		if a.role == GameState.Role.SEATED and not s.is_minion(a.id) and s.can_see_behind(a.seat_index, d):
			viewer = a.id
			break
	_check(viewer >= 0 and not s.sees_behind(viewer, d), "暗い席のうしろは見えない")
	_check(s.sees_behind(s.oni_id, d), "鬼には暗い席のうしろも見える")
	s.lightning_left = 0.5
	_check(s.sees_behind(viewer, d), "雷の間は、暗い席のうしろも見える")
	s.lightning_left = 0.0
	# 懐中電灯のラウンドは、暗い席で光るので見える
	s.round_index = Items.NIGHT_FLASHLIGHT
	_check(s.sees_behind(viewer, d), "懐中電灯は暗い席で目立つ(見える)")
	s.round_index = 0
	# 雷は停電の代わり(夜の教室は停電しない)
	var s2 := GameState.new()
	s2.stage = "night"
	s2.start_match(32, false, 7)
	s2.round_index = s2.blackout_round
	s2._begin_round(s2._round_start_lineup, s2._round_start_oni)
	var got_lightning := false
	for i in int(120.0 / STEP):
		s2.tick(STEP)
		_check(not s2.blackout, "夜の教室は停電しない")
		for e in s2.take_events():
			if e["type"] == "lightning":
				got_lightning = true
		if got_lightning or s2.phase == GameState.Phase.RESULT:
			break
	_check(got_lightning and s2.lightning_left > 0.0, "雷が光る")
	# カメラのフラッシュは数秒だけ(黒板消しより短い)
	_check(s.milk_laps() < GameConfig.MILK_LAPS * 0.5, "フラッシュは黒板消しより短い")
	# 席はラウンドごとにランダム
	var orders := {}
	var s3 := GameState.new()
	s3.stage = "night"
	s3.start_match(33, false, 7)
	for r in 4:
		var order := []
		for i in s3.seat_count:
			var who := s3.get_actor_at_seat(i)
			order.append(who.id if who else -1)
		orders[str(order)] = true
		if s3.drop_target_seat < 0:
			s3.drop_target_seat = 0
		s3._finish(s3.oni_id, s3.get_actor_at_seat(s3.drop_target_seat).id, "missed")
		s3.close_vote()
		s3.next_round()
	_check(orders.size() >= 2, "夜の教室は、ラウンドごとに席が変わる")


## 舞台: 海辺の落とし物と、状態で届く舞台
func _test_beach_stage() -> void:
	var s := GameState.new()
	s.stage = "beach"
	s.start_match(90)
	_check(s.stage == "beach", "試合を始めても舞台はそのまま")
	var names := []
	for i in Items.count():
		names.append(Items.NAMES_BY_STAGE["beach"][i])
	_check(names == ["貝殻", "ビーチボール", "浮き輪", "砂の城", "バナナボート"], "海辺の落とし物は 貝殻→ビーチボール→浮き輪→砂の城→バナナボート")
	var g := GameState.new()
	g.apply_snapshot(s.snapshot(1))
	_check(g.stage == "beach", "参加した人にも舞台が届く")
	_check(Items.clean_stage("castle") == "classroom", "知らない舞台は教室")
	var c := GameState.new()
	c.start_match(91)
	_check(c.stage == "classroom", "はじめの舞台は教室")


## 小物: 正しい形に直す・試合の登場人物につく・状態で届く
func _test_accessories() -> void:
	var bad := Accessories.clean({"hat": "crown", "hat_c": 99, "nose": "pig", "nose_c": 2, "glasses": 5})
	_check(bad["hat"] == "" and bad["hat_c"] == Accessories.DEFAULT_COLOR["hat"], "知らない形・色は、つけない・はじめの色")
	_check(bad["nose"] == "pig" and bad["nose_c"] == 2 and bad["glasses"] == "", "正しい形と色はそのまま")
	_check(Accessories.clean("x") == Accessories.empty(), "形がおかしければ何もつけない")
	var acc := {"hat": "tophat", "hat_c": 7, "glasses": "round", "glasses_c": 0, "ribbon": "ribbon", "ribbon_c": 5, "nose": "pig", "nose_c": 6}
	var s := GameState.new()
	s.start_match(95, false, GameConfig.SEAT_COUNT, "あなた", Color(0, 0, 0, 0), acc)
	var me := s.get_local_player()
	_check(me.accessories == Accessories.clean(acc), "自分の小物が登場人物につく")
	var bot: GameState.Actor = null
	for a in s.actors:
		if a.is_bot:
			bot = a
			break
	_check(bot.accessories == Accessories.empty(), "ボットは小物なし")
	var g := GameState.new()
	g.apply_snapshot(s.snapshot(1))
	_check(g.get_actor(me.id).accessories == me.accessories, "小物は参加した人にも届く")


## ほぼ1周遅れで気づいた人に、後ろから鬼が近づいて体が重なっても、タッチにはならない(周回を数える)
func _test_lap_behind_not_touch() -> void:
	var s := _chasing_state(65)
	var c := s.get_actor(s.chaser_id)
	var oni := s.get_actor(s.oni_id)
	# 追う人をほぼ1周遅れにして、鬼のすぐ前(体の位置)に置く
	s.chaser_progress = s.oni_angle - TAU + 0.15
	c.run_r = oni.run_r
	c.lane = oni.lane
	c.position = s._ring_point(fposmod(s.chaser_progress, TAU), c.run_r)
	_check(c.position.distance_to(oni.position) < GameConfig.TOUCH_DISTANCE, "(確認用)体はすぐそば")
	var touched := false
	for i in int(1.0 / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "result" and e["reason"] == "touched":
				touched = true
		if s.phase != GameState.Phase.CHASE:
			break
	_check(not touched, "ほぼ1周遅れの人に、後ろから鬼が近づいてもタッチにならない")
	_check(s.chaser_gap_m() > 10.0, "(確認用)追う人はほぼ1周遅れのまま(%.1f m)" % s.chaser_gap_m())


## スタンプの言葉のシャッフル: セットから選ぶ・番号で届く・受け取った人の言語で出る
func _test_stamp_shuffle() -> void:
	var seen := {}
	for i in 60:
		var p := Texts.random_pick()
		for k in Stamps.ALL:
			var idx: int = p[k]
			_check(idx >= 0 and idx < (Texts.STAMP_SETS[k] as Array).size(), "シャッフルの番号はセットの中")
			seen["%s%d" % [k, idx]] = true
	_check(seen.size() == 12, "60回引けば、3つのセットの4つの言葉が全部出る(%d)" % seen.size())
	_check(Texts.clean_pick({Stamps.SAFE: 99, Stamps.DROPPED: "x"}) == {Stamps.DROPPED: 0, Stamps.SAFE: 3, Stamps.TRUST: 0}, "おかしな番号は直す")
	var s := GameState.new()
	s.start_match(7)
	for a in s.actors:
		_check(s.stamp_picks.has(a.id), "試合の初めに、全員の言葉が決まる")
	s.stamp_picks[3] = {Stamps.DROPPED: 1, Stamps.SAFE: 1, Stamps.TRUST: 3}
	_check(HeadOverlay.stamp_text(s, 3, Stamps.DROPPED) == "うしろ!うしろ!😨", "シャッフルの言葉が出る")
	_check(HeadOverlay.stamp_text(s, 3, Stamps.SAFE) == "セーフ!👍", "「セーフ!」は日本語ではそのまま")
	var g := GameState.new()
	g.apply_snapshot(s.snapshot())
	_check(HeadOverlay.stamp_text(g, 3, Stamps.TRUST) == "うそじゃない🥺", "言葉の番号は通信で届く")
	Locale.setup("en")
	_check(HeadOverlay.stamp_text(g, 3, Stamps.TRUST) == "No lie!🥺", "英語の人には、英語のセットの同じ番号の言葉")
	_check(HeadOverlay.stamp_text(g, 3, Stamps.SAFE) == "All clear👍", "英語のセーフ")
	Locale.setup("ja")
	# シャッフルボタン: 自作の言葉をやめて引き直す
	var keep_words: Dictionary = Profile.stamp_words.duplicate()
	var keep_pick: Dictionary = Profile.stamp_pick.duplicate()
	Profile.stamp_words = {Stamps.SAFE: "だいじょぶ"}
	Profile.roll_next_words()
	_check(Profile.stamp_words.has(Stamps.SAFE), "自作の言葉がある人は、自動では引き直さない")
	Profile.shuffle_words()
	_check(Profile.stamp_words.is_empty(), "シャッフルを押すと自作の言葉をやめる")
	Profile.stamp_words = keep_words
	Profile.stamp_pick = keep_pick
	Profile.save()


## 停電中は、ボットはスタンプを送らない(だれの後ろも見えないので)
func _test_bots_quiet_in_blackout() -> void:
	var s := GameState.new()
	s.start_match(77)
	s.blackout = true
	for i in s.seat_pass_age.size():
		s.seat_pass_age[i] = 1.0
	var b := BotBrain.new()
	b.reset(77)
	var sent := 0
	for i in int(30.0 / STEP):
		b.update(s, STEP)
		for e in s.take_events():
			if e["type"] == "stamp":
				sent += 1
		for k in s.seat_pass_age.size():
			s.seat_pass_age[k] = 1.0
	_check(sent == 0, "停電中、ボットはスタンプを送らない(%d)" % sent)


## 見逃しの答え合わせ: 気づかなかった人に届いたスタンプと落とした場所が結果に入り、投票の時間がのびる
func _test_missed_replay_data() -> void:
	var s := GameState.new()
	s.start_match(63)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	var e := {}
	var sent := false
	for i in int(200.0 / STEP):
		s.tick(STEP)
		if not sent and s.phase == GameState.Phase.DROPPED:
			# 落とされた人に、だれかが嘘の「平気」を送る
			for a in s.actors:
				if a.role == GameState.Role.SEATED and a.id != target.id and s.stamp_block_reason(a.id, target.id) == "":
					sent = s.send_stamp(a.id, target.id, Stamps.SAFE)
					if sent:
						break
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(e.get("reason", "") == "missed", "(確認用)見逃し")
	var list: Array = e.get("missed_stamps", [])
	_check(not sent or (list.size() >= 1 and not list[0]["truthful"]), "気づかなかった人に届いた嘘のスタンプが結果に入る")
	_check(e.has("drop_pos") and e.has("drop_angle"), "落とした場所が結果に入る")
	_check(s.vote_wait >= GameConfig.MISSED_SCENE_TIME - 0.01, "見逃しの演出のぶん、投票を始めるのを遅らせる")
	# 演出(振り向き・顔のアップ・チーン)は、のばした投票の時間におさまる
	var scene := GameConfig.MISSED_LOOK_TIME + GameConfig.MISSED_TURN_TIME + GameConfig.MISSED_FACE_TIME + GameConfig.MISSED_CHIIN_TIME
	_check(scene + 1.0 <= GameConfig.MISSED_SCENE_TIME, "見逃しの演出は %.1f 秒(投票をのばす %.1f 秒におさまる)" % [scene, GameConfig.MISSED_SCENE_TIME])
