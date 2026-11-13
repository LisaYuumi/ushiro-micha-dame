class_name RemoteCommands
extends RefCounted
## ホスト以外の画面で使う、命令の送り先。GameState と同じ名前の関数を持ち、中身はホストに送るだけ。
## (ルールを動かすのはホストだけ。結果は状態としてホストから届く)
## 毎フレーム呼ばれる命令(振り向く・止まる・走る向き)は、変わったときだけ送る。

var _net: NetSession
var _last := {}


func _init(net: NetSession) -> void:
	_net = net


func set_looking_back(_id: int, value: bool) -> void:
	_send_if_changed("set_looking_back", [value])


func set_oni_stop(_id: int, value: bool) -> void:
	_send_if_changed("set_oni_stop", [value])


func set_move(_id: int, dir: Vector3) -> void:
	# 細かすぎる変化は送らない
	var q := Vector3(snappedf(dir.x, 0.1), 0.0, snappedf(dir.z, 0.1))
	_send_if_changed("set_move", [q])


func pick_up(_id: int) -> void:
	_net.send_command("pick_up", [])


func oni_drop(_id: int) -> void:
	_net.send_command("oni_drop", [])


func oni_feint(_id: int) -> void:
	_net.send_command("oni_feint", [])


func oni_milk(_id: int) -> void:
	_net.send_command("oni_milk", [])


func throw_banana(_id: int, target_id: int) -> void:
	_net.send_command("throw_banana", [target_id])


func send_stamp(_id: int, target_id: int, kind: String) -> void:
	_net.send_command("send_stamp", [target_id, kind])


func _send_if_changed(cmd: String, args: Array) -> void:
	if _last.get(cmd) == args:
		return
	_last[cmd] = args
	_net.send_command(cmd, args)
