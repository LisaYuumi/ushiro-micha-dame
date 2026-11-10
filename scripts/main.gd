extends Node3D
## 全体のつなぎ役。
##   GameState(状態) ← 入力・ボットが命令を出す
##   GameState(状態) → WorldView / Hud が読んで表示する

var state: GameState

@onready var view: WorldView = $WorldView
@onready var hud: Hud = $Hud


func _ready() -> void:
	InputSetup.register()
	state = GameState.new()
	_start_round()


func _start_round() -> void:
	state.start_round()
	view.build(state)
	_update_help()


func _physics_process(delta: float) -> void:
	state.tick(delta)
	for e in state.take_events():
		view.on_event(e)
		_update_help()


func _process(_delta: float) -> void:
	view.sync(state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("restart"):
		_start_round()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func _update_help() -> void:
	var lines := PackedStringArray(["段階2: 鬼が歩いてハンカチを落とす"])
	if view.is_top_camera():
		lines.append("今のカメラ: 上から見る(確認用)")
		# 確認用カメラのときだけ答えを出す
		var target := state.get_actor_at_seat(state.drop_target_seat)
		var who: String = target.display_name if target else "?"
		if state.handkerchief_on_floor:
			lines.append("【確認用】%s の後ろに落とした" % who)
		else:
			lines.append("【確認用】%s の後ろに落とす予定" % who)
	else:
		lines.append("今のカメラ: 自分の席から見る")
	lines.append("F1: カメラ切りかえ / R: やり直し / Esc: 終了")
	hud.set_help("\n".join(lines))
