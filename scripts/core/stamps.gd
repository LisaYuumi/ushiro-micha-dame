class_name Stamps
extends RefCounted
## スタンプの種類。中身(ルール)だけ。言葉は Texts、色と見た目は view 側で決める。

const DROPPED := "dropped" # 落ちてる!(赤)。「見ろ」の意味
const SAFE := "safe"       # まだへいき!(緑)。「見るな」の意味
const TRUST := "trust"     # 信じて!(紫)。「見ろ」の意味

## 選ぶときに並べる順番
const ALL := [DROPPED, SAFE, TRUST]


## このスタンプは「後ろを見ろ」という意味か(落ちてる・信じて)。まだへいきは「見るな」
static func says_look(kind: String) -> bool:
	return kind == DROPPED or kind == TRUST
