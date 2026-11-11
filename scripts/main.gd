extends Node3D
## 全体のつなぎ役。
##   GameState(状態) ← 入力(PlayerInput)・ボット(BotBrain)が命令を出す
##   GameState(状態) → WorldView / Hud が読んで表示する

var state: GameState
var bots := BotBrain.new()
## 確認用: 最後に鳴った物音が本物かニセか
var _last_sound := ""
## スタンプを送る相手(画面でタップして選ぶ。-1 は未選択)
var _stamp_target := -1
## Web版で、最初のタップを待っている間は true(ゲームを止めておく)
var _waiting_start := false
## この画面のプレイヤーが鬼をやるか
var _player_is_oni := false

@onready var view: WorldView = $WorldView
@onready var hud: Hud = $Hud
@onready var touch: TouchControls = $TouchControls


func _ready() -> void:
	InputSetup.register()
	state = GameState.new()
	_start_round()
	if OS.has_feature("web"):
		_waiting_start = true
		var gate := StartGate.new()
		gate.started.connect(_on_start_tapped)
		add_child(gate) # いちばん最後の子にして、最初に入力を受け取る
		hud.show_message("タップしてスタート\n(音が鳴ります)", Color(0.2, 0.4, 0.8), 0.0)


func _on_start_tapped() -> void:
	_waiting_start = false
	hud.hide_message()


## 新しい試合を始める
func _start_round() -> void:
	state.start_match(-1, _player_is_oni)
	_refresh_round()


## ラウンドが変わったときに、画面とボットを作り直す
func _refresh_round() -> void:
	bots.reset()
	touch.set_oni_mode(state.oni_is_player)
	_last_sound = ""
	_stamp_target = -1
	hud.show_stamp("", Color.WHITE)
	hud.hide_message()
	view.build(state)
	_update_help()


func _physics_process(delta: float) -> void:
	if _waiting_start:
		return
	PlayerInput.apply(state, view.get_camera_basis())
	bots.update(state, delta)
	state.tick(delta)
	for e in state.take_events():
		view.on_event(e)
		bots.on_event(state, e)
		_show_event(e)
		_update_help()
	if state.get_actor(_stamp_target) == null or state.get_actor(_stamp_target).role != GameState.Role.SEATED:
		_stamp_target = -1
	view.set_stamp_target(state, _stamp_target)
	var me := state.get_local_player()
	var judged := state.phase == GameState.Phase.WALKING or state.phase == GameState.Phase.DROPPED
	touch.set_looks_left(me.looks_left if judged else -1)
	touch.set_oni_mode(state.oni_is_player,
			me.role == GameState.Role.SEATED and state.phase == GameState.Phase.CHASE)
	if state.oni_is_player:
		# 何周目かの表示を更新する
		_update_help()


func _process(delta: float) -> void:
	view.sync(state, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		_on_restart_pressed()
	elif event.is_action_pressed("toggle_role"):
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
			if not state.oni_is_player and event.is_action_pressed("stamp_%d" % i):
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
	state.send_stamp(state.local_player_id, _stamp_target, kind)


func _show_event(e: Dictionary) -> void:
	var me := state.local_player_id
	match e.get("type"):
		"stamp":
			if e["target"] == me:
				var text: String = Stamps.LABELS[e["kind"]]
				if GameConfig.SHOW_STAMP_SENDER:
					text += " (%s)" % _name(e["sender"])
				hud.show_stamp(text, WorldView.STAMP_COLORS[e["kind"]])
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
			elif e["target"] == me:
				hud.show_message("だまされた…", Color(0.6, 0.3, 0.8), 1.2)
		"stamp_end":
			if e["target"] == me:
				hud.show_stamp("", Color.WHITE)
		"stamp_blocked":
			if e["sender"] == me:
				if e.get("reason", "") == "neighbor":
					hud.show_message("となりの人には送れない", Color(0.3, 0.3, 0.3), 1.2)
				else:
					hud.show_message("先に別のスタンプが届いていた", Color(0.3, 0.3, 0.3), 1.2)
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
			if state.oni_is_player:
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
			elif state.oni_is_player:
				hud.show_message("気づかれた! 逃げろ!", Color(0.85, 0.1, 0.1), GameConfig.MESSAGE_TIME)
			else:
				hud.show_message("%s が追いかけた!" % _name(e["actor"]), Color(0.3, 0.3, 0.3), GameConfig.MESSAGE_TIME)
		"result":
			_show_result(e)


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
	var me_score: int = state.scores.get(me, 0)
	var last := state.round_index + 1 >= GameConfig.ROUNDS_PER_MATCH
	var next_text := "最終結果" if last else "次のラウンド(%s)" % Items.name_of(state.round_index + 1)
	hud.show_message("%s\nあなた: %d点\n「次へ」(R)で%s" % [text, me_score, next_text], color, 0.0)


func _name(id: int) -> String:
	var a := state.get_actor(id)
	return a.display_name if a else "?"


func _update_help() -> void:
	var lines := PackedStringArray(["ラウンド %d/%d: %s / あなた %d点" % [
		state.round_index + 1, GameConfig.ROUNDS_PER_MATCH, state.item_name(), state.scores.get(state.local_player_id, 0)]])
	if state.oni_is_player:
		lines.append("あなたは鬼")
	var me := state.get_local_player()
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
		lines.append("  声のすぐあと(0.8秒以内)に落とすと、置く音がかき消される")
	else:
		lines.append("スペース /「振り向く」(押している間): 振り向く")
		lines.append("E /「拾う」: 後ろのハンカチを拾う")
		lines.append("人をタップ → スタンプ(1〜4キー)で送る")
	lines.append("F1: 上から見る / R: 次へ・やり直し / O: 鬼で新しい試合 / T: 音テスト")
	hud.set_help("\n".join(lines))
