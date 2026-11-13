class_name Texts
extends RefCounted
## 画面に出す言葉をまとめて持つ(あとで翻訳しやすいように)。
## いまはスタンプの言葉と、スタンプを送るときの言葉だけ。言語を足すときは TABLE に同じキーで足す。

## 使う言語
static var lang := "ja"

const TABLE := {
	"ja": {
		"stamp_dropped": "落ちてる!",
		"stamp_safe": "まだへいき!",
		"stamp_trust": "信じて!",
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


## スタンプの言葉(Stamps の種類から)
static func stamp(kind: String) -> String:
	return t("stamp_" + kind)
