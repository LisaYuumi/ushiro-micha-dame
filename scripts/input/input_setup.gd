class_name InputSetup
extends RefCounted
## キー割り当てをまとめて登録する(project.godot を手で書かずに済むように)。

const KEYS := {
	"look_back": [KEY_SPACE],
	"pick_up": [KEY_E],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"debug_top_camera": [KEY_F1],
	"restart": [KEY_R],
	"sound_test": [KEY_T],
	"toggle_role": [KEY_O],
	"oni_stop": [KEY_SPACE],
	"oni_drop": [KEY_E],
	"oni_feint": [KEY_F],
	"stamp_0": [KEY_1],
	"stamp_1": [KEY_2],
	"stamp_2": [KEY_3],
	"stamp_3": [KEY_4],
	"quit": [KEY_ESCAPE],
}


static func register() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
