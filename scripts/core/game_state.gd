class_name GameState
extends RefCounted
## ゲームの状態(誰がどこにいるか、ハンカチの位置、勝敗)だけを持つ。
##
## ルール:
## - ノード・画面・キー入力・音には一切さわらない。
## - 状態を変えるのは、このクラスの関数だけ。
## 将来のオンライン対戦では、ホストがこのクラスを動かし、
## snapshot() の中身を全員に配る想定。

enum Role { SEATED, ONI }


class Actor:
	var id: int
	var display_name: String
	var is_bot: bool
	var role: int = Role.SEATED
	## 座っている席の番号(座っていなければ -1)
	var seat_index: int = -1
	## 床の上の位置
	var position: Vector3 = Vector3.ZERO
	## 向き(Y軸まわりの回転・ラジアン)。0 のとき -Z 方向を向く
	var yaw: float = 0.0
	## 仮の体の色
	var color: Color = Color.WHITE


## 席の位置(床の上)
var seat_positions: Array[Vector3] = []
## 席の向き(輪の内側を向く yaw)
var seat_yaws: Array[float] = []
## 登場人物(Actor の配列)
var actors: Array = []
## この画面で操作しているプレイヤーの id
var local_player_id: int = 0


## 初期配置: 6席の輪、プレイヤー1人+ボット5体が着席、鬼が輪の外に立つ。
func setup_default() -> void:
	seat_positions.clear()
	seat_yaws.clear()
	actors.clear()

	for i in GameConfig.SEAT_COUNT:
		var a := seat_angle(i)
		seat_positions.append(Vector3(sin(a), 0.0, cos(a)) * GameConfig.RING_RADIUS)
		# 輪の中心を向く向き(-Z が正面なので、角度 a がそのまま中心向き)
		seat_yaws.append(a)

	var palette := [
		Color(0.95, 0.55, 0.25), # プレイヤー
		Color(0.35, 0.65, 0.95),
		Color(0.45, 0.8, 0.45),
		Color(0.9, 0.8, 0.3),
		Color(0.75, 0.5, 0.9),
		Color(0.95, 0.6, 0.75),
	]

	for i in GameConfig.SEAT_COUNT:
		var actor := Actor.new()
		actor.id = i
		actor.is_bot = i != local_player_id
		actor.display_name = "あなた" if i == local_player_id else "ボット%d" % i
		actor.color = palette[i % palette.size()]
		_sit(actor, i)
		actors.append(actor)

	var oni := Actor.new()
	oni.id = actors.size()
	oni.is_bot = true
	oni.display_name = "鬼"
	oni.role = Role.ONI
	oni.color = Color(0.85, 0.2, 0.2)
	_place_on_walk_ring(oni, seat_angle(0) + TAU / (GameConfig.SEAT_COUNT * 2))
	actors.append(oni)


## 席 i の、輪の上での角度(ラジアン)。席0 は +Z 側。
func seat_angle(i: int) -> float:
	return TAU * float(i) / float(GameConfig.SEAT_COUNT)


func get_actor(id: int) -> Actor:
	for a in actors:
		if a.id == id:
			return a
	return null


func get_local_player() -> Actor:
	return get_actor(local_player_id)


## 通信や保存に使える、ただのデータ(Dictionary)に変換する。
func snapshot() -> Dictionary:
	var list := []
	for a in actors:
		list.append({
			"id": a.id,
			"name": a.display_name,
			"is_bot": a.is_bot,
			"role": a.role,
			"seat": a.seat_index,
			"pos": a.position,
			"yaw": a.yaw,
		})
	return {"actors": list}


func _sit(actor: Actor, seat: int) -> void:
	actor.role = Role.SEATED
	actor.seat_index = seat
	actor.position = seat_positions[seat]
	actor.yaw = seat_yaws[seat]


## 鬼が歩く輪の上、角度 angle の位置に置き、進行方向(角度が増える向き)を向かせる。
func _place_on_walk_ring(actor: Actor, angle: float) -> void:
	actor.seat_index = -1
	actor.position = Vector3(sin(angle), 0.0, cos(angle)) * GameConfig.ONI_WALK_RADIUS
	actor.yaw = angle - PI / 2.0
