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
				b.on_event(s, e)
				if e["type"] == "stamp":
					sent += 1
					var t := s.get_actor(e["target"])
					_check(s.seat_pass_age[t.seat_index] <= GameConfig.BOT_STAMP_RECENT_PASS + 0.01,
							"ボットは鬼がついさっき後ろを通った人にだけスタンプを送る")
				elif e["type"] == "otetsuki":
					otetsuki_after_stamp += 1
			if s.phase == GameState.Phase.RESULT:
				break
		for a in s.actors:
			_check(a.stamps_left == GameConfig.STAMPS_PER_ROUND or a.stamps_left >= 0, "スタンプの残りの数がおかしくならない")
	_check(sent > 0, "ボットがスタンプを送る")
	_check(otetsuki_after_stamp > 0, "ボットがスタンプを信じて振り向き、お手つきすることがある")
	print("bot stamps sent: %d, otetsuki: %d" % [sent, otetsuki_after_stamp])


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
