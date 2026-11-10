class_name Items
extends RefCounted
## 落とし物(舞台: 教室)。ラウンドごとに重くなる。
## 重さ(0〜1)で、置く音の大きさ・追いかける人の速さなどが変わる(数値は GameConfig)。

const NAMES := ["ハンカチ", "上履き", "ランドセル", "机", "教卓"]
const WEIGHTS := [0.0, 0.25, 0.5, 0.75, 1.0]


static func count() -> int:
	return NAMES.size()


static func name_of(index: int) -> String:
	return NAMES[clampi(index, 0, NAMES.size() - 1)]


static func weight_of(index: int) -> float:
	return WEIGHTS[clampi(index, 0, WEIGHTS.size() - 1)]
