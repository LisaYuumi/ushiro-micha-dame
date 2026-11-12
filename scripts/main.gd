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

const SNAPSHOT_INTERVAL := 0.05

@onready var view: WorldView = $WorldView
@onready var hud: Hud = $Hud
@onready var touch: TouchControls = $TouchControls
@onready var net: NetSession = $Net
@onready var lobby: Lobby = $Lobby


func _ready() -> void:
	InputSetup.register()
	state = GameState.new()
	cmds = state
	# 後ろに見える教室だけ先に作っておく(ロビーの背景)
	state.start_match(-1, false)
	view.build(state)
	lobby.solo_pressed.connect(_on_solo)
	lobby.host_pressed.connect(_on_host)
	lobby.join_pressed.connect(_on_join)
	lobby.start_pressed.connect(_on_host_start)
	net.status_changed.connect(lobby.set_status)
	net.peers_changed.connect(_on_peers_changed)
	net.connected_to_host.connect(func() -> void:
		net.send_profile(Profile.to_dict())
		lobby.show_waiting("つながりました! ホストがスタートするのを待っています"))
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
	lobby.show_host("(作成中)", 1)
	net.status_changed.connect(func(_t: String) -> void:
		if net.is_host and mode == Mode.LOBBY:
			lobby.show_host(net.room_code, 1 + multiplayer.get_peers().size()))


func _on_join(code: String) -> void:
	net.join_room(code)
	lobby.show_waiting("部屋 %s をさがしています…" % code)


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
				hud.show_message("%s が抜けたのでボットが代わります" % (a.display_name if a else "?"), Color(0.3, 0.3, 0.3), 2.0)


## ホストが「スタート」: 人は id 0(ホスト)から順に、残りはボット。最初の鬼は人からランダム
func _on_host_start() -> void:
	var peers := multiplayer.get_peers()
	var max_humans := _seats + 1
	_peer_actor.clear()
	var humans := [0]
	var names := {0: Profile.player_name}
	var colors := {0: Profile.color}
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
		next_id += 1
	var first_oni: int = humans[randi_range(0, humans.size() - 1)]
	state.start_match_custom(-1, humans, first_oni, names, true, _seats, colors)
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
		hud.show_message("スタート!", Color(0.3, 0.3, 0.3), 1.0)
	elif info.get("late", false):
		lobby.show_waiting("つながりました! いまは試合中です。\n次の試合から参加できます(ホストが新しい試合を始めるまで待ってください)")
	else:
		lobby.show_waiting("つながりました! いま %d人。ホストがスタートするのを待っています" % info.get("players", 0))


func _on_host_lost() -> void:
	if mode == Mode.GUEST:
		hud.show_message("ホストとの通信が切れました\nページを読み込み直してください", Color(0.85, 0.1, 0.1), 0.0)


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
		"set_oni_stop":
			state.set_oni_stop(id, bool(args[0]))
		"set_move":
			state.set_move(id, args[0])
		"pick_up":
			state.pick_up(id)
		"oni_drop":
			state.oni_drop(id)
		"oni_feint":
			state.oni_feint(id)
		"oni_voice":
			state.oni_voice(id, str(args[0]))
		"throw_banana":
			state.throw_banana(id, int(args[0]))
		"send_stamp":
			state.send_stamp(id, int(args[0]), str(args[1]))


# --- 試合 ---

func _i_am_oni() -> bool:
	return state.oni_id == state.local_player_id


## 新しい試合を始める(ひとりのとき。ホストは「スタート」から)
func _start_round() -> void:
	if mode == Mode.HOST:
		_on_host_start()
		return
	state.start_match(-1, _player_is_oni, _seats, Profile.player_name, Profile.color)
	_refresh_round()


## ラウンドが変わったときに、画面とボットを作り直す
func _refresh_round() -> void:
	bots.reset()
	_round_start_scores = state.scores.duplicate()
	touch.set_oni_mode(_i_am_oni())
	_last_sound = ""
	_stamp_target = -1
	hud.show_my_stamps([])
	hud.hide_message()
	view.build(state)
	_update_help()


func _physics_process(delta: float) -> void:
	if mode == Mode.LOBBY:
		return
	if mode == Mode.GUEST and _built_serial < 0:
		return # まだ最初の状態が届いていない
	PlayerInput.apply(state, cmds, view.get_camera_basis())
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
	if state.get_actor(_stamp_target) == null or state.get_actor(_stamp_target).role != GameState.Role.SEATED:
		_stamp_target = -1
	view.set_stamp_target(state, _stamp_target)
	var me := state.get_local_player()
	if me == null:
		return
	_update_my_stamps()
	hud.set_role_badge("あなたは鬼の手下" if state.minion_id == me.id \
			and state.phase != GameState.Phase.RESULT else "", Color(0.55, 0.2, 0.7))
	var judged := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	touch.set_looks_left(me.looks_left if judged else -1)
	touch.set_oni_mode(_i_am_oni(),
			me.role == GameState.Role.SEATED and state.phase == GameState.Phase.CHASE)
	touch.set_stick_visible(me.role != GameState.Role.SEATED)
	if _i_am_oni():
		# 何周目かの表示を更新する
		_update_help()


func _process(delta: float) -> void:
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
			"text": Stamps.LABELS[st["kind"]].trim_suffix("!"),
			# 「見ろ」は「!」、「まだ平気」は「○」
			"mark": "!" if Stamps.says_look(st["kind"]) else "○",
			"color": WorldView.STAMP_COLORS[st["kind"]],
			"sender": _short_name(st["sender"]),
			"sender_color": sender.color if sender else Color.WHITE,
		})
	hud.show_my_stamps(list)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		if mode == Mode.GUEST:
			hud.show_message("次へ進むのはホストです", Color(0.3, 0.3, 0.3), 1.2)
		elif mode != Mode.LOBBY:
			_on_restart_pressed()
	elif event.is_action_pressed("toggle_role"):
		if mode != Mode.SOLO:
			hud.show_message("オンラインでは、鬼は負けた人がやります", Color(0.3, 0.3, 0.3), 1.5)
			return
		# 最初の鬼を自分にするかどうかを切りかえて、新しい試合を始める
		_player_is_oni = not _player_is_oni
		_start_round()
		hud.show_message("あなたが鬼で新しい試合" if _player_is_oni else "座る側で新しい試合", Color(0.3, 0.3, 0.3), 1.2)
	elif event.is_action_pressed("toggle_personality"):
		Profile.load_saved()
		Profile.show_personality = not Profile.show_personality
		Profile.save()
		view.build(state)
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
		# 画面に映っている人をタップ/クリックすると、スタンプを送る相手になる
		var pos := Vector2(-1, -1)
		if event is InputEventScreenTouch and event.pressed:
			pos = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
		if pos.x >= 0.0:
			var id := view.pick_actor_at(state, pos)
			if id >= 0:
				if state.stamp_block_reason(state.local_player_id, id) == "neighbor":
					hud.show_message("となりの人にはスタンプを送れない\n(8人のとき)", Color(0.3, 0.3, 0.3), 1.2)
					return
				_stamp_target = id
				_update_help()


## 「次へ・やり直し」: 勝敗が出ていれば次のラウンドへ、試合が終わっていれば新しい試合、
## ラウンドの途中なら、そのラウンドをやり直す
func _on_restart_pressed() -> void:
	if state.match_over:
		_start_round()
	elif state.phase == GameState.Phase.RESULT:
		if state.next_round():
			_refresh_round()
			var msg := "ラウンド %d: %s" % [state.round_index + 1, state.item_name()]
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
		row["mark"] = "★" if rank == 1 else "%d位" % rank
		rows.append(row)
	var me_first: bool = state.scores.get(state.local_player_id, 0) == state.scores[ids[0]]
	var title := "ゆうしょう!" if me_first else "試合おわり!"
	var sub := "あなたがいちばん!" if me_first else "いちばんは %s!" % top_name
	hud.hide_message()
	if mode == Mode.GUEST:
		hud.show_result_card(title, sub, [], GameConfig.COLOR_ACCENT, rows, "ホストが「次へ」を押すと新しい試合")
	else:
		hud.show_result_card(title, sub, [], GameConfig.COLOR_ACCENT, rows, "", "新しい試合へ ▶")


## 結果カードの1行。delta: このラウンドで増えた分も出すか
func _score_row_for(id: int, scores: Dictionary, delta: bool) -> Dictionary:
	var a := state.get_actor(id)
	var n: String = "あなた" if id == state.local_player_id else (a.display_name.get_slice("(", 0) if a else "?")
	var sc: int = scores.get(id, 0)
	return {
		"name": n,
		"color": a.color if a else Color.WHITE,
		"score": sc,
		"delta": sc - int(_round_start_scores.get(id, sc)) if delta else 0,
		"me": id == state.local_player_id,
	}


func _send_stamp(kind: String) -> void:
	if _stamp_target < 0:
		hud.show_message("先に相手をタップ", Color(0.3, 0.3, 0.3), 1.0)
		return
	if state.get_local_player().stamps_left == 0:
		hud.show_message("スタンプは使い切った", Color(0.3, 0.3, 0.3), 1.0)
		return
	cmds.send_stamp(state.local_player_id, _stamp_target, kind)
	# 同じ相手には1ラウンド1回なので、送ったら相手えらびをやめる
	_stamp_target = -1
	_update_help()


func _show_event(e: Dictionary) -> void:
	var me := state.local_player_id
	if e.get("private_to", me) != me:
		return # ほかの人だけが知るお知らせ(ホストの画面でも出さない)
	match e.get("type"):
		"minion":
			if e["actor"] == me:
				hud.show_message("あなたは鬼の手下!\nだまして +1点 / 鬼が勝ったら +2点\nあなたには両どなりの後ろも見える", Color(0.55, 0.2, 0.7), 3.0)
		"stamp":
			if e["target"] == me:
				hud.flash_stamp(WorldView.STAMP_COLORS[e["kind"]])
				view.play_stamp_sound(e["kind"])
				# 対応しているスマホ(主に Android)では短く震える
				Input.vibrate_handheld(150)
		"helped":
			if e["sender"] == me:
				hud.show_message("教えた! +%d点\n(%s を助けた)" % [e["points"], _name(e["target"])], Color(0.1, 0.6, 0.4), 1.5)
				_update_help()
		"deceived":
			if e["sender"] == me:
				hud.show_message("だました! +%d点\n(%s が引っかかった)" % [e["points"], _name(e["target"])], Color(0.6, 0.3, 0.8), 1.5)
				_update_help()
		"stamp_blocked":
			if e["sender"] == me:
				var why := {
					"neighbor": "となりの人には送れない",
					"already": "この人には、このラウンドもう送った",
					"full": "この人はスタンプがいっぱい(%d つ)\n鬼が進むと空く。また送れるよ" % GameConfig.STAMP_SLOTS,
				}
				hud.show_message(why.get(e.get("reason", ""), "いまは送れない"), Color(0.3, 0.3, 0.3), 1.4)
		"dropped":
			_last_sound = "本物"
		"rustle":
			_last_sound = "ニセ"
		"banana":
			var who := "あなた" if e["sender"] == me else _name(e["sender"])
			var whom := "鬼" if e["target"] == state.oni_id else "追う人"
			if e["target"] == me:
				whom = "あなた"
			hud.show_message("%s が %s にバナナ!" % [who, whom], Color(0.85, 0.7, 0.0), 1.2)
		"slip":
			hud.show_message("つるっ! %s が転んだ" % ("あなた" if e["actor"] == me else _name(e["actor"])), Color(0.85, 0.7, 0.0), 1.2)
		"no_looks":
			if e["actor"] == me:
				hud.show_message("もう振り向けない!\n(1ラウンド%d回まで)" % GameConfig.LOOKS_PER_ROUND, Color(0.3, 0.3, 0.3), 1.2)
		"drop_failed":
			if e["actor"] == me:
				hud.show_message("席の後ろで押してね", Color(0.3, 0.3, 0.3), 1.0)
		"auto_drop":
			if _i_am_oni():
				hud.show_message("4周したので\n次の席で自動で落とす", Color(0.3, 0.3, 0.3), 1.5)
		"otetsuki":
			if e["actor"] == me:
				# 外れ: 減点はないが、振り向ける回数は減る
				hud.show_message("なにもない…", Color(0.85, 0.1, 0.1), GameConfig.MESSAGE_TIME)
		"found":
			if e["actor"] == me:
				hud.show_message("あった!", Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
		"picked_up":
			if e["actor"] == me:
				hud.show_message("追いかけろ!", Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
			elif _i_am_oni():
				hud.show_message("気づかれた! 逃げろ!", Color(0.85, 0.1, 0.1), GameConfig.MESSAGE_TIME)
			else:
				hud.show_message("%s が追いかけた!" % _name(e["actor"]), Color(0.3, 0.3, 0.3), GameConfig.MESSAGE_TIME)
		"result":
			_show_result(e)
		"match_over":
			_show_match_result()


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
				title = "タッチ成功!"
				sub = "鬼をつかまえた! やったね"
				color = win
			elif r["loser"] == me:
				title = "つかまっちゃった…"
				sub = "%s にタッチされた" % winner
				color = lose
			else:
				title = "タッチ!"
				sub = "%s が鬼をつかまえた!" % winner
		"sat":
			if r["winner"] == me:
				title = "セーフ!"
				sub = "空いた席にすわれた〜!"
				color = win
			elif r["loser"] == me:
				title = "すわられちゃった…"
				sub = "あとちょっとだったのに!"
				color = lose
			else:
				title = "鬼のかち!"
				sub = "%s の席にすわった!" % loser
		"missed":
			if r["loser"] == me:
				title = "気づかなかった〜!"
				sub = "うしろに落ちてたよ…"
				color = lose
			elif r["winner"] == me:
				title = "気づかれなかった!"
				sub = "%s はぜんぜん気づかなかった" % loser
				color = win
			else:
				title = "鬼のかち!"
				sub = "%s が気づかなかった!" % loser
	var notes := []
	var minion: int = r.get("minion", -1)
	if minion == me:
		notes.append("あなたは手下だったよ" + (" 鬼がかって +%d" % GameConfig.SCORE_MINION_ONI_WIN if r.get("minion_bonus", false) else ""))
	elif minion >= 0:
		notes.append("手下は %s だったよ!" % _name(minion))
	# 全員の点数(この試合の合計。点の多い順、このラウンドで増えた分つき)
	var scores: Dictionary = r.get("scores", state.scores)
	var ids := scores.keys()
	ids.sort_custom(func(a, b): return scores[a] > scores[b])
	var rows := []
	for id in ids:
		rows.append(_score_row_for(id, scores, true))
	var last := state.round_index + 1 >= GameConfig.ROUNDS_PER_MATCH
	var next_text := "さいごの結果へ" if last else "次のラウンド(%s)へ" % Items.name_of(state.round_index + 1)
	hud.hide_message()
	if mode == Mode.GUEST:
		hud.show_result_card(title, sub, notes, color, rows, "ホストが「次へ」を押すと" + next_text)
	else:
		hud.show_result_card(title, sub, notes, color, rows, "", "次へ ▶ " + next_text)


## 札に出す短い名前(「ボット2(せっかち)」→「ボット2」、鬼は「鬼」)
func _short_name(id: int) -> String:
	if id == state.oni_id:
		return "鬼"
	var a := state.get_actor(id)
	if a == null:
		return "?"
	var n := a.display_name
	var cut := n.find("(")
	return n.substr(0, cut) if cut > 0 else n


func _name(id: int) -> String:
	if id == state.local_player_id:
		return "あなた"
	var a := state.get_actor(id)
	return a.display_name if a else "?"


## 画面の札(左上: ラウンド・落とし物・鬼の周回、右上: 全員の点数)を更新する。説明文は出さない
func _update_help() -> void:
	var me := state.get_local_player()
	if me == null:
		return
	var extra := ""
	if _i_am_oni() and state.phase == GameState.Phase.WALKING:
		var laps := int((state.oni_angle - state.oni_start_angle) / TAU) + 1
		extra = "鬼 %d周目(%d周で自動で落とす)" % [laps, GameConfig.ONI_MAX_LAPS_BEFORE_DROP]
	elif _i_am_oni():
		extra = "あなたは鬼"
	elif _stamp_target >= 0:
		extra = "スタンプを送る相手: %s" % _short_name(_stamp_target)
	hud.set_round_info("ラウンド %d/%d" % [state.round_index + 1, GameConfig.ROUNDS_PER_MATCH],
			"いまの落とし物:%s" % state.item_name(), extra)


