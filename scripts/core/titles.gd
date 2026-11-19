class_name Titles
extends RefCounted
## 試合の最後に、試合中の出来事から全員に1つずつ称号をつける(ホストが決めて、match_over で全員に送る)。
## 出来事の回数は GameState.match_stats(id -> {出来事: 回数})。
## 決め方: LIST の上から順に(面白い・珍しいものが先)、まだ称号のない人の中で回数が一番多い人(同点はランダム)。
## 条件に当てはまる人がいなければ、その称号は出ない。最後まで何もない人は「マイペースで賞」。

## [称号, 出来事, 何回から(無口な人は「何回まで」), 理由の文(%d に回数)]
## 表の文字はすべて翻訳のキー(英語は tools/i18n/make_translations.py)
const LIST := [
	["道連れ名人", "dragged", 1, "お手つきのあと %d人を道連れ"],
	["ウソつき大賞", "minion_deceived", 1, "手下として %d人をだました"],
	["気づかな賞", "missed", 1, "一周まわっても気づかず %d回"],
	["バナナの被害者", "banana", 1, "バナナで %d回転んだ"],
	["だまされ王", "fooled", 1, "ウソを信じて %d回失敗"],
	["暗やみパニック賞", "otetsuki_dark", 1, "暗やみでお手つき %d回"],
	["カミナリの目撃者", "found_lightning", 1, "カミナリの光で %d回見つけた"],
	["ガイコツのお友だち", "skeleton", 1, "ガイコツをかかえて %d回走った"],
	["お手つき王", "otetsuki", 1, "お手つき %d回"],
	["TOOL", "tool_hit", 1, ""],
	["逃げ足No.1", "escaped", 1, "%d回 逃げ切った"],
	["タッチの達人", "touched", 1, "鬼に %d回タッチした"],
	["名探偵", "vote_correct", 1, "手下を %d回当てた"],
	["振り向き名人", "found", 1, "振り向いて %d回見つけた"],
	["信じられる人", "stamps_true", 2, "本当の言葉を %d回送った"],
	["おしゃべりさん", "stamps_sent", 3, "言葉を %d回送った"],
	["無口な人", "stamps_sent", -1, "言葉は %d回だけ"],
	["鬼の常連", "oni_rounds", 2, "鬼を %d回やった"],
]
## 鬼の技でくらった回数の称号(ステージごと)
const TOOL_TITLES := {
	"classroom": ["粉まみれ賞", "黒板消しを %d回くらった"],
	"beach": ["びしょぬれ賞", "水鉄砲を %d回くらった"],
	"night": ["まぶしかった賞", "フラッシュを %d回くらった"],
}
## 何も当てはまらない人の称号(重ならないように順に使う。足りなければ最初の「マイペースで賞」)
const FALLBACKS := [
	["マイペースで賞", "のんびり楽しんだ"],
	["平和の使者", "事件にまきこまれなかった"],
	["縁の下の力持ち", "そっと輪を支えた"],
	["安定感No.1", "ずっと落ち着いていた"],
]
const FALLBACK := "マイペースで賞"
const SILENT_NONE := "言葉を送らなかった"


## 称号を決める。戻り値: id -> {"title": 称号, "reason": 理由の文(翻訳のキー), "n": 回数}
static func decide(stats: Dictionary, ids: Array, stage: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for row in LIST:
		var title: String = row[0]
		var reason: String = row[3]
		if title == "TOOL":
			var tt: Array = TOOL_TITLES.get(stage, TOOL_TITLES["classroom"])
			title = tt[0]
			reason = tt[1]
		var key: String = row[1]
		var limit: int = row[2]
		var best := []
		var best_n := 0
		for id in ids:
			if out.has(id):
				continue
			var n := int((stats.get(id, {}) as Dictionary).get(key, 0))
			var ok := n <= -limit if limit < 0 else n >= limit
			if not ok:
				continue
			# 多い人(無口な人は少ない人)を選ぶ
			var better := best.is_empty() or (n < best_n if limit < 0 else n > best_n)
			if better:
				best = [id]
				best_n = n
			elif n == best_n:
				best.append(id)
		if best.is_empty():
			continue
		var pick: int = best[rng.randi_range(0, best.size() - 1)]
		if limit < 0 and best_n == 0:
			reason = SILENT_NONE
		out[pick] = {"title": title, "reason": reason, "n": best_n}
	var spare := FALLBACKS.duplicate()
	for k in range(spare.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = spare[k]
		spare[k] = spare[j]
		spare[j] = tmp
	var used := 0
	for id in ids:
		if not out.has(id):
			var f: Array = spare[used] if used < spare.size() else FALLBACKS[0]
			used += 1
			out[id] = {"title": f[0], "reason": f[1], "n": 0}
	return out


## 予備の称号か
static func is_fallback(title: String) -> bool:
	for f in FALLBACKS:
		if f[0] == title:
			return true
	return false


## 理由の文(今の言語。回数を入れる)
static func reason_text(t: Dictionary) -> String:
	var r := Locale.t(str(t.get("reason", "")))
	return r % int(t.get("n", 0)) if "%d" in r else r


## 称号(今の言語)
static func title_text(t: Dictionary) -> String:
	return Locale.t(str(t.get("title", "")))


## 撮影モード用: それらしい称号をランダムに並べる(試合をしていなくても称号の画面を撮れるように)
static func sample(ids: Array, stage: String, rng: RandomNumberGenerator) -> Dictionary:
	var stats := {}
	var keys := ["dragged", "minion_deceived", "missed", "banana", "fooled", "otetsuki", "tool_hit",
			"escaped", "touched", "vote_correct", "found", "stamps_true", "stamps_sent", "oni_rounds"]
	if stage == "night":
		keys += ["otetsuki_dark", "found_lightning", "skeleton"]
	for id in ids:
		var s := {}
		for k in keys:
			if rng.randf() < 0.35:
				s[k] = rng.randi_range(1, 4)
		s["stamps_sent"] = rng.randi_range(0, 6)
		stats[id] = s
	return decide(stats, ids, stage, rng)
