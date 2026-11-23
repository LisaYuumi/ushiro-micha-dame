class_name Titles
extends RefCounted
## 試合の最後の称号(ホストが決めて、match_over で全員に送る)。本当に目立った出来事があった人だけ、最大 MAX_AWARDS 個。
## 出来事の回数は GameState.match_stats(id -> {出来事: 回数})。
## 決め方:
##   - 回数が「何回から」以上で、かつ全員の中でひとりだけ一番、2位とはっきり差がある(clear_lead)ときだけ候補
##   - 候補を「珍しい・面白い順」(punch が大きい順)に、1人1つ・同じ称号は1つで、MAX_AWARDS 個まで選ぶ
##   - 発表は punch の小さい順(最後の1つが、いちばん笑える/いちばんすごい称号=オチ)
##   - だれも当てはまらなければ空(称号発表はとばして記念写真だけ)

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
static func decide(stats: Dictionary, ids: Array, stage: String, _rng: RandomNumberGenerator = null) -> Array:
	var cands := []
	for row in LIST:
		var key: String = row[1]
		var best_id := -1
		var best := 0
		var second := 0
		for id in ids:
			var n := int((stats.get(id, {}) as Dictionary).get(key, 0))
			if n > best:
				second = best
				best = n
				best_id = id
			elif n > second:
				second = n
		if best_id < 0 or best < int(row[2]) or not clear_lead(best, second):
			continue
		var title: String = row[0]
		var reason: String = row[3]
		if title == "TOOL":
			var tt: Array = TOOL_TITLES.get(stage, TOOL_TITLES["classroom"])
			title = tt[0]
			reason = tt[1]
		cands.append({"id": best_id, "title": title, "reason": reason, "n": best, "tone": row[4],
				"punch": int(row[5]), "face": row[6]})
	# 珍しい・面白い順に、1人1つまで
	cands.sort_custom(func(a, b): return a["punch"] > b["punch"])
	var picked := []
	var used := {}
	for c in cands:
		if picked.size() >= MAX_AWARDS:
			break
		if used.has(c["id"]):
			continue
		used[c["id"]] = true
		picked.append(c)
	# 発表は、最後がオチ(punch がいちばん大きい)になる順
	picked.reverse()
	return picked


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
