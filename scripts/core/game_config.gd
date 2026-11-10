class_name GameConfig
extends RefCounted
## ゲームの調整用の数値をまとめた場所。
## 遊びながら変えたい数値は、すべてここに置く。

# --- 配置 ---
## 席の数(プレイヤー1人+座るボット4体。鬼のボットは別)
const SEAT_COUNT := 5
## 席が並ぶ輪の半径(メートル)
const RING_RADIUS := 3.0
## 鬼が歩く輪の半径(席の輪より外側)
const ONI_WALK_RADIUS := 4.3
## ハンカチが落ちる位置の半径(席の真後ろ。背もたれに隠れない距離)
const DROP_RADIUS := 3.8

# --- 鬼の動き ---
## 鬼が歩く速さ(メートル/秒)
const ONI_WALK_SPEED := 1.6
## 席の後ろで立ち止まる時間(秒)。本当に落とすときも、ニセの物音のときも同じ
const ONI_PAUSE_TIME := 0.6
## 席の後ろを通るたびに、ニセで立ち止まる確率(0〜1)。
## 1.0 = 毎回どの席の後ろでも止まる(止まったことでは、どこに落としたかわからない)
const DECOY_STOP_CHANCE := 1.0
## ニセで立ち止まったとき、置く音に似た物音を出す確率(0〜1)
const DECOY_SOUND_CHANCE := 0.6
## ハンカチを落とすまでに最低何周歩くか(この範囲でランダム)
const ONI_LAPS_BEFORE_DROP_MIN := 0.3
const ONI_LAPS_BEFORE_DROP_MAX := 1.0

# --- 音 ---
## 足音を鳴らす間隔(歩いた距離・メートル)
const FOOTSTEP_STRIDE := 0.7
## 足音の大きさ(dB。小さいほど静か)
const FOOTSTEP_VOLUME_DB := -4.0
## ハンカチを置いた音(とニセの物音)の大きさ(dB)。ハンカチは足音にまぎれるくらい小さく
const DROP_VOLUME_DB := -8.0
## 置いた音が、この距離(メートル)より離れると急に小さくなる。
## 小さいほど「自分のすぐ後ろ」でないと聞こえない
const DROP_SOUND_RANGE := 1.2

# --- 振り向き ---
## 振り向くのにかかる時間(秒)
const LOOK_BACK_TIME := 0.15
## 前を向いているときのカメラの下向き角度(度)
const SEAT_CAM_PITCH_FRONT := -12.0
## 振り向いたときのカメラの下向き角度(度)。床のハンカチが見えるように深く
const SEAT_CAM_PITCH_BACK := -55.0
## 振り向いたとき、頭が後ろへ乗り出す距離(メートル)
const LOOK_BACK_LEAN := 0.2
## 「お手つき!」などの表示時間(秒)
const MESSAGE_TIME := 1.5

# --- 追いかけっこ ---
## 鬼が走る速さ(メートル/秒)
const ONI_RUN_SPEED := 3.0
## 追いかける人の速さ(メートル/秒)。鬼よりわずかに速い
const CHASER_SPEED := 3.3
## この距離(メートル)まで近づいたらタッチ成立
const TOUCH_DISTANCE := 1.0
## 追いかける人が走れる範囲(輪の中心からの距離)。席の内側には入れない
const CHASER_MIN_RADIUS := 3.55
const CHASER_MAX_RADIUS := 6.0
## 追いかける人は自動で鬼と同じ向きに走り続ける。操作は内側/外側へのハンドルだけ。
## 1.0 で、いっぱいに切ると斜め45度に曲がる
const CHASER_STEER := 1.0

# --- ボット ---
## 後ろにハンカチを落とされたボットが気づくまでの時間(秒)。この範囲でランダム。
## 鬼がもう一周してくるまで(約17秒)に気づかなければ見逃し
const BOT_NOTICE_TIME_MIN := 1.5
const BOT_NOTICE_TIME_MAX := 22.0

# --- 追いかけるときのカメラ ---
## 自分が追いかけるとき、カメラを輪の外側のどれだけ後ろ・上に置くか(メートル)
const CHASE_CAM_DISTANCE := 3.0
const CHASE_CAM_HEIGHT := 3.2

# --- スタンプ ---
## 届いたスタンプが表示される時間(秒)。表示中はほかのスタンプは届かない(早い者勝ち)
const STAMP_SHOW_TIME := 3.0
## 1人が1ラウンドに送れる数。-1 = 何回でも送れる
const STAMPS_PER_ROUND := -1
## 誰が送ったかを表示するか(企画書: 試遊で決める)
const SHOW_STAMP_SENDER := false
## ボットが本当のことを言う確率(0〜1)
const BOT_STAMP_HONEST_CHANCE := 0.5
## ボットが届いたスタンプを信じて振り向く確率(0〜1)
const BOT_TRUST_CHANCE := 0.5
## ボットがスタンプを送る間隔(秒)。この範囲でランダム
const BOT_STAMP_INTERVAL_MIN := 2.0
const BOT_STAMP_INTERVAL_MAX := 9.0
## ボットが振り向いてから前を向くまで(秒)
const BOT_LOOK_TIME := 0.8
