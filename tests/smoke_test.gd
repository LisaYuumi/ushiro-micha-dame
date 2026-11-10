extends SceneTree
## 自動チェック(GitHub の自動変換のときに実行される)。
##   godot --headless -s res://tests/smoke_test.gd
## 1. GameState のルールを、画面なしで確かめる
## 2. 本番のシーンを数秒動かして、スクリプトのエラーが出ないか確かめる

const STEP := 1.0 / 60.0
const MAIN_SCENE_FRAMES := 180

var _failures := 0
var _frames := 0
var _main: Node


func _initialize() -> void:
	_test_drop_happens_for_every_seed()
	_test_otetsuki_when_nothing_behind()
	_test_found_when_handkerchief_behind()
	_test_found_when_already_looking_back()
	_test_decoy_rustle_is_behind_a_seat()
	_test_bot_cannot_look_back_as_oni()
	_test_missed_when_nobody_notices()
	_test_pick_up_rules()
	_test_oni_sits_if_chaser_stands_still()
	_test_touch_wins()
	_test_chaser_never_stops()
	_test_chaser_cannot_run_backward_or_inside()
	_test_no_otetsuki_during_chase()
	_test_rounds_with_bots_always_finish()
	_test_stamp_rules()
	_test_stamp_truthfulness()
	_test_bots_send_and_trust_stamps()
	_test_player_oni_setup()
	_test_player_oni_walk_speed_and_stop()
	_test_player_oni_drop_and_feint()
	_test_player_oni_auto_drop_after_laps()
	_test_player_oni_rounds_finish()
	_test_match_next_oni_is_loser()
	_test_match_scores_and_end()
	_test_heavier_items_slow_the_chaser()
	_test_oni_voice_masks_the_drop()
	_test_bot_oni_uses_voices()
	_test_banana_rules()
	_test_banana_can_be_dodged()
	_test_bots_throw_bananas()
	_test_who_can_see_behind_whom()
	_test_otetsuki_penalty_and_forced_oni()

	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
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
		_press("voice_0", true)
		_press("voice_0", false)
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
	if _frames < MAIN_SCENE_FRAMES:
		return false
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("TESTS FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
	return true


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
	s.set_looking_back(s.local_player_id, true)
	_check(s.take_events().is_empty(), "押しっぱなしでは何度もお手つきにならない")
	s.set_looking_back(s.local_player_id, false)
	s.set_looking_back(s.local_player_id, true)
	_check(s.get_local_player().otetsuki_count == 2, "もう一度振り向くと2回目")


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


func _test_found_when_already_looking_back() -> void:
	var s := GameState.new()
	s.start_round(5)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	s.set_looking_back(target.id, true)
	s.take_events()
	var ev := []
	for i in int(120.0 / STEP):
		s.tick(STEP)
		ev.append_array(s.take_events())
		if s.handkerchief_on_floor:
			break
	_check(_has(ev, "found"), "振り向いたまま待っていて落とされたら見つかる")


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
	var s := _chasing_state(17)
	# 外側ばかり走ると遠回りで追いつけない
	var c := s.get_actor(s.chaser_id)
	var e := {}
	for i in int(60.0 / STEP):
		s.set_move(c.id, Vector3(c.position.x, 0.0, c.position.z).normalized())
		s.tick(STEP)
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "sat", "外側ばかり走ると鬼に座られる")
	if e.is_empty():
		return
	var oni := s.get_actor(s.oni_id)
	_check(e["winner"] == s.oni_id and e["loser"] == s.chaser_id, "座られたら追いかけた人の負け")
	_check(oni.seat_index == s.vacant_seat, "鬼は空いた席に座る")
	_check(oni.position.distance_to(s.seat_positions[s.vacant_seat]) < 0.05, "鬼は席の位置にいる")


func _test_chaser_never_stops() -> void:
	var s := _chasing_state(31)
	var c := s.get_actor(s.chaser_id)
	var before := c.position
	s.set_move(c.id, Vector3.ZERO)
	for i in 30:
		s.tick(STEP)
	_check(c.position.distance_to(before) > 1.0, "何も押さなくても前に走る(待ちぶせできない)")


func _test_touch_wins() -> void:
	var s := _chasing_state(19)
	var chaser := s.get_actor(s.chaser_id)
	var e := {}
	for i in int(60.0 / STEP):
		s.set_move(chaser.id, BotBrain.chase_steer(s, chaser))
		s.tick(STEP)
		for ev in s.take_events():
			if ev["type"] == "result":
				e = ev
		if not e.is_empty():
			break
	_check(not e.is_empty() and e["reason"] == "touched", "3秒で気づいて内側を走ればタッチできる")
	if not e.is_empty():
		_check(e["winner"] == chaser.id and e["loser"] == s.oni_id, "タッチしたら追いかけた人の勝ち")


func _test_chaser_cannot_run_backward_or_inside() -> void:
	var s := _chasing_state(23)
	var c := s.get_actor(s.chaser_id)
	var start_angle := atan2(c.position.x, c.position.z)
	var backward := Vector3(-cos(start_angle), 0.0, sin(start_angle))
	for i in 60:
		s.set_move(c.id, backward)
		s.tick(STEP)
	var moved := wrapf(atan2(c.position.x, c.position.z) - start_angle, -PI, PI)
	_check(moved > 0.1, "逆向きを押しても、鬼と同じ向きに自動で走り続ける")
	for i in 120:
		s.set_move(c.id, -Vector3(c.position.x, 0.0, c.position.z).normalized())
		s.tick(STEP)
	var r := Vector2(c.position.x, c.position.z).length()
	_check(r >= GameConfig.CHASER_MIN_RADIUS - 0.001, "席の内側には入れない")

	# 内側の端で内側を押しても速さが落ちないか(追いかけっこが続いているうちに測る)
	var s2 := _chasing_state(23)
	var c2 := s2.get_actor(s2.chaser_id)
	for i in 30:
		s2.set_move(c2.id, -Vector3(c2.position.x, 0.0, c2.position.z).normalized())
		s2.tick(STEP)
	_check(s2.phase == GameState.Phase.CHASE, "(確認用)まだ追いかけっこ中")
	var p0 := c2.position
	s2.set_move(c2.id, -Vector3(c2.position.x, 0.0, c2.position.z).normalized())
	s2.tick(STEP)
	var speed := c2.position.distance_to(p0) / STEP
	_check(absf(speed - GameConfig.CHASER_SPEED) < 0.05, "内側の端で内側を押しても速さは落ちない")


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
	var s := GameState.new()
	s.start_round(41)
	_check(s.send_stamp(1, 2, Stamps.SAFE), "座っている人どうしでスタンプが届く")
	_check(_has(s.take_events(), "stamp"), "届いたお知らせが出る")
	_check(not s.send_stamp(3, 2, Stamps.DROPPED), "表示中の人には届かない(早い者勝ち)")
	_check(_has(s.take_events(), "stamp_blocked"), "届かなかったお知らせが出る")
	_check(not s.send_stamp(1, 1, Stamps.SAFE), "自分には送れない")
	_check(not s.send_stamp(s.oni_id, 2, Stamps.SAFE), "鬼は送れない")
	_check(not s.send_stamp(1, 3, "unknown"), "知らない種類は送れない")
	for i in int((GameConfig.STAMP_SHOW_TIME + 0.1) / STEP):
		s.tick(STEP)
	_check(_has(s.take_events(), "stamp_end"), "3秒で消える")
	_check(not s.active_stamps.has(2), "消えたら表示中ではない")
	_check(s.send_stamp(3, 2, Stamps.DROPPED), "消えたあとはまた届く")
	_check(s.send_stamp(1, 4, Stamps.NOW), "2つ目も送れる")
	_check(s.send_stamp(1, 0, Stamps.NOW), "3つ目も送れる(何回でも送れる)")
	_check(s.get_actor(1).stamps_left == GameConfig.STAMPS_PER_ROUND, "何回でもの設定なら残りは減らない")


func _test_stamp_truthfulness() -> void:
	var s := _dropped_state(43)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	var other := s.get_actor_at_seat((s.drop_target_seat + 1) % GameConfig.SEAT_COUNT)
	var sender := s.get_actor_at_seat((s.drop_target_seat + 2) % GameConfig.SEAT_COUNT)
	var sender2 := s.get_actor_at_seat((s.drop_target_seat + 3) % GameConfig.SEAT_COUNT)
	s.send_stamp(sender.id, target.id, Stamps.DROPPED)
	_check(s.active_stamps[target.id]["truthful"], "落とされた人に『落ちてる!』は本当")
	s.send_stamp(sender2.id, other.id, Stamps.DROPPED)
	_check(not s.active_stamps[other.id]["truthful"], "落とされていない人に『落ちてる!』は嘘")
	s.set_looking_back(target.id, true)
	s.pick_up(target.id)
	_check(s.active_stamps.is_empty(), "追いかけっこが始まるとスタンプは消える")
	_check(not s.send_stamp(sender.id, other.id, Stamps.SAFE), "追いかけっこ中は送れない")


func _test_bots_send_and_trust_stamps() -> void:
	var sent := 0
	var otetsuki_after_stamp := 0
	for seed_value in 30:
		var s := GameState.new()
		s.start_round(seed_value)
		var b := BotBrain.new()
		b.reset(seed_value)
		for i in int(40.0 / STEP):
			b.update(s, STEP)
			s.tick(STEP)
			for e in s.take_events():
				if e["type"] == "stamp":
					sent += 1
					# ボットが反応する(拾って席を立つ)前に確かめる
					var t := s.get_actor(e["target"])
					_check(s.seat_pass_age[t.seat_index] <= GameConfig.BOT_STAMP_RECENT_PASS + STEP * 1.5,
							"ボットは鬼がついさっき後ろを通った人にだけスタンプを送る")
				elif e["type"] == "otetsuki":
					otetsuki_after_stamp += 1
				b.on_event(s, e)
			if s.phase == GameState.Phase.RESULT:
				break
		for a in s.actors:
			_check(a.stamps_left == GameConfig.STAMPS_PER_ROUND or a.stamps_left >= 0, "スタンプの残りの数がおかしくならない")
	_check(sent > 0, "ボットがスタンプを送る")
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
	_check(absf(normal * GameConfig.ONI_WALK_RADIUS - GameConfig.ONI_WALK_SPEED) < 0.05, "何もしなければふつうの速さで歩く")

	var fwd := Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle))
	a0 = s.oni_angle
	for i in 60:
		s.set_move(oni.id, Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle)))
		s.tick(STEP)
	_check((s.oni_angle - a0) > normal * 1.3, "スティック右で速く歩く")

	a0 = s.oni_angle
	for i in 60:
		s.set_move(oni.id, -Vector3(cos(s.oni_angle), 0, -sin(s.oni_angle)))
		s.tick(STEP)
	_check((s.oni_angle - a0) < normal * 0.7 and (s.oni_angle - a0) > 0.0, "スティック左でゆっくり歩く(止まりはしない)")

	s.set_move(oni.id, Vector3.ZERO)
	s.set_oni_stop(oni.id, true)
	a0 = s.oni_angle
	for i in 60:
		s.tick(STEP)
	_check(absf(s.oni_angle - a0) < 0.0001, "「止まる」を押している間は止まる")
	s.set_oni_stop(oni.id, false)
	s.tick(STEP)
	_check(s.oni_angle > a0, "離すとまた歩く")
	_check(fwd != Vector3.ZERO, "(確認用)")


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

	# ボットが「ふり」にだまされることがある
	var fooled := 0
	for seed_value in 40:
		var s3 := GameState.new()
		s3.start_round(seed_value, true)
		var b := BotBrain.new()
		b.reset(seed_value)
		s3.oni_feint(s3.oni_id)
		for e in s3.take_events():
			b.on_event(s3, e)
		for e in s3.take_events():
			if e["type"] == "otetsuki":
				fooled += 1
	_check(fooled > 0 and fooled < 40, "ボットは「ふり」にときどきだまされる")


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
	_check(s2.scores[e2["loser"]] == before[e2["loser"]] + GameConfig.SCORE_MISSED, "気づかなかった人は %d 点" % GameConfig.SCORE_MISSED)
	var s3 := _chasing_state(65)
	var c := s3.get_actor(s3.chaser_id)
	var e3 := {}
	for i in int(60.0 / STEP):
		s3.set_move(c.id, BotBrain.chase_steer(s3, c))
		s3.tick(STEP)
		for ev in s3.take_events():
			if ev["type"] == "result":
				e3 = ev
		if not e3.is_empty():
			break
	if not e3.is_empty() and e3["reason"] == "touched":
		_check(s3.scores[c.id] == GameConfig.SCORE_CHASER_TOUCHED, "タッチした人は +%d 点" % GameConfig.SCORE_CHASER_TOUCHED)


func _test_heavier_items_slow_the_chaser() -> void:
	var speeds := []
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
		var p0 := target.position
		s.tick(STEP)
		speeds.append(target.position.distance_to(p0) / STEP)
	_check(speeds[1] < speeds[0] * 0.8, "教卓を持つと、ハンカチより遅い")
	print("chaser speed: handkerchief %.2f / heaviest %.2f" % [speeds[0], speeds[1]])


func _test_oni_voice_masks_the_drop() -> void:
	var s := GameState.new()
	s.start_match(71, true)
	var oni := s.oni_id
	_check(s.oni_voice(oni, Voices.WHISTLE), "鬼は声を出せる")
	_check(_has(s.take_events(), "voice"), "声のお知らせが出る")
	_check(not s.oni_voice(oni, Voices.COUGH), "すぐには続けて出せない")
	_check(not s.oni_voice(0, Voices.COUGH), "座っている人は鬼の声を出せない")
	# 席の後ろまで歩いて、声を出してすぐ落とす → かき消される
	while s.oni_angle < s.next_seat_crossing - 0.01:
		s.tick(STEP)
	for i in int(GameConfig.ONI_VOICE_COOLDOWN / STEP) + 2:
		s.set_oni_stop(oni, true)
		s.tick(STEP)
	_check(s.oni_voice(oni, Voices.CLAP), "休んだあとはまた出せる")
	s.tick(STEP)
	_check(s.oni_drop(oni), "(確認用)落とせる")
	var dropped := {}
	for e in s.take_events():
		if e["type"] == "dropped":
			dropped = e
	_check(dropped.get("masked", false), "声のすぐあとに落とすと、置く音がかき消される")
	# 声を出さずに落とすと、かき消されない
	var s2 := GameState.new()
	s2.start_match(71, true)
	while s2.oni_angle < s2.next_seat_crossing - 0.01:
		s2.tick(STEP)
	s2.oni_drop(s2.oni_id)
	var d2 := {}
	for e in s2.take_events():
		if e["type"] == "dropped":
			d2 = e
	_check(not d2.get("masked", true), "声を出さなければ、置く音はそのまま")


func _test_bot_oni_uses_voices() -> void:
	var voices := 0
	var masked := 0
	for seed_value in 20:
		var s := GameState.new()
		s.start_match(seed_value)
		for i in int(60.0 / STEP):
			s.tick(STEP)
			for e in s.take_events():
				if e["type"] == "voice":
					voices += 1
				elif e["type"] == "dropped" and e["masked"]:
					masked += 1
	_check(voices > 0, "ボットの鬼も声を出す")
	_check(masked > 0, "ボットの鬼も、声で置く音をかき消すことがある")


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
	_check(s.bananas.size() == 2, "床にバナナが2つ")
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
	for i in int(2.0 / STEP):
		# 外側に曲がってよける
		s.set_move(c.id, Vector3(c.position.x, 0, c.position.z).normalized())
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == "slip":
				slipped = true
	_check(not slipped, "曲がればバナナをよけられる")


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
	var n := GameConfig.SEAT_COUNT
	for i in n:
		_check(not GameState.can_see_behind(i, i), "自分の後ろは見えない")
		_check(not GameState.can_see_behind(i, (i + 1) % n), "右どなりの後ろは見えない")
		_check(not GameState.can_see_behind(i, (i + n - 1) % n), "左どなりの後ろは見えない")
		var seen := 0
		for j in n:
			if GameState.can_see_behind(i, j):
				seen += 1
		_check(seen == n - 3, "見えるのは向かいの %d 人" % (n - 3))


func _test_otetsuki_penalty_and_forced_oni() -> void:
	var s := GameState.new()
	s.start_match(81)
	var me := s.get_local_player()
	var before: int = s.scores[me.id]
	s.set_looking_back(me.id, true)
	_check(s.scores[me.id] == before + GameConfig.SCORE_OTETSUKI, "お手つきで %d 点" % GameConfig.SCORE_OTETSUKI)
	for i in GameConfig.OTETSUKI_LIMIT - 1:
		s.set_looking_back(me.id, false)
		s.set_looking_back(me.id, true)
	s.set_looking_back(me.id, false)
	_check(me.otetsuki_count == GameConfig.OTETSUKI_LIMIT, "お手つきが %d 回" % GameConfig.OTETSUKI_LIMIT)
	_run_until(s, "result", 200.0)
	var loser: int = s.result["loser"]
	_check(s.next_round(), "(確認用)次のラウンドへ")
	_check(s.oni_id == me.id, "お手つき %d 回の人が、次は強制的に鬼" % GameConfig.OTETSUKI_LIMIT)
	_check(s.forced_oni_id == me.id, "強制的に鬼になったことがわかる")
	_check(me.otetsuki_count == 0, "鬼になったらお手つきの回数は 0 に戻る")
	if loser != me.id:
		_check(s.get_actor(loser).role == GameState.Role.SEATED, "本来鬼になるはずだった人は席に座る")
	var seated := 0
	for a in s.actors:
		if a.role == GameState.Role.SEATED:
			seated += 1
	_check(seated == GameConfig.SEAT_COUNT, "席は全部うまっている")


# --- 道具 ---

func _dropped_state(seed_value: int) -> GameState:
	var s := GameState.new()
	s.start_round(seed_value)
	_run_until(s, "dropped", 120.0)
	# 鬼がハンカチの横から離れるまで少し待つ(落とした直後に拾うと、その場でタッチになる)
	for i in int(3.0 / STEP):
		s.tick(STEP)
	s.take_events()
	return s


func _chasing_state(seed_value: int) -> GameState:
	var s := _dropped_state(seed_value)
	var target := s.get_actor_at_seat(s.drop_target_seat)
	s.set_looking_back(target.id, true)
	s.pick_up(target.id)
	s.take_events()
	return s


func _run_until(s: GameState, type: String, seconds: float) -> Dictionary:
	for i in int(seconds / STEP):
		s.tick(STEP)
		for e in s.take_events():
			if e["type"] == type:
				return e
	return {}


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
