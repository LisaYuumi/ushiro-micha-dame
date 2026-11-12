class_name Stamps
extends RefCounted
## スタンプの種類。中身(ルール)だけで、見た目は view 側(StampIcon)で決める。
## 見た目は「落とし物アイコン+記号」(信じては、うるうる顔+!)。

const DROPPED := "dropped" # 落ちてる(落とし物+!)
const SAFE := "safe"       # まだ平気(落とし物+×)
const FAKE := "fake"       # ニセかも(落とし物+?)。「見るな」の意味(まだ平気と同じ扱い)
const TRUST := "trust"     # 信じて(うるうる顔+!)。「見ろ」の意味

## 選ぶときに並べる順番
const ALL := [DROPPED, SAFE, FAKE, TRUST]

## 名前(説明やテスト用。画面ではアイコンで出す)
const LABELS := {
	DROPPED: "落ちてる",
	SAFE: "まだ平気",
	FAKE: "ニセかも",
	TRUST: "信じて",
}

## アイコンの右下の記号(x は ×)
const SYMBOLS := {
	DROPPED: "!",
	SAFE: "x",
	FAKE: "?",
	TRUST: "!",
}


## このスタンプは「後ろを見ろ」という意味か(落ちてる・信じて)。まだ平気・ニセかもは「見るな」
static func says_look(kind: String) -> bool:
	return kind == DROPPED or kind == TRUST
