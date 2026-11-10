class_name InputSetup
extends RefCounted
## キー割り当てをまとめて登録する(project.godot を手で書かずに済むように)。

const KEYS := {
	"debug_top_camera": KEY_F1,
	"restart": KEY_R,
	"quit": KEY_ESCAPE,
}


static func register() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, ev)
