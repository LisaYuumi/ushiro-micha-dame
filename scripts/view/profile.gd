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


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "color", "#" + color.to_html(false))
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


## 通信で送れる形
static func to_dict() -> Dictionary:
	return {"name": player_name, "color": "#" + color.to_html(false)}
