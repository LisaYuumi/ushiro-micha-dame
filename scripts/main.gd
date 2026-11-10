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

@onready var view: WorldView = $WorldView
@onready var hud: Hud = $Hud


func _ready() -> void:
	InputSetup.register()
	state = GameState.new()
	_start_round()


func _start_round() -> void:
	state.start_round()
	bots.reset()
	_last_sound = ""
	_stamp_target = -1
	hud.show_stamp("", Color.WHITE)
	hud.hide_message()
	view.build(state)
	_update_help()


func _physics_process(delta: float) -> void:
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


func _process(delta: float) -> void:
	view.sync(state, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		_start_round()
	elif event.is_action_pressed("sound_test"):
		view.play_test_beep()
	else:
		for i in Stamps.ALL.size():
			if event.is_action_pressed("stamp_%d" % i):
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
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func _send_stamp(kind: String) -> void:
	if _stamp_target < 0:
		hud.show_message("先に相手をタップ", Color(0.3, 0.3, 0.3), 1.0)
		return
	if state.get_local_player().stamps_left <= 0:
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
		"stamp_end":
			if e["target"] == me:
				hud.show_stamp("", Color.WHITE)
		"stamp_blocked":
			if e["sender"] == me:
				hud.show_message("先に別のスタンプが届いていた", Color(0.3, 0.3, 0.3), 1.2)
		"dropped":
			_last_sound = "本物"
		"rustle":
			_last_sound = "ニセ"
		"otetsuki":
			if e["actor"] == me:
				hud.show_message("お手つき!", Color(0.85, 0.1, 0.1), GameConfig.MESSAGE_TIME)
		"found":
			if e["actor"] == me:
				hud.show_message("ハンカチがある!\n「拾う」(E)", Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
		"picked_up":
			if e["actor"] == me:
				hud.show_message("追いかけろ!", Color(0.1, 0.5, 0.9), GameConfig.MESSAGE_TIME)
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
			else:
				text = "%s の勝ち\n(鬼をタッチ)" % _name(r["winner"])
		"sat":
			if r["loser"] == me:
				text = "負け…\n鬼に座られた"
				color = Color(0.2, 0.3, 0.8)
			else:
				text = "鬼の勝ち\n(%s の席に座った)" % _name(r["loser"])
		"missed":
			if r["loser"] == me:
				text = "負け…\n一周しても気づかなかった"
				color = Color(0.2, 0.3, 0.8)
			else:
				text = "鬼の勝ち\n(%s が気づかなかった)" % _name(r["loser"])
	hud.show_message(text + "\n「やり直し」(R)で次のラウンド", color, 0.0)


func _name(id: int) -> String:
	var a := state.get_actor(id)
	return a.display_name if a else "?"


func _update_help() -> void:
	var lines := PackedStringArray(["ステップ3: スタンプで教える/だます"])
	var me := state.get_local_player()
	lines.append("お手つき: %d 回 / スタンプ残り: %d" % [me.otetsuki_count, me.stamps_left])
	if _stamp_target >= 0:
		lines.append("スタンプを送る相手: %s" % _name(_stamp_target))
	if view.is_top_camera():
		lines.append("今のカメラ: 上から見る(確認用)")
		# 確認用カメラのときだけ答えを出す
		var who: String = _name(state.get_actor_at_seat(state.drop_target_seat).id) if state.vacant_seat < 0 else _name(state.chaser_id)
		if state.handkerchief_on_floor or state.chaser_id >= 0:
			lines.append("【確認用】%s の後ろに落とした" % who)
		else:
			lines.append("【確認用】%s の後ろに落とす予定" % who)
		if _last_sound != "":
			lines.append("【確認用】さっきの物音: %s" % _last_sound)
	if me.role == GameState.Role.CHASER:
		lines.append("自動で走る! ↑(W)/スティック上: 内側へ(近道)  ↓(S): 外側へ")
	else:
		lines.append("スペース /「振り向く」(押している間): 振り向く")
		lines.append("E /「拾う」: 後ろのハンカチを拾う")
		lines.append("人をタップ → スタンプ(1〜4キー)で送る")
	lines.append("F1: 上から見る / R: やり直し / T: 音テスト / Esc: 終了")
	hud.set_help("\n".join(lines))
