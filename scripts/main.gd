extends Node3D
## 全体のつなぎ役。
##   GameState(状態) ← 入力(PlayerInput)・ボット(BotBrain)が命令を出す
##   GameState(状態) → WorldView / Hud が読んで表示する
## オンライン対戦:
##   ホスト   … ひとりのときと同じくルールを動かし、状態とお知らせを参加者に配る
##   参加者   … ルールは動かさない。操作をホストに送り、届いた状態を表示するだけ

enum Mode { LOBBY, SOLO, HOST, GUEST }

var state: GameState
var bots := BotBrain.new()
var mode := Mode.LOBBY
## 命令の送り先(ひとり/ホスト: state、参加者: RemoteCommands)
var cmds: Object
## 確認用: 最後に鳴った物音が本物かニセか
var _last_sound := ""
## スタンプを送る相手(画面でタップして選ぶ。-1 は未選択)
var _stamp_target := -1
## 鬼が牛乳ボタンを押して、かける相手を選んでいるところか(「えいっ」の状態)
var _milk_aiming := false
## ひとりで遊ぶとき、この画面のプレイヤーが鬼をやるか
var _player_is_oni := false
## この試合の席の数(遊ぶ人数 - 鬼1人)
var _seats: int = GameConfig.SEAT_COUNT
## ホスト: 参加者の peer id -> 登場人物の id
var _peer_actor := {}
## ホスト: 参加者の peer id -> {"name", "color"}(ロビーで決めた名前と色)
var _peer_profile := {}
## ホスト: 状態を配るまでの時間
var _snapshot_left := 0.0
## 参加者: 最後に見た目を作ったラウンド
var _built_serial := -1
## ラウンドが始まったときの点数(結果カードで「このラウンドで何点ふえたか」を出す)
var _round_start_scores := {}
## 撮影モード(開いている間はゲームを止める)
var _studio: PhotoStudio
var _lobby_was_visible := false

const SNAPSHOT_INTERVAL := 0.05

@onready var view: WorldView = $WorldView
@onready var hud: Hud = $Hud
@onready var touch: TouchControls = $TouchControls
@onready var net: NetSession = $Net
@onready var lobby: Lobby = $Lobby
var audio: AudioDirector
## 結果のジングルを鳴らしている間は BGM を止めておく残り時間(秒)
var _jingle_hold := 0.0


func _ready() -> void:
	InputSetup.register()
	# 音の出力の余裕(ブラウザの開発者ツールで確かめる用)
	print("audio output latency: %.3f s, mix rate: %d" % [AudioServer.get_output_latency(), AudioServer.get_mix_rate()])
	# 音: BGM と、場所のない効果音(ボタン・チャイム・ジングルなど)
	audio = AudioDirector.new()
	add_child(audio)
	audio.play_bgm("bgm_lobby")
	state = GameState.new()
	cmds = state
	# 後ろに見える教室だけ先に作っておく(ロビーの背景)
	state.start_match(-1, false)
	_build_view()
	# 結果カードで、手下だと思う人の札をタップした
	hud.vote_pressed.connect(_on_vote_pressed)
	lobby.solo_pressed.connect(_on_solo)
	lobby.host_pressed.connect(_on_host)
	lobby.join_pressed.connect(_on_join)
	lobby.start_pressed.connect(_on_host_start)
	lobby.language_pressed.connect(func() -> void: set_language(Locale.next_language()))
	net.status_changed.connect(lobby.set_status)
	net.peers_changed.connect(_on_peers_changed)
	net.connected_to_host.connect(func() -> void:
		net.send_profile(Profile.to_dict())
		lobby.show_waiting(tr("つながりました! ホストがスタートするのを待っています")))
	net.profile_received.connect(func(pid: int, p: Dictionary) -> void: _peer_profile[pid] = p)
	net.lobby_received.connect(_on_lobby_info)
	net.snapshot_received.connect(_on_snapshot)
	net.events_received.connect(_on_net_events)
	net.command_received.connect(_on_remote_command)
	net.host_lost.connect(_on_host_lost)
	if DisplayServer.get_name() == "headless":
		# 自動チェックのときは、すぐひとりで始める
		_on_solo()


# --- ロビー ---

func _on_solo() -> void:
	_seats = lobby.players - 1
	mode = Mode.SOLO
	lobby.visible = false
	cmds = state
	_start_round()


func _on_host() -> void:
	_seats = lobby.players - 1
	mode = Mode.LOBBY
	net.host_room()
	lobby.show_host(tr("(作成中)"), 1)
	net.status_changed.connect(func(_t: String) -> void:
		if net.is_host and mode == Mode.LOBBY:
			lobby.show_host(net.room_code, 1 + multiplayer.get_peers().size()))


func _on_join(code: String) -> void:
	net.join_room(code)
	lobby.show_waiting(tr("部屋 %s をさがしています…") % code)


func _on_peers_changed(peer_ids: Array) -> void:
	if mode == Mode.LOBBY:
		# スタート前: 入れるのは席と鬼をあわせた人数まで
		lobby.show_host(net.room_code, 1 + peer_ids.size())
		for pid in peer_ids:
			net.send_lobby(pid, {"started": false, "players": 1 + peer_ids.size()})
	elif mode == Mode.HOST:
		# 試合中に入ってきた人: 次の試合から参加できる
		for pid in peer_ids:
			if not _peer_actor.has(pid):
				net.send_lobby(pid, {"started": false, "late": true, "players": 1 + peer_ids.size()})
		# 試合中に抜けた人の席は、ボットが引き継ぐ
		for pid in _peer_actor.keys():
			if not (pid in peer_ids):
				var a := state.get_actor(_peer_actor[pid])
				if a:
					a.is_bot = true
					a.display_name += "(ボット)"
				_peer_actor.erase(pid)
				hud.show_message(tr("%s が抜けたのでボットが代わります") % (Locale.actor_name(a.display_name) if a else "?"), Color(0.3, 0.3, 0.3), 2.0)


## ホストが「スタート」: 人は id 0(ホスト)から順に、残りはボット。最初の鬼は人からランダム
func _on_host_start() -> void:
	var peers := multiplayer.get_peers()
	var max_humans := _seats + 1
	_peer_actor.clear()
	var humans := [0]
	var names := {0: Profile.player_name}
	var colors := {0: Profile.color}
	var accs := {0: Profile.accessories}
	var next_id := 1
	for pid in peers:
		if next_id >= max_humans:
			break
		_peer_actor[pid] = next_id
		humans.append(next_id)
		# ロビーで決めた名前と色(届いていなければ「プレイヤーN」と決まった色)
		var prof: Dictionary = _peer_profile.get(pid, {})
		names[next_id] = Profile.clean_name(str(prof.get("name", "プレイヤー%d" % (next_id + 1))))
		var c := Profile.parse_color(str(prof.get("color", "")), Color(0, 0, 0, 0))
		if c.a > 0.0:
			colors[next_id] = c
		accs[next_id] = Accessories.clean(prof.get("acc", {}))
		next_id += 1
	var first_oni: int = humans[randi_range(0, humans.size() - 1)]
	state.stage = Profile.stage
	state.start_match_custom(-1, humans, first_oni, names, true, _seats, colors, accs)
	state.local_player_id = 0
	mode = Mode.HOST
	cmds = state
	lobby.visible = false
	for pid in _peer_actor:
		net.send_lobby(pid, {"started": true, "your_id": _peer_actor[pid]})
	_refresh_round()
	_snapshot_left = 0.0


func _on_lobby_info(info: Dictionary) -> void:
	if info.get("started", false):
		mode = Mode.GUEST
		cmds = RemoteCommands.new(net)
		state.local_player_id = info["your_id"]
		_built_serial = -1
		lobby.visible = false
		hud.show_message(tr("スタート!"), Color(0.3, 0.3, 0.3), 1.0)
	elif info.get("late", false):
		lobby.show_waiting(tr("つながりました! いまは試合中です。\n次の試合から参加できます(ホストが新しい試合を始めるまで待ってください)"))
	else:
		lobby.show_waiting(tr("つながりました! いま %d人。ホストがスタートするのを待っています") % info.get("players", 0))


func _on_host_lost() -> void:
	if mode == Mode.GUEST:
		hud.show_message(tr("ホストとの通信が切れました\nページを読み込み直してください"), Color(0.85, 0.1, 0.1), 0.0)


# --- 参加者: ホストから届いた状態とお知らせ ---

func _on_snapshot(snap: Dictionary) -> void:
	if mode != Mode.GUEST:
		return
	state.apply_snapshot(snap)
	if state.round_serial != _built_serial:
		_built_serial = state.round_serial
		_refresh_round()


func _on_net_events(events: Array) -> void:
	if mode != Mode.GUEST:
		return
	for e in events:
		view.on_event(e)
		_show_event(e)
	_update_help()


# --- ホスト: 参加者から届いた命令を、その人の登場人物として実行する ---

func _on_remote_command(peer_id: int, cmd: String, args: Array) -> void:
	if mode != Mode.HOST or not _peer_actor.has(peer_id):
		return
	var id: int = _peer_actor[peer_id]
	match cmd:
		"set_looking_back":
			state.set_looking_back(id, bool(args[0]))
		"set_move":
			state.set_move(id, args[0])
		"pick_up":
			state.pick_up(id)
		"oni_drop":
			state.oni_drop(id)
		"oni_feint":
			state.oni_feint(id)
		"oni_milk":
			state.oni_milk(id, int(args[0]))
		"throw_banana":
			state.throw_banana(id, int(args[0]))
		"chase_steer":
			state.chase_steer(id, float(args[0]))
		"send_stamp":
			state.send_stamp(id, int(args[0]), str(args[1]))
		"cast_vote":
			state.cast_vote(id, int(args[0]))


# --- 試合 ---

func _i_am_oni() -> bool:
	return state.oni_id == state.local_player_id


## 新しい試合を始める(ひとりのとき。ホストは「スタート」から)
func _start_round() -> void:
	if mode == Mode.HOST:
		_on_host_start()
		return
	state.stage = Profile.stage
	state.start_match(-1, _player_is_oni, _seats, Profile.player_name, Profile.color, Profile.accessories)
	_refresh_round()


## 3D の画面を作り直す。舞台が海辺なら、牛乳のボタンと画面の白いたれを水鉄砲・水しぶきにする
func _build_view() -> void:
	view.build(state)
	var water := state.stage == "beach"
	hud.set_water(water)
	touch.set_water(water)


## ラウンドが変わったときに、画面とボットを作り直す
func _refresh_round() -> void:
	bots.reset()
	_round_start_scores = state.scores.duplicate()
	touch.set_oni_mode(_i_am_oni())
	_last_sound = ""
	# 前のラウンドで開いていた「◯◯に送る」は閉じる
	_close_picker()
	_milk_aiming = false
	_apply_stamp_words()
	hud.show_my_stamps([])
	hud.hide_message()
	_build_view()
	_update_help()


func _physics_process(delta: float) -> void:
	if mode == Mode.LOBBY or _studio:
		return
	if mode == Mode.GUEST and _built_serial < 0:
		return # まだ最初の状態が届いていない
	PlayerInput.apply(state, cmds, view.get_camera_basis())
	_update_milk()
	if mode != Mode.GUEST:
		# ルールを動かすのは、ひとりのときとホストだけ
		bots.update(state, delta)
		state.tick(delta)
		var events := state.take_events()
		for e in events:
			view.on_event(e)
			bots.on_event(state, e)
			_show_event(e)
			_update_help()
		if mode == Mode.HOST:
			_send_to_guests(events, delta)
	if _stamp_target >= 0 and (state.get_actor(_stamp_target) == null or state.get_actor(_stamp_target).role != GameState.Role.SEATED
			or (state.phase != GameState.Phase.WALKING and state.phase != GameState.Phase.DROPPED)):
		_close_picker()
	view.set_stamp_target(state, _stamp_target)
	var me := state.get_local_player()
	if me == null:
		return
	_update_my_stamps()
	var out := me.role == GameState.Role.OUT
	if out and state.phase != GameState.Phase.RESULT:
		hud.set_role_badge(tr("お手つきでお休み中(このラウンド0点)"), Color(0.35, 0.45, 0.6))
	else:
		var badge := ""
		if state.phase != GameState.Phase.RESULT:
			if state.is_minion(me.id):
				badge = tr("あなたは鬼の手下")
			elif _i_am_oni() and state.minion_count > 0:
				# 鬼は、手下の人数だけ知っている(だれかは知らない)
				badge = tr("今回の手下は%d人(だれかはひみつ)") % state.minion_count
		hud.set_role_badge(badge, Color(0.55, 0.2, 0.7))
	# 牛乳がかかっている間は、画面が白い
	# 追いかけっこで走っている間は、手で牛乳をぬぐって下のほうが見える(すぐ転ばないように)
	hud.set_milk(state.is_milked(me) and state.phase != GameState.Phase.RESULT, state.milk_left_ratio(me), state.is_runner(me))
	touch.set_milk_state(state.milk_left, _milk_aiming)
	var judged := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	touch.set_looks_left(me.looks_left if judged else -1)
	# 勝敗が出ている間は、名札とゲーム用のボタンを隠して結果カードだけにする(⚙は残す)
	var showing_result := state.phase == GameState.Phase.RESULT
	touch.set_result_mode(showing_result)
	var runner := state.is_runner(me)
	touch.set_oni_mode(_i_am_oni(),
			(me.role == GameState.Role.SEATED or out) and state.phase == GameState.Phase.CHASE, out, runner)
	# スティックは、鬼が歩いているときと、追いかけっこで走っているとき(左右によける)
	touch.set_stick_visible(me.role == GameState.Role.ONI or runner)
	var ov := view.get_overlay()
	if ov:
		# 牛乳がかかっている間は名札も見えない(鬼の名札で場所がわからないように)。吹き出しは出したまま
		ov.visible = not showing_result
		ov.set_tags_hidden(state.is_milked(me))
	# 左上の札(鬼の周回・自分の点数)を毎回更新する(参加者の点数は状態といっしょに届く)
	_update_help()


## BGM: ロビー・結果は明るい曲、ラウンド中は控えめな曲(ラウンドが進むほど楽器が増える)、追いかけっこは速い曲。
## 鬼との距離では変えない(BGM で鬼の場所がわからないように)
func _update_music(delta: float) -> void:
	_jingle_hold = maxf(_jingle_hold - delta, 0.0)
	var want := "bgm_lobby"
	if mode != Mode.LOBBY and _studio == null:
		match state.phase:
			GameState.Phase.WALKING, GameState.Phase.DROPPED:
				want = "bgm_round_%d" % _round_level()
			GameState.Phase.CHASE:
				want = "bgm_chase"
			_:
				want = "" if _jingle_hold > 0.0 else "bgm_lobby"
	audio.play_bgm(want)


## ラウンド中の曲の段階: 1〜2ラウンド目 = 1、3〜4ラウンド目 = 2、最後のラウンド = 3
func _round_level() -> int:
	if state.round_index >= GameConfig.ROUNDS_PER_MATCH - 1:
		return 3
	return 1 if state.round_index < 2 else 2


## 重さの記録(ブラウザの開発者ツールのコンソールに、5秒ごとに出す)
var _perf_left := 5.0
var _perf_frames := 0
var _perf_worst := 0.0


func _log_perf(delta: float) -> void:
	_perf_frames += 1
	_perf_worst = maxf(_perf_worst, delta)
	_perf_left -= delta
	if _perf_left > 0.0:
		return
	print("perf fps=%d worst=%.0fms process=%.1fms physics=%.1fms draws=%d objects=%d prims=%dk nodes=%d" % [
		Engine.get_frames_per_second(), _perf_worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_perf_left = 5.0
	_perf_frames = 0
	_perf_worst = 0.0


func _process(delta: float) -> void:
	_log_perf(delta)
	_update_music(delta)
	if _studio:
		return
	view.sync(state, delta)


## ホスト: 参加者1人ずつに、その人が知ってよいお知らせと状態だけを送る
## (手下がだれかは本人にだけ。点が入ったお知らせは送った本人にだけ)
func _send_to_guests(events: Array, delta: float) -> void:
	_snapshot_left -= delta
	var send_snapshot := _snapshot_left <= 0.0
	if send_snapshot:
		_snapshot_left = SNAPSHOT_INTERVAL
	for pid in _peer_actor:
		var id: int = _peer_actor[pid]
		var mine := events.filter(func(e: Dictionary) -> bool: return e.get("private_to", id) == id)
		net.send_events(pid, mine)
		if send_snapshot:
			net.send_snapshot(pid, state.snapshot(id))


## 自分に届いているスタンプ(3つまで)を、画面の下に送り主つきで並べる
func _update_my_stamps() -> void:
	var list := []
	for st in state.active_stamps.get(state.local_player_id, []):
		var sender := state.get_actor(st["sender"])
		list.append({
			"kind": st["kind"],
			"text": HeadOverlay.stamp_text(state, st["sender"], st["kind"]),
			"sender": HeadOverlay.sender_name(state, st["sender"]),
			"sender_color": sender.color if sender else Color.WHITE,
		})
	hud.show_my_stamps(list)

func _unhandled_input(event: InputEvent) -> void:
	if _studio:
		return
	if event.is_action_pressed("photo_mode"):
		_open_studio()
	elif event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		if mode == Mode.GUEST:
			hud.show_message(tr("次へ進むのはホストです"), Color(0.3, 0.3, 0.3), 1.2)
		elif mode != Mode.LOBBY:
			_on_restart_pressed()
	elif event.is_action_pressed("toggle_role"):
		if mode != Mode.SOLO:
			hud.show_message(tr("オンラインでは、鬼は負けた人がやります"), Color(0.3, 0.3, 0.3), 1.5)
			return
		# 最初の鬼を自分にするかどうかを切りかえて、新しい試合を始める
		_player_is_oni = not _player_is_oni
		_start_round()
		hud.show_message(tr("あなたが鬼で新しい試合") if _player_is_oni else tr("座る側で新しい試合"), Color(0.3, 0.3, 0.3), 1.2)
	elif event.is_action_pressed("toggle_personality"):
		Profile.load_saved()
		Profile.show_personality = not Profile.show_personality
		Profile.save()
		_build_view()
	elif event.is_action_pressed("debug_finish"):
		# 確認用(ひとりのときだけ): いまのラウンドをすぐ「見逃し」で終わらせて、結果カードを見る
		if mode == Mode.SOLO and state.phase != GameState.Phase.RESULT and state.phase != GameState.Phase.CHASE:
			var loser := state.get_actor_at_seat(maxi(state.drop_target_seat, 0))
			if loser:
				state._finish(state.oni_id, loser.id, "missed")
	elif event.is_action_pressed("toggle_language"):
		set_language(Locale.next_language())
	elif event.is_action_pressed("debug_blackout_next"):
		# 開発用: 次のラウンドを停電にする(ひとり・ホストのとき)
		if mode == Mode.SOLO or mode == Mode.HOST:
			state.blackout_round = state.round_index + 1
			hud.show_message(tr("次のラウンドは停電"), Color(0.15, 0.15, 0.35), 1.5)
	elif event.is_action_pressed("debug_milk"):
		# 確認用(ひとりのときだけ): 自分に牛乳をかけて、白い画面を見る
		var me := state.get_local_player()
		if mode == Mode.SOLO and me and me.role == GameState.Role.SEATED:
			me.milk_angle = state.oni_angle
	elif event.is_action_pressed("debug_slip"):
		view.debug_slip_all()
	elif event.is_action_pressed("sound_test"):
		view.play_test_beep()
	elif event.is_action_pressed("quit"):
		get_tree().quit()
	else:
		for i in Stamps.ALL.size():
			if not _i_am_oni() and event.is_action_pressed("stamp_%d" % i):
				_send_stamp(Stamps.ALL[i])
				return
			if _i_am_oni() and event.is_action_pressed("oni_stamp_%d" % i):
				_send_stamp(Stamps.ALL[i])
				return
		# 追いかけっこで走っているとき: 操作はスティックだけ(タップしても何もしない)
		if state.is_runner(state.get_local_player()):
			return
		# 画面に映っている人をタップ/クリックすると、スタンプを送る相手になる
		var pos := Vector2(-1, -1)
		if event is InputEventScreenTouch and event.pressed:
			pos = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
		if pos.x >= 0.0:
			_on_tap(pos)


## 「次へ・やり直し」: 勝敗が出ていれば次のラウンドへ、試合が終わっていれば新しい試合、
## ラウンドの途中なら、そのラウンドをやり直す
func _on_restart_pressed() -> void:
	if state.match_over:
		_start_round()
	elif state.phase == GameState.Phase.RESULT:
		if state.next_round():
			_refresh_round()
			var msg := tr("ラウンド %d: %s") % [state.round_index + 1, state.item_name()]
			hud.show_message(msg, Color(0.3, 0.3, 0.3), 2.0)
		else:
			_show_match_result()
	else:
		state.restart_round()
		_refresh_round()


## 試合が終わった: 順位のカード(1位に★)
func _show_match_result() -> void:
	var ids := state.scores.keys()
	ids.sort_custom(func(a, b): return state.scores[a] > state.scores[b])
	var rows := []
	var rank := 0
	var prev := INF
	var top_name := ""
	for i in ids.size():
		var sc: int = state.scores[ids[i]]
		if sc != prev:
			rank = i + 1
			prev = sc
		if rank == 1 and top_name == "":
			top_name = _name(ids[i])
		var row := _score_row_for(ids[i], state.scores, false)
		row["mark"] = "★" if rank == 1 else tr("%d位") % rank
		rows.append(row)
	var me_first: bool = state.scores.get(state.local_player_id, 0) == state.scores[ids[0]]
	var title := tr("ゆうしょう!") if me_first else tr("試合おわり!")
	if me_first:
		hud.confetti()
	var sub := tr("あなたがいちばん!") if me_first else tr("いちばんは %s!") % top_name
	hud.hide_message()
	if mode == Mode.GUEST:
		hud.show_result_card(title, sub, [], GameConfig.COLOR_ACCENT, rows, tr("ホストが「次へ」を押すと新しい試合"))
	else:
		hud.show_result_card(title, sub, [], GameConfig.COLOR_ACCENT, rows, "", tr("新しい試合へ ▶"))


## 結果カードの1行。delta: このラウンドで増えた分も出すか
func _score_row_for(id: int, scores: Dictionary, delta: bool) -> Dictionary:
	var a := state.get_actor(id)
	var n: String = tr("あなた") if id == state.local_player_id else (Locale.actor_name(a.display_name) if a else "?")
	var sc: int = scores.get(id, 0)
	return {
		"name": n,
		"color": a.color if a else Color.WHITE,
		"score": sc,
		"delta": sc - int(_round_start_scores.get(id, sc)) if delta else 0,
		"me": id == state.local_player_id,
	}


## 撮影モードを開く(ゲームは止まる)。オンライン対戦中は、ほかの人のゲームも止まってしまうので開かない
func _open_studio() -> void:
	if _studio or not GameConfig.SHOW_PHOTO_MODE:
		return
	if mode == Mode.HOST or mode == Mode.GUEST:
		hud.show_message(tr("撮影モードは、ひとりで遊ぶときだけ"), Color(0.3, 0.3, 0.3), 1.5)
		return
	_close_picker()
	_studio = PhotoStudio.new()
	add_child(_studio)
	_studio.closed.connect(_close_studio)
	view.set_shown(false)
	hud.visible = false
	touch.visible = false
	_lobby_was_visible = lobby.visible
	lobby.visible = false


func _close_studio() -> void:
	if _studio == null:
		return
	_studio.queue_free()
	_studio = null
	view.set_shown(true)
	hud.visible = true
	touch.visible = true
	lobby.visible = _lobby_was_visible


## 画面をタップした: スタンプの選択肢を押した/人(か名札)をタップした/外をタップした
func _on_tap(pos: Vector2) -> void:
	var ov := view.get_overlay()
	if ov == null:
		return
	# 下のまん中の言葉のボタン
	var kind := hud.send_panel_hit(pos)
	if kind != "":
		_send_stamp(kind)
		return
	if hud.send_panel_contains(pos):
		return # ボタンのすき間: 何もしない
	var id := ov.tag_hit(pos)
	if id < 0:
		id = view.pick_actor_at(state, pos)
	# 鬼が牛乳ボタンを押したあと(「えいっ」): タップした座っている人にかける(スタンプは出さない)
	if _milk_aiming:
		if id >= 0 and state.can_milk(id):
			cmds.oni_milk(state.local_player_id, id)
			_milk_aiming = false
		return
	if _stamp_target >= 0:
		# 選んでいるときは、同じ人か外をタップしたら閉じる。ほかの人なら、その人を選び直す
		var was := _stamp_target
		_close_picker()
		if id == was or id < 0:
			return
	if id < 0:
		return
	# 送れない相手(8人のときの両どなり・このラウンド送った人)は、タップしても何もしない(名札が薄い)
	var why := state.stamp_block_reason(state.local_player_id, id)
	if why != "" and why != "full":
		return
	# 足もとが光り、頭の上に「送る相手」の印。下のまん中に「◯◯に送る」と3つの言葉
	_stamp_target = id
	ov.set_send_target(id)
	hud.open_send_panel(_short_name(id), _i_am_oni())


## 言語を切りかえる(ロビーの言語ボタン・⚙メニューから)。端末に保存し、画面の文字を作り直す
func set_language(lang: String) -> void:
	Profile.lang = lang
	Profile.save()
	Locale.setup(lang)
	lobby.refresh_texts()
	touch.refresh_texts()
	UiStyle.refit_all()
	if mode != Mode.LOBBY:
		_apply_stamp_words()
		if mode == Mode.GUEST:
			net.send_profile(Profile.to_dict())
		_build_view()
		_update_help()


## 自作のスタンプの言葉を状態に入れる(ひとり・ホストだけ。参加者の分はロビーで届いた言葉を、もう一度チェックして使う)
func _apply_stamp_words() -> void:
	hud.set_send_words(Profile.stamp_words)
	if mode == Mode.GUEST:
		return
	state.stamp_words[state.local_player_id] = Profile.stamp_words.duplicate()
	state.stamp_langs[state.local_player_id] = Locale.current()
	for pid in _peer_actor:
		var prof: Dictionary = _peer_profile.get(pid, {})
		state.stamp_words[_peer_actor[pid]] = Profile.clean_words(prof.get("words", {}))
		state.stamp_langs[_peer_actor[pid]] = Locale.pick(str(prof.get("lang", "")))


## 鬼の牛乳: ボタンを押すと「えいっ」(相手を選ぶ)になり、もう一度押すとやめる。
## 牛乳がなくなった・追いかけっこになったなどで、選ぶのをやめる
func _update_milk() -> void:
	var usable := _i_am_oni() and state.milk_left > 0 \
			and (state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED)
	if _milk_aiming and not usable:
		_milk_aiming = false
	if usable and Input.is_action_just_pressed("oni_milk"):
		_milk_aiming = not _milk_aiming
		if _milk_aiming:
			_close_picker()
			hud.show_message(tr("かける人をタップ!"), Color(0.3, 0.45, 0.7), 1.0)
	view.set_milk_aim(_milk_aiming)


func _close_picker() -> void:
	_stamp_target = -1
	hud.close_send_panel()
	var ov := view.get_overlay()
	if ov:
		ov.set_send_target(-1)


func _send_stamp(kind: String) -> void:
	if _stamp_target < 0:
		return
	cmds.send_stamp(state.local_player_id, _stamp_target, kind)
	# 押したときの短い効果音
	view.play_stamp_sound(kind)
	# 同じ相手には1ラウンド1回なので、送ったら閉じる
	_close_picker()


func _show_event(e: Dictionary) -> void:
	var me := state.local_player_id
	if e.get("private_to", me) != me:
		return # ほかの人だけが知るお知らせ(ホストの画面でも出さない)
	match e.get("type"):
		"minion":
			if e["actor"] == me:
				hud.show_popup_card(tr("あなたは鬼の手下!"), [tr("だまして +1点"), tr("鬼が勝てば +2点")],
						Color(0.55, 0.2, 0.7), tr("ほかの人にはないしょだよ"), 3.0)
		"minion_count":
			if int(e["count"]) >= 2:
				hud.show_message(tr("今回は手下が2人!\n(だれかはひみつ)"), Color(0.55, 0.2, 0.7), 2.2)
		"vote_result":
			var correct: Array = e.get("correct", [])
			hud.apply_vote_result(correct, e.get("scores", {}))
			if me in correct:
				hud.show_message(tr("手下を当てた! +%d点") % GameConfig.SCORE_VOTE_CORRECT, Color(0.1, 0.6, 0.4), 1.6)
				audio.play("win", -8.0)
			_update_help()
		"stamp":
			if e["target"] == me:
				hud.flash_stamp(WorldView.STAMP_COLORS[e["kind"]])
				view.play_stamp_sound(e["kind"])
				# 対応しているスマホ(主に Android)では短く震える
				Input.vibrate_handheld(150)
		"helped":
			if e["sender"] == me:
				hud.show_message(tr("教えた! +%d点\n(%s を助けた)") % [e["points"], _name(e["target"])], Color(0.1, 0.6, 0.4), 1.5)
				_update_help()
		"deceived":
			if e["sender"] == me:
				hud.show_message(tr("だました! +%d点\n(%s が引っかかった)") % [e["points"], _name(e["target"])], Color(0.6, 0.3, 0.8), 1.5)
				_update_help()
		"stamp_blocked":
			if e["sender"] == me:
				var why := {
					"neighbor": tr("となりの人には送れない"),
					"already": tr("この人には、このラウンドもう送った"),
					"full": tr("この人はスタンプがいっぱい(%d つ)\n鬼が進むと空く。また送れるよ") % GameConfig.STAMP_SLOTS,
				}
				hud.show_message(why.get(e.get("reason", ""), tr("いまは送れない")), Color(0.3, 0.3, 0.3), 1.4)
		"dropped":
			_last_sound = "本物"
		"rustle":
			_last_sound = "ニセ"
		"banana":
			var who := tr("あなた") if e["sender"] == me else _name(e["sender"])
			var whom := tr("鬼") if e["target"] == state.oni_id else tr("追う人")
			if e["target"] == me:
				whom = tr("あなた")
			hud.show_message(tr("%s が %s にバナナ!") % [who, whom], Color(0.85, 0.7, 0.0), 1.2)
		"slip":
			hud.show_message(tr("つるっ! %s が転んだ") % (tr("あなた") if e["actor"] == me else _name(e["actor"])), Color(0.85, 0.7, 0.0), 1.2)
		"no_looks":
			if e["actor"] == me:
				hud.show_message(tr("もう振り向けない!\n(1ラウンド%d回まで)") % GameConfig.LOOKS_PER_ROUND, Color(0.3, 0.3, 0.3), 1.2)
		"drop_failed":
			if e["actor"] == me:
				var empty: bool = e.get("reason", "") == "empty"
				hud.show_message(tr("空いた席には落とせない") if empty else tr("席の後ろで押してね"), Color(0.3, 0.3, 0.3), 1.0)
		"milk_failed":
			if e["actor"] == me:
				hud.show_message(tr("かける人をタップしてね"), Color(0.3, 0.3, 0.3), 1.0)
		"milk":
			if e["target"] == me:
				hud.show_message(tr("水鉄砲でかけられた!") if state.stage == "beach" else tr("牛乳かけられた!"), Color(0.3, 0.45, 0.7), 1.2)
			elif e["sender"] == me:
				hud.show_message((tr("%s に水鉄砲!") if state.stage == "beach" else tr("%s に牛乳!")) % _name(e["target"]), Color(0.3, 0.45, 0.7), 1.0)
		"out":
			if e["actor"] == me:
				hud.show_message(tr("お手つき!\n真ん中でお休み(このラウンド0点)"), Color(0.85, 0.1, 0.1), 2.0)
				_close_picker()
				_update_help()
		"auto_drop":
			if _i_am_oni():
				hud.show_message(tr("4周したので\n次の席で自動で落とす"), Color(0.3, 0.3, 0.3), 1.5)
		"found":
			if e["actor"] == me:
				hud.show_message(tr("あった!"), Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
		"picked_up":
			if e["actor"] == me:
				hud.show_message(tr("追いかけろ!\nスティックを左右に倒してよける"), Color(0.1, 0.5, 0.9), 2.2)
			elif _i_am_oni():
				hud.show_message(tr("気づかれた! 逃げろ!\nスティックを左右に倒してよける"), Color(0.85, 0.1, 0.1), 2.2)
			else:
				hud.show_message(tr("%s が追いかけた!") % _name(e["actor"]), Color(0.3, 0.3, 0.3), GameConfig.MESSAGE_TIME)
		"result":
			_play_result_sounds(e)
			_show_result(e)
		"match_over":
			audio.play("match_end", -2.0)
			_jingle_hold = 3.0
			_show_match_result()
		"round_start":
			# ラウンド開始: 学校のチャイムのような音
			audio.play("chime", -6.0)
		"blackout":
			# 停電イベント(音は WorldView が鳴らす)
			hud.show_message(tr("停電!"), Color(0.15, 0.15, 0.35), 1.8)
		"last_lap":
			# 鬼が最後の1周に入った合図
			audio.play("lap", -4.0)


## 勝敗の音: タッチ「パシッ✨」/座れた「ストン」、そのあと勝ち・負けのジングル(BGM は少し止める)
func _play_result_sounds(r: Dictionary) -> void:
	var me := state.local_player_id
	match r["reason"]:
		"touched":
			audio.play("touch", -2.0)
		"sat":
			audio.play("sit", -2.0)
	var jingle := "win" if r["winner"] == me else ("lose" if r["loser"] == me else "win")
	var vol := -4.0 if (r["winner"] == me or r["loser"] == me) else -10.0
	_jingle_hold = 2.6
	get_tree().create_timer(0.45).timeout.connect(func() -> void: audio.play(jingle, vol))


## ラウンドが終わった: 可愛い結果カード(見出し・一言・がまんや手下の発表・全員の点数)
func _show_result(r: Dictionary) -> void:
	var me := state.local_player_id
	var win := Color("FFB020")
	var lose := Color("6C8CFF")
	var plain := GameConfig.COLOR_ACCENT
	var title := ""
	var sub := ""
	var color := plain
	var winner := _name(r["winner"])
	var loser := _name(r["loser"])
	match r["reason"]:
		"touched":
			if r["winner"] == me:
				title = tr("タッチ成功!")
				sub = tr("鬼をつかまえた! やったね")
				color = win
			elif r["loser"] == me:
				title = tr("つかまっちゃった…")
				sub = tr("%s にタッチされた") % winner
				color = lose
			else:
				title = tr("タッチ!")
				sub = tr("%s が鬼をつかまえた!") % winner
		"sat":
			if r["winner"] == me:
				title = tr("セーフ!")
				sub = tr("空いた席にすわれた〜!")
				color = win
			elif r["loser"] == me:
				title = tr("すわられちゃった…")
				sub = tr("あとちょっとだったのに!")
				color = lose
			else:
				title = tr("鬼のかち!")
				sub = tr("%s の席にすわった!") % loser
		"missed":
			if r["loser"] == me:
				title = tr("気づかなかった〜!")
				sub = tr("うしろに落ちてたよ…")
				color = lose
			elif r["winner"] == me:
				title = tr("気づかれなかった!")
				sub = tr("%s はぜんぜん気づかなかった") % loser
				color = win
			else:
				title = tr("鬼のかち!")
				sub = tr("%s が気づかなかった!") % loser
		"all_out":
			if r["winner"] == me:
				title = tr("全員お手つき!")
				sub = tr("だれも残らなかった〜!")
				color = win
			else:
				title = tr("全員お手つき…")
				sub = tr("鬼のかち! みんな振り向きすぎ!")
	var notes := []
	# 手下は「手下はだれ?」のカードをめくると見られる
	# 手下が2人のときは、2人とも出る
	var minions: Array = r.get("minions", [])
	if minions.is_empty() and int(r.get("minion", -1)) >= 0:
		minions = [int(r["minion"])]
	var bonuses: Dictionary = r.get("minion_bonuses", {})
	var reveal := {}
	if not minions.is_empty():
		var people := []
		for m in minions:
			var ma := state.get_actor(m)
			people.append({
				"name": _short_name(m),
				"color": ma.color if ma else Color.WHITE,
				"is_me": m == me,
				"bonus": bool(bonuses.get(m, r.get("minion_bonus", false))),
			})
		reveal = {"people": people}
	# 手下を当てる投票(手下以外の全員。鬼も)。自分と鬼以外の札をタップできる
	var voting: bool = bool(r.get("voting", false))
	var can_vote := voting and not (me in minions)
	# 全員の点数(この試合の合計。点の多い順、このラウンドで増えた分つき)
	var scores: Dictionary = r.get("scores", state.scores)
	var ids := scores.keys()
	ids.sort_custom(func(a, b): return scores[a] > scores[b])
	var rows := []
	for id in ids:
		var row := _score_row_for(id, scores, true)
		if can_vote and id != me and id != state.oni_id:
			row["id"] = id
		rows.append(row)
	var vote := {"open": voting, "can_vote": can_vote}
	var last := state.round_index + 1 >= GameConfig.ROUNDS_PER_MATCH
	var next_text := tr("さいごの結果へ") if last else tr("次のラウンド(%s)へ") % Items.name_of(state.round_index + 1, state.stage)
	hud.hide_message()
	if r["winner"] == me:
		hud.confetti()
	if mode == Mode.GUEST:
		hud.show_result_card(title, sub, notes, color, rows, tr("ホストが「次へ」を押すと") + next_text, "", reveal, vote)
	else:
		hud.show_result_card(title, sub, notes, color, rows, "", tr("次へ ▶ ") + next_text, reveal, vote)


## 結果カードで、手下だと思う人に投票した
func _on_vote_pressed(target_id: int) -> void:
	if state.phase != GameState.Phase.RESULT:
		return
	hud.mark_my_vote(target_id)
	cmds.cast_vote(state.local_player_id, target_id)


## 札に出す短い名前(「ボット2(せっかち)」→「ボット2」、鬼は「鬼」)
func _short_name(id: int) -> String:
	if id == state.oni_id:
		return tr("鬼")
	var a := state.get_actor(id)
	if a == null:
		return "?"
	return Locale.actor_name(a.display_name)


func _name(id: int) -> String:
	if id == state.local_player_id:
		return tr("あなた")
	var a := state.get_actor(id)
	if a == null:
		return "?"
	# ボットの性格は、⚙メニューでオンにしたときだけ出す。ボットの名前は今の言語で
	return Locale.actor_name(a.display_name, Profile.show_personality)


## 画面の札(左上: ラウンド・落とし物・鬼の周回、右上: 全員の点数)を更新する。説明文は出さない
func _update_help() -> void:
	var me := state.get_local_player()
	if me == null:
		return
	var extra := ""
	if _i_am_oni() and state.phase == GameState.Phase.WALKING:
		var laps := int((state.oni_angle - state.oni_start_angle) / TAU) + 1
		extra = tr("鬼 %d周目(%d周で自動で落とす)") % [laps, GameConfig.ONI_MAX_LAPS_BEFORE_DROP]
	elif state.phase == GameState.Phase.CHASE:
		var laps_left := maxi(int(ceilf((state.oni_seat_angle - state.oni_angle) / TAU)), 1)
		extra = tr("鬼が座るまで あと%d周") % laps_left
	elif _i_am_oni():
		extra = tr("あなたは鬼")
	hud.set_round_info(tr("ラウンド %d/%d") % [state.round_index + 1, GameConfig.ROUNDS_PER_MATCH],
			tr("いまの落とし物:%s") % state.item_name(), extra, tr("あなた %d点") % state.scores.get(state.local_player_id, 0))


