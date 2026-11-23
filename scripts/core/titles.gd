class_name Titles
extends RefCounted
## 試合の最後の称号(ホストが決めて、match_over で全員に送る)。1人1つ・同じ称号は1つ・最大 MAX_AWARDS 個。
## 出来事の回数は GameState.match_stats(id -> {出来事: 回数})。数字(条件)はこのファイルの上の方にまとめてある。
##
## 決め方(decide):
##   1. 称号ごとに、当てはまる人を決める
##      - 回数の称号(rule "top"): 「何回から」以上で、その人がひとりだけ一番(2位と同点でない)
##      - 出来事の称号(rule "any"): 1回でも起きた人。何人もいたらランダム
##   2. 点数をつけて高い順に選ぶ: 珍しさ(rarity)× 10 + 笑える称号は +5(珍しい → 笑える → すごい の順)。
##      FORCED の称号は当てはまったら最優先。さらに、毎回少しずつちがう組み合わせになるように:
##      - 直前の試合で出た称号は大きく下げる(ほかに当てはまる称号が1つもないときだけ出る)
##      - 直近3試合で出た称号は下げる
##      - 直前の試合でその人がもらった称号は、その人には下げる
##      - これまでに出た回数が少ない称号を少し上げる
##      - 少しだけランダム(JITTER)
##   3. 3つに足りないときは、条件をゆるめて足す(「1回から」・同点はランダム → よく起きる出来事の称号 EXTRA)
##   4. 発表は点数の低い順で、最後の1つはいちばん笑える称号(オチ。笑える称号がなければ点数がいちばん高い称号)
## 理由の文は称号ごとに2〜3通りあり、ランダムに1つ選ぶ(ホストが選んで、全員に同じ文を送る)

const MAX_AWARDS := 3

# --- 条件の数字(遊んでみて調整する) ---
## 早とちり大王: ラウンドが始まってから何秒以内のお手つきか
const EARLY_SECONDS := 5.0
## フェイクの達人: フェイクの音のあと何秒以内のお手つきを、フェイクにだまされたとするか
const FAKE_WINDOW := 3.0
## あと一歩の人: 鬼が座ったとき、追いかけた人があと何秒で追いつけたか
const SO_CLOSE_SECONDS := 1.0
## 重いの担当: この重さ以上の落とし物を「重い」とする(Items.WEIGHTS。0〜1)
const HEAVY_WEIGHT := 0.75
## 正直者がバカを見た賞: 言葉を何回以上送っていて(全部本当)
const HONEST_MIN_SENT := 2
## 点数のつけ方
const FORCED_BONUS := 200
const FUNNY_BONUS := 5
const RECENT_LAST_PENALTY := 1000
const RECENT_PENALTY := 60
const SAME_PERSON_PENALTY := 45
const COUNT_PREFER := 2.0
const COUNT_PREFER_MAX := 10
const JITTER := 12.0
## 何試合前までの称号を「最近出た」とするか
const RECENT_MATCHES := 3
## 当てはまったら最優先で選ぶ称号
const FORCED := ["正直者がバカを見た賞", "名演技賞", "逆転の道連れ王", "早とちり大王"]

## 称号の表。title: 称号(翻訳のキー)/key: 出来事/min: 何回から/rule: "top" か "any"/tone: "good"(金色) か "funny"(紫)/
## rarity: 珍しさ 1〜10/group: 同じグループの称号は1試合に1つ/stage: その舞台だけ/need: ほかの条件/
## show: 理由の文に出す数字の出来事(なければ key)/face: 表情/gesture: ポーズ(CharacterModel.set_gesture)/
## reasons: 理由の文(%d に回数)。2〜3通り
const LIST := [
	# だまし・ウソ
	{"title": "正直者がバカを見た賞", "key": "votes_innocent", "min": 2, "rule": "top", "tone": "funny", "rarity": 9,
		"need": "honest", "face": "shock", "gesture": "head",
		"reasons": ["本当のことしか言わないのに %d票", "正直者なのに %d票も入った", "ウソゼロなのに疑われた(%d票)"]},
	{"title": "大ウソつき", "key": "lies_normal", "min": 3, "rule": "top", "tone": "funny", "rarity": 5,
		"face": "smirk", "gesture": "chin",
		"reasons": ["手下でもないのにウソを %d回", "ふつうの人なのにウソ %d回", "ウソの言葉を %d回も送った"]},
	{"title": "名演技賞", "key": "minion_low_votes", "min": 1, "rule": "any", "tone": "good", "rarity": 8,
		"face": "smirk", "gesture": "chin",
		"reasons": ["手下なのにほぼノーマーク", "手下だとバレずに %d回", "だれにも疑われない名演技(%d回)"]},
	{"title": "みんなの信用ゼロ", "key": "top_voted_innocent", "min": 2, "rule": "top", "tone": "funny", "rarity": 7,
		"face": "awkward", "gesture": "shrug",
		"reasons": ["手下じゃないのに %d回も一番票", "%d回も手下だと思われた", "無実なのに %dラウンド疑われた"]},
	{"title": "オオカミ少年", "key": "wolf", "min": 3, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "smirk", "gesture": "wave",
		"reasons": ["「落ちてる!」がウソだった %d回", "何もないのに「落ちてる!」%d回", "「落ちてる!」%d回、全部ハズレ"]},
	{"title": "ウソつき大賞", "key": "minion_deceived", "min": 3, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "smirk", "gesture": "chin",
		"reasons": ["手下として %d人をだました", "手下で %d人をひっかけた"]},
	{"title": "名探偵", "key": "vote_sharp", "min": 1, "rule": "top", "tone": "good", "rarity": 6,
		"face": "win", "gesture": "magnifier",
		"reasons": ["みんながだまされる中、手下を %d回見抜いた", "少数派で手下を当てた(%d回)"]},
	{"title": "だまされ王", "key": "fooled", "min": 2, "rule": "top", "tone": "funny", "rarity": 5,
		"face": "shock", "gesture": "head",
		"reasons": ["ウソを信じて %d回失敗", "%d回もだまされた"]},
	# 振り向き・お手つき
	{"title": "早とちり大王", "key": "early_otetsuki", "min": 1, "rule": "any", "tone": "funny", "rarity": 8,
		"show": "early_sec", "face": "shock", "gesture": "head",
		"reasons": ["%d秒で振り向いて、お手つき", "開始%d秒でガマンできなかった", "%d秒で振り向いた。早すぎ!"]},
	{"title": "体育座りのプロ", "key": "otetsuki", "min": 3, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "awkward", "gesture": "shrug",
		"reasons": ["真ん中で体育座り %d回", "お手つきで %d回お休み"]},
	{"title": "逆転の道連れ王", "key": "dragged", "min": 2, "rule": "top", "tone": "funny", "rarity": 9,
		"group": "dragged", "face": "smirk", "gesture": "chin",
		"reasons": ["お手つきのあと %d人を道連れ", "休みながら %d人をお手つきに", "ただでは転ばない(道連れ %d人)"]},
	{"title": "道連れ名人", "key": "dragged", "min": 1, "rule": "top", "tone": "funny", "rarity": 7,
		"group": "dragged", "face": "smirk", "gesture": "chin",
		"reasons": ["お手つきのあと %d人を道連れ", "休みながら %d人をお手つきに"]},
	{"title": "信じる者は救われなかった賞", "key": "trusted_wrong", "min": 1, "rule": "any", "tone": "funny", "rarity": 8,
		"face": "shock", "gesture": "head",
		"reasons": ["「落ちてる」を信じたら何もなかった(%d回)", "みんなを信じて振り向いたのに…(%d回)"]},
	{"title": "野生の勘", "key": "instinct", "min": 1, "rule": "any", "tone": "good", "rarity": 8,
		"face": "win", "gesture": "cheer",
		"reasons": ["だれにも教わらずに %d回見つけた", "ノーヒントで %d回見つけた"]},
	{"title": "振り向き名人", "key": "found", "min": 3, "rule": "top", "tone": "funny", "rarity": 5,
		"face": "win", "gesture": "cheer",
		"reasons": ["振り向いて %d回見つけた", "%d回も見つけた"]},
	{"title": "暗やみパニック賞", "key": "otetsuki_dark", "min": 2, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "shock", "gesture": "head",
		"reasons": ["暗やみでお手つき %d回", "暗くてあわてて %d回お手つき"]},
	{"title": "カミナリの目撃者", "key": "found_lightning", "min": 1, "rule": "any", "tone": "funny", "rarity": 7,
		"face": "win", "gesture": "cheer",
		"reasons": ["カミナリの光で %d回見つけた", "ピカッと光った瞬間に見つけた(%d回)"]},
	# 気づかない・のんびり
	{"title": "鈍感力No.1", "key": "missed", "min": 2, "rule": "top", "tone": "funny", "rarity": 7,
		"face": "awkward", "gesture": "shrug",
		"reasons": ["一周まわっても気づかず %d回", "%d回も気づかなかった"]},
	{"title": "背中で語る人", "key": "dropped_on", "min": 3, "rule": "top", "tone": "funny", "rarity": 5,
		"face": "awkward", "gesture": "shrug",
		"reasons": ["%d回もうしろに落とされた", "鬼に %d回ねらわれた"]},
	{"title": "平和主義者", "key": "peaceful", "min": 1, "rule": "any", "tone": "funny", "rarity": 5,
		"face": "win", "gesture": "peace",
		"reasons": ["一度も振り向かなかった", "最後まで前だけを見ていた"]},
	# 追いかけっこ
	{"title": "バナナ職人", "key": "banana_hits", "min": 3, "rule": "top", "tone": "good", "rarity": 8,
		"face": "smirk", "gesture": "banana",
		"reasons": ["バナナで %d人を転ばせた", "投げたバナナが %d回命中"]},
	{"title": "バナナの被害者", "key": "banana", "min": 3, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "shock", "gesture": "banana",
		"reasons": ["バナナで %d回転んだ", "%d回もバナナを踏んだ"]},
	{"title": "ずっこけ大賞", "key": "max_slips", "min": 3, "rule": "top", "tone": "funny", "rarity": 7,
		"face": "shock", "gesture": "head",
		"reasons": ["1回の追いかけっこで %d回転んだ", "追いかけっこ中に %d回ずっこけた"]},
	{"title": "重いの担当", "key": "heavy", "min": 2, "rule": "top", "tone": "funny", "rarity": 4,
		"face": "awkward", "gesture": "shrug",
		"reasons": ["重い落とし物を %d回かかえて走った", "重いものばかり %d回運んだ"]},
	{"title": "あと一歩の人", "key": "so_close", "min": 1, "rule": "top", "tone": "funny", "rarity": 6,
		"face": "shock", "gesture": "head",
		"reasons": ["あと1秒で追いつけたのに(%d回)", "あと一歩で鬼に逃げられた(%d回)"]},
	{"title": "韋駄天", "key": "clean_catch", "min": 1, "rule": "top", "tone": "good", "rarity": 6,
		"face": "win", "gesture": "cheer",
		"reasons": ["一度も転ばずに鬼をつかまえた(%d回)", "ノーミスで %d回タッチ"]},
	{"title": "タッチの達人", "key": "touched", "min": 2, "rule": "top", "tone": "funny", "rarity": 3,
		"face": "win", "gesture": "cheer",
		"reasons": ["鬼に %d回タッチした", "%d回も鬼をつかまえた"]},
	# 鬼のとき
	{"title": "忍者", "key": "ninja", "min": 2, "rule": "top", "tone": "good", "rarity": 8,
		"face": "smirk", "gesture": "peace",
		"reasons": ["鬼で %d回、一周気づかれなかった", "気配を消して %d回成功"]},
	{"title": "フェイクの達人", "key": "fake_hits", "min": 2, "rule": "top", "tone": "good", "rarity": 9,
		"face": "smirk", "gesture": "chin",
		"reasons": ["フェイクの音で %d人をお手つきに", "ニセの音で %d人をだました"]},
	{"title": "逃げ足No.1", "key": "escaped", "min": 2, "rule": "top", "tone": "good", "rarity": 5,
		"need": "never_caught", "face": "win", "gesture": "peace",
		"reasons": ["鬼で %d回、一度もつかまらなかった", "%d回逃げ切って無敗"]},
	# ステージ限定
	{"title": "粉まみれ", "key": "tool_hit", "min": 2, "rule": "top", "tone": "funny", "rarity": 4, "stage": "classroom",
		"group": "tool", "face": "awkward", "gesture": "shrug",
		"reasons": ["黒板消しを %d回くらった", "チョークの粉で %d回まっしろ"]},
	{"title": "びしょぬれ", "key": "tool_hit", "min": 2, "rule": "top", "tone": "funny", "rarity": 4, "stage": "beach",
		"group": "tool", "face": "awkward", "gesture": "shrug",
		"reasons": ["水鉄砲を %d回くらった", "%d回もびしょぬれ"]},
	{"title": "まぶしかった賞", "key": "tool_hit", "min": 2, "rule": "top", "tone": "funny", "rarity": 4, "stage": "night",
		"group": "tool", "face": "awkward", "gesture": "shrug",
		"reasons": ["フラッシュを %d回くらった", "%d回もパシャッとやられた"]},
	{"title": "骨折り損", "key": "skeleton_fail", "min": 1, "rule": "any", "tone": "funny", "rarity": 6, "stage": "night",
		"face": "shock", "gesture": "head",
		"reasons": ["ガイコツをかかえて走ったのに…", "ガイコツと走って、鬼に逃げられた"]},
	{"title": "モナリザに見つめられた人", "key": "mona_missed", "min": 1, "rule": "any", "tone": "funny", "rarity": 9, "stage": "night",
		"face": "awkward", "gesture": "shrug",
		"reasons": ["うしろのモナリザに気づかなかった", "モナリザがずっと見ていたのに…"]},
	{"title": "停電の被害者", "key": "blackout_missed", "min": 1, "rule": "any", "tone": "funny", "rarity": 8,
		"face": "shock", "gesture": "head",
		"reasons": ["停電中に落とされて気づかなかった", "まっくらの中で、一周気づかなかった"]},
]

## 3つに足りないときに使う、よく起きる出来事の称号(形は LIST と同じ)
const EXTRA := [
	{"title": "手下ハンター", "key": "vote_correct", "min": 1, "rule": "top", "tone": "funny", "rarity": 2,
		"face": "win", "gesture": "magnifier", "reasons": ["手下を %d回当てた", "%d回も手下を見つけた"]},
	{"title": "信じられる人", "key": "stamps_true", "min": 1, "rule": "top", "tone": "funny", "rarity": 1,
		"face": "win", "gesture": "peace", "reasons": ["本当の言葉を %d回送った", "正直な言葉を %d回"]},
	{"title": "おしゃべりさん", "key": "stamps_sent", "min": 1, "rule": "top", "tone": "funny", "rarity": 1,
		"face": "win", "gesture": "wave", "reasons": ["言葉を %d回送った", "%d回もしゃべった"]},
	{"title": "鬼の常連", "key": "oni_rounds", "min": 1, "rule": "top", "tone": "funny", "rarity": 1,
		"face": "smirk", "gesture": "chin", "reasons": ["鬼を %d回やった", "%dラウンドも鬼だった"]},
]


static func _all() -> Array:
	return LIST + EXTRA


static func find(title: String) -> Dictionary:
	for d in _all():
		if d["title"] == title:
			return d
	return {}


## 称号を決める。history: {"recent": [[称号, ...], ...](新しい順), "counts": {称号: 出た回数}, "last_by_actor": {id: 称号}}。
## 戻り値: 発表する順の配列 [{"id", "title", "reason", "n", "tone", "face", "gesture"}]
static func decide(stats: Dictionary, ids: Array, stage: String, rng: RandomNumberGenerator = null,
		history: Dictionary = {}) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# 直近3試合で出た称号は、ほかに当てはまる称号があれば選ばない(まず除いて選ぶ)。
	# 3つに足りなければ、直前の試合の称号だけ除いて足す。直前の試合の称号は、ほかに1つも選べないときだけ
	var recent: Array = history.get("recent", [])
	var last: Array = recent[0] if not recent.is_empty() else []
	var recent_all := []
	for i in mini(recent.size(), RECENT_MATCHES):
		recent_all += recent[i] as Array
	var picked := []
	_pick(stats, ids, stage, rng, history, recent_all, picked)
	_pick(stats, ids, stage, rng, history, last, picked)
	if picked.is_empty():
		_pick(stats, ids, stage, rng, history, [], picked)
	return _order(picked)


static func _pick(stats: Dictionary, ids: Array, stage: String, rng: RandomNumberGenerator, history: Dictionary,
		skip_titles: Array, picked: Array) -> void:
	var used_ids := {}
	var used_titles := {}
	var used_groups := {}
	for c in picked:
		used_ids[c["id"]] = true
		used_titles[c["title"]] = true
		if str(c.get("group", "")) != "":
			used_groups[c["group"]] = true
	# [表, ゆるめるか]
	for tier in [[LIST, false], [LIST, true], [EXTRA, false]]:
		if picked.size() >= MAX_AWARDS:
			break
		var cands := []
		for d in tier[0]:
			if d["title"] in skip_titles:
				continue
			var c := _candidate(d, bool(tier[1]), stats, ids, stage, rng)
			if not c.is_empty():
				c["score"] = _score(d, c, history, rng) - (100 if tier[1] or tier[0] == EXTRA else 0)
				cands.append(c)
		cands.sort_custom(func(a, b): return a["score"] > b["score"])
		for c in cands:
			if picked.size() >= MAX_AWARDS:
				break
			var g: String = c.get("group", "")
			if used_ids.has(c["id"]) or used_titles.has(c["title"]) or (g != "" and used_groups.has(g)):
				continue
			used_ids[c["id"]] = true
			used_titles[c["title"]] = true
			if g != "":
				used_groups[g] = true
			picked.append(c)


## 発表の順: 点数の低い順。最後はいちばん笑える称号(オチ)
static func _order(picked: Array) -> Array:
	picked.sort_custom(func(a, b): return a["score"] < b["score"])
	var last := -1
	for i in picked.size():
		if picked[i]["tone"] == "funny" and (last < 0 or int(picked[i]["base"]) >= int(picked[last]["base"])):
			last = i
	if last >= 0:
		var c = picked[last]
		picked.remove_at(last)
		picked.append(c)
	for c in picked:
		c.erase("score")
		c.erase("base")
		c.erase("group")
	return picked


## 1つの称号の当てはまる人(いなければ {})
static func _candidate(d: Dictionary, relax: bool, stats: Dictionary, ids: Array, stage: String,
		rng: RandomNumberGenerator) -> Dictionary:
	var st: String = d.get("stage", "")
	if st != "" and st != stage:
		return {}
	var key: String = d["key"]
	var need := 1 if relax else int(d["min"])
	var best := 0
	var tops := []
	for id in ids:
		var s: Dictionary = stats.get(id, {})
		# (「出来事の称号」は、ほかの条件に合う人だけ。「回数の称号」は全員の中で一番を決めてから、ほかの条件を見る)
		if d["rule"] == "any" and not _passes(d, s):
			continue
		var n := _value(key, s)
		if n < need:
			continue
		if d["rule"] == "any":
			tops.append(id)
		elif n > best:
			best = n
			tops = [id]
		elif n == best:
			tops.append(id)
	if tops.is_empty():
		return {}
	# 回数の称号は、ひとりだけ一番(2位と同点でない)ときだけ。ゆるめた段では同点もランダム
	if d["rule"] == "top" and tops.size() > 1 and not relax:
		return {}
	var who: int = tops[rng.randi_range(0, tops.size() - 1)]
	var s2: Dictionary = stats.get(who, {})
	if not _passes(d, s2):
		return {}
	var reasons: Array = d["reasons"]
	return {"id": who, "title": d["title"], "reason": reasons[rng.randi_range(0, reasons.size() - 1)],
			"n": _value(str(d.get("show", key)), s2), "tone": d["tone"], "face": d["face"], "gesture": d["gesture"],
			"group": d.get("group", ""), "base": _base(d)}


## 出来事の回数(「平和主義者」だけは、ほかの出来事から決める)
static func _value(key: String, s: Dictionary) -> int:
	if key == "peaceful":
		# 一度も振り向かず、お手つきも、落とされたこともない
		return 1 if int(s.get("looks", 0)) == 0 and int(s.get("otetsuki", 0)) == 0 and int(s.get("dropped_on", 0)) == 0 else 0
	return int(s.get(key, 0))


## ほかの条件
static func _passes(d: Dictionary, s: Dictionary) -> bool:
	match str(d.get("need", "")):
		"honest":
			return int(s.get("lies", 0)) == 0 and int(s.get("stamps_sent", 0)) >= HONEST_MIN_SENT
		"never_caught":
			return int(s.get("oni_caught", 0)) == 0
	return true


## 珍しい → 笑える → すごい の順の点数
static func _base(d: Dictionary) -> int:
	var b := int(d["rarity"]) * 10 + (FUNNY_BONUS if d["tone"] == "funny" else 0)
	if d["title"] in FORCED:
		b += FORCED_BONUS
	return b


## 選ぶときの点数(最近出た称号・同じ人の同じ称号を下げ、出た回数の少ない称号を少し上げ、少しランダム)
static func _score(d: Dictionary, c: Dictionary, history: Dictionary, rng: RandomNumberGenerator) -> float:
	var sc := float(c["base"])
	var title: String = d["title"]
	var recent: Array = history.get("recent", [])
	for i in mini(recent.size(), RECENT_MATCHES):
		if title in (recent[i] as Array):
			sc -= RECENT_LAST_PENALTY if i == 0 else RECENT_PENALTY
			break
	var last_by: Dictionary = history.get("last_by_actor", {})
	if str(last_by.get(c["id"], last_by.get(int(c["id"]), ""))) == title:
		sc -= SAME_PERSON_PENALTY
	var counts: Dictionary = history.get("counts", {})
	sc -= minf(float(counts.get(title, 0)), COUNT_PREFER_MAX) * COUNT_PREFER
	sc += rng.randf() * JITTER
	return sc


## 称号のある人 id -> 称号(記念写真のバッジ用)
static func by_actor(awards: Array) -> Dictionary:
	var out := {}
	for a in awards:
		out[int(a["id"])] = a
	return out


## 理由の文(今の言語。回数を入れる)
static func reason_text(t: Dictionary) -> String:
	var r := Locale.t(str(t.get("reason", "")))
	return r % int(t.get("n", 0)) if "%d" in r else r


## 称号(今の言語)
static func title_text(t: Dictionary) -> String:
	return Locale.t(str(t.get("title", "")))


## 撮影モード用: それらしい称号を3つ(試合をしていなくても称号の発表と記念写真を撮れるように)
static func sample(ids: Array, stage: String, rng: RandomNumberGenerator) -> Array:
	var rows := LIST.filter(func(d): return str(d.get("stage", "")) == "" or d["stage"] == stage)
	for k in range(rows.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = rows[k]
		rows[k] = rows[j]
		rows[j] = tmp
	var people := ids.duplicate()
	for k in range(people.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = people[k]
		people[k] = people[j]
		people[j] = tmp
	var stats := {}
	for i in mini(MAX_AWARDS, mini(rows.size(), people.size())):
		var d: Dictionary = rows[i]
		var s := {d["key"]: int(d["min"]) + rng.randi_range(0, 2), "stamps_sent": HONEST_MIN_SENT, "looks": 1}
		if d["key"] == "peaceful":
			s = {"looks": 0}
		if d.has("show"):
			s[d["show"]] = 3
		stats[people[i]] = s
	return decide(stats, ids, stage, rng)
