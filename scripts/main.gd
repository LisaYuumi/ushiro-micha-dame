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
## ホスト: 状態を配るまでの時間
var _snapshot_left := 0.0
## 参加者: 最後に見た目を作ったラウンド
var _built_serial := -1

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
	net.connected_to_host.connect(func() -> void: lobby.show_waiting("つながりました! ホストがスタートするのを待っています"))
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
	var names := {0: "プレイヤー1(ホスト)"}
	var next_id := 1
	for pid in peers:
		if next_id >= max_humans:
			break
		_peer_actor[pid] = next_id
		humans.append(next_id)
		names[next_id] = "プレイヤー%d" % (next_id + 1)
		next_id += 1
	var first_oni: int = humans[randi_range(0, humans.size() - 1)]
	state.start_match_custom(-1, humans, first_oni, names, true, _seats)
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
	state.start_match(-1, _player_is_oni, _seats)
	_refresh_round()


## ラウンドが変わったときに、画面とボットを作り直す
func _refresh_round() -> void:
	bots.reset()
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
	hud.set_role_badge("あなたは鬼の手下(だますと+1 / 鬼が勝つと+2)" if state.minion_id == me.id \
			and state.phase != GameState.Phase.RESULT else "", Color(0.55, 0.2, 0.7))
	var judged := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	touch.set_looks_left(me.looks_left if judged else -1)
	touch.set_oni_mode(_i_am_oni(),
			me.role == GameState.Role.SEATED and state.phase == GameState.Phase.CHASE)
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
			"text": Stamps.LABELS[st["kind"]],
			"color": WorldView.STAMP_COLORS[st["kind"]],
			"sender": (("鬼 " if st["sender"] == state.oni_id else "") + sender.display_name) if sender else "?",
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
			if state.forced_oni_id >= 0:
				msg += "\nお手つき%d回で %s が鬼!" % [GameConfig.OTETSUKI_LIMIT,
						"あなた" if state.forced_oni_id == state.local_player_id else _name(state.forced_oni_id)]
			hud.show_message(msg, Color(0.3, 0.3, 0.3), 2.0)
		else:
			_show_match_result()
	else:
		state.restart_round()
		_refresh_round()


func _show_match_result() -> void:
	var ids := state.scores.keys()
	ids.sort_custom(func(a, b): return state.scores[a] > state.scores[b])
	var lines := PackedStringArray(["試合終了!"])
	var rank := 0
	var prev := INF
	for i in ids.size():
		var sc: int = state.scores[ids[i]]
		if sc != prev:
			rank = i + 1
			prev = sc
		lines.append("%d位 %s  %d点" % [rank, _name(ids[i]), sc])
	lines.append("「次へ」(R)で新しい試合")
	hud.show_message("\n".join(lines), Color(0.9, 0.6, 0.1), 0.0)


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
				var text := "お手つき! %d点\n(これで %d 回目)" % [e["points"], e["count"]]
				if e["limit_reached"]:
					text = "お手つき%d回!\n%s" % [GameConfig.OTETSUKI_LIMIT,
							"プラスの点数が0点に…" if e["score_reset"] else "点数はそのまま(マイナスだったので)"]
					if GameConfig.OTETSUKI_FORCES_ONI:
						text += "\n次のラウンドは鬼"
				hud.show_message(text, Color(0.85, 0.1, 0.1), GameConfig.MESSAGE_TIME * 1.5)
				_update_help()
		"found":
			if e["actor"] == me:
				hud.show_message("ハンカチがある!\n「拾う」(E)", Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
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


func _show_result(r: Dictionary) -> void:
	var me := state.local_player_id
	var text := ""
	var color := Color(0.3, 0.3, 0.3)
	match r["reason"]:
		"touched":
			if r["winner"] == me:
				text = "勝ち!\n鬼をタッチした"
				color = Color(0.9, 0.6, 0.1)
			elif r["loser"] == me:
				text = "負け…\n%s にタッチされた" % _name(r["winner"])
				color = Color(0.2, 0.3, 0.8)
			else:
				text = "%s の勝ち\n(鬼をタッチ)" % _name(r["winner"])
		"sat":
			if r["loser"] == me:
				text = "負け…\n鬼に座られた"
				color = Color(0.2, 0.3, 0.8)
			elif r["winner"] == me:
				text = "勝ち!\n空いた席に座れた"
				color = Color(0.9, 0.6, 0.1)
			else:
				text = "鬼の勝ち\n(%s の席に座った)" % _name(r["loser"])
		"missed":
			if r["loser"] == me:
				text = "負け…\n一周しても気づかなかった"
				color = Color(0.2, 0.3, 0.8)
			elif r["winner"] == me:
				text = "勝ち!\n%s は気づかなかった" % _name(r["loser"])
				color = Color(0.9, 0.6, 0.1)
			else:
				text = "鬼の勝ち\n(%s が気づかなかった)" % _name(r["loser"])
	if me in r.get("patient", []):
		text += "\nがまんした! +%d点" % GameConfig.SCORE_PATIENCE
	# 手下の発表
	var minion: int = r.get("minion", -1)
	if minion >= 0:
		if minion == me:
			text += "\nあなたは手下だった" + (" 鬼が勝って +%d点" % GameConfig.SCORE_MINION_ONI_WIN if r.get("minion_bonus", false) else "")
		else:
			text += "\n手下は %s だった" % _name(minion)
	var me_score: int = state.scores.get(me, 0)
	var last := state.round_index + 1 >= GameConfig.ROUNDS_PER_MATCH
	var next_text := "最終結果" if last else "次のラウンド(%s)" % Items.name_of(state.round_index + 1)
	var how := "「次へ」(R)で" if mode != Mode.GUEST else "ホストが「次へ」を押すと"
	hud.show_message("%s\nあなた: %d点\n%s%s" % [text, me_score, how, next_text], color, 0.0)


func _name(id: int) -> String:
	if id == state.local_player_id:
		return "あなた"
	var a := state.get_actor(id)
	return a.display_name if a else "?"


func _update_help() -> void:
	var lines := PackedStringArray(["ラウンド %d/%d: %s / あなた %d点" % [
		state.round_index + 1, GameConfig.ROUNDS_PER_MATCH, state.item_name(), state.scores.get(state.local_player_id, 0)]])
	var me := state.get_local_player()
	if me == null:
		return
	if _i_am_oni():
		lines.append("あなたは鬼(スタンプでだますと +%d点)" % GameConfig.SCORE_DECEIVE_ONI)
	elif state.minion_id == me.id and state.phase != GameState.Phase.RESULT:
		lines.append("あなたは鬼の手下: だますと +%d点 / 鬼が勝つと +%d点 / 両どなりの後ろも見える" % [
				GameConfig.SCORE_DECEIVE_MINION, GameConfig.SCORE_MINION_ONI_WIN])
	lines.append("振り向き: 残り %d/%d 回 (一度もしなければ +%d点) / お手つき: %d 回 (1回 %d点)" % [
		me.looks_left, GameConfig.LOOKS_PER_ROUND, GameConfig.SCORE_PATIENCE, me.otetsuki_count, GameConfig.SCORE_OTETSUKI])
	if _stamp_target >= 0:
		lines.append("スタンプを送る相手: %s" % _name(_stamp_target))
	if view.is_top_camera():
		lines.append("今のカメラ: 上から見る(確認用)")
		# 確認用カメラのときだけ答えを出す
		var who := "?"
		if state.vacant_seat >= 0:
			who = _name(state.chaser_id)
		elif state.drop_target_seat >= 0:
			who = _name(state.get_actor_at_seat(state.drop_target_seat).id)
		if state.handkerchief_on_floor or state.chaser_id >= 0:
			lines.append("【確認用】%s の後ろに落とした" % who)
		elif not state.oni_is_player:
			lines.append("【確認用】%s の後ろに落とす予定" % who)
		if _last_sound != "":
			lines.append("【確認用】さっきの物音: %s" % _last_sound)
	if me.role == GameState.Role.CHASER or (me.role == GameState.Role.ONI and state.phase == GameState.Phase.CHASE):
		lines.append("自動で走る! ↑(W)/スティック上: 内側へ(近道)  ↓(S): 外側へ")
		lines.append("前に落ちたバナナの皮は、曲がってよけよう")
	elif state.phase == GameState.Phase.CHASE:
		lines.append("B: 鬼にバナナ / N: 追う人にバナナ(1ラウンド %d 個)" % GameConfig.BANANAS_PER_ROUND)
	elif me.role == GameState.Role.ONI:
		var laps := int((state.oni_angle - state.oni_start_angle) / TAU) + 1
		lines.append("%d 周目 (%d 周しても落とさないと自動で落とす)" % [laps, GameConfig.ONI_MAX_LAPS_BEFORE_DROP])
		lines.append("→(D)/スティック右: 速く  ←(A): ゆっくり")
		lines.append("スペース /「止まる」(押している間): 止まる")
		lines.append("E /「落とす」: いちばん近い席の後ろに落とす(1回だけ)")
		lines.append("F /「落とす音」: 落とさずに、置く音だけ出す(何回でも)")
		lines.append("1〜4 / 咳・口笛・手拍子・叫ぶ: 声を出す")
		lines.append("人をタップ → スタンプ(Z X C V)で送れる(だますと +%d点)" % GameConfig.SCORE_DECEIVE_ONI)
		lines.append("  声のすぐあと(0.8秒以内)に落とすと、置く音がかき消される")
	else:
		lines.append("スペース /「振り向く」(押している間): 振り向く")
		lines.append("E /「拾う」: 後ろのハンカチを拾う")
		lines.append("人をタップ → スタンプ(1〜4キー)で送る(同じ人には1ラウンド1回)")
		if state.minion_id != me.id:
			lines.append("本当を教えると +%d点 / 嘘は点にならない(手下と鬼は嘘で点)" % GameConfig.SCORE_HELP_NORMAL)
	lines.append("F1: 上から見る / R: 次へ・やり直し / O: 鬼で新しい試合 / T: 音テスト")
	hud.set_help("\n".join(lines))
