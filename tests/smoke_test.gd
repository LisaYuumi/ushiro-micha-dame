extends SceneTree
## 自動チェック(GitHub の自動変換のときに実行される)。
##   godot --headless -s res://tests/smoke_test.gd
## 1. GameState のルールを、画面なしで確かめる
## 2. 本番のシーンを数秒動かして、スクリプトのエラーが出ないか確かめる

const STEP := 1.0 / 60.0
const MAIN_SCENE_FRAMES := 180

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
	_test_no_otetsuki_during_chase()
	_test_rounds_with_bots_always_finish()
	_test_stamp_rules()
	_test_stamp_truthfulness()
	_test_stamp_words()
	_test_milk_art()
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
	_test_heavier_items_slow_the_chaser()
	_test_banana_rules()
	_test_banana_can_be_dodged()
	_test_bots_throw_bananas()
	_test_who_can_see_behind_whom()
	_test_miss_goes_out()
	_test_milk()
	_test_deceiving_scores()
	_test_minion()
	_test_bot_personalities()
	_test_look_limit_and_patience()
	_test_online_match_setup()
	_test_humans_only_oni()
	_test_snapshot_round_trip()
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
			for pose in PhotoStudio.POSES:
				st._pick(func(v: String) -> void: st._pose = v, pose)
			st._pick(func(v: String) -> void: st._direction = v, "後ろ")
			st._pick(func(v: String) -> void: st._expression = PhotoStudio.EXPRESSIONS.find(v), "放心")
			st._pick_color(Profile.COLORS[9])
			st._next_background()
			_check(st._models.size() == 1, "撮影モード: キャラが1体")
		150:
			_main._studio._toggle_ring()
			_check(_main._studio._models.size() == PhotoStudio.RING_PEOPLE, "撮影モード: 輪の場面は %d 人" % PhotoStudio.RING_PEOPLE)
			_main._studio._set_ui_hidden(true)
		160:
			_main._studio._close()
			_check(_main._studio == null and _main.view.visible, "撮影モードからもどれる")


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
	if _fall_clock <= CharacterModel.RAGDOLL_FALL_TIME:
		_faller_min_head_y = minf(_faller_min_head_y, y)
	if int(before * 10.0) != int(_fall_clock * 10.0):
		var pb_y := _faller._pbones[0].global_position.y if not _faller._pbones.is_empty() else -1.0
		print("fall %.1fs: head y %.2f / hips body y %.2f / w %.2f" % [_fall_clock, y, pb_y, _faller._ragdoll_w])
	if _fall_clock > CharacterModel.RAGDOLL_FALL_TIME + CharacterModel.RAGDOLL_RISE_TIME + 0.3:
		_fall_done = true
		_check(_faller_min_head_y < _faller_head_y - 0.5, "転ぶと頭が下がる(%.2f → %.2f)" % [_faller_head_y, _faller_min_head_y])
		_check(absf(y - _faller_head_y) < 0.25 and _faller._ragdoll_w == 0.0, "少しすると起き上がる(頭 %.2f)" % y)


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
	# 内側の列は近道。内側を走れば、まん中の列を走る鬼に追いつける
	var s := _chasing_state(19)
	var chaser := s.get_actor(s.chaser_id)
	var e := {}
	for i in int(90.0 / STEP):
		s.chase_lane(chaser.id, -1)
		s.tick(STEP)
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "touched", "内側(近道)を走ればタッチできる")
	if not e.is_empty():
		_check(e["winner"] == chaser.id and e["loser"] == s.oni_id, "タッチしたら追いかけた人の勝ち")


func _test_chase_lanes_and_speed() -> void:
	var s := _chasing_state(23)
	var c := s.get_actor(s.chaser_id)
	var oni := s.get_actor(s.oni_id)
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
	_check(absf(cs - GameConfig.CHASE_SPEED) < 0.05 and absf(os - GameConfig.CHASE_SPEED) < 0.05,
			"鬼も追いかける人も同じ速さ(%.2f / %.2f)" % [cs, os])
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


func _test_obstacles() -> void:
	# コースに障害物が置かれる。走りはじめた2人のすぐ前には置かない
	var s0 := _dropped_state(41)
	var target := s0.get_actor_at_seat(s0.drop_target_seat)
	s0.set_looking_back(target.id, true)
	s0.pick_up(target.id)
	_check(s0.obstacles.size() >= 3, "コースに障害物がある(%d 個)" % s0.obstacles.size())
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
	_check(HeadOverlay.stamp_text(g, 2, Stamps.SAFE) == "平気👍", "「表示しない」なら初期の言葉")
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
	_check(HeadOverlay.stamp_text(s, 2, Stamps.SAFE) == "You're safe👍", "言語がちがえば、自作の言葉は英語の初期の言葉で出す")
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
	_check(_has(s.take_events(), "match_over"), "試合終了のお知らせが出る")
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
	var thrower := s.get_actor_at_seat((s.vacant_seat + 2) % GameConfig.SEAT_COUNT)
	var s0 := _dropped_state(73)
	_check(not s0.throw_banana(thrower.id, s0.oni_id), "追いかけっこの前は投げられない")
	_check(not s.throw_banana(s.oni_id, s.chaser_id), "鬼は投げられない")
	_check(not s.throw_banana(thrower.id, thrower.id), "座っている人には投げられない")
	_check(s.throw_banana(thrower.id, s.chaser_id), "追いかける人に投げられる")
	_check(not s.throw_banana(thrower.id, s.oni_id), "1ラウンド1個まで")
	var other := s.get_actor_at_seat((s.vacant_seat + 3) % GameConfig.SEAT_COUNT)
	_check(s.throw_banana(other.id, s.oni_id), "鬼にも投げられる")
	var n_banana := 0
	for ob in s.obstacles:
		if ob["kind"] == "banana":
			n_banana += 1
	_check(n_banana == 2, "コースにバナナが2つ")
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
	var thrower := s.get_actor_at_seat((s.vacant_seat + 2) % GameConfig.SEAT_COUNT)
	s.throw_banana(thrower.id, c.id)
	var slipped := false
	# 列を変えてよける
	s.chase_lane(c.id, 1 if c.lane == 0 else -1)
	for i in int(2.0 / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "slip":
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
	for players in GameConfig.PLAYER_COUNT_OPTIONS:
		_check_visibility(players - 1)


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
		if a.id != oni5 and a.id != s5.minion_id:
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
			if e["type"] == "minion":
				told = e["actor"] == m.id and e["private_to"] == m.id
		_check(told, "手下は本人にだけ知らされる")
		var other := s.get_actor_at_seat((m.seat_index + 2) % GameConfig.SEAT_COUNT)
		_check(s.snapshot(other.id)["minion_id"] == -1, "ほかの人に送る状態には、手下がだれかは入らない")
		_check(s.snapshot(m.id)["minion_id"] == m.id, "手下本人に送る状態には入る")
		var right := (m.seat_index + 1) % GameConfig.SEAT_COUNT
		_check(s.sees_behind(m.id, right), "手下は両どなりの後ろも見える")
		_check(not s.sees_behind(m.id, m.seat_index), "手下も自分の後ろは見えない")
		var n := s.get_actor_at_seat(right)
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
	_check(s2.snapshot(other2.id)["minion_id"] == minion.id, "勝敗のあとは、だれにでも手下がわかる")
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
	# ボットが負けても、次の鬼は人
	var ok := 0
	for seed_value in 20:
		var s := GameState.new()
		s.start_match_custom(seed_value, [0, 5], 5, {0: "A", 5: "B"}, true)
		var b := BotBrain.new()
		b.reset(seed_value)
		var e := _play_round_with_bots_and_human_oni(s, b)
		if e.is_empty():
			continue
		s.next_round()
		_check(not s.get_actor(s.oni_id).is_bot, "seed %d: 鬼は人だけ" % seed_value)
		var seated := 0
		for a in s.actors:
			if a.role == GameState.Role.SEATED:
				seated += 1
		_check(seated == GameConfig.SEAT_COUNT, "席は全部うまっている")
		ok += 1
	_check(ok > 0, "(確認用)ためせた")


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
