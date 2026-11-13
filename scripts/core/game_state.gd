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

## OUT: お手つきで輪から抜けて、真ん中で体育座りしている(そのラウンドの間)
enum Role { SEATED, ONI, CHASER, OUT }
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
	## 外れの振り向きの回数(試合のあいだ数える。表情に使う)
	var otetsuki_count: int = 0
	## 走る向き(追いかけるとき。長さ 0〜1)
	var move_dir: Vector3 = Vector3.ZERO
	## このラウンドで送れるスタンプの残り(-1 = 何回でも)
	var stamps_left: int = 0
	## このラウンドで投げられるバナナの皮の残り
	var bananas_left: int = 0
	## バナナで転んで止まっている残り時間(秒)
	var slip_left: float = 0.0
	## このラウンドで振り向ける残り回数/振り向いた回数
	var looks_left: int = 0
	var looks_used: int = 0
	## このラウンドでスタンプを届けた相手の id(同じ相手には1ラウンド1回まで)
	var stamped_targets: Array = []
	## ボットの性格(Personalities の名前。人は "")
	var personality: String = ""
	## お手つきで抜けた人の、もとの席(次のラウンドはここに戻る。抜けていなければ -1)
	var home_seat: int = -1
	## 牛乳をかけられたときの鬼の角度(INF = かかっていない)。鬼が半周歩くまで画面が白い
	var milk_angle: float = INF


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
## 人の鬼がいちばん進んだ角度(そこから ONI_BACK_LIMIT メートルまでしか後ろに戻れない)
var oni_max_angle: float = 0.0
## 人の鬼がスティックを後ろに倒している時間(ONI_BACK_HOLD 秒たったら後ろに戻りはじめる)
var _oni_back_hold: float = 0.0
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
## 鬼がこのラウンドでかけられる牛乳の残り
var milk_left: int = 0
## ボットの鬼: 牛乳をかける席と、かけてよくなる角度(-1 = かけない)/落とすときに落とす相手にかけるか
var _bot_milk_seat: int = -1
var _bot_milk_after: float = 0.0
var _bot_milk_at_drop: bool = false
## このラウンドが始まったときの点数(お手つきで抜けた人は、ここに戻す = そのラウンド0点)
var _round_base_scores: Dictionary = {}

## 床に落ちているバナナの皮 [{"pos": Vector3, "sender": id}]
var bananas: Array = []

## 席の数(この試合。鬼は別に1人)
var seat_count: int = GameConfig.SEAT_COUNT
## 鬼は人だけにするか(オンラインの試遊用)
var humans_only_oni: bool = false
## ラウンドを始めるたびに1つ増える(ホスト以外の画面が、見た目を作り直す合図)
var round_serial: int = 0

## 試合: 今のラウンド(0 から)、点数(id -> 点)、試合が終わったか
var round_index: int = 0
var scores: Dictionary = {}
var match_over: bool = false
var _round_start_lineup: Array = []
var _round_start_oni: int = -1

## いま表示中のスタンプ。受け取った人の id -> 届いた順の配列(STAMP_SLOTS 個まで)
## [{"kind", "sender", "sender_role", "born_angle", "truthful", "looked", "scorable", "credited"}]
var active_stamps: Dictionary = {}

## 鬼の手下(このラウンド。いなければ -1)。本人以外には勝敗が出るまで知らせない
## (ホストは snapshot(見る人) で、ほかの人の分からは消して送る)
var minion_id: int = -1
## 人ごとの、自分で決めたスタンプの言葉(id -> {種類: 言葉})。ない人・ない種類は初期の言葉
var stamp_words: Dictionary = {}
## 前のラウンドの手下(発表ずみなので、全員が知っている。ボットの信用に使う)
var last_minion_id: int = -1

## 表示側へのお知らせ(Dictionary の配列)
var events: Array = []

var rng := RandomNumberGenerator.new()


## 新しい試合を始める(ラウンド1から)。seed を指定すると毎回同じ展開になる(テスト用)。
## player_is_oni = true なら、この画面のプレイヤーが最初の鬼になる。
## seats: 席の数(鬼は別に1人。8人で遊ぶなら7、5人なら4)
## me_name / me_color: この画面のプレイヤーの名前と体の色(色の a が 0 なら決まった色)
func start_match(seed_value: int = -1, player_is_oni: bool = false, seats: int = GameConfig.SEAT_COUNT,
		me_name: String = "あなた", me_color: Color = Color(0, 0, 0, 0)) -> void:
	var me := seats if player_is_oni else 0
	var colors := {}
	if me_color.a > 0.0:
		colors[me] = me_color
	start_match_custom(seed_value, [me], me if player_is_oni else seats, {me: me_name}, false, seats, colors)
	local_player_id = me


## 人とボットの組み合わせを決めて、新しい試合を始める(オンライン対戦のホストが使う)。
## human_ids: 人が操作する登場人物の id(0〜SEAT_COUNT)/first_oni: 最初の鬼の id/
## names: id -> 表示名(書かれていない人はボット名)/humans_only_oni: 鬼は人だけにする/
## colors: id -> 体の色(人が選んだ色。書かれていない人は決まった色から、人の色と重ならないように)
func start_match_custom(seed_value: int, human_ids: Array, first_oni: int, names: Dictionary, humans_only: bool,
		seats: int = GameConfig.SEAT_COUNT, colors: Dictionary = {}) -> void:
	seat_count = seats
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_init_seats()
	humans_only_oni = humans_only

	var palette := [
		Color(0.95, 0.55, 0.25),
		Color(0.35, 0.65, 0.95),
		Color(0.45, 0.8, 0.45),
		Color(0.9, 0.8, 0.3),
		Color(0.75, 0.5, 0.9),
		Color(0.85, 0.2, 0.2),
		Color(0.3, 0.8, 0.8),
		Color(0.6, 0.45, 0.3),
	]
	# 登場人物は試合のあいだ同じ。席に SEAT_COUNT 人、鬼が1人(id は 0〜SEAT_COUNT)
	actors.clear()
	var bot_no := 1
	# 人が選んだ色に近い色は、ほかの人には使わない
	var free_colors := []
	for c in palette:
		var taken := false
		for k in colors:
			var mine: Color = colors[k]
			if Vector3(c.r - mine.r, c.g - mine.g, c.b - mine.b).length() < 0.25:
				taken = true
		if not taken:
			free_colors.append(c)
	if free_colors.is_empty():
		free_colors = palette.duplicate()
	var next_color := 0
	for i in seat_count + 1:
		var actor := Actor.new()
		actor.id = i
		actor.is_bot = not (i in human_ids)
		if names.has(i):
			actor.display_name = names[i]
		else:
			# ボットには性格をつけて、名前の横に出す
			actor.personality = Personalities.ALL[rng.randi_range(0, Personalities.ALL.size() - 1)]
			actor.display_name = "ボット%d(%s)" % [bot_no, Personalities.label(actor.personality)]
			bot_no += 1
		if colors.has(i):
			actor.color = colors[i]
		else:
			actor.color = free_colors[next_color % free_colors.size()]
			next_color += 1
		actors.append(actor)
	scores = {}
	for a in actors:
		scores[a.id] = 0
	round_index = 0
	match_over = false
	last_minion_id = -1
	var lineup := []
	for i in seat_count + 1:
		if i != first_oni:
			lineup.append(i)
	_begin_round(lineup, first_oni)


func _init_seats() -> void:
	seat_positions.clear()
	seat_yaws.clear()
	for i in seat_count:
		var a := seat_angle(i)
		seat_positions.append(_ring_point(a, GameConfig.RING_RADIUS))
		# 輪の中心を向く向き(-Z が正面なので、角度 a がそのまま中心向き)
		seat_yaws.append(a)


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
	seat_ids.resize(seat_count)
	for a in actors:
		if a.role == Role.SEATED and a.seat_index >= 0:
			seat_ids[a.seat_index] = a.id
		elif a.role == Role.OUT and a.home_seat >= 0:
			# お手つきで抜けた人は、もとの席に戻る
			seat_ids[a.home_seat] = a.id
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
		"all_out":
			# 全員お手つきで抜けた: 鬼はそのまま
			next_oni = oni_id
	# オンラインの試遊: 鬼は人だけ。ボットが負けたら、座っている人の中から次の鬼を選ぶ
	if humans_only_oni and get_actor(next_oni).is_bot:
		var humans := []
		for i in seat_ids.size():
			if not get_actor(seat_ids[i]).is_bot:
				humans.append(i)
		if not humans.is_empty():
			var idx: int = humans[rng.randi_range(0, humans.size() - 1)]
			var human: int = seat_ids[idx]
			seat_ids[idx] = next_oni
			next_oni = human
	return [seat_ids, next_oni]


## seat_ids[i] の人を席 i に座らせ、oni を鬼にしてラウンドを始める
func _begin_round(seat_ids: Array, oni: int) -> void:
	events.clear()
	round_serial += 1
	_round_start_lineup = seat_ids.duplicate()
	_round_start_oni = oni
	for a in actors:
		a.looking_back = false
		a.move_dir = Vector3.ZERO
		a.stamps_left = GameConfig.STAMPS_PER_ROUND
		a.bananas_left = GameConfig.BANANAS_PER_ROUND
		a.looks_left = GameConfig.LOOKS_PER_ROUND
		a.looks_used = 0
		a.stamped_targets = []
		a.slip_left = 0.0
		a.home_seat = -1
		a.milk_angle = INF
	for i in seat_ids.size():
		_sit(get_actor(seat_ids[i]), i)
	oni_id = oni
	var oni_actor := get_actor(oni)
	oni_actor.role = Role.ONI
	# 鬼を人が操作しているか(ボットの鬼は自動で歩いて落とす)
	oni_is_player = not oni_actor.is_bot

	# 鬼は席と席の間から歩きはじめる
	oni_angle = seat_angle(0) + TAU / (seat_count * 2)
	oni_start_angle = oni_angle
	oni_radius = GameConfig.ONI_WALK_RADIUS
	oni_max_angle = oni_angle
	_oni_back_hold = 0.0
	_place_on_walk_ring(oni_actor, oni_angle)

	phase = Phase.WALKING
	handkerchief_on_floor = false
	oni_pause_left = 0.0
	seat_pass_age.clear()
	for i in seat_count:
		seat_pass_age.append(INF)
	chaser_id = -1
	vacant_seat = -1
	oni_entering = false
	result = {}
	active_stamps = {}
	bananas = []
	milk_left = GameConfig.MILK_PER_ROUND
	_round_base_scores = scores.duplicate()
	var step := TAU / seat_count
	next_seat_crossing = ceilf(oni_angle / step) * step
	if oni_is_player:
		# 人が鬼のときは、いつ誰に落とすかは本人が決める
		drop_target_seat = -1
		drop_angle = INF
	else:
		_plan_drop()
		_plan_bot_milk()
	events.append({"type": "round_start", "round": round_index, "item": item_name()})
	# 座っている人(ボットも)から1人を手下にする。本人にだけ知らせる
	minion_id = seat_ids[rng.randi_range(0, seat_ids.size() - 1)]
	events.append({"type": "minion", "actor": minion_id, "private_to": minion_id})


## 時間を delta 秒すすめる。
func tick(delta: float) -> void:
	_tick_stamps(delta)
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
	oni_angle += _oni_walk_speed(oni, delta) / GameConfig.ONI_WALK_RADIUS * delta
	# 後ろに戻れるのは、いちばん進んだ地点から ONI_BACK_LIMIT メートル(3歩分)まで
	oni_angle = maxf(oni_angle, oni_max_angle - GameConfig.ONI_BACK_LIMIT / GameConfig.ONI_WALK_RADIUS)
	oni_max_angle = maxf(oni_max_angle, oni_angle)
	if oni_is_player and phase == Phase.WALKING and drop_angle == INF \
			and oni_angle - oni_start_angle >= GameConfig.ONI_MAX_LAPS_BEFORE_DROP * TAU \
			and get_actor_at_seat(_seat_at_angle(next_seat_crossing)) != null:
		# 何周しても落とさない: 次の席の後ろで自動的に落とす
		drop_angle = next_seat_crossing
		drop_target_seat = _seat_at_angle(next_seat_crossing)
		events.append({"type": "auto_drop", "seat": drop_target_seat})
	if oni_angle >= next_seat_crossing:
		# ちょうど席の真後ろで止まれるように位置をそろえる
		oni_angle = next_seat_crossing
		next_seat_crossing += TAU / seat_count
		_on_pass_behind_seat()
	_place_on_walk_ring(oni, oni_angle)


# --- 命令(プレイヤーの入力やボットから呼ばれる) ---

## 振り向く/前を向く。振り向いた瞬間に、後ろにハンカチがあるかを判定する。
func set_looking_back(actor_id: int, value: bool) -> void:
	var a := get_actor(actor_id)
	if a == null or a.role != Role.SEATED or a.looking_back == value:
		return
	var judged := phase == Phase.WALKING or phase == Phase.DROPPED
	if value and judged:
		# 振り向ける回数には限りがある
		if a.looks_left <= 0:
			events.append({"type": "no_looks", "actor": actor_id})
			return
		a.looks_left -= 1
		a.looks_used += 1
	a.looking_back = value
	# 追いかけっこ中・勝敗が出た後は、振り向いて見物してもお手つきにならない
	if not value or not judged:
		return
	var shown: Array = active_stamps.get(actor_id, [])
	for st in shown:
		# スタンプが出ている間に振り向いた(「まだ平気」は、教えるのもだますのも失敗)
		st["looked"] = true
	if has_handkerchief_behind(a):
		events.append({"type": "found", "actor": actor_id})
		# 本当の「落ちてる!」などで振り向けた: 教えた人に点
		for st in shown:
			if st["scorable"] and Stamps.says_look(st["kind"]) and st["truthful"] and not st["credited"]:
				st["credited"] = true
				_award_help(st, actor_id)
	else:
		# 外れの振り向き: 減点はしない。回数だけ数える(表情と、だました人の点数に使う)
		a.otetsuki_count += 1
		events.append({
			"type": "otetsuki",
			"actor": actor_id,
			"count": a.otetsuki_count,
		})
		# 嘘の「落ちてる!」などにだまされて振り向いた: 送った人に点
		for st in shown:
			if st["scorable"] and Stamps.says_look(st["kind"]) and not st["truthful"] and not st["credited"]:
				st["credited"] = true
				_award_deceive(st, actor_id)
		# 1回でもお手つきしたら、輪から抜けて真ん中で体育座り(このラウンドは0点)
		_go_out(a)


## お手つきした人が輪から抜ける。席は空いたまま残り、次のラウンドで戻る。
## 抜けた人は全員の後ろが見え、だれにでもスタンプを送れ、バナナも投げられる。このラウンドの点は0点
func _go_out(a: Actor) -> void:
	a.looking_back = false
	a.home_seat = a.seat_index
	a.seat_index = -1
	a.role = Role.OUT
	a.milk_angle = INF
	# 輪の真ん中に、もとの席の方を向いて座る
	var ang := seat_angle(a.home_seat)
	a.position = _ring_point(ang, GameConfig.OUT_SIT_RADIUS)
	a.yaw = ang + PI
	# このラウンドで取った点はなし(0点)
	scores[a.id] = _round_base_scores.get(a.id, scores.get(a.id, 0))
	# この人あてのスタンプは消える(点数は決めない)
	for st in active_stamps.get(a.id, []):
		events.append({"type": "stamp_end", "target": a.id, "sender": st["sender"]})
	active_stamps.erase(a.id)
	events.append({"type": "out", "actor": a.id})
	# ボットの鬼が落とす予定だった人が抜けたら、ほかの人を選び直す
	if not oni_is_player and phase == Phase.WALKING and drop_target_seat == a.home_seat:
		_plan_drop_from_here()
	if _bot_milk_seat == a.home_seat:
		_bot_milk_seat = -1
	# 全員が抜けて、もう落とす相手がいない: 鬼の勝ち(負けた人はいない)
	if phase == Phase.WALKING and _occupied_seats().is_empty():
		_finish(oni_id, -1, "all_out")


## 人が座っている席の番号
func _occupied_seats() -> Array:
	var out := []
	for i in seat_count:
		if get_actor_at_seat(i) != null:
			out.append(i)
	return out


## 牛乳が晴れるまでの残り(1 = かかったばかり、0 = 晴れた)
func milk_left_ratio(a: Actor) -> float:
	if not is_milked(a):
		return 0.0
	return 1.0 - (oni_angle - a.milk_angle) / (GameConfig.MILK_LAPS * TAU)


## 牛乳がかかっていて、画面が白いか(鬼が半周歩くまで)
func is_milked(a: Actor) -> bool:
	return a != null and a.milk_angle != INF and oni_angle - a.milk_angle < GameConfig.MILK_LAPS * TAU


## 後ろのハンカチを拾って立ち上がる。
## 振り向いていなければ、まず振り向く(後ろに何もなければ、ふつうに振り向いたときと同じくお手つき)。
func pick_up(actor_id: int) -> void:
	var a := get_actor(actor_id)
	if a == null or a.role != Role.SEATED:
		return
	if not a.looking_back:
		set_looking_back(actor_id, true)
	if not a.looking_back:
		return # もう振り向けない
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
	_clear_stamps(false)
	# 鬼は気づいてすぐ走り出す。空いた席まで(少なくとも一度は)輪を回ってから座る
	oni_pause_left = 0.0
	oni_entering = false
	var target := seat_angle(vacant_seat)
	oni_seat_angle = target + ceilf((oni_angle - target + 0.001) / TAU) * TAU
	events.append({"type": "picked_up", "actor": a.id})


## この人にスタンプを送れるか。送れるなら ""、送れないなら理由:
## "neighbor"(8人のときの両どなり)/"already"(このラウンドもう送った)/"full"(表示中が3つ)/
## "phase"(追いかけっこ中など)/"invalid"(自分・座っていない人など)
func stamp_block_reason(sender_id: int, target_id: int) -> String:
	var sender := get_actor(sender_id)
	var target := get_actor(target_id)
	if sender == null or target == null or sender_id == target_id:
		return "invalid"
	if (sender.role != Role.SEATED and sender.role != Role.ONI and sender.role != Role.OUT) or target.role != Role.SEATED:
		return "invalid"
	if phase != Phase.WALKING and phase != Phase.DROPPED:
		return "phase"
	if sender.stamps_left == 0:
		return "invalid"
	if sender.role == Role.SEATED and is_stamp_neighbor(sender.seat_index, target.seat_index):
		return "neighbor"
	if target_id in sender.stamped_targets:
		return "already"
	if active_stamps.get(target_id, []).size() >= GameConfig.STAMP_SLOTS:
		return "full"
	return ""


## 席 a と席 b が両どなりで、スタンプを送れない組か(8人のときだけ。5人のときは送れる)
func is_stamp_neighbor(a: int, b: int) -> bool:
	if seat_count < GameConfig.STAMP_NEIGHBOR_BLOCK_MIN_SEATS:
		return false
	var d := posmod(b - a, seat_count)
	return d == 1 or d == seat_count - 1


## スタンプを送る。座っている人と鬼から、座っている人へ。追いかけっこの前まで。
## 1人に表示されるのは STAMP_SLOTS 個まで(早い者勝ち)。同じ相手には1ラウンド1回。
## 届かなかったときは、その相手への1回を使わない。戻り値: 届いたら true
func send_stamp(sender_id: int, target_id: int, kind: String) -> bool:
	if not (kind in Stamps.ALL):
		return false
	var reason := stamp_block_reason(sender_id, target_id)
	if reason != "":
		if reason != "invalid":
			events.append({"type": "stamp_blocked", "sender": sender_id, "target": target_id,
					"reason": reason, "private_to": sender_id})
		return false
	var sender := get_actor(sender_id)
	var target := get_actor(target_id)
	if sender.stamps_left > 0:
		sender.stamps_left -= 1
	sender.stamped_targets.append(target_id)
	# 本当のことを言ったか(あとで点数に使う)。「信じて!」は「見ろ」の意味として扱う
	var truthful := Stamps.says_look(kind) == has_handkerchief_behind(target)
	if not active_stamps.has(target_id):
		active_stamps[target_id] = []
	active_stamps[target_id].append({
		"kind": kind,
		"sender": sender_id,
		# 点数は、送ったときの役で決まる(普通の人/手下/鬼)
		"sender_role": stamp_role_of(sender_id),
		# 鬼がここから半周歩いたら消える
		"born_angle": oni_angle,
		"truthful": truthful,
		"looked": false,
		"credited": false,
		# 鬼がついさっき後ろを通った人へのスタンプだけ、点数の対象
		"scorable": seat_pass_age[target.seat_index] <= GameConfig.STAMP_SCORE_RECENT_PASS,
	})
	events.append({"type": "stamp", "sender": sender_id, "target": target_id, "kind": kind})
	return true


## スタンプの点数を決める役: "oni"/"minion"/"normal"
func stamp_role_of(actor_id: int) -> String:
	if actor_id == oni_id:
		return "oni"
	if actor_id == minion_id:
		return "minion"
	return "normal"


## 走る向きの希望を伝える(追いかける人だけ)。dir は床の上の向き、長さ 0〜1。
## 追いかける人は自動で前に走るので、使われるのは「内側/外側」の成分だけ。
func set_move(actor_id: int, dir: Vector3) -> void:
	var a := get_actor(actor_id)
	if a == null:
		return
	dir.y = 0.0
	a.move_dir = dir.limit_length(1.0)


# --- 人が鬼のときの命令 ---

## 牛乳をかける(人の鬼の命令)。タップで選んだ座っている人にかける(1ラウンド MILK_PER_ROUND 回。どこからでも)。
## かかった人は、鬼が半周歩くまで画面が白くなる(見た目だけ。音は聞こえる)。かけられたら true
func oni_milk(actor_id: int, target_id: int) -> bool:
	if not _is_player_oni(actor_id):
		return false
	var target := get_actor(target_id)
	if not can_milk(target_id):
		if target == null and (phase == Phase.WALKING or phase == Phase.DROPPED):
			events.append({"type": "milk_failed", "actor": actor_id, "private_to": actor_id})
		return false
	return _milk(target)


## この人に、いま牛乳をかけられるか(座っている人だけ。残りがあり、追いかけっこの前)
func can_milk(target_id: int) -> bool:
	var t := get_actor(target_id)
	return t != null and t.role == Role.SEATED and milk_left > 0 \
			and (phase == Phase.WALKING or phase == Phase.DROPPED)


func _milk(target: Actor) -> bool:
	if milk_left <= 0 or target == null or target.role != Role.SEATED:
		return false
	if phase != Phase.WALKING and phase != Phase.DROPPED:
		return false
	milk_left -= 1
	target.milk_angle = oni_angle
	events.append({"type": "milk", "sender": oni_id, "target": target.id})
	return true


## ボットの鬼が牛乳をかける予定: 落とすときに落とす相手にかけるか、どこかの席でかける
func _plan_bot_milk() -> void:
	_bot_milk_seat = -1
	_bot_milk_at_drop = false
	if rng.randf() >= GameConfig.BOT_ONI_MILK_CHANCE:
		return
	if rng.randf() < GameConfig.BOT_ONI_MILK_AT_DROP:
		_bot_milk_at_drop = true
		return
	_bot_milk_seat = rng.randi_range(0, seat_count - 1)
	_bot_milk_after = oni_angle + TAU * rng.randf_range(0.3, 1.5)


## バナナの皮を投げる。座っている人が、追いかけっこ中に、鬼か追いかける人を狙う。
## 狙った人の少し前の通り道に落ちる(曲がればよけられる)。投げられたら true
func throw_banana(sender_id: int, target_id: int) -> bool:
	var sender := get_actor(sender_id)
	var target := get_actor(target_id)
	if sender == null or target == null or phase != Phase.CHASE:
		return false
	if (sender.role != Role.SEATED and sender.role != Role.OUT) or sender.bananas_left <= 0:
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


func oni_drop(actor_id: int) -> bool:
	if not _is_player_oni(actor_id) or phase != Phase.WALKING:
		return false
	var crossing := _nearest_seat_crossing()
	if absf(oni_angle - crossing) * GameConfig.ONI_WALK_RADIUS > GameConfig.ONI_DROP_REACH:
		events.append({"type": "drop_failed", "actor": actor_id})
		return false
	if get_actor_at_seat(_seat_at_angle(crossing)) == null:
		# お手つきで抜けた人の空いた席には落とせない
		events.append({"type": "drop_failed", "actor": actor_id, "reason": "empty"})
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
	var step := TAU / seat_count
	return roundf(oni_angle / step) * step


## 鬼が歩く速さ(マイナスなら後ろに戻る)。ボットの鬼はいつも同じ。
## 人の鬼: スティックを倒さなければ自動で前へ歩く。歩く向きに倒すと速く、反対に倒すと止まり、
## 倒し続けると(ONI_BACK_HOLD 秒たつと)後ろに戻る
func _oni_walk_speed(oni: Actor, delta: float = 0.0) -> float:
	# 落とすまでは重い落とし物を持っているので遅い
	var carry := lerpf(1.0, GameConfig.ONI_CARRY_SPEED_HEAVY, item_weight()) if phase == Phase.WALKING else 1.0
	if not oni_is_player:
		return GameConfig.ONI_WALK_SPEED * carry
	var ang := oni_angle
	var forward := Vector3(cos(ang), 0.0, -sin(ang))
	var f := clampf(oni.move_dir.dot(forward), -1.0, 1.0)
	if f <= -GameConfig.ONI_BACK_DEADZONE:
		_oni_back_hold += delta
		if _oni_back_hold < GameConfig.ONI_BACK_HOLD:
			return 0.0
		return -GameConfig.ONI_BACK_SPEED
	_oni_back_hold = 0.0
	return lerpf(GameConfig.ONI_WALK_SPEED, GameConfig.ONI_WALK_SPEED_MAX, maxf(f, 0.0)) * carry


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
	return TAU * float(i) / float(seat_count)


func get_actor(id: int) -> Actor:
	for a in actors:
		if a.id == id:
			return a
	return null


func get_local_player() -> Actor:
	return get_actor(local_player_id)


## 席 from に座っている人から、席 to の人の後ろが見えるか。
## 両どなりは見えない(向かい側だけ見える)。見え方はカメラ(SEAT_CAM_HFOV)と合わせてある
func can_see_behind(from_seat: int, to_seat: int) -> bool:
	var n := seat_count
	var d := posmod(to_seat - from_seat, n)
	return d >= 2 and d <= n - 2


## この人から、席 to_seat の後ろが見えるか(役も考える)。
## 手下は両どなりも見える。鬼は全部見える。自分の後ろはだれでも見えない
func sees_behind(viewer_id: int, to_seat: int) -> bool:
	var v := get_actor(viewer_id)
	if v == null:
		return false
	if v.role == Role.ONI or v.role == Role.OUT:
		# 鬼と、お手つきで真ん中に抜けた人は、全員の後ろが見える
		return true
	if v.role != Role.SEATED or v.seat_index == to_seat:
		return false
	if viewer_id == minion_id:
		return true
	return can_see_behind(v.seat_index, to_seat)


## 席に座っている人(いなければ null)
func get_actor_at_seat(seat: int) -> Actor:
	for a in actors:
		if a.seat_index == seat:
			return a
	return null


## 通信や保存に使える、ただのデータ(Dictionary)に変換する。
## viewer: この状態を受け取る人の id。手下がだれかは、手下本人と、勝敗が出たあとだけ入れる
## (-1 = 全部入れる。ホスト自身やテスト用)
func snapshot(viewer: int = -1) -> Dictionary:
	var minion_shown := minion_id
	if viewer >= 0 and viewer != minion_id and phase != Phase.RESULT:
		minion_shown = -1
	var list := []
	for a in actors:
		list.append({
			"id": a.id,
			"name": a.display_name,
			"is_bot": a.is_bot,
			"color": a.color,
			"role": a.role,
			"seat": a.seat_index,
			"pos": a.position,
			"yaw": a.yaw,
			"looking_back": a.looking_back,
			"otetsuki": a.otetsuki_count,
			"stamps_left": a.stamps_left,
			"looks_left": a.looks_left,
			"bananas_left": a.bananas_left,
			"stamped": a.stamped_targets,
			"personality": a.personality,
			"home_seat": a.home_seat,
			"milk_angle": a.milk_angle,
		})
	return {
		"actors": list,
		"phase": phase,
		"oni_id": oni_id,
		"oni_is_player": oni_is_player,
		"oni_angle": oni_angle,
		"oni_start_angle": oni_start_angle,
		"drop_target_seat": drop_target_seat,
		"handkerchief_on_floor": handkerchief_on_floor,
		"handkerchief_pos": handkerchief_position,
		"chaser": chaser_id,
		"vacant_seat": vacant_seat,
		"result": result,
		"stamps": active_stamps,
		"round": round_index,
		"scores": scores,
		"match_over": match_over,
		"bananas": bananas,
		"milk_left": milk_left,
		"stamp_words": stamp_words,
		"round_serial": round_serial,
		"seat_count": seat_count,
		"minion_id": minion_shown,
		"last_minion_id": last_minion_id,
	}


## snapshot() の中身をこの状態に写す(オンライン対戦で、ホスト以外が受け取った状態を表示するため)。
## 写したあとはルールを動かさず(tick しない)、表示に使うだけ。
func apply_snapshot(s: Dictionary) -> void:
	var seats: int = s.get("seat_count", GameConfig.SEAT_COUNT)
	if seat_positions.is_empty() or seats != seat_count:
		seat_count = seats
		_init_seats()
	var list: Array = s["actors"]
	if actors.size() != list.size():
		actors.clear()
		for i in list.size():
			actors.append(Actor.new())
	for i in list.size():
		var d: Dictionary = list[i]
		var a: Actor = actors[i]
		a.id = d["id"]
		a.display_name = d["name"]
		a.is_bot = d["is_bot"]
		a.color = d["color"]
		a.role = d["role"]
		a.seat_index = d["seat"]
		a.position = d["pos"]
		a.yaw = d["yaw"]
		a.looking_back = d["looking_back"]
		a.otetsuki_count = d["otetsuki"]
		a.stamps_left = d["stamps_left"]
		a.looks_left = d["looks_left"]
		a.bananas_left = d["bananas_left"]
		a.stamped_targets = d.get("stamped", [])
		a.personality = d.get("personality", "")
		a.home_seat = d.get("home_seat", -1)
		a.milk_angle = d.get("milk_angle", INF)
	phase = s["phase"]
	oni_id = s["oni_id"]
	oni_is_player = s["oni_is_player"]
	oni_angle = s["oni_angle"]
	oni_start_angle = s["oni_start_angle"]
	drop_target_seat = s["drop_target_seat"]
	handkerchief_on_floor = s["handkerchief_on_floor"]
	handkerchief_position = s["handkerchief_pos"]
	chaser_id = s["chaser"]
	vacant_seat = s["vacant_seat"]
	result = s["result"]
	active_stamps = s["stamps"]
	round_index = s["round"]
	scores = s["scores"]
	match_over = s["match_over"]
	bananas = s["bananas"]
	milk_left = s.get("milk_left", 0)
	stamp_words = s.get("stamp_words", {})
	round_serial = s["round_serial"]
	minion_id = s.get("minion_id", -1)
	last_minion_id = s.get("last_minion_id", -1)


# --- 内部の処理 ---

## 落とす相手と、落とすタイミング(角度)を決める。
## 相手はプレイヤーもボットも含めてランダム。
func _plan_drop() -> void:
	drop_target_seat = rng.randi_range(0, seat_count - 1)
	var laps := rng.randf_range(GameConfig.ONI_LAPS_BEFORE_DROP_MIN, GameConfig.ONI_LAPS_BEFORE_DROP_MAX)
	var earliest := oni_angle + TAU * laps
	var target := seat_angle(drop_target_seat)
	# earliest 以降で、はじめて相手の真後ろを通る角度
	drop_angle = target + ceilf((earliest - target) / TAU) * TAU


## 落とす相手を、座っている人から選び直す(ボットの鬼。今の位置から先で、はじめて後ろを通るとき)
func _plan_drop_from_here() -> void:
	var seats := _occupied_seats()
	if seats.is_empty():
		return
	drop_target_seat = seats[rng.randi_range(0, seats.size() - 1)]
	var target := seat_angle(drop_target_seat)
	var earliest := oni_angle + 0.001
	drop_angle = target + ceilf((earliest - target) / TAU) * TAU


## 鬼が席の真後ろに来たとき: 本当に落とす/ニセで立ち止まる/そのまま通りすぎる
func _on_pass_behind_seat() -> void:
	var passed_seat := _seat_at_angle(oni_angle)
	seat_pass_age[passed_seat] = 0.0
	if phase == Phase.DROPPED and absf(oni_angle - (drop_angle + TAU)) < 0.001:
		# 一周して戻ってきても気づかれなかった: 落とされた人の負け
		var target := get_actor_at_seat(drop_target_seat)
		_finish(oni_id, target.id, "missed")
		return
	if phase == Phase.WALKING and absf(oni_angle - drop_angle) < 0.001:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		if not oni_is_player and _bot_milk_at_drop:
			# ボットの鬼: 落とす相手に牛乳をかけてから落とす(影が見えなくなる)
			_bot_milk_at_drop = false
			_milk(get_actor_at_seat(drop_target_seat))
		_drop()
	elif oni_is_player:
		# 人が鬼のときは、立ち止まるのも物音も牛乳も本人が決める
		return
	elif get_actor_at_seat(passed_seat) == null:
		# お手つきで抜けた人の空いた席: 立ち止まらない
		return
	elif _bot_milk_seat == passed_seat and oni_angle >= _bot_milk_after:
		_bot_milk_seat = -1
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		_milk(get_actor_at_seat(passed_seat))
	elif rng.randf() < GameConfig.DECOY_STOP_CHANCE:
		oni_pause_left = GameConfig.ONI_PAUSE_TIME
		if rng.randf() < GameConfig.BOT_ONI_FAKE_DROP_CHANCE:
			# ボットの鬼が、わざと「落とす音」を出す
			_emit_fake_drop()


func _tick_stamps(_delta: float) -> void:
	for id in active_stamps.keys():
		var list: Array = active_stamps[id]
		for st in list.duplicate():
			# 鬼が半周歩いたら消える(空いた枠に次のスタンプが届く)
			if oni_angle - st["born_angle"] >= GameConfig.STAMP_EXPIRE_LAPS * TAU:
				list.erase(st)
				_end_stamp(id, st, true)
		if list.is_empty():
			active_stamps.erase(id)


## スタンプを全部消す(追いかけっこが始まったとき・勝敗が出たとき)。
## judge = true なら、「まだ平気」の点数を消えるときと同じく決める
func _clear_stamps(judge: bool) -> void:
	for id in active_stamps.keys():
		for st in active_stamps[id]:
			_end_stamp(id, st, judge)
	active_stamps = {}


func _end_stamp(target_id: int, st: Dictionary, judge: bool) -> void:
	events.append({"type": "stamp_end", "target": target_id, "sender": st["sender"]})
	# 「まだ平気」「ニセかも」(見るな)で、出ている間に振り向かなかった:
	#   本当は落ちていた → だました / 本当に落ちていない → 教えた(振り向かずにすんだ)
	if judge and not Stamps.says_look(st["kind"]) and st["scorable"] and not st["looked"]:
		if st["truthful"]:
			_award_help(st, target_id)
		else:
			_award_deceive(st, target_id)


## 教えた点。送ったときの役で点数が変わる(0点なら何もしない)
func _award_help(st: Dictionary, target_id: int) -> void:
	var points: int = {"normal": GameConfig.SCORE_HELP_NORMAL, "minion": GameConfig.SCORE_HELP_MINION,
			"oni": GameConfig.SCORE_HELP_ONI}[st["sender_role"]]
	var sender_id: int = st["sender"]
	# お手つきで抜けた人は、このラウンドは0点
	if points == 0 or _is_out(sender_id):
		return
	scores[sender_id] = scores.get(sender_id, 0) + points
	# 点が入ったことは送った本人にだけ知らせる(手下がばれないように)
	events.append({
		"type": "helped",
		"sender": sender_id,
		"target": target_id,
		"points": points,
		"private_to": sender_id,
	})


## だました点。送ったときの役で点数が変わる(0点なら何もしない)
func _award_deceive(st: Dictionary, target_id: int) -> void:
	var points: int = {"normal": GameConfig.SCORE_DECEIVE_NORMAL, "minion": GameConfig.SCORE_DECEIVE_MINION,
			"oni": GameConfig.SCORE_DECEIVE_ONI}[st["sender_role"]]
	var sender_id: int = st["sender"]
	# お手つきで抜けた人は、このラウンドは0点
	if points == 0 or _is_out(sender_id):
		return
	scores[sender_id] = scores.get(sender_id, 0) + points
	events.append({
		"type": "deceived",
		"sender": sender_id,
		"target": target_id,
		"kind": st["kind"],
		"points": points,
		"private_to": sender_id,
	})


func _is_out(actor_id: int) -> bool:
	var a := get_actor(actor_id)
	return a != null and a.role == Role.OUT


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
	if loser_id >= 0:
		scores[loser_id] += GameConfig.SCORE_LOSE
	# 表示中のスタンプは、ここで消える(「まだ平気」の点もここで決まる)
	_clear_stamps(true)
	# 鬼が勝ったら、手下にも点(手下が負けた本人のときはもらえない)
	var minion_bonus := false
	if minion_id >= 0 and (reason == "sat" or reason == "missed" or reason == "all_out") and minion_id != loser_id \
			and not _is_out(minion_id):
		scores[minion_id] += GameConfig.SCORE_MINION_ONI_WIN
		minion_bonus = true
	result["minion"] = minion_id
	result["minion_bonus"] = minion_bonus
	last_minion_id = minion_id
	result["scores"] = scores.duplicate()
	for a in actors:
		a.move_dir = Vector3.ZERO
	var e := result.duplicate()
	e["type"] = "result"
	events.append(e)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _seat_at_angle(angle: float) -> int:
	var n := seat_count
	return posmod(roundi(angle / TAU * n), n)


func _drop() -> void:
	phase = Phase.DROPPED
	handkerchief_on_floor = true
	handkerchief_position = _ring_point(drop_angle, GameConfig.DROP_RADIUS)
	events.append({
		"type": "dropped",
		"seat": drop_target_seat,
		"pos": handkerchief_position,
		"weight": item_weight(),
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
