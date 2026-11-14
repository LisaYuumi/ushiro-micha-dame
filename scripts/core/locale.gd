class_name Locale
extends RefCounted
## 言語の切りかえ(Godot の翻訳機能 TranslationServer を使う)。
## - 画面の文字は assets/i18n/texts.csv(翻訳ファイル)にまとめてある。キーは日本語の元の文。
##   Godot が CSV を読みこんで texts.ja.translation / texts.en.translation を作り、project.godot に登録してある。
## - Label や Button に入れた文字は、Godot が自動で今の言語に置きかえる。
##   名前や数字を入れる文は、先に t("…%s…") で置きかえてから % で入れる。
## - 最初は端末の言語に合わせる(日本語なら日本語、それ以外は英語)。設定で切りかえると Profile に保存する。
## 言語を足すときは: texts.csv に列(例: "ko")を足し、SUPPORTED と NAMES に加える(docs/TRANSLATIONS.md)。

## 対応している言語
const SUPPORTED := ["ja", "en"]
## 言語の名前(切りかえボタンに出す。どの言語でもその言語の書き方で)
const NAMES := {"ja": "日本語", "en": "English"}
const FILES := ["res://assets/i18n/texts.ja.translation", "res://assets/i18n/texts.en.translation"]


## 翻訳を読みこんで(まだなら)、言語を決める。chosen: 自分で選んだ言語("" なら端末に合わせる)
static func setup(chosen: String = "") -> void:
	var loaded := TranslationServer.get_loaded_locales()
	for path in FILES:
		if ResourceLoader.exists(path):
			var tr_res: Translation = load(path)
			if tr_res and not (tr_res.locale in loaded):
				TranslationServer.add_translation(tr_res)
	TranslationServer.set_locale(pick(chosen))


## 使う言語: 選んだ言語があればそれ、なければ端末の言語(対応していなければ英語)
static func pick(chosen: String) -> String:
	if chosen in SUPPORTED:
		return chosen
	var device := OS.get_locale_language()
	return device if device in SUPPORTED else "en"


## 今の言語("ja" / "en")
static func current() -> String:
	var l := TranslationServer.get_locale().get_slice("_", 0)
	return l if l in SUPPORTED else "en"


## 次の言語(切りかえボタン用)
static func next_language() -> String:
	return SUPPORTED[(SUPPORTED.find(current()) + 1) % SUPPORTED.size()]


## 文を今の言語にする(ノードの外・static な関数からも使える)
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## 登場人物の名前を今の言語で。ボット(「ボット3(せっかち)」)と、決まった名前(「プレイヤー」「プレイヤー2」)だけ置きかえる。
## 人が自分でつけた名前はそのまま
static func actor_name(raw: String, show_personality: bool = false) -> String:
	if raw.begins_with("ボット"):
		var rest := raw.substr(3)
		var num := ""
		for ch in rest:
			if ch >= "0" and ch <= "9":
				num += ch
			else:
				break
		var label := ""
		var open := raw.find("(")
		if open >= 0:
			label = raw.substr(open + 1).trim_suffix(")")
		var shown := t("ボット%d") % int(num) if num != "" else raw
		if show_personality and label != "":
			shown += t("(%s)") % t(label)
		return shown
	if raw == "プレイヤー":
		return t("プレイヤー")
	if raw.begins_with("プレイヤー") and raw.substr(5).is_valid_int():
		return t("プレイヤー%d") % int(raw.substr(5))
	if raw.ends_with("(ボット)"):
		return raw.trim_suffix("(ボット)") + t("(ボット)")
	return raw
