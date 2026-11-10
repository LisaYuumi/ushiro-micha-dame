class_name StartGate
extends Node
## Web版の「タップしてスタート」。
## ブラウザは、画面に触れるまで音を出させてくれないので、最初のタップでゲームを始める
## (そのタップで音も使えるようになる)。いちばん最後の子として置くと、最初に入力を受け取れる。

signal started

var waiting := true


func _input(event: InputEvent) -> void:
	if not waiting:
		return
	var pressed := false
	if event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey:
		pressed = event.pressed
	elif event is InputEventAction:
		pressed = event.pressed
	if not pressed:
		return
	waiting = false
	get_viewport().set_input_as_handled()
	started.emit()
