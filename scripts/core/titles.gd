class_name Titles
extends RefCounted
## 試合の最後の称号(ホストが決めて、match_over で全員に送る)。本当に目立った出来事があった人だけ、最大 MAX_AWARDS 個。
## 出来事の回数は GameState.match_stats(id -> {出来事: 回数})。
## 決め方:
##   - 回数が「何回から」以上で、かつ全員の中でひとりだけ一番、2位とはっきり差がある(clear_lead)ときだけ候補
##   - 候補を「珍しい・面白い順」(punch が大きい順)に、1人1つ・同じ称号は1つで、MAX_AWARDS 個まで選ぶ
##   - 発表は punch の小さい順(最後の1つが、いちばん笑える/いちばんすごい称号=オチ)
##   - 3つに足りないときは、条件をゆるめて足す(1試合でだいたい3人に出す):
##       2段目: 同じ称号で「1回から」、2位との差は1でよい(一番がひとりだけ)
##       3段目: よく起きる出来事の称号(EXTRA。同点はランダム)
##       4段目: LIST の称号で「1回から」、同点はランダム
##     ゆるめた称号ほど先に発表する(最後のオチは、いちばん厳しい条件の称号)
##   - 出来事がまったくなければ空(称号発表はとばして記念写真だけ)

const MAX_AWARDS := 3

## [称号, 出来事, 何回から, 理由の文(%d に回数), 種類("good" = 金色・ファンファーレ / "funny" = 紫・ガーン), punch, 表情]
## 表の文字はすべて翻訳のキー(英語は tools/i18n/make_translations.py)。数字は遊んでみて調整する
const LIST := [
	["気づかな賞", "missed", 2, "一周まわっても気づかず %d回", "funny", 10, "awkward"],
	["道連れ名人", "dragged", 1, "お手つきのあと %d人を道連れ", "funny", 9, "smirk"],
	["ウソつき大賞", "minion_deceived", 3, "手下として %d人をだました", "good", 8, "smirk"],
	["名探偵", "vote_sharp", 1, "みんながだまされる中、手下を %d回見抜いた", "good", 8, "win"],
	["バナナの被害者", "banana", 3, "バナナで %d回転んだ", "funny", 7, "shock"],
	["振り向き名人", "found", 3, "振り向いて %d回見つけた", "good", 7, "win"],
	["だまされ王", "fooled", 2, "ウソを信じて %d回失敗", "funny", 6, "shock"],
	["逃げ足No.1", "escaped", 2, "鬼で %d回 逃げ切った", "good", 5, "win"],
	["暗やみパニック賞", "otetsuki_dark", 2, "暗やみでお手つき %d回", "funny", 5, "shock"],
	["タッチの達人", "touched", 2, "鬼に %d回タッチした", "good", 4, "win"],
	["お手つき王", "otetsuki", 3, "お手つき %d回", "funny", 4, "shock"],
	["カミナリの目撃者", "found_lightning", 1, "カミナリの光で %d回見つけた", "good", 3, "win"],
	["TOOL", "tool_hit", 2, "", "funny", 3, "awkward"],
]
## 3つに足りないときに使う、よく起きる出来事の称号(3段目)。形は LIST と同じ
const EXTRA := [
	["手下ハンター", "vote_correct", 1, "手下を %d回当てた", "good", 2, "win"],
	["信じられる人", "stamps_true", 1, "本当の言葉を %d回送った", "good", 1, "win"],
	["おしゃべりさん", "stamps_sent", 1, "言葉を %d回送った", "good", 1, "win"],
	["鬼の常連", "oni_rounds", 1, "鬼を %d回やった", "funny", 1, "smirk"],
]
## 段ごとに、発表の順番(punch)から引く数(ゆるめた称号ほど先に発表する)
const TIER_PENALTY := 20
## 鬼の技でくらった回数の称号(ステージごと)
const TOOL_TITLES := {
	"classroom": ["粉まみれ賞", "黒板消しを %d回くらった"],
	"beach": ["びしょぬれ賞", "水鉄砲を %d回くらった"],
	"night": ["まぶしかった賞", "フラッシュを %d回くらった"],
}


## 2位とはっきり差があるか: 一番がひとりだけで、2位との差が max(1, 一番の1/3) 以上
static func clear_lead(n: int, second: int) -> bool:
	return n - second >= maxi(1, ceili(n / 3.0))


## 称号を決める。戻り値: 発表する順の配列 [{"id", "title", "reason", "n", "tone", "face"}](最大 MAX_AWARDS 個。空もある)
static func decide(stats: Dictionary, ids: Array, stage: String, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var picked := []
	var used_ids := {}
	var used_titles := {}
	# [表, 何回からを1にするか, 2位との差の決まり("clear" / "unique" / "tie_random")]
	var tiers := [[LIST, false, "clear"], [LIST, true, "unique"], [EXTRA, false, "tie_random"], [LIST, true, "tie_random"]]
	for tier in tiers.size():
		if picked.size() >= MAX_AWARDS:
			break
		var cands := _candidates(tiers[tier][0], bool(tiers[tier][1]), str(tiers[tier][2]), stats, ids, stage, rng)
		cands.sort_custom(func(a, b): return a["punch"] > b["punch"])
		for c in cands:
			if picked.size() >= MAX_AWARDS:
				break
			if used_ids.has(c["id"]) or used_titles.has(c["title"]):
				continue
			used_ids[c["id"]] = true
			used_titles[c["title"]] = true
			c["punch"] = int(c["punch"]) - tier * TIER_PENALTY
			picked.append(c)
	# 発表は、最後がオチ(いちばん厳しい条件で、いちばん面白い称号)になる順
	picked.sort_custom(func(a, b): return a["punch"] < b["punch"])
	return picked


## 1つの段の候補(称号ごとに1人)
static func _candidates(rows: Array, relax_min: bool, rule: String, stats: Dictionary, ids: Array, stage: String,
		rng: RandomNumberGenerator) -> Array:
	var cands := []
	for row in rows:
		var key: String = row[1]
		var best := 0
		var second := 0
		var tops := []
		for id in ids:
			var n := int((stats.get(id, {}) as Dictionary).get(key, 0))
			if n > best:
				second = best
				best = n
				tops = [id]
			elif n == best and n > 0:
				tops.append(id)
			elif n > second:
				second = n
		var need := 1 if relax_min else int(row[2])
		if tops.is_empty() or best < need:
			continue
		match rule:
			"clear":
				if tops.size() > 1 or not clear_lead(best, second):
					continue
			"unique":
				if tops.size() > 1:
					continue
		var who: int = tops[rng.randi_range(0, tops.size() - 1)]
		var title: String = row[0]
		var reason: String = row[3]
		if title == "TOOL":
			var tt: Array = TOOL_TITLES.get(stage, TOOL_TITLES["classroom"])
			title = tt[0]
			reason = tt[1]
		cands.append({"id": who, "title": title, "reason": reason, "n": best, "tone": row[4],
				"punch": int(row[5]), "face": row[6]})
	return cands


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
	var rows := LIST.duplicate()
	if stage != "night":
		rows = rows.filter(func(r): return r[1] != "otetsuki_dark" and r[1] != "found_lightning")
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
		var row: Array = rows[i]
		stats[people[i]] = {row[1]: int(row[2]) + rng.randi_range(0, 2)}
	return decide(stats, ids, stage, rng)
