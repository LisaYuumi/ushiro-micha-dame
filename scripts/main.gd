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
	state.setup_default()
	view.build(state)
	_update_help()


func _process(_delta: float) -> void:
	view.sync(state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_top_camera"):
		view.toggle_top_camera()
		_update_help()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func _update_help() -> void:
	var cam := "上から見る(確認用)" if view.is_top_camera() else "自分の席から見る"
	hud.set_help("段階1: 表示の確認\n今のカメラ: %s\nF1: カメラ切りかえ / Esc: 終了" % cam)
