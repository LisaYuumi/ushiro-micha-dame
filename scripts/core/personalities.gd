class_name Personalities
extends RefCounted
## ボットの性格。正直さは役(普通/手下/鬼)で決まるので、性格はそれ以外を変える。
## 中身はただの数値。使うのは BotBrain だけ(状態には性格の名前だけを持つ)。

const HASTY := "hasty"     # せっかち: すぐ振り向く・早く気づく
const CAREFUL := "careful" # 慎重: スタンプが2つ以上そろわないと振り向かない・がまん強い
const DOUBTER := "doubter" # うたがい屋: スタンプをあまり信じない
const CHATTY := "chatty"   # おしゃべり: スタンプをたくさん送る

const ALL := [HASTY, CAREFUL, DOUBTER, CHATTY]

const LABELS := {
	HASTY: "せっかち",
	CAREFUL: "慎重",
	DOUBTER: "うたがい屋",
	CHATTY: "おしゃべり",
}

## notice: 後ろに落とされて気づくまでの時間の倍率(小さいほど早い)
## threshold: 届いたスタンプの多数決(「見ろ」+1、「まだ平気」-1)がこれ以上なら振り向くか考える
## trust: そのとき実際に振り向く確率の倍率(GameConfig.BOT_TRUST_CHANCE にかける)
## interval: スタンプを送る間隔の倍率(小さいほどたくさん送る)
const PARAMS := {
	HASTY: {"notice": 0.6, "threshold": 1.0, "trust": 1.3, "interval": 1.0},
	CAREFUL: {"notice": 1.3, "threshold": 2.0, "trust": 1.0, "interval": 1.3},
	DOUBTER: {"notice": 1.0, "threshold": 1.0, "trust": 0.5, "interval": 1.0},
	CHATTY: {"notice": 1.0, "threshold": 1.0, "trust": 1.0, "interval": 0.5},
}
## 性格のない人(途中で抜けて、ボットが代わった人など)
const DEFAULT := {"notice": 1.0, "threshold": 1.0, "trust": 1.0, "interval": 1.0}


static func params(kind: String) -> Dictionary:
	return PARAMS.get(kind, DEFAULT)


static func label(kind: String) -> String:
	return LABELS.get(kind, "")
