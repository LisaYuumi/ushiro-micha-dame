class_name Texts
extends RefCounted
## スタンプの言葉と絵文字。言葉そのものは翻訳ファイル(assets/i18n/texts.csv)にあり、Locale で今の言語にする。
## スタンプは「種類」(落ちてる・平気・信じて)で送り、受け取った人の画面で、その人の言語で出す。

## スタンプの絵文字(言葉を変えても、言語が変わっても、絵文字と意味は変わらない)
const STAMP_EMOJI := {
	"dropped": "😨",
	"safe": "👍",
	"trust": "🥺",
}
## スタンプの言葉のセット(意味ごと。翻訳ファイルのキー = 日本語の元の文)。
## 試合ごとに、プレイヤーごとに、それぞれのセットから1つずつランダムに選ぶ(シャッフル)。
## 言葉は番号で送るので、受け取った人の画面では、その人の言語の同じ番号の言葉が出る
const STAMP_SETS := {
	"dropped": ["落ちてる", "うしろ!うしろ!", "来てるよ!", "あるある!"],
	# (「セーフ!」は結果の見出しでも使う別の訳があるので、スタンプ用のキーにする。日本語の表示は「セーフ!」)
	"safe": ["平気", "スタンプ:セーフ!", "まだまだ", "なんもないよ"],
	"trust": ["信じて", "マジだって!", "ぜったいホント", "うそじゃない"],
}
## (前からある呼び出しのため: セットの1番目)
const STAMP_KEYS := {
	"dropped": "落ちてる",
	"safe": "平気",
	"trust": "信じて",
}


## 翻訳した文(Locale.t と同じ。古い呼び出しのため)
static func t(key: String) -> String:
	return Locale.t(key)


## スタンプの言葉(今の言語。絵文字なし)。index はセットの何番目か(省略すると1番目)
static func stamp_word(kind: String, index: int = 0) -> String:
	var list: Array = STAMP_SETS.get(kind, [kind])
	return Locale.t(list[clampi(index, 0, list.size() - 1)])


## 3つのスタンプの言葉を、それぞれのセットからランダムに選ぶ({kind: 何番目か})
static func random_pick(rng: RandomNumberGenerator = null) -> Dictionary:
	var d := {}
	for kind in STAMP_SETS:
		var n: int = (STAMP_SETS[kind] as Array).size()
		d[kind] = rng.randi_range(0, n - 1) if rng else randi_range(0, n - 1)
	return d


## 通信や保存から読んだ選び方を、正しい形に直す(知らない番号は1番目)
static func clean_pick(v: Variant) -> Dictionary:
	var d := {}
	var src: Dictionary = v if v is Dictionary else {}
	for kind in STAMP_SETS:
		var raw: Variant = src.get(kind, 0)
		var i: int = int(raw) if (raw is int or raw is float) else 0
		d[kind] = clampi(i, 0, (STAMP_SETS[kind] as Array).size() - 1)
	return d


## スタンプに出す文字: 言葉+絵文字(word が "" なら初期の言葉)。例: 「落ちてる😨」「Behind you!😨」
static func stamp(kind: String, word: String = "") -> String:
	var w := word if word != "" else stamp_word(kind)
	return w + STAMP_EMOJI.get(kind, "")
