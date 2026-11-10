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
## ハンカチが落ちる位置の半径(席の真後ろ)
const DROP_RADIUS := 3.6

# --- 鬼の動き ---
## 鬼が歩く速さ(メートル/秒)
const ONI_WALK_SPEED := 1.6
## ハンカチを落とすまでに最低何周歩くか(この範囲でランダム)
const ONI_LAPS_BEFORE_DROP_MIN := 0.3
const ONI_LAPS_BEFORE_DROP_MAX := 1.0

# --- 音 ---
## 足音を鳴らす間隔(歩いた距離・メートル)
const FOOTSTEP_STRIDE := 0.7
## 足音の大きさ(dB。小さいほど静か)
const FOOTSTEP_VOLUME_DB := -14.0
## ハンカチを落とした音の大きさ(dB)
const DROP_VOLUME_DB := -8.0
