class_name Stamps
extends RefCounted
## スタンプの種類。中身(ルール)だけで、見た目は view 側で決める。

const DROPPED := "dropped" # 落ちてる!
const SAFE := "safe"       # まだ平気
const NOW := "now"         # いま!
const TRUST := "trust"     # 信じて!

## ボタンに並べる順番
const ALL := [DROPPED, SAFE, NOW, TRUST]

## 仮の表示名(あとで顔・記号のアイコンに差しかえる)
const LABELS := {
	DROPPED: "落ちてる!",
	SAFE: "まだ平気",
	NOW: "いま!",
	TRUST: "信じて!",
}


## このスタンプは「後ろを見ろ」という意味か
static func says_look(kind: String) -> bool:
	return kind == DROPPED or kind == NOW or kind == TRUST
