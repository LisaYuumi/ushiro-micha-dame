class_name GameState
extends RefCounted
## ゲームの状態(誰がどこにいるか、ハンカチの位置、勝敗)とルールだけを持つ。
##
## ルール:
## - ノード・画面・キー入力・音には一切さわらない。
## - 状態を変えるのは、このクラスの関数だけ(tick と、これから足す命令の関数)。
## - 画面や音に知らせたいことは events に積む。表示側が take_events() で受け取る。
## 将来のオンライン対戦では、ホストだけがこのクラスを動かし、
## snapshot() と events を全員に配る想定。

enum Role { SEATED, ONI, CHASER }
## WALKING: 鬼がハンカチを持って歩いている
## DROPPED: 落とした後、鬼は歩き続けている(もう一周で見逃し)
## CHASE: 拾った人が鬼を追いかけている
## RESULT: 勝敗が決まった
enum Phase { WALKING, DROPPED, CHASE, RESULT }


class Actor:
	var id: int
	var display_name: String
	var is_bot: bool
	var role: int = 0 # Role.SEATED
	## 座っている席の番号(座っていなければ -1)
	var seat_index: int = -1
	## 床の上の位置
	var position: Vector3 = Vector3.ZERO
	## 向き(Y軸まわりの回転・ラジアン)。0 のとき -Z 方向を向く
	var yaw: float = 0.0
	## 仮の体の色
	var color: Color = Color.WHITE
	## 振り向いているか(全員から見える)
	var looking_back: bool = false
	## お手つきの回数(このステップでは数えるだけ。点数はまだ)
	var otetsuki_count: int = 0
	## 走る向き(追いかけるとき。長さ 0〜1)
	var move_dir: Vector3 = Vector3.ZERO


## 席の位置(床の上)
var seat_positions: Array[Vector3] = []
## 席の向き(輪の内側を向く yaw)
var seat_yaws: Array[float] = []
## 登場人物(Actor の配列)
var actors: Array = []
## この画面で操作しているプレイヤーの id
var local_player_id: int = 0
## 鬼の id
var oni_id: int = -1

var phase: int = Phase.WALKING
## 鬼が輪の上のどこにいるか(角度・ラジアン。増え続ける=何周したかもわかる)
var oni_angle: float = 0.0
## ハンカチを落とす相手の席
var drop_target_seat: int = -1
## 鬼がこの角度まで来たら落とす
var drop_angle: float = 0.0
## 次に鬼が席の真後ろを通る角度
var next_seat_crossing: float = 0.0
## 鬼が立ち止まっている残り時間(秒)
var oni_pause_left: float = 0.0
## ハンカチが床に落ちているか
var handkerchief_on_floor: bool = false
var handkerchief_position: Vector3 = Vector3.ZERO

## 追いかけている人の id(いなければ -1)
var chaser_id: int = -1
## 追いかける人が立って空いた席(鬼が座りに行く)
var vacant_seat: int = -1
## 鬼が空いた席の真後ろに着く角度
var oni_seat_angle: float = 0.0
## 鬼が輪から席に向かって入っているところか
var oni_entering: bool = false
## 勝敗。{"winner": id, "loser": id, "reason": "touched" / "sat" / "missed"}
var result: Dictionary = {}

## 表示側へのお知らせ(Dictionary の配列)
var events: Array = []

var rng := RandomNumberGenerator.new()


## ラウンドを最初から始める。seed を指定すると毎回同じ展開になる(テスト用)。
func start_round(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	seat_positions.clear()
	seat_yaws.clear()
	actors.clear()
	events.clear()

	for i in GameConfig.SEAT_COUNT:
		var a := seat_angle(i)
		seat_positions.append(_ring_point(a, GameConfig.RING_RADIUS))
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
	actors.append(oni)
	oni_id = oni.id

	# 鬼は席と席の間から歩きはじめる
	oni_angle = seat_angle(0) + TAU / (GameConfig.SEAT_COUNT * 2)
	_place_on_walk_ring(oni, oni_angle)

	phase = Phase.WALKING
	handkerchief_on_floor = false
	oni_pause_left = 0.0
	chaser_id = -1
	vacant_seat = -1
	oni_entering = false
	result = {}
	var step := TAU / GameConfig.SEAT_COUNT
	next_seat_crossing = ceilf(oni_angle / step) * step
	_plan_drop()


## 時間を delta 秒すすめる。
func tick(delta: float) -> void:
	match phase:
		Phase.WALKING, Phase.DROPPED:
			_tick_walking(delta)
		Phase.CHASE:
			_tick_chase(delta)


func _tick_walking(delta: float) -> void:
	if oni_pause_left > 0.0:
		oni_pause_left -= delta
		return

	var oni := get_actor(oni_id)
	oni_angle += GameConfig.ONI_WALK_SPEED / GameConfig.ONI_WALK_RADIUS * delta
	if oni_angle >= next_seat_crossing:
		# ちょうど席の真後ろで止まれるように位置をそろえる
		oni_angle = next_seat_crossing
		next_seat_crossing += TAU / GameConfig.SEAT_COUNT
		_on_pass_behind_seat()
	_place_on_walk_ring(oni, oni_angle)


# --- 命令(プレイヤーの入力やボットから呼ばれる) ---

## 振り向く/前を向く。振り向いた瞬間に、後ろにハンカチがあるかを判定する。
func set_looking_back(actor_id: int, value: bool) -> void:
	var a := get_actor(actor_id)
	if a == null or a.role != Role.SEATED or a.looking_back == value:
		return
	a.looking_back = value
	# 追いかけっこ中・勝敗が出た後は、振り向いて見物してもお手つきにならない
	if not value or phase == Phase.CHASE or phase == Phase.RESULT:
		return
	if has_handkerchief_behind(a):
		events.append({"type": "found", "actor": actor_id})
	else:
		a.otetsuki_count += 1
		events.append({"type": "otetsuki", "actor": actor_id})


## ハンカチを拾って立ち上がる。振り向いていて、後ろにハンカチがあるときだけできる。
func pick_up(actor_id: int) -> void:
	var a := get_actor(actor_id)
	if a == null or phase != Phase.DROPPED or not a.looking_back or not has_handkerchief_behind(a):
		return
	vacant_seat = a.seat_index
	a.role = Role.CHASER
	a.seat_index = -1
	a.looking_back = false
	a.position = handkerchief_position
	a.yaw = drop_angle - PI / 2.0
	chaser_id = a.id
	handkerchief_on_floor = false
	phase = Phase.CHASE
	# 鬼は気づいてすぐ走り出す。空いた席まで(少なくとも一度は)輪を回ってから座る
	oni_pause_left = 0.0
	oni_entering = false
	var target := seat_angle(vacant_seat)
	oni_seat_angle = target + ceilf((oni_angle - target + 0.001) / TAU) * TAU
	events.append({"type": "picked_up", "actor": a.id})


## 走る向きの希望を伝える(追いかける人だけ)。dir は床の上の向き、長さ 0〜1。
## 追いかける人は自動で前に走るので、使われるのは「内側/外側」の成分だけ。
func set_move(actor_id: int, dir: Vector3) -> void:
	var a := get_actor(actor_id)
	if a == null:
		return
	dir.y = 0.0
	a.move_dir = dir.limit_length(1.0)


## この人の後ろにハンカチが落ちているか
func has_handkerchief_behind(a: Actor) -> bool:
	return handkerchief_on_floor and a.role == Role.SEATED and a.seat_index == drop_target_seat


## たまったお知らせを受け取る(受け取ると空になる)。
func take_events() -> Array:
	var out := events
	events = []
	return out


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


## 席に座っている人(いなければ null)
func get_actor_at_seat(seat: int) -> Actor:
	for a in actors:
		if a.seat_index == seat:
			return a
	return null


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
			"looking_back": a.looking_back,
			"otetsuki": a.otetsuki_count,
			"move": a.move_dir,
		})
	return {
		"actors": list,
		"phase": phase,
		"oni_angle": oni_angle,
		"handkerchief_on_floor": handkerchief_on_floor,
		"handkerchief_pos": handkerchief_position,
		"chaser": chaser_id,
		"vacant_seat": vacant_seat,
		"result": result,
	}


# --- 内部の処理 ---

## 落とす相手と、落とすタイミング(角度)を決める。
## 相手はプレイヤーもボットも含めてランダム。
func _plan_drop() -> void:
	drop_target_seat = rng.randi_range(0, GameConfig.SEAT_COUNT - 1)
	var laps := rng.randf_range(GameConfig.ONI_LAPS_BEFORE_DROP_MIN, GameConfig.ONI_LAPS_BEFORE_DROP_MAX)
	var earliest := oni_angle + TAU * laps
	var target := seat_angle(drop_target_seat)
	# earliest 以降で、はじめて相手の真後ろを通る角度
	drop_angle = target + ceilf((earliest - target) / TAU) * TAU


## 鬼が席の真後ろに来たとき: 本当に落とす/ニセで立ち止まる/そのまま通りすぎる
func _on_pass_behind_seat() -> void:
	if phase == Phase.DROPPED and absf(oni_angle - (drop_angle + TAU)) < 0.001:
		# 一周して戻ってきても気づかれなかった: 落とされた人の負け
		var target := get_actor_at_seat(drop_target_seat)
		_finish(oni_id, target.id, "missed")
		return
	if phase == Phase.WALKING and absf(oni_angle - drop_angle) < 0.001:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		_drop()
	elif rng.randf() < GameConfig.DECOY_STOP_CHANCE:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		if rng.randf() < GameConfig.DECOY_SOUND_CHANCE:
			# 本物と同じ音を、同じ場所(席の真後ろ)で出す
			events.append({
				"type": "rustle",
				"seat": _seat_at_angle(oni_angle),
				"pos": _ring_point(oni_angle, GameConfig.DROP_RADIUS),
			})


func _tick_chase(delta: float) -> void:
	var oni := get_actor(oni_id)
	var chaser := get_actor(chaser_id)
	_move_chaser(chaser, delta)

	var sat := false
	if oni_entering:
		var seat_pos := seat_positions[vacant_seat]
		var to_seat := seat_pos - oni.position
		if to_seat.length() > 0.001:
			oni.yaw = atan2(-to_seat.x, -to_seat.z)
		oni.position = oni.position.move_toward(seat_pos, GameConfig.ONI_RUN_SPEED * delta)
		sat = oni.position.distance_to(seat_pos) < 0.01
	else:
		oni_angle = minf(oni_angle + GameConfig.ONI_RUN_SPEED / GameConfig.ONI_WALK_RADIUS * delta, oni_seat_angle)
		_place_on_walk_ring(oni, oni_angle)
		oni_entering = oni_angle >= oni_seat_angle

	if _flat_distance(chaser.position, oni.position) <= GameConfig.TOUCH_DISTANCE:
		_finish(chaser_id, oni_id, "touched")
	elif sat:
		_sit(oni, vacant_seat)
		_finish(oni_id, chaser_id, "sat")


## 追いかける人を動かす。鬼と同じ向きに自動で走り続け、内側/外側にだけ曲がれる。
## 席の内側には入れない。立ち止まって待ちぶせはできない。
func _move_chaser(a: Actor, delta: float) -> void:
	var ang := atan2(a.position.x, a.position.z)
	# 鬼が走る向き(角度が増える向き)と、輪の外向き
	var forward := Vector3(cos(ang), 0.0, -sin(ang))
	var outward := Vector3(sin(ang), 0.0, cos(ang))
	var steer := clampf(a.move_dir.dot(outward), -1.0, 1.0) * GameConfig.CHASER_STEER
	# 走れる範囲の端では、それ以上曲がらない(曲がろうとして前へのスピードが落ちないように)
	var r_now := Vector2(a.position.x, a.position.z).length()
	if (steer < 0.0 and r_now <= GameConfig.CHASER_MIN_RADIUS + 0.001) \
			or (steer > 0.0 and r_now >= GameConfig.CHASER_MAX_RADIUS - 0.001):
		steer = 0.0
	var dir := (forward + outward * steer).normalized()
	var p := a.position + dir * GameConfig.CHASER_SPEED * delta
	var flat := Vector2(p.x, p.z)
	var r := clampf(flat.length(), GameConfig.CHASER_MIN_RADIUS, GameConfig.CHASER_MAX_RADIUS)
	flat = flat.normalized() * r
	a.position = Vector3(flat.x, 0.0, flat.y)
	a.yaw = atan2(-dir.x, -dir.z)


func _finish(winner_id: int, loser_id: int, reason: String) -> void:
	phase = Phase.RESULT
	result = {"winner": winner_id, "loser": loser_id, "reason": reason}
	for a in actors:
		a.move_dir = Vector3.ZERO
	var e := result.duplicate()
	e["type"] = "result"
	events.append(e)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _seat_at_angle(angle: float) -> int:
	var n := GameConfig.SEAT_COUNT
	return posmod(roundi(angle / TAU * n), n)


func _drop() -> void:
	phase = Phase.DROPPED
	handkerchief_on_floor = true
	handkerchief_position = _ring_point(drop_angle, GameConfig.DROP_RADIUS)
	events.append({
		"type": "dropped",
		"seat": drop_target_seat,
		"pos": handkerchief_position,
	})
	# 振り向いたまま待っていた人の後ろに落とした場合は、その場で見つかる
	var target := get_actor_at_seat(drop_target_seat)
	if target and target.looking_back:
		events.append({"type": "found", "actor": target.id})


func _sit(actor: Actor, seat: int) -> void:
	actor.role = Role.SEATED
	actor.seat_index = seat
	actor.position = seat_positions[seat]
	actor.yaw = seat_yaws[seat]


## 鬼が歩く輪の上、角度 angle の位置に置き、進行方向(角度が増える向き)を向かせる。
func _place_on_walk_ring(actor: Actor, angle: float) -> void:
	actor.seat_index = -1
	actor.position = _ring_point(angle, GameConfig.ONI_WALK_RADIUS)
	actor.yaw = angle - PI / 2.0


func _ring_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle)) * radius
