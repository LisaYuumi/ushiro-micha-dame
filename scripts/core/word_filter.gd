class_name WordFilter
extends RefCounted
## 自分で決めたスタンプの言葉に、使えない言葉が入っていないか調べる(自動のチェック)。
## - 長さ: MAX_LEN 文字まで
## - 悪口・いやな言葉: NG の一覧(ひらがな・カタカナ・全角/半角のちがい、間の空白や記号は無視して比べる)
## - 個人情報: 3けた以上の数字(電話番号など)、メールアドレス、URL、住所や連絡先を表す言葉
## 完全ではないので、一覧はあとから足せるようにまとめておく。

## 言葉の長さの上限(文字)
const MAX_LEN := 6

## 使えない言葉(ひらがな・英字の小文字で書く。比べる前に、言葉もひらがな・小文字にそろえる)
const NG_WORDS := [
	"しね", "しんで", "しんじゃえ", "ころす", "ころせ", "ころして", "きえろ", "きえて",
	"きもい", "きもっ", "きしょい", "きしょ", "うざい", "うざ", "うぜ", "だまれ",
	"ばか", "あほ", "ぶす", "ぶさいく", "でぶ", "くず", "かす", "ごみ", "ちび", "はげ",
	"きちがい", "がいじ", "のろま", "まぬけ", "へたくそ", "ざこ",
	"ちんこ", "ちんちん", "まんこ", "うんこ", "うんち", "おっぱい", "せっくす", "えっち",
	"fuck", "shit", "bitch", "kill", "die", "dick", "sex",
]
## 漢字などの、そのままの形で調べる言葉
const NG_RAW := [
	"死ね", "死んで", "殺す", "殺せ", "消えろ", "糞", "馬鹿", "阿呆", "不細工", "気持ち悪", "雑魚",
]
## 個人情報(住所・連絡先)を表す言葉
const PERSONAL_WORDS := [
	"〒", "丁目", "番地", "住所", "じゅうしょ", "電話", "でんわ", "でんばん", "http", "www", ".com", ".jp",
	"line", "ライン", "insta", "インスタ", "twitter", "ついった", "@",
]


## 言葉を調べる。使えるなら ""、使えないなら理由: "empty" / "long" / "bad"(悪口など) / "personal"(個人情報)
static func check(word: String) -> String:
	var w := word.strip_edges()
	if w == "":
		return "empty"
	if w.length() > MAX_LEN:
		return "long"
	for raw in NG_RAW:
		if w.contains(raw):
			return "bad"
	var n := normalize(w)
	for ng in NG_WORDS:
		if n.contains(normalize(ng)):
			return "bad"
	for pw in PERSONAL_WORDS:
		if n.contains(normalize(pw)) or w.contains(pw):
			return "personal"
	# 3けた以上の数字(電話番号・郵便番号・番地など)
	var digits := 0
	for ch in n:
		if ch >= "0" and ch <= "9":
			digits += 1
			if digits >= 3:
				return "personal"
		else:
			digits = 0
	return ""


## 理由を、画面に出す言葉にする
static func reason_text(reason: String) -> String:
	match reason:
		"empty":
			return "言葉を入れてね"
		"long":
			return "%d文字までにしてね" % MAX_LEN
		"bad":
			return "その言葉は使えません"
		"personal":
			return "数字や連絡先・住所は使えません"
	return ""


## 使える言葉ならそのまま、使えなければ ""(初期の言葉を使う)を返す
static func clean(word: String) -> String:
	var w := word.strip_edges().replace("\n", "").replace("\t", "")
	return w if check(w) == "" else ""


## 比べるための形: 小文字・全角の英数字を半角に・カタカナをひらがなに・空白や記号やのばし棒をとる
static func normalize(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		var c := ch.unicode_at(0)
		# 全角の英数字 → 半角
		if c >= 0xFF01 and c <= 0xFF5E:
			c -= 0xFEE0
		# カタカナ → ひらがな
		if c >= 0x30A1 and c <= 0x30F6:
			c -= 0x60
		var s := String.chr(c).to_lower()
		# 空白・記号・のばし棒・小さい「っ」は無視する(「し ね」「しーね」なども見つける)
		if s in [" ", "　", "ー", "-", "~", "〜", "・", ".", "、", "。", "!", "?", "!", "?", "_", "*", "っ"]:
			continue
		out += s
	return out
