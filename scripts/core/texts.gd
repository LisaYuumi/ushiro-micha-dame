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
## スタンプの初期の言葉の、翻訳ファイルのキー(日本語の元の文)
const STAMP_KEYS := {
	"dropped": "落ちてる",
	"safe": "平気",
	"trust": "信じて",
}


## 翻訳した文(Locale.t と同じ。古い呼び出しのため)
static func t(key: String) -> String:
	return Locale.t(key)


## スタンプの初期の言葉(今の言語。絵文字なし)。日本語「落ちてる」、英語「Behind you!」など
static func stamp_word(kind: String) -> String:
	return Locale.t(STAMP_KEYS.get(kind, kind))


## スタンプに出す文字: 言葉+絵文字(word が "" なら初期の言葉)。例: 「落ちてる😨」「Behind you!😨」
static func stamp(kind: String, word: String = "") -> String:
	var w := word if word != "" else stamp_word(kind)
	return w + STAMP_EMOJI.get(kind, "")
