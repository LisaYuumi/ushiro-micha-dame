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
	# GPU を使えていないブラウザでは、軽い動きにする(1秒30コマまで。CPU を休ませて、熱で遅くなるのを防ぐ)
	print("GPU: %s, light mode: %s" % [Device.gpu_name(), Device.light_mode()])
	if Device.light_mode():
		Engine.max_fps = 30
	# 音の出力の余裕(ブラウザの開発者ツールで確かめる用)
	print("audio output latency: %.3f s, mix rate: %d, smooth audio: %s" % [AudioServer.get_output_latency(), AudioServer.get_mix_rate(), Profile.smooth_audio()])
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
	hud.skip_vote_pressed.connect(_on_skip_vote)
	# 見逃しの演出
	view.missed_scene_done.connect(_on_missed_scene_done)
	lobby.solo_pressed.connect(_on_solo)
	lobby.host_pressed.connect(_on_host)
	lobby.join_pressed.connect(_on_join)
	lobby.start_pressed.connect(_on_host_start)
	lobby.language_pressed.connect(func() -> void: set_language(Locale.next_language()))
	# ロビーで名前・色・小物・スタンプの言葉を変えたら、部屋に入っているならホストに送り直す
	lobby.profile_changed.connect(func() -> void:
		if net.is_online and not net.is_host:
			net.send_profile(Profile.to_dict()))
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
	lobby.tutorial_pressed.connect(start_tutorial)
	if DisplayServer.get_name() == "headless":
		# 自動チェックのときは、すぐひとりで始める
		_on_solo()


# --- ロビー ---

# --- チュートリアル(はじめて遊ぶ人向け。オフライン・ボットだけ・教室) ---
var _tutorial: Tutorial


## チュートリアルを始める(ロビーか、ひとりで遊んでいるときだけ)
func start_tutorial() -> void:
	if mode == Mode.HOST or mode == Mode.GUEST or _tutorial:
		return
	mode = Mode.SOLO
	lobby.visible = false
	cmds = state
	_close_titles()
	hud.hide_result_card()
	_tutorial = Tutorial.new()
	add_child(_tutorial)
	_tutorial.finished.connect(_end_tutorial)
	_tutorial.setup(self)


## チュートリアルの場面: 教室・5人の新しい試合(player_oni = true なら自分が鬼)。ボットの名前は決まったもの
func tutorial_scene(player_oni: bool) -> void:
	state.stage = "classroom"
	state.custom_bot_names = []
	state.start_match(Tutorial.SEED, player_oni, Tutorial.SEAT_COUNT, Profile.player_name, Profile.color, Profile.accessories)
	_apply_stamp_words(true)
	# 手下のお知らせなどは出さない(台本で決める)
	state.take_events()
	_refresh_round()
	hud.hide_message()
	hud.hide_result_card()
	audio.play("chime", -6.0)


## チュートリアルが終わった(completed = 最後まで / false = スキップ): 端末に覚えて、ロビーへもどる
func _end_tutorial(completed: bool) -> void:
	Profile.tutorial = maxi(Profile.tutorial, 2 if completed else 1)
	Profile.save()
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
	_tutorial = null
	state.scripted = false
	back_to_lobby()


## ロビーにもどる(ひとりで遊んでいるとき)
func back_to_lobby() -> void:
	if mode == Mode.HOST or mode == Mode.GUEST:
		return
	mode = Mode.LOBBY
	_close_titles()
	_close_picker()
	hud.hide_result_card()
	hud.hide_message()
	hud.set_vote_ui(false)
	hud.set_next_ui(false, false)
	if _reveal and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null
	state.start_match(-1, false)
	_refresh_round()
	lobby.visible = true
	lobby.show_menu()

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
	state.custom_bot_names = Profile.active_bot_names()
	state.start_match_custom(-1, humans, first_oni, names, true, _seats, colors, accs)
	mode = Mode.HOST
	_apply_stamp_words(true)
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
		# この試合の言葉はホストに送ってある。次の試合の言葉を引いて、ホストに送っておく
		Profile.roll_next_words()
		lobby.refresh_texts()
		net.send_profile(Profile.to_dict())
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
	state.custom_bot_names = Profile.active_bot_names()
	state.start_match(-1, _player_is_oni, _seats, Profile.player_name, Profile.color, Profile.accessories)
	_apply_stamp_words(true)
	_refresh_round()


## 3D の画面を作り直す。舞台が海辺なら、牛乳のボタンと画面の白いたれを水鉄砲・水しぶきにする
func _build_view() -> void:
	view.build(state)
	var water := state.stage == "beach"
	var tool := "water" if water else ("camera" if state.stage == "night" else "eraser")
	hud.set_tool(tool)
	touch.set_tool(tool)
	# 「落とす」「フェイク」のボタンの絵は、このラウンドの落とし物
	touch.set_item_icon(ButtonIcon.item_key(state.stage, state.round_index))
	# 送るボタンの言葉(参加者は、ホストから届いた自分の言葉)
	_update_send_words()


## ラウンドが変わったときに、画面とボットを作り直す
func _refresh_round() -> void:
	var t0 := Time.get_ticks_usec()
	_refresh_round_inner()
	print("round rebuild %dms" % ((Time.get_ticks_usec() - t0) / 1000))


func _refresh_round_inner() -> void:
	_seen_serial = state.round_serial
	_close_titles()
	_my_vote = -1
	if _reveal and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null
	hud.set_vote_ui(false)
	hud.set_next_ui(false, false)
	hud.hide_result_card()
	bots.reset()
	_missed_result = {}
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
	var t0 := Time.get_ticks_usec()
	var slow := []
	_look_tame()
	PlayerInput.apply(state, cmds, view.get_camera_basis())
	_update_milk()
	if mode != Mode.GUEST:
		# ルールを動かすのは、ひとりのときとホストだけ(チュートリアルの間は、ボットは台本どおり)
		if _tutorial:
			_tutorial.update(delta)
		else:
			bots.update(state, delta)
		state.tick(delta)
		var t1 := Time.get_ticks_usec()
		if t1 - t0 > 8000:
			slow.append("tick %dms" % ((t1 - t0) / 1000))
		var events := state.take_events()
		for e in events:
			var te := Time.get_ticks_usec()
			view.on_event(e)
			if _tutorial:
				_tutorial.on_event(e)
			else:
				bots.on_event(state, e)
			_show_event(e)
			_update_help()
			var ms := (Time.get_ticks_usec() - te) / 1000
			if ms >= 8:
				slow.append("%s %dms" % [e.get("type", "?"), ms])
		if mode == Mode.HOST:
			_send_to_guests(events, delta)
		# 発表のあと、自動で次のラウンドになった: 画面を作り直す
		if state.round_serial != _seen_serial and not state.match_over:
			_refresh_round()
			hud.show_message(tr("ラウンド %d: %s") % [state.round_index + 1, state.item_name()], Color(0.3, 0.3, 0.3), 2.0)
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
	# 手下の間は、画面の四すみに紫のカギ形を出す(途中で自分が手下か忘れないように)
	hud.set_minion_mark(state.is_minion(me.id) and state.phase != GameState.Phase.RESULT and not out)
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
	# 手下を当てる投票(教室のまま)と発表: 少し高いところから全員を映し、名札を出す
	var voting := showing_result and state.voting_open and not state.match_over
	var revealing := showing_result and not state.voting_open and state.reveal_left >= 0.0 and not state.match_over
	view.set_vote_view(voting or revealing)
	# 発表が終わったら、ルーム主が「次へ」を押すまで、手下が出た画面のまま待つ
	var waiting_next := state.can_go_next()
	if voting:
		var hint := tr("あやしい人をタップして投票!")
		if state.is_minion(me.id):
			hint = tr("あなたは手下。バレないように!")
		elif _my_vote >= 0:
			hint = tr("%s に投票した(入れ直せる)") % _short_name(_my_vote)
		hud.set_vote_ui(true, state.votes.size(), state.voter_count(), hint, mode != Mode.GUEST, state.can_skip_vote())
	elif waiting_next and _tutorial == null:
		hud.set_next_ui(true, mode != Mode.GUEST)
	else:
		hud.set_vote_ui(false)
		hud.set_next_ui(false, false)
	var ov := view.get_overlay()
	if ov:
		# 牛乳がかかっている間は名札も見えない(鬼の名札で場所がわからないように)。吹き出しは出したまま
		# (夜の教室のフラッシュは、まぶしい間は言葉の吹き出しも見えない)
		# (お手つきで自分の顔を大きく映している間は、名札が顔にかぶらないように隠す)
		ov.visible = (not showing_result or voting or revealing) and not _play_ui_hidden and not view.self_close_up and not view.in_ceremony()
		ov.set_tags_hidden(state.is_milked(me) and not showing_result)
		ov.set_bubbles_hidden(_flashed(me) and not showing_result)
		if showing_result:
			ov.set_voted(state.votes.keys() if voting else [])
			ov.set_send_target(_my_vote if voting else -1, tr("あなたの票"))
	# 左上の札(鬼の周回・自分の点数)を毎回更新する(参加者の点数は状態といっしょに届く)
	_update_help()
	# 重かったときは、何をしていたかをコンソールに出す(調べる用)
	_perf_phys_us += Time.get_ticks_usec() - t0
	_perf_phys_n += 1
	var total := (Time.get_ticks_usec() - t0) / 1000
	if total >= 25:
		print("slow physics %dms: %s" % [total, ", ".join(slow)])


## 振り向く瞬間のタメ: 「振り向く」を押した瞬間に「ザッ…」と集中線(見た目と音だけ。
## 当たり・ハズレの判定や立ち上がりは、押した瞬間のまま遅らせない)
func _look_tame() -> void:
	if not (Input.is_action_just_pressed("look_back") or Input.is_action_just_pressed("pick_up")):
		return
	var me := state.get_local_player()
	if me == null or me.role != GameState.Role.SEATED or me.looking_back:
		return
	var judged := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	if judged and me.looks_left <= 0:
		return
	audio.play("look_zah", -2.0)
	if judged:
		hud.speed_lines()


## BGM: ロビー・結果は明るい曲、ラウンド中は控えめな曲(ラウンドが進むほど楽器が増える)、追いかけっこは速い曲。
## 鬼との距離では変えない(BGM で鬼の場所がわからないように)
func _update_music(delta: float) -> void:
	_jingle_hold = maxf(_jingle_hold - delta, 0.0)
	var want := "bgm_lobby"
	if _title_reveal and is_instance_valid(_title_reveal) and _studio == null:
		# 試合の終わり: 行進曲で盛り上げて、記念写真で明るい曲(途切れさせない)
		want = "bgm_photo" if _title_reveal.is_done() else "bgm_ending"
	elif mode != Mode.LOBBY and _studio == null:
		match state.phase:
			GameState.Phase.WALKING, GameState.Phase.DROPPED:
				# 教室は小学校っぽい曲(リコーダー・木琴・鍵盤ハーモニカ)、海辺はハワイアン、夜の教室はちょっと怖い曲
				var fmt := {"beach": "bgm_beach_%d", "night": "bgm_night_%d"}.get(state.stage, "bgm_school_%d") as String
				want = fmt % _round_level()
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
## 5秒の間の合計(マイクロ秒): 3D の動きの更新(sync)・ゲームの進行(physics)
var _perf_sync_us := 0
var _perf_phys_us := 0
var _perf_phys_n := 0


func _log_perf(delta: float) -> void:
	_perf_frames += 1
	_perf_worst = maxf(_perf_worst, delta)
	_perf_left -= delta
	if _perf_left > 0.0:
		return
	# いまの場面(重くなったときに、何をしていたかわかるように)
	var scene := "lobby"
	if not lobby.visible:
		scene = str(GameState.Phase.keys()[state.phase]).to_lower()
		if state.blackout:
			scene += "+blackout"
		var me := state.get_local_player()
		if me and state.is_milked(me):
			scene += "+milk"
	print("perf [%s] fps=%d worst=%.0fms sync=%.1fms game=%.1fms process=%.1fms physics=%.1fms draws=%d objects=%d prims=%dk nodes=%d" % [
		scene, Engine.get_frames_per_second(), _perf_worst * 1000.0,
		float(_perf_sync_us) / 1000.0 / maxf(_perf_frames, 1),
		float(_perf_phys_us) / 1000.0 / maxf(_perf_phys_n, 1),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_perf_left = 5.0
	_perf_frames = 0
	_perf_worst = 0.0
	_perf_sync_us = 0
	_perf_phys_us = 0
	_perf_phys_n = 0


## 重い機種で 3D の細かさを自動で下げる(画面が細かいスマホなどだけ)
var _aq_step := 0
var _aq_time := 0.0
var _aq_frames := 0


func _auto_quality(delta: float) -> void:
	if lobby.visible or _studio or _aq_step >= GameConfig.AUTO_QUALITY_STEPS.size() - 1:
		return
	_aq_time += delta
	_aq_frames += 1
	if _aq_time < GameConfig.AUTO_QUALITY_WINDOW:
		return
	var fps := _aq_frames / _aq_time
	_aq_time = 0.0
	_aq_frames = 0
	if fps >= GameConfig.AUTO_QUALITY_FPS:
		return
	# 画面が細かい(スマホなど)ときだけ下げる。GPU を使えていない PC では、粗く描いて引きのばすと
	# かえって重くなり音も割れたことがあるので、下げない(docs/AI_BRIEF.md)
	if Device.pixel_ratio() < 1.5 or Device.light_mode():
		return
	_aq_step += 1
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = GameConfig.AUTO_QUALITY_STEPS[_aq_step]
	print("auto quality: fps=%.0f -> 3D scale %.2f (pixel ratio %.1f)" % [fps, vp.scaling_3d_scale, Device.pixel_ratio()])


func _process(delta: float) -> void:
	_log_perf(delta)
	_auto_quality(delta)
	if _play_ui_hidden and _hold_start >= 0 and Time.get_ticks_msec() - _hold_start > 800:
		_hold_start = -1
		_set_play_ui_hidden(false)
	_update_music(delta)
	if _titles_wait > 0.0:
		_titles_wait -= delta
		if _titles_wait <= 0.0 and state.match_over:
			_open_titles()
	if _studio:
		return
	# ロビーの間は、後ろの3D(教室)を描かない(水色の幕でほとんど見えないのに重いので)
	var show_3d := not lobby.visible
	if view.visible != show_3d:
		view.set_shown(show_3d)
	var ts := Time.get_ticks_usec()
	view.sync(state, delta)
	_perf_sync_us += Time.get_ticks_usec() - ts
	var sync_ms := (Time.get_ticks_usec() - ts) / 1000
	if sync_ms >= 25:
		print("slow sync %dms" % sync_ms)


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
## 夜の教室のフラッシュでまぶしい間か(言葉も見えない)
func _flashed(me: GameState.Actor) -> bool:
	return state.is_night() and state.is_milked(me)


func _update_my_stamps() -> void:
	var list := []
	var me := state.get_local_player()
	if me and _flashed(me) and state.phase != GameState.Phase.RESULT:
		# フラッシュでまぶしい間は、自分に届いた言葉も見えない(消えるのではなく、見えないだけ)
		hud.show_my_stamps(list)
		return
	for st in state.active_stamps.get(state.local_player_id, []):
		list.append({
			"kind": st["kind"],
			"text": HeadOverlay.stamp_text(state, st["sender"], st["kind"]),
			"sender": HeadOverlay.sender_name(state, st["sender"]),
			"sender_color": HeadOverlay.sender_color(state, st["sender"]),
		})
	hud.show_my_stamps(list)

## 見逃しの演出が終わった(またはタップでとばした): 結果の音と見出し
var _missed_result := {}
## 投票: 自分が入れた人(印を出す。入れ直せる)と、発表の演出
var _my_vote := -1
var _reveal: VoteReveal
## ルールを動かす人(ひとり・ホスト)が、最後に画面を作ったラウンド(発表のあと自動で次のラウンドになったら作り直す)
var _seen_serial := -1


## ルーム主の「発表へ」(投票が始まって5秒たってから押せる)と、発表のあとの「次へ」
func _on_skip_vote() -> void:
	if mode == Mode.GUEST:
		return
	if state.voting_open:
		state.skip_vote()
	elif state.can_go_next():
		_on_restart_pressed()


func _on_missed_scene_done() -> void:
	if _missed_result.is_empty():
		return
	var e := _missed_result
	_missed_result = {}
	_play_result_sounds(e)
	_show_result(e)


## 見逃しの演出中は、画面のどこをタップしてもとばせる
func _input(event: InputEvent) -> void:
	_check_ui_hold(event)
	if not view.is_missed_scene_playing():
		return
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tap:
		view.skip_missed_scene()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _studio:
		return
	if event.is_action_pressed("hide_ui") and mode != Mode.LOBBY:
		_set_play_ui_hidden(not _play_ui_hidden)
	elif event.is_action_pressed("photo_mode"):
		_open_studio()
	elif event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif _tutorial and (event.is_action_pressed("restart") or event.is_action_pressed("toggle_role")
			or event.is_action_pressed("debug_finish") or event.is_action_pressed("debug_blackout_next")):
		# チュートリアルの間は、やり直し・役の切りかえなどは使えない(台本が崩れるので)
		return
	elif event.is_action_pressed("tutorial"):
		if mode == Mode.HOST or mode == Mode.GUEST:
			hud.show_message(tr("チュートリアルは、ひとりのときに遊べます"), Color(0.3, 0.3, 0.3), 1.5)
		else:
			start_tutorial()
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
	elif state.phase == GameState.Phase.RESULT and (state.voting_open or state.vote_wait > 0.0):
		# (確認用のキー: 投票をすぐ締めきって発表へ)
		state.close_vote()
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


## 試合が終わった: 順位のカード(1位に★)を見せてから、称号の発表(TitleReveal)。
## ホストは next_round と match_over のお知らせの両方から呼ばれるので、1試合に1回だけ
var _title_reveal: TitleReveal
var _titles_wait := -1.0
var _match_shown_serial := -1


func _show_match_result() -> void:
	if _match_shown_serial == state.round_serial:
		return
	_match_shown_serial = state.round_serial
	# 手下の発表の表示(投票の矢印・指マーク・「だましきった!」などの吹き出し・スポットライト)は、ここで全部消す
	if _reveal and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null
	view.set_vote_view(false)
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
		row["title_id"] = ids[i]
		rows.append(row)
	hud.hide_message()
	# 試合の終わりの演出(試合終了 → 表彰台 → 称号発表 → 記念写真。TitleReveal)を、そのまま始める
	_title_rows = rows
	_open_titles()


var _title_rows: Array = []


## 称号の発表を始める(点数のカードと入れかえ)
func _open_titles() -> void:
	_close_titles()
	hud.hide_result_card()
	hud.hide_message()
	if _reveal and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null
	_title_reveal = TitleReveal.new()
	add_child(_title_reveal)
	if mode == Mode.GUEST:
		_title_reveal.setup(view, state, _title_rows, state.titles, "", tr("ホストが「次へ」を押すと新しい試合"))
	else:
		_title_reveal.setup(view, state, _title_rows, state.titles, tr("新しい試合へ ▶"), "")
	_title_reveal.next_pressed.connect(hud._press_next)
	# ルーム主の「スキップ」: 全員が記念写真へ(お知らせで参加者にも送る)
	_title_reveal.skip_pressed.connect(func() -> void:
		if mode != Mode.GUEST:
			state.events.append({"type": "ending_skip"}))
	# 称号発表と記念写真の間は、ゲームのボタンや札を隠す(スクショがきれいに撮れるように)
	_set_ui_tree_visible(hud, false)
	_set_ui_tree_visible(touch, false)


func _close_titles() -> void:
	_titles_wait = -1.0
	if _title_reveal and is_instance_valid(_title_reveal):
		_title_reveal.queue_free()
		_set_ui_tree_visible(hud, not _play_ui_hidden)
		_set_ui_tree_visible(touch, not _play_ui_hidden)
	_title_reveal = null
	view.ceremony_end()


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


## 遊んでいる画面の UI を全部消す(撮影用: スクリーンショット・紹介動画)。見た目だけで、ゲームの進行は変わらない。
## PC は H キー、スマホは⚙メニューから。消している間は、画面を長押し(0.8秒)すると戻る
var _play_ui_hidden := false
var _hold_start := -1
var _hold_pos := Vector2.ZERO


func _set_play_ui_hidden(v: bool) -> void:
	_play_ui_hidden = v
	_set_ui_tree_visible(hud, not v)
	_set_ui_tree_visible(touch, not v)
	if _reveal and is_instance_valid(_reveal):
		_reveal.visible = not v
	var ov := view.get_overlay()
	if ov:
		ov.visible = not v
	if v:
		touch.close_menu()


## CanvasLayer を、中に入っている CanvasLayer(上に重ねる札など)もまとめて出す/隠す
## (CanvasLayer の visible は、中の CanvasLayer には効かないので)
func _set_ui_tree_visible(layer: CanvasLayer, v: bool) -> void:
	layer.visible = v
	for c in layer.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = v


## UI を消している間の長押し(スマホで戻すため)
func _check_ui_hold(event: InputEvent) -> void:
	if not _play_ui_hidden:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		_hold_start = Time.get_ticks_msec() if t.pressed else -1
		_hold_pos = t.position
	elif event is InputEventScreenDrag and _hold_start >= 0:
		if (event as InputEventScreenDrag).position.distance_to(_hold_pos) > 30.0:
			_hold_start = -1


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
	_set_ui_tree_visible(hud, false)
	_set_ui_tree_visible(touch, false)
	if _reveal and is_instance_valid(_reveal):
		_reveal.visible = false
	if _title_reveal and is_instance_valid(_title_reveal):
		_title_reveal.visible = false
	_lobby_was_visible = lobby.visible
	lobby.visible = false


func _close_studio() -> void:
	if _studio == null:
		return
	_studio.queue_free()
	_studio = null
	view.set_shown(true)
	_set_ui_tree_visible(hud, not _play_ui_hidden)
	_set_ui_tree_visible(touch, not _play_ui_hidden)
	if _reveal and is_instance_valid(_reveal):
		_reveal.visible = not _play_ui_hidden
	if _title_reveal and is_instance_valid(_title_reveal):
		_title_reveal.visible = true
	lobby.visible = _lobby_was_visible


## 画面をタップした: スタンプの選択肢を押した/人(か名札)をタップした/外をタップした
func _on_tap(pos: Vector2) -> void:
	var ov := view.get_overlay()
	if ov == null:
		return
	# 手下を当てる投票: 人(か名札)をタップすると、その人に投票(全員がそろうまで入れ直せる)
	if state.phase == GameState.Phase.RESULT:
		var me_id := state.local_player_id
		if state.voting_open and state.can_vote(me_id):
			var vid := ov.tag_hit(pos)
			if vid < 0:
				vid = view.pick_any_actor(state, pos)
			if vid in state.vote_candidates(me_id):
				_my_vote = vid
				AudioDirector.click()
				cmds.cast_vote(me_id, vid)
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
		if _tutorial and not _tutorial.allows_milk():
			return
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
	# チュートリアル中は、言われた人にだけ送れる
	if _tutorial and not _tutorial.allows_stamp_target(id):
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


## スタンプの言葉を状態に入れる(ひとり・ホストだけ。参加者の分はロビーで届いた言葉を、もう一度チェックして使う)。
## new_match: 試合の初めだけ、言葉(シャッフルの番号・自作の言葉)を決める。試合の途中では変えない。
## 決めたら、次の試合の言葉を引いておく(ロビーに出る。自作の言葉を入れている人は引き直さない)
func _apply_stamp_words(new_match: bool = false) -> void:
	if mode != Mode.GUEST:
		var me := state.local_player_id
		if new_match:
			state.stamp_words[me] = Profile.stamp_words.duplicate()
			state.stamp_picks[me] = Profile.stamp_pick.duplicate()
			for pid in _peer_actor:
				var prof: Dictionary = _peer_profile.get(pid, {})
				state.stamp_words[_peer_actor[pid]] = Profile.clean_words(prof.get("words", {}))
				state.stamp_picks[_peer_actor[pid]] = Texts.clean_pick(prof.get("pick", {}))
			Profile.roll_next_words()
			lobby.refresh_texts()
		state.stamp_langs[me] = Locale.current()
		for pid in _peer_actor:
			var prof2: Dictionary = _peer_profile.get(pid, {})
			state.stamp_langs[_peer_actor[pid]] = Locale.pick(str(prof2.get("lang", "")))
	_update_send_words()


## 送るボタンの言葉: この試合の自分の言葉(自作の言葉があればそれ、なければシャッフルの言葉)
func _update_send_words() -> void:
	var me := state.local_player_id
	var custom: Dictionary = state.stamp_words.get(me, {})
	var pick: Dictionary = state.stamp_picks.get(me, Profile.stamp_pick)
	var words := {}
	for kind in Stamps.ALL:
		var w := str(custom.get(kind, ""))
		words[kind] = w if w != "" else Texts.stamp_word(kind, int(pick.get(kind, 0)))
	hud.set_send_words(words)


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
	if _tutorial and not (_tutorial.allows_stamp_target(_stamp_target) and _tutorial.allows_stamp_kind(kind)):
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
		"vote_start":
			_my_vote = -1
		"vote_result":
			# 発表: 票が飛ぶ → ため → 手下にスポットライト → 点数(このあと自動で次のラウンドへ)
			_my_vote = -1
			if _reveal and is_instance_valid(_reveal):
				_reveal.queue_free()
			_reveal = VoteReveal.new()
			add_child(_reveal)
			_reveal.setup(state, e, view, view.get_overlay())
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
			if e["actor"] == me and _tutorial:
				# チュートリアル: 「拾おう」と言うまでは振り向けない
				hud.show_message(tr("まだだよ!みんなの言葉を待とう"), Color(0.3, 0.3, 0.3), 1.2)
			elif e["actor"] == me:
				hud.show_message(tr("もう振り向けない!\n(1ラウンド%d回まで)") % GameConfig.LOOKS_PER_ROUND, Color(0.3, 0.3, 0.3), 1.2)
		"drop_failed":
			if e["actor"] == me:
				var empty: bool = e.get("reason", "") == "empty"
				hud.show_message(tr("空いた席には落とせない") if empty else tr("席の後ろで押してね"), Color(0.3, 0.3, 0.3), 1.0)
		"milk_failed":
			if e["actor"] == me:
				hud.show_message(tr("かける人をタップしてね"), Color(0.3, 0.3, 0.3), 1.0)
		"milk":
			if state.stage == "night":
				# 夜の教室: カメラのフラッシュ
				if e["target"] == me:
					hud.show_message(tr("フラッシュでまぶしい!"), Color(0.3, 0.45, 0.7), 1.2)
				elif e["sender"] == me:
					hud.show_message(tr("%s をパシャッ!") % _name(e["target"]), Color(0.3, 0.45, 0.7), 1.0)
			elif e["target"] == me:
				hud.show_message(tr("水鉄砲でかけられた!") if state.stage == "beach" else tr("黒板消しでポンポンされた!"), Color(0.3, 0.45, 0.7), 1.2)
			elif e["sender"] == me:
				hud.show_message((tr("%s に水鉄砲!") if state.stage == "beach" else tr("%s を黒板消しでポンポン!")) % _name(e["target"]), Color(0.3, 0.45, 0.7), 1.0)
		"out":
			if e["actor"] == me:
				# ハズレ: 「ガーン!」(画面のゆれと音は WorldView)。そのあと、どうなったかの説明
				hud.show_banner(tr("ガーン!"), Color("6EA8F0"), 0.9)
				# 自分の顔のアップと崩れ落ちるところを見せてから、説明を出す
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					hud.show_message(tr("お手つき!\n真ん中でお休み(このラウンド0点)"), Color(0.85, 0.1, 0.1), 1.6))
				_close_picker()
				_update_help()
		"auto_drop":
			if _i_am_oni():
				hud.show_message(tr("4周したので\n次の席で自動で落とす"), Color(0.3, 0.3, 0.3), 1.5)
		"found":
			if e["actor"] == me:
				# 当たり: 画面の上のほうに「あったー!!」(0.5秒。前の障害物が見えるように上のほう)
				hud.show_banner(tr("あったー!!"), Color("FFB020"), 0.5)
		"picked_up":
			if e["actor"] == me:
				# 「あったー!!」が消えたら、上のほうに小さく操作の案内(まん中には出さない: 前が見えるように)
				get_tree().create_timer(0.5).timeout.connect(func() -> void:
					if state.phase == GameState.Phase.CHASE:
						hud.show_banner(tr("追いかけろ!\nスティックを左右に倒してよける"), Color(0.1, 0.5, 0.9), 1.8, 34))
			elif _i_am_oni():
				hud.show_message(tr("気づかれた! 逃げろ!\nスティックを左右に倒してよける"), Color(0.85, 0.1, 0.1), 2.2)
			else:
				hud.show_message(tr("%s が追いかけた!") % _name(e["actor"]), Color(0.3, 0.3, 0.3), GameConfig.MESSAGE_TIME)
		"result":
			if e.get("reason", "") == "missed":
				# 見逃し: トントン → 振り向く → 放心 → 答え合わせ → とぼとぼ のあとに、結果カード(タップでとばせる)
				_missed_result = e
				# 答え合わせのリプレイの最後に出す、このラウンドで入った点数
				var gains := {}
				var sc: Dictionary = e.get("scores", state.scores)
				for id in sc:
					gains[id] = int(sc[id]) - int(_round_start_scores.get(id, sc[id]))
				e["round_gains"] = gains
				view.play_missed_scene(state, e)
			else:
				_play_result_sounds(e)
				_show_result(e)
		"match_over":
			_show_match_result()
		"ending_skip":
			# ルーム主が試合の終わりの演出をスキップした: 記念写真へ
			if _title_reveal and is_instance_valid(_title_reveal):
				_title_reveal.jump_to_photo()
		"round_start":
			# ラウンド開始: 学校のチャイムのような音
			# (海辺はスチールドラムのジングル)
			audio.play("beach_start" if state.stage == "beach" else "chime", -6.0)
		"lightning":
			# 夜の教室の雷(音と光は WorldView)。一瞬だけ、暗い席のうしろも見える
			hud.show_message(tr("カミナリ!"), Color(0.25, 0.3, 0.6), 1.2)
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


## ラウンドが終わった: 結果のページは出さず、教室のまま見出しと一言をポンと出す(このあと手下を当てる投票)
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
	hud.hide_message()
	if r["winner"] == me:
		hud.confetti()
	hud.show_banner(title, color, GameConfig.VOTE_INTRO_TIME - 0.2, 72)
	hud.show_message(sub, Color(0.3, 0.3, 0.3), GameConfig.VOTE_INTRO_TIME - 0.2)


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


