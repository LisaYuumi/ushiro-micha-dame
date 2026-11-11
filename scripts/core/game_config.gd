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
## 鬼が歩く速さ(メートル/秒)。1周 約30秒(席の後ろで止まる時間込み)。
## 遅いほど、スタンプを送ったり考えたりする時間が長くなる
const ONI_WALK_SPEED := 1.0
## 席の後ろで立ち止まる時間(秒)。本当に落とすときも、ニセの物音のときも同じ
const ONI_PAUSE_TIME := 0.6
## 席の後ろを通るたびに、ニセで立ち止まる確率(0〜1)。
## 1.0 = 毎回どの席の後ろでも止まる(止まったことでは、どこに落としたかわからない)
const DECOY_STOP_CHANCE := 1.0
## ボットの鬼が、立ち止まったときに「落とす音」(本物と同じ置く音)をわざと出す確率(0〜1)
const BOT_ONI_FAKE_DROP_CHANCE := 0.15
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

# --- 見え方 ---
## 自分の席から見える左右の幅(度)。画面の形(横長のスマホなど)に関係なく同じになる。
## 両どなりの人の姿まで見える広さ。両どなりの後ろに落ちた物は、見え方のルール
## (GameState.can_see_behind)で自分の画面には映さない
const SEAT_CAM_HFOV := 120.0

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
## 鬼がもう一周してくるまで(約30秒)に気づかなければ見逃し
const BOT_NOTICE_TIME_MIN := 1.5
const BOT_NOTICE_TIME_MAX := 36.0

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
const BOT_STAMP_INTERVAL_MIN := 4.0
const BOT_STAMP_INTERVAL_MAX := 12.0
## ボットは、鬼がこの秒数以内に後ろを通った人にだけスタンプを送る
## (鬼が通ってもいないのに「落ちてる!」と言わないように)
const BOT_STAMP_RECENT_PASS := 6.0
## ボットが振り向いてから前を向くまで(秒)
const BOT_LOOK_TIME := 0.8

# --- 人が鬼をやるとき ---
## 歩く速さの範囲(メートル/秒)。スティック左でゆっくり、右で速く。何もしなければ ONI_WALK_SPEED
const ONI_WALK_SPEED_MIN := 0.4
const ONI_WALK_SPEED_MAX := 1.6
## 「落とす」「ふり」が効く範囲: 席の真後ろからこの距離(メートル、輪にそって)以内
const ONI_DROP_REACH := 1.4
## この周数を歩いても落とさなければ、次の席の後ろで自動的に落とす
const ONI_MAX_LAPS_BEFORE_DROP := 4
## 鬼の「ふり」の物音で、その席のボットがだまされて振り向く確率(0〜1)
const BOT_FEINT_FOOL_CHANCE := 0.3

# --- 試合 ---
## 1試合のラウンド数(落とし物は Items の順に重くなる)
const ROUNDS_PER_MATCH := 5
## 点数(企画書の仮の点数表)
const SCORE_ONI_SAT := 3
const SCORE_CHASER_TOUCHED := 3
## 負けた人(座られた・タッチされた・気づかなかった)
const SCORE_LOSE := -3
## スタンプでだました人の点数
## (「まだ平気」→本当は落ちていた→振り向かなかった / 「落ちてる!」など→本当は落ちていない→お手つき)
const SCORE_DECEIVE := 1
## スタンプで正しく教えた人の点数(本当の「落ちてる!」などで、相手が振り向けた)
const SCORE_HELP := 1
## お手つき1回の点数
const SCORE_OTETSUKI := -1
## この回数お手つきすると、それまでの点数のプラス分が消えて 0 点になる(マイナスはそのまま)。
## そのあと回数は 0 に戻る
const OTETSUKI_LIMIT := 3
## お手つき OTETSUKI_LIMIT 回で、次のラウンドは強制的に鬼にもするか(企画書の案。今は使わない: 次の鬼は負けた人)
const OTETSUKI_FORCES_ONI := false

# --- 落とし物の重さ(重さ 0 = ハンカチ、1 = 教卓) ---
## 置く音の大きさ(dB)と、聞こえる距離。重いほど大きく遠くまで
const DROP_VOLUME_DB_HEAVY := 6.0
const DROP_SOUND_RANGE_HEAVY := 8.0
## 拾って追いかける人の速さの倍率(重いほど遅い)
const CARRY_SPEED_HEAVY := 0.7
## 落とすまで鬼が持ち歩く間の速さの倍率
const ONI_CARRY_SPEED_HEAVY := 0.8
## ボットが気づくまでの時間の倍率(重いほど音が大きく、早く気づく)
const BOT_NOTICE_HEAVY := 0.45

# --- 鬼の声 ---
## 声を出したあと、次に出せるまで(秒)
const ONI_VOICE_COOLDOWN := 1.5
## 声を出してからこの秒数以内に落とすと、置く音がかき消される
const VOICE_MASK_WINDOW := 0.8
## かき消されたときの置く音の小ささ(dB、元の音から引く)
const VOICE_MASK_DB := -14.0
## かき消されたとき、ボットが気づくまでの時間の倍率
const BOT_NOTICE_MASKED := 1.6
## 鬼の声で、いちばん近い席のボットがだまされて振り向く確率
const BOT_VOICE_FOOL_CHANCE := 0.2
## ボットの鬼が、落とす直前に声を出す確率/ふだんに声を出す間隔(秒)
const BOT_ONI_VOICE_AT_DROP := 0.5
const BOT_ONI_VOICE_INTERVAL_MIN := 5.0
const BOT_ONI_VOICE_INTERVAL_MAX := 14.0

# --- バナナの皮 ---
## 1人が1ラウンドに投げられる数
const BANANAS_PER_ROUND := 1
## 狙った人の、どれだけ前(メートル、通り道にそって)に落ちるか
const BANANA_AHEAD := 2.5
## 踏んだと判定する距離(メートル)
const BANANA_HIT_RADIUS := 0.45
## 転んで止まる時間(秒)
const SLIP_TIME := 1.0
## ボットが追いかけっこ中にバナナを投げる確率と、投げるまでの時間(秒)
const BOT_BANANA_CHANCE := 0.35
const BOT_BANANA_DELAY_MIN := 0.5
const BOT_BANANA_DELAY_MAX := 3.0
