extends Node3D
## 全体のつなぎ役。
##   GameState(状態) ← 入力(PlayerInput)・ボット(BotBrain)が命令を出す
##   GameState(状態) → WorldView / Hud が読んで表示する

var state: GameState
var bots := BotBrain.new()
## 確認用: 最後に鳴った物音が本物かニセか
var _last_sound := ""

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
	hud.hide_message()
	view.build(state)
	_update_help()


func _physics_process(delta: float) -> void:
	PlayerInput.apply(state, view.get_camera_basis())
	bots.update(state, delta)
	state.tick(delta)
	for e in state.take_events():
		view.on_event(e)
		_show_event(e)
		_update_help()


func _process(delta: float) -> void:
	view.sync(state, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		_start_round()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func _show_event(e: Dictionary) -> void:
	var me := state.local_player_id
	match e.get("type"):
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
	var lines := PackedStringArray(["段階4: 拾って追いかける・勝敗"])
	var me := state.get_local_player()
	lines.append("お手つき: %d 回" % me.otetsuki_count)
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
		lines.append("矢印キー / WASD / 左下のスティック: 走る")
	else:
		lines.append("スペース /「振り向く」(押している間): 振り向く")
		lines.append("E /「拾う」: 後ろのハンカチを拾う")
	lines.append("F1: 上から見る / R: やり直し / Esc: 終了")
	hud.set_help("\n".join(lines))
