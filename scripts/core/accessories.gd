class_name Accessories
extends RefCounted
## キャラにつける小物(帽子・メガネ・リボン・豚の鼻)。全部同時につけられ、色も選べる。
## ロビーの「小物」の画面で選び、この端末に保存する。オンラインでは名前・色と一緒にホストに送り、
## ホストが登場人物につけて、状態でみんなに届ける(見た目だけ。ルールは変わらない)。
## 形は {"hat": "cap", "hat_c": 4, "glasses": "", "glasses_c": 7, ...}("" はつけない、_c は色の番号)

const SLOTS := ["hat", "glasses", "ribbon", "nose"]
## 小物の名前(翻訳ファイルのキー)
const SLOT_NAMES := {"hat": "帽子", "glasses": "メガネ", "ribbon": "リボン", "nose": "豚の鼻"}
## 選べる形(1つだけの物は「つける」ボタンになる)
const KINDS := {
	"hat": ["cap", "beanie", "tophat"],
	"glasses": ["round", "square"],
	"ribbon": ["ribbon"],
	"nose": ["pig"],
}
const KIND_NAMES := {
	"cap": "キャップ", "beanie": "ニット帽", "tophat": "シルクハット",
	"round": "丸メガネ", "square": "四角メガネ",
	"ribbon": "つける", "pig": "つける",
}
## 選べる色
const COLORS := [
	Color("E5483B"), Color("F2AA4C"), Color("EDC94B"), Color("7CC576"), Color("4D96FF"),
	Color("B07CF0"), Color("F4A3B6"), Color("2E2B28"), Color("FFFFFF"),
]
## はじめの色(帽子は青、メガネは黒、リボンは赤、鼻はピンク)
const DEFAULT_COLOR := {"hat": 4, "glasses": 7, "ribbon": 0, "nose": 6}


## 何もつけていない形
static func empty() -> Dictionary:
	var d := {}
	for slot in SLOTS:
		d[slot] = ""
		d[slot + "_c"] = DEFAULT_COLOR[slot]
	return d


## 通信や保存から読んだ値を、正しい形に直す(知らない形・色は、つけない・はじめの色)
static func clean(v: Variant) -> Dictionary:
	var d := empty()
	if not v is Dictionary:
		return d
	var src: Dictionary = v
	for slot in SLOTS:
		var kind := str(src.get(slot, ""))
		if kind in KINDS[slot]:
			d[slot] = kind
		var raw: Variant = src.get(slot + "_c", DEFAULT_COLOR[slot])
		var c: int = int(raw) if (raw is int or raw is float) else int(DEFAULT_COLOR[slot])
		d[slot + "_c"] = c if c >= 0 and c < COLORS.size() else int(DEFAULT_COLOR[slot])
	return d


static func color_of(acc: Dictionary, slot: String) -> Color:
	return COLORS[clampi(int(acc.get(slot + "_c", DEFAULT_COLOR[slot])), 0, COLORS.size() - 1)]
