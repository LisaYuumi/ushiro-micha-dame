class_name Items
extends RefCounted
## 落とし物。舞台ごとに5つあり、ラウンドごとに重くなる。
## 重さ(0〜1)で、置く音の大きさ・追いかける人の速さなどが変わる(数値は GameConfig)。
## 舞台: "classroom"(教室)・"beach"(海辺)

const STAGES := ["classroom", "beach"]
## 舞台の名前(翻訳ファイルのキー)
const STAGE_NAMES := {"classroom": "教室", "beach": "海辺"}
const NAMES_BY_STAGE := {
	"classroom": ["ハンカチ", "上履き", "ランドセル", "机", "教卓"],
	"beach": ["貝殻", "ビーチボール", "浮き輪", "砂の城", "バナナボート"],
}
## 教室の落とし物(前からある名前。テストなどで使う)
const NAMES := ["ハンカチ", "上履き", "ランドセル", "机", "教卓"]
const WEIGHTS := [0.0, 0.25, 0.5, 0.75, 1.0]


static func count() -> int:
	return NAMES.size()


## 知らない舞台なら教室
static func clean_stage(stage: String) -> String:
	return stage if stage in STAGES else "classroom"


static func stage_name(stage: String) -> String:
	return Locale.t(STAGE_NAMES[clean_stage(stage)])


## 落とし物の名前(今の言語で。名前は翻訳ファイルのキー)
static func name_of(index: int, stage: String = "classroom") -> String:
	var names: Array = NAMES_BY_STAGE[clean_stage(stage)]
	return Locale.t(names[clampi(index, 0, names.size() - 1)])


static func weight_of(index: int) -> float:
	return WEIGHTS[clampi(index, 0, WEIGHTS.size() - 1)]
