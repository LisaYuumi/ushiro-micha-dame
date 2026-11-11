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
	## お手つきの回数(OTETSUKI_LIMIT 回でペナルティ。そのあと 0 に戻る)
	var otetsuki_count: int = 0
	## お手つきが多すぎて、次のラウンドは強制的に鬼
	var must_be_oni: bool = false
	## 走る向き(追いかけるとき。長さ 0〜1)
	var move_dir: Vector3 = Vector3.ZERO
	## このラウンドで送れるスタンプの残り(-1 = 何回でも)
	var stamps_left: int = 0
	## このラウンドで投げられるバナナの皮の残り
	var bananas_left: int = 0
	## バナナで転んで止まっている残り時間(秒)
	var slip_left: float = 0.0


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
## 鬼を人(この画面のプレイヤー)が操作しているか
var oni_is_player: bool = false
## 人が鬼のとき: 立ち止まっているか(「止まる」を押している間)
var oni_holding_stop: bool = false
## 鬼が歩きはじめた角度(何周したかを数える)
var oni_start_angle: float = 0.0
## 鬼の、輪の中心からの距離(人が鬼で追いかけっこ中は、内側/外側に曲がれる)
var oni_radius: float = GameConfig.ONI_WALK_RADIUS

var phase: int = Phase.WALKING
## 鬼が輪の上のどこにいるか(角度・ラジアン。増え続ける=何周したかもわかる)
var oni_angle: float = 0.0
## ハンカチを落とす相手の席
var drop_target_seat: int = -1
## 鬼がこの角度まで来たら落とす
var drop_angle: float = 0.0
## 次に鬼が席の真後ろを通る角度
var next_seat_crossing: float = 0.0
## 鬼が最後にその席の真後ろを通ってから何秒たったか(席の番号順。まだ通っていなければ INF)
var seat_pass_age: Array[float] = []
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

## 鬼の声: 次に出せるまでの時間/最後に声を出してから何秒たったか/
## 本物を落としたとき声でかき消されたか/ボットの鬼が次に声を出すまで
var oni_voice_cooldown: float = 0.0
var last_voice_age: float = INF
var drop_masked: bool = false
var _bot_oni_voice_left: float = 0.0

## 床に落ちているバナナの皮 [{"pos": Vector3, "sender": id}]
var bananas: Array = []

## 試合: 今のラウンド(0 から)、点数(id -> 点)、試合が終わったか
var round_index: int = 0
var scores: Dictionary = {}
var match_over: bool = false
## 直前のラウンド切りかえで、お手つきが多くて強制的に鬼になった人(いなければ -1)
var forced_oni_id: int = -1
var _round_start_lineup: Array = []
var _round_start_oni: int = -1

## いま表示中のスタンプ。受け取った人の id -> {"kind", "sender", "time_left", "truthful"}
var active_stamps: Dictionary = {}

## 表示側へのお知らせ(Dictionary の配列)
var events: Array = []

var rng := RandomNumberGenerator.new()


## 新しい試合を始める(ラウンド1から)。seed を指定すると毎回同じ展開になる(テスト用)。
## player_is_oni = true なら、この画面のプレイヤーが最初の鬼になる。
func start_match(seed_value: int = -1, player_is_oni: bool = false) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	seat_positions.clear()
	seat_yaws.clear()
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
		Color(0.85, 0.2, 0.2),
	]
	# 登場人物は試合のあいだ同じ。席に5人、鬼が1人(id は 0〜5)
	actors.clear()
	local_player_id = GameConfig.SEAT_COUNT if player_is_oni else 0
	var bot_no := 1
	for i in GameConfig.SEAT_COUNT + 1:
		var actor := Actor.new()
		actor.id = i
		actor.is_bot = i != local_player_id
		if actor.is_bot:
			actor.display_name = "ボット%d" % bot_no
			bot_no += 1
		else:
			actor.display_name = "あなた"
		actor.color = palette[0] if not actor.is_bot else palette[bot_no - 1]
		actors.append(actor)
	scores = {}
	for a in actors:
		scores[a.id] = 0
	round_index = 0
	match_over = false
	var lineup := []
	for i in GameConfig.SEAT_COUNT:
		lineup.append(i)
	_begin_round(lineup, GameConfig.SEAT_COUNT)


## 互換用: 新しい試合を始める
func start_round(seed_value: int = -1, player_is_oni: bool = false) -> void:
	start_match(seed_value, player_is_oni)


## 勝敗が出たあと、次のラウンドへ。負けた人が次の鬼になる。
## 最後のラウンドのあとなら試合終了(match_over)。戻り値: 次のラウンドが始まったら true
func next_round() -> bool:
	if phase != Phase.RESULT or match_over:
		return false
	if round_index + 1 >= GameConfig.ROUNDS_PER_MATCH:
		match_over = true
		events.append({"type": "match_over", "scores": scores.duplicate()})
		return false
	var seats := _lineup_after_result()
	round_index += 1
	_begin_round(seats[0], seats[1])
	return true


## 今のラウンドを、同じ並びのまま最初からやり直す
func restart_round() -> void:
	_begin_round(_round_start_lineup.duplicate(), _round_start_oni)


## 今のラウンドの落とし物の名前と重さ(0〜1)
func item_name() -> String:
	return Items.name_of(round_index)


func item_weight() -> float:
	return Items.weight_of(round_index)


## 勝敗のあとの並び: [席ごとの id の配列, 次の鬼の id]
func _lineup_after_result() -> Array:
	var seat_ids := []
	seat_ids.resize(GameConfig.SEAT_COUNT)
	for a in actors:
		if a.role == Role.SEATED and a.seat_index >= 0:
			seat_ids[a.seat_index] = a.id
	var next_oni: int = result["loser"]
	match result["reason"]:
		"touched":
			# 鬼が負け: 追いかけた人は自分の席に戻る。鬼はそのまま
			seat_ids[vacant_seat] = chaser_id
		"sat":
			# 鬼はもう空いた席に座っている。追いかけた人が次の鬼
			pass
		"missed":
			# 気づかなかった人が鬼になり、鬼がその席に入る
			seat_ids[drop_target_seat] = oni_id
	# お手つきが多すぎる人は、次のラウンドは強制的に鬼
	var forced := _too_many_otetsuki()
	forced_oni_id = forced
	if forced >= 0:
		if forced != next_oni:
			var idx := seat_ids.find(forced)
			if idx >= 0:
				# 本来鬼になるはずだった人は、強制的に鬼になる人の席に座る
				seat_ids[idx] = next_oni
				next_oni = forced
		get_actor(forced).must_be_oni = false
	return [seat_ids, next_oni]


## お手つきが多すぎて、次は強制的に鬼になる人(いなければ -1)
func _too_many_otetsuki() -> int:
	for a in actors:
		if a.must_be_oni:
			return a.id
	return -1


## seat_ids[i] の人を席 i に座らせ、oni を鬼にしてラウンドを始める
func _begin_round(seat_ids: Array, oni: int) -> void:
	events.clear()
	_round_start_lineup = seat_ids.duplicate()
	_round_start_oni = oni
	for a in actors:
		a.looking_back = false
		a.move_dir = Vector3.ZERO
		a.stamps_left = GameConfig.STAMPS_PER_ROUND
		a.bananas_left = GameConfig.BANANAS_PER_ROUND
		a.slip_left = 0.0
	for i in seat_ids.size():
		_sit(get_actor(seat_ids[i]), i)
	oni_id = oni
	var oni_actor := get_actor(oni)
	oni_actor.role = Role.ONI
	oni_is_player = oni == local_player_id

	# 鬼は席と席の間から歩きはじめる
	oni_angle = seat_angle(0) + TAU / (GameConfig.SEAT_COUNT * 2)
	oni_start_angle = oni_angle
	oni_radius = GameConfig.ONI_WALK_RADIUS
	oni_holding_stop = false
	_place_on_walk_ring(oni_actor, oni_angle)

	phase = Phase.WALKING
	handkerchief_on_floor = false
	oni_pause_left = 0.0
	seat_pass_age.clear()
	for i in GameConfig.SEAT_COUNT:
		seat_pass_age.append(INF)
	chaser_id = -1
	vacant_seat = -1
	oni_entering = false
	result = {}
	active_stamps = {}
	bananas = []
	oni_voice_cooldown = 0.0
	last_voice_age = INF
	drop_masked = false
	_bot_oni_voice_left = rng.randf_range(GameConfig.BOT_ONI_VOICE_INTERVAL_MIN, GameConfig.BOT_ONI_VOICE_INTERVAL_MAX)
	var step := TAU / GameConfig.SEAT_COUNT
	next_seat_crossing = ceilf(oni_angle / step) * step
	if oni_is_player:
		# 人が鬼のときは、いつ誰に落とすかは本人が決める
		drop_target_seat = -1
		drop_angle = INF
	else:
		_plan_drop()
	events.append({"type": "round_start", "round": round_index, "item": item_name()})


## 時間を delta 秒すすめる。
func tick(delta: float) -> void:
	_tick_stamps(delta)
	oni_voice_cooldown = maxf(oni_voice_cooldown - delta, 0.0)
	last_voice_age += delta
	for i in seat_pass_age.size():
		seat_pass_age[i] += delta
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
	if not oni_is_player:
		# ボットの鬼も、ときどき声を出す(ふりになる)
		_bot_oni_voice_left -= delta
		if _bot_oni_voice_left <= 0.0:
			_bot_oni_voice_left = rng.randf_range(GameConfig.BOT_ONI_VOICE_INTERVAL_MIN, GameConfig.BOT_ONI_VOICE_INTERVAL_MAX)
			_emit_voice(Voices.ALL[rng.randi_range(0, Voices.ALL.size() - 1)])
	oni_angle += _oni_walk_speed(oni) / GameConfig.ONI_WALK_RADIUS * delta
	if oni_is_player and phase == Phase.WALKING and drop_angle == INF \
			and oni_angle - oni_start_angle >= GameConfig.ONI_MAX_LAPS_BEFORE_DROP * TAU:
		# 何周しても落とさない: 次の席の後ろで自動的に落とす
		drop_angle = next_seat_crossing
		drop_target_seat = _seat_at_angle(next_seat_crossing)
		events.append({"type": "auto_drop", "seat": drop_target_seat})
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
	if active_stamps.has(actor_id):
		# スタンプが出ている間に振り向いた(「まだ平気」のだましは失敗)
		active_stamps[actor_id]["looked"] = true
	if has_handkerchief_behind(a):
		events.append({"type": "found", "actor": actor_id})
		# 本当の「落ちてる!」などで振り向けた: 教えた人に点
		var helped: Dictionary = active_stamps.get(actor_id, {})
		if not helped.is_empty() and helped["scorable"] and Stamps.says_look(helped["kind"]) and helped["truthful"] \
				and not helped.get("credited", false):
			helped["credited"] = true
			_award_help(helped["sender"], actor_id)
	else:
		a.otetsuki_count += 1
		scores[a.id] = scores.get(a.id, 0) + GameConfig.SCORE_OTETSUKI
		var reset := false
		if a.otetsuki_count >= GameConfig.OTETSUKI_LIMIT:
			# お手つきが多すぎる: プラスの点数は 0 に(マイナスはそのまま)
			reset = scores[a.id] > 0
			scores[a.id] = mini(scores[a.id], 0)
			a.otetsuki_count = 0
			if GameConfig.OTETSUKI_FORCES_ONI:
				a.must_be_oni = true
		events.append({
			"type": "otetsuki",
			"actor": actor_id,
			"count": a.otetsuki_count,
			"points": GameConfig.SCORE_OTETSUKI,
			"limit_reached": a.otetsuki_count == 0,
			"score_reset": reset,
		})
		# 嘘の「落ちてる!」などにだまされて振り向いた: 送った人に点
		var st: Dictionary = active_stamps.get(actor_id, {})
		if not st.is_empty() and st["scorable"] and Stamps.says_look(st["kind"]) and not st["truthful"]:
			_award_deceive(st["sender"], actor_id, st["kind"])


## 後ろのハンカチを拾って立ち上がる。
## 振り向いていなければ、まず振り向く(後ろに何もなければ、ふつうに振り向いたときと同じくお手つき)。
func pick_up(actor_id: int) -> void:
	var a := get_actor(actor_id)
	if a == null or a.role != Role.SEATED:
		return
	if not a.looking_back:
		set_looking_back(actor_id, true)
	if phase != Phase.DROPPED or not has_handkerchief_behind(a):
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
	# 追いかけっこが始まったらスタンプは消える
	for id in active_stamps.keys():
		events.append({"type": "stamp_end", "target": id})
	active_stamps = {}
	# 鬼は気づいてすぐ走り出す。空いた席まで(少なくとも一度は)輪を回ってから座る
	oni_pause_left = 0.0
	oni_entering = false
	var target := seat_angle(vacant_seat)
	oni_seat_angle = target + ceilf((oni_angle - target + 0.001) / TAU) * TAU
	events.append({"type": "picked_up", "actor": a.id})


## スタンプを送る。座っている人どうしで、追いかけっこの前まで。
## 相手に表示中のスタンプがあれば届かない(早い者勝ち)。届かなかったときは回数を使わない。
## 戻り値: 届いたら true
func send_stamp(sender_id: int, target_id: int, kind: String) -> bool:
	var sender := get_actor(sender_id)
	var target := get_actor(target_id)
	if sender == null or target == null or sender_id == target_id:
		return false
	if sender.role != Role.SEATED or target.role != Role.SEATED:
		return false
	if phase != Phase.WALKING and phase != Phase.DROPPED:
		return false
	if sender.stamps_left == 0 or not (kind in Stamps.ALL):
		return false
	if active_stamps.has(target_id):
		events.append({"type": "stamp_blocked", "sender": sender_id, "target": target_id})
		return false
	if sender.stamps_left > 0:
		sender.stamps_left -= 1
	# 本当のことを言ったか(あとで点数に使う)。「信じて!」は「見ろ」の意味として扱う
	var truthful := Stamps.says_look(kind) == has_handkerchief_behind(target)
	active_stamps[target_id] = {
		"kind": kind,
		"sender": sender_id,
		"time_left": GameConfig.STAMP_SHOW_TIME,
		"truthful": truthful,
		"looked": false,
		# 鬼がついさっき後ろを通った人へのスタンプだけ、点数の対象
		"scorable": seat_pass_age[target.seat_index] <= GameConfig.STAMP_SCORE_RECENT_PASS,
	}
	events.append({"type": "stamp", "sender": sender_id, "target": target_id, "kind": kind})
	return true


## 走る向きの希望を伝える(追いかける人だけ)。dir は床の上の向き、長さ 0〜1。
## 追いかける人は自動で前に走るので、使われるのは「内側/外側」の成分だけ。
func set_move(actor_id: int, dir: Vector3) -> void:
	var a := get_actor(actor_id)
	if a == null:
		return
	dir.y = 0.0
	a.move_dir = dir.limit_length(1.0)


# --- 人が鬼のときの命令 ---

## 鬼が声を出す(人の鬼の命令)。出せたら true
func oni_voice(actor_id: int, kind: String) -> bool:
	if not _is_player_oni(actor_id):
		return false
	return _emit_voice(kind)


func _emit_voice(kind: String) -> bool:
	if not (kind in Voices.ALL) or oni_voice_cooldown > 0.0:
		return false
	if phase != Phase.WALKING and phase != Phase.DROPPED:
		return false
	oni_voice_cooldown = GameConfig.ONI_VOICE_COOLDOWN
	last_voice_age = 0.0
	var oni := get_actor(oni_id)
	events.append({
		"type": "voice",
		"kind": kind,
		"pos": oni.position,
		"seat": _seat_at_angle(_nearest_seat_crossing()),
	})
	return true


## バナナの皮を投げる。座っている人が、追いかけっこ中に、鬼か追いかける人を狙う。
## 狙った人の少し前の通り道に落ちる(曲がればよけられる)。投げられたら true
func throw_banana(sender_id: int, target_id: int) -> bool:
	var sender := get_actor(sender_id)
	var target := get_actor(target_id)
	if sender == null or target == null or phase != Phase.CHASE:
		return false
	if sender.role != Role.SEATED or sender.bananas_left <= 0:
		return false
	if target_id != oni_id and target_id != chaser_id:
		return false
	sender.bananas_left -= 1
	var ang := atan2(target.position.x, target.position.z)
	var r := Vector2(target.position.x, target.position.z).length()
	var pos := _ring_point(ang + GameConfig.BANANA_AHEAD / maxf(r, 0.01), r)
	bananas.append({"pos": pos, "sender": sender_id})
	events.append({"type": "banana", "sender": sender_id, "target": target_id, "pos": pos})
	return true


## 「止まる」を押している/離した
func set_oni_stop(actor_id: int, value: bool) -> void:
	if _is_player_oni(actor_id):
		oni_holding_stop = value


## いちばん近い席の後ろにハンカチを落とす。席の後ろから離れすぎていたら落とせない。
func oni_drop(actor_id: int) -> bool:
	if not _is_player_oni(actor_id) or phase != Phase.WALKING:
		return false
	var crossing := _nearest_seat_crossing()
	if absf(oni_angle - crossing) * GameConfig.ONI_WALK_RADIUS > GameConfig.ONI_DROP_REACH:
		events.append({"type": "drop_failed", "actor": actor_id})
		return false
	drop_angle = crossing
	drop_target_seat = _seat_at_angle(crossing)
	_drop()
	return true


## 落とすふり: いちばん近い席の後ろで、本物と同じ物音だけを出す
## 「落とす音」: 落とさずに、いちばん近い席の後ろで本物と同じ置く音だけを出す(人の鬼の命令)
func oni_feint(actor_id: int) -> void:
	if not _is_player_oni(actor_id):
		return
	_emit_fake_drop()


func _emit_fake_drop() -> void:
	if phase != Phase.WALKING and phase != Phase.DROPPED:
		return
	var crossing := _nearest_seat_crossing()
	events.append({
		"type": "rustle",
		"seat": _seat_at_angle(crossing),
		"pos": _ring_point(crossing, GameConfig.DROP_RADIUS),
		"weight": item_weight(),
		"feint": true,
	})


func _is_player_oni(actor_id: int) -> bool:
	return oni_is_player and actor_id == oni_id


## 鬼にいちばん近い「席の真後ろ」の角度
func _nearest_seat_crossing() -> float:
	var step := TAU / GameConfig.SEAT_COUNT
	return roundf(oni_angle / step) * step


## 鬼が歩く速さ。ボットの鬼はいつも同じ。人の鬼はスティックで変えられ、止まることもできる
func _oni_walk_speed(oni: Actor) -> float:
	# 落とすまでは重い落とし物を持っているので遅い
	var carry := lerpf(1.0, GameConfig.ONI_CARRY_SPEED_HEAVY, item_weight()) if phase == Phase.WALKING else 1.0
	return _oni_walk_speed_base(oni) * carry


func _oni_walk_speed_base(oni: Actor) -> float:
	if not oni_is_player:
		return GameConfig.ONI_WALK_SPEED
	if oni_holding_stop:
		return 0.0
	var ang := oni_angle
	var forward := Vector3(cos(ang), 0.0, -sin(ang))
	var f := clampf(oni.move_dir.dot(forward), -1.0, 1.0)
	if f >= 0.0:
		return lerpf(GameConfig.ONI_WALK_SPEED, GameConfig.ONI_WALK_SPEED_MAX, f)
	return lerpf(GameConfig.ONI_WALK_SPEED, GameConfig.ONI_WALK_SPEED_MIN, -f)


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


## 席 from に座っている人から、席 to の人の後ろが見えるか。
## 両どなりは見えない(向かい側だけ見える)。見え方はカメラ(SEAT_CAM_HFOV)と合わせてある
static func can_see_behind(from_seat: int, to_seat: int) -> bool:
	var n := GameConfig.SEAT_COUNT
	var d := posmod(to_seat - from_seat, n)
	return d >= 2 and d <= n - 2


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
			"stamps_left": a.stamps_left,
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
		"stamps": active_stamps,
		"oni_is_player": oni_is_player,
		"round": round_index,
		"item": item_name(),
		"scores": scores,
		"match_over": match_over,
		"bananas": bananas,
		"drop_masked": drop_masked,
		"oni_radius": oni_radius,
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
	seat_pass_age[_seat_at_angle(oni_angle)] = 0.0
	if phase == Phase.DROPPED and absf(oni_angle - (drop_angle + TAU)) < 0.001:
		# 一周して戻ってきても気づかれなかった: 落とされた人の負け
		var target := get_actor_at_seat(drop_target_seat)
		_finish(oni_id, target.id, "missed")
		return
	if phase == Phase.WALKING and absf(oni_angle - drop_angle) < 0.001:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		if not oni_is_player and rng.randf() < GameConfig.BOT_ONI_VOICE_AT_DROP:
			# ボットの鬼: 声で置く音をかき消す
			oni_voice_cooldown = 0.0
			_emit_voice(Voices.ALL[rng.randi_range(0, Voices.ALL.size() - 1)])
		_drop()
	elif oni_is_player:
		# 人が鬼のときは、立ち止まるのも物音も本人が決める
		return
	elif rng.randf() < GameConfig.DECOY_STOP_CHANCE:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		if rng.randf() < GameConfig.BOT_ONI_FAKE_DROP_CHANCE:
			# ボットの鬼が、わざと「落とす音」を出す
			_emit_fake_drop()


func _tick_stamps(delta: float) -> void:
	for id in active_stamps.keys():
		active_stamps[id]["time_left"] -= delta
		if active_stamps[id]["time_left"] <= 0.0:
			var st: Dictionary = active_stamps[id]
			active_stamps.erase(id)
			events.append({"type": "stamp_end", "target": id})
			# 「まだ平気」で、出ている間に振り向かなかった:
			#   本当は落ちていた → だました / 本当に落ちていない → 教えた(振り向かずにすんだ)
			if st["kind"] == Stamps.SAFE and st["scorable"] and not st["looked"]:
				if st["truthful"]:
					_award_help(st["sender"], id)
				else:
					_award_deceive(st["sender"], id, st["kind"])


func _award_help(sender_id: int, target_id: int) -> void:
	scores[sender_id] = scores.get(sender_id, 0) + GameConfig.SCORE_HELP
	events.append({
		"type": "helped",
		"sender": sender_id,
		"target": target_id,
		"points": GameConfig.SCORE_HELP,
	})


func _award_deceive(sender_id: int, target_id: int, kind: String) -> void:
	scores[sender_id] = scores.get(sender_id, 0) + GameConfig.SCORE_DECEIVE
	events.append({
		"type": "deceived",
		"sender": sender_id,
		"target": target_id,
		"kind": kind,
		"points": GameConfig.SCORE_DECEIVE,
	})


func _tick_chase(delta: float) -> void:
	var oni := get_actor(oni_id)
	var chaser := get_actor(chaser_id)
	if not _slipping(chaser, delta):
		_move_chaser(chaser, delta)
		_check_banana(chaser)

	var sat := false
	if _slipping(oni, delta):
		pass
	elif oni_entering:
		var seat_pos := seat_positions[vacant_seat]
		var to_seat := seat_pos - oni.position
		if to_seat.length() > 0.001:
			oni.yaw = atan2(-to_seat.x, -to_seat.z)
		oni.position = oni.position.move_toward(seat_pos, GameConfig.ONI_RUN_SPEED * delta)
		sat = oni.position.distance_to(seat_pos) < 0.01
	else:
		_move_oni_running(oni, delta)
		oni_entering = oni_angle >= oni_seat_angle
		_check_banana(oni)

	if _flat_distance(chaser.position, oni.position) <= GameConfig.TOUCH_DISTANCE:
		_finish(chaser_id, oni_id, "touched")
	elif sat:
		_sit(oni, vacant_seat)
		_finish(oni_id, chaser_id, "sat")


## 転んでいる間は動けない。転んでいたら true
func _slipping(a: Actor, delta: float) -> bool:
	if a.slip_left <= 0.0:
		return false
	a.slip_left -= delta
	return true


## バナナの皮を踏んだら転ぶ(皮はなくなる)
func _check_banana(a: Actor) -> void:
	for i in bananas.size():
		if _flat_distance(a.position, bananas[i]["pos"]) <= GameConfig.BANANA_HIT_RADIUS:
			a.slip_left = GameConfig.SLIP_TIME
			var b: Dictionary = bananas[i]
			bananas.remove_at(i)
			events.append({"type": "slip", "actor": a.id, "sender": b["sender"]})
			return


## 追いかけっこ中の鬼: 空いた席に向かって自動で走る。
## 人の鬼は、追いかける人と同じく内側/外側に曲がれる。ボットの鬼は輪の上をそのまま走る。
func _move_oni_running(oni: Actor, delta: float) -> void:
	var forward := Vector3(cos(oni_angle), 0.0, -sin(oni_angle))
	var outward := Vector3(sin(oni_angle), 0.0, cos(oni_angle))
	var steer := 0.0
	if oni_is_player:
		steer = clampf(oni.move_dir.dot(outward), -1.0, 1.0) * GameConfig.CHASER_STEER
	var dir := (forward + outward * steer).normalized()
	var step := GameConfig.ONI_RUN_SPEED * delta
	var new_r := clampf(oni_radius + dir.dot(outward) * step, GameConfig.CHASER_MIN_RADIUS, GameConfig.CHASER_MAX_RADIUS)
	var dr := new_r - oni_radius
	var forward_step := sqrt(maxf(step * step - dr * dr, 0.0))
	oni_angle = minf(oni_angle + forward_step / ((oni_radius + new_r) / 2.0), oni_seat_angle)
	oni_radius = new_r
	oni.position = _ring_point(oni_angle, oni_radius)
	oni.yaw = atan2(-dir.x, -dir.z)


## 追いかける人を動かす。鬼と同じ向きに自動で走り続け、内側/外側にだけ曲がれる。
## 席の内側には入れない。立ち止まって待ちぶせはできない。
func _move_chaser(a: Actor, delta: float) -> void:
	var ang := atan2(a.position.x, a.position.z)
	# 鬼が走る向き(角度が増える向き)と、輪の外向き
	var forward := Vector3(cos(ang), 0.0, -sin(ang))
	var outward := Vector3(sin(ang), 0.0, cos(ang))
	var steer := clampf(a.move_dir.dot(outward), -1.0, 1.0) * GameConfig.CHASER_STEER
	var dir := (forward + outward * steer).normalized()
	# 輪の中心からの距離(r)と角度(ang)で動かす。走れる範囲の端に当たったら、
	# 外/内へ動けなかった分を前へ回して、いつでも同じ速さで走る
	# 重い落とし物を持っているほど遅い
	var step := GameConfig.CHASER_SPEED * lerpf(1.0, GameConfig.CARRY_SPEED_HEAVY, item_weight()) * delta
	var r := Vector2(a.position.x, a.position.z).length()
	var dr := dir.dot(outward) * step
	var new_r := clampf(r + dr, GameConfig.CHASER_MIN_RADIUS, GameConfig.CHASER_MAX_RADIUS)
	dr = new_r - r
	var forward_step := sqrt(maxf(step * step - dr * dr, 0.0))
	ang += forward_step / maxf((r + new_r) / 2.0, 0.01)
	a.position = Vector3(sin(ang), 0.0, cos(ang)) * new_r
	a.yaw = atan2(-dir.x, -dir.z)


func _finish(winner_id: int, loser_id: int, reason: String) -> void:
	phase = Phase.RESULT
	result = {"winner": winner_id, "loser": loser_id, "reason": reason}
	match reason:
		"sat":
			scores[winner_id] += GameConfig.SCORE_ONI_SAT
		"touched":
			scores[winner_id] += GameConfig.SCORE_CHASER_TOUCHED
	scores[loser_id] += GameConfig.SCORE_LOSE
	result["scores"] = scores.duplicate()
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
	# 声を出した直後なら、置く音はかき消される
	drop_masked = last_voice_age <= GameConfig.VOICE_MASK_WINDOW
	handkerchief_position = _ring_point(drop_angle, GameConfig.DROP_RADIUS)
	events.append({
		"type": "dropped",
		"seat": drop_target_seat,
		"pos": handkerchief_position,
		"weight": item_weight(),
		"masked": drop_masked,
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
