class_name Profile
extends RefCounted
## 自分の名前と体の色。ロビーで決めて、この端末に保存する(次に開いたときも同じ)。
## オンラインでは、参加する人はホストに送り、ホストがその名前と色で登場人物を作る。

const PATH := "user://profile.cfg"
## 名前の長さの上限(文字)
const NAME_MAX := 8
## ロビーで選べる10色(A案の見本)
const COLORS := [
	Color("EE6A4D"), Color("F2AA4C"), Color("EDC94B"), Color("7CC576"), Color("4D96FF"),
	Color("B07CF0"), Color("EF8FB0"), Color("FFFFFF"), Color("C9C2B6"), Color("2E2B28"),
]
const DEFAULT_NAME := "プレイヤー"

static var player_name := DEFAULT_NAME
static var color: Color = COLORS[4]
## ボットの性格(「(せっかち)」など)を名前の横に出すか(⚙メニューで切りかえ。はじめはオフ)
static var show_personality := false
## 自分で決めたスタンプの言葉(Stamps の種類 -> 言葉。"" なら初期の言葉)。絵文字と意味は変わらない
static var stamp_words := {}
## ほかの人の自作の言葉を表示せず、初期の言葉で表示する
static var hide_custom_words := false
## 自分で選んだ言語("" なら端末の言語に合わせる。Locale)
static var lang := ""
## 音量(0〜1): 全体・BGM・効果音
static var vol_master := 1.0
static var vol_bgm := 0.7
static var vol_sfx := 1.0
## ロビーで選んだ舞台(Items.STAGES)
static var stage := "classroom"
## 小物(Accessories の形)
static var accessories := {}
static var _loaded := false


static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	player_name = clean_name(str(cfg.get_value("profile", "name", DEFAULT_NAME)))
	color = parse_color(str(cfg.get_value("profile", "color", "")), color)
	show_personality = bool(cfg.get_value("profile", "show_personality", false))
	hide_custom_words = bool(cfg.get_value("profile", "hide_custom_words", false))
	lang = str(cfg.get_value("profile", "lang", ""))
	vol_master = clampf(float(cfg.get_value("profile", "vol_master", 1.0)), 0.0, 1.0)
	vol_bgm = clampf(float(cfg.get_value("profile", "vol_bgm", 0.7)), 0.0, 1.0)
	vol_sfx = clampf(float(cfg.get_value("profile", "vol_sfx", 1.0)), 0.0, 1.0)
	stamp_words = clean_words(cfg.get_value("profile", "stamp_words", {}))
	stage = Items.clean_stage(str(cfg.get_value("profile", "stage", "classroom")))
	accessories = Accessories.clean(cfg.get_value("profile", "accessories", {}))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "color", "#" + color.to_html(false))
	cfg.set_value("profile", "show_personality", show_personality)
	cfg.set_value("profile", "hide_custom_words", hide_custom_words)
	cfg.set_value("profile", "lang", lang)
	cfg.set_value("profile", "vol_master", vol_master)
	cfg.set_value("profile", "vol_bgm", vol_bgm)
	cfg.set_value("profile", "vol_sfx", vol_sfx)
	cfg.set_value("profile", "stamp_words", stamp_words)
	cfg.set_value("profile", "stage", stage)
	cfg.set_value("profile", "accessories", accessories)
	cfg.save(PATH)


## 名前を整える: 前後の空白と改行をとり、長すぎたら切る。空なら「プレイヤー」
static func clean_name(text: String) -> String:
	var t := text.strip_edges().replace("\n", "").replace("\t", "")
	if t.length() > NAME_MAX:
		t = t.substr(0, NAME_MAX)
	return t if t != "" else DEFAULT_NAME


## 「#4D96FF」や「4D96FF」を色にする。読めなければ fallback
static func parse_color(text: String, fallback: Color) -> Color:
	var t := text.strip_edges()
	if t == "":
		return fallback
	if not t.begins_with("#"):
		t = "#" + t
	if not Color.html_is_valid(t):
		return fallback
	var c := Color.html(t)
	c.a = 1.0
	return c


## スタンプの言葉を整える: 3つの種類だけ、使えない言葉(WordFilter)は消す(初期の言葉になる)
static func clean_words(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in Stamps.ALL:
		var w := WordFilter.clean(str((v as Dictionary).get(k, "")))
		if w != "":
			out[k] = w
	return out


## 音量を名前("vol_master" / "vol_bgm" / "vol_sfx")で読む・書く
static func get_volume(key: String) -> float:
	match key:
		"vol_master":
			return vol_master
		"vol_bgm":
			return vol_bgm
	return vol_sfx


static func set_volume(key: String, v: float) -> void:
	match key:
		"vol_master":
			vol_master = clampf(v, 0.0, 1.0)
		"vol_bgm":
			vol_bgm = clampf(v, 0.0, 1.0)
		_:
			vol_sfx = clampf(v, 0.0, 1.0)


## 通信で送れる形
static func to_dict() -> Dictionary:
	return {"name": player_name, "color": "#" + color.to_html(false), "words": stamp_words, "lang": Locale.current(),
			"acc": accessories}
