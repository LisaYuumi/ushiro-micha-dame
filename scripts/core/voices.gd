class_name Voices
extends RefCounted
## 鬼が出せる声・音。落とす音をかき消したり、落とすふりに使ったりする。

const COUGH := "cough"     # 咳
const WHISTLE := "whistle" # 口笛
const CLAP := "clap"       # 手拍子
const SHOUT := "shout"     # 叫ぶ(あー!)

const ALL := [COUGH, WHISTLE, CLAP, SHOUT]
const LABELS := {
	COUGH: "咳",
	WHISTLE: "口笛",
	CLAP: "手拍子",
	SHOUT: "叫ぶ",
}
