class_name PlayerInput
extends RefCounted
## この画面のプレイヤーのキー入力を、GameState への命令に変える。
## (オンライン対戦では、この命令をホストに送る形に置きかえる)


static func apply(state: GameState) -> void:
	state.set_looking_back(state.local_player_id, Input.is_action_pressed("look_back"))
