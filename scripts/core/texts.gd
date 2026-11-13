class_name Texts
extends RefCounted
## 画面に出す言葉をまとめて持つ(あとで翻訳しやすいように)。
## いまはスタンプの言葉と、スタンプを送るときの言葉だけ。言語を足すときは TABLE に同じキーで足す。

## 使う言語
static var lang := "ja"

const TABLE := {
	"ja": {
		"stamp_dropped": "落ちてる",
		"stamp_safe": "平気",
		"stamp_trust": "信じて",
		## %s = 相手の名前
		"send_to": "%sに送る",
		"send_target": "送る相手",
		"me": "あなた",
		"oni": "鬼",
	},
}


## キーの言葉(なければキーをそのまま返す)
static func t(key: String) -> String:
	var table: Dictionary = TABLE.get(lang, TABLE["ja"])
	return table.get(key, key)


## スタンプの絵文字(言葉を変えても、絵文字と意味は変わらない)
const STAMP_EMOJI := {
	"dropped": "😨",
	"safe": "👍",
	"trust": "🥺",
}


## スタンプの初期の言葉(絵文字なし)
static func stamp_word(kind: String) -> String:
	return t("stamp_" + kind)


## スタンプに出す文字: 言葉+絵文字(word が "" なら初期の言葉)。例: 「落ちてる😨」
static func stamp(kind: String, word: String = "") -> String:
	var w := word if word != "" else stamp_word(kind)
	return w + STAMP_EMOJI.get(kind, "")
