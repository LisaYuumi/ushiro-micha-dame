class_name GameConfig
extends RefCounted
## ゲームの調整用の数値をまとめた場所。
## 遊びながら変えたい数値は、すべてここに置く。

# --- 配置 ---
## 席の数(座る人の数。鬼は別に1人なので、全部で SEAT_COUNT + 1 人。企画書は4〜8人)
const SEAT_COUNT := 7
## 選べる人数(全員の数 = 席 + 鬼1人)。ロビーで選ぶ
const PLAYER_COUNT_OPTIONS := [8, 5]
## 席が並ぶ輪の半径(メートル)
const RING_RADIUS := 3.0
## 鬼が歩く輪の半径(席の輪より外側)
const ONI_WALK_RADIUS := 4.3
## ハンカチが落ちる位置の半径(席の真後ろ。背もたれに隠れない距離)
const DROP_RADIUS := 3.8

# --- 鬼の動き ---
## 鬼が歩く速さ(メートル/秒)。1周 約46秒(席の後ろで止まる時間込み)。
## 遅いほど、スタンプを送ったり考えたりする時間が長くなる
const ONI_WALK_SPEED := 0.7
## 席の後ろで立ち止まる時間(秒)。本当に落とすときも、ニセの物音のときも同じ
const ONI_PAUSE_TIME := 1.5
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
const SEAT_CAM_HFOV := 100.0
## 5人で遊ぶ(席が4〜5つ)ときの見える幅。席が少ないほど両どなりが正面寄りになるので狭くてよい
const SEAT_CAM_HFOV_SMALL := 80.0

# --- 振り向き ---
## 振り向くのにかかる時間(秒)
const LOOK_BACK_TIME := 0.15
## 前を向いているときのカメラの下向き角度(度)
const SEAT_CAM_PITCH_FRONT := -16.0
## 前を向いているとき、カメラを頭より後ろ・上に引く量(メートル)。輪の全体と正面の人の顔が見えるように。
## 両どなりは画面の端に少し見えるくらいになる
const SEAT_CAM_BACK := 0.6
const SEAT_CAM_HEIGHT := 1.8
## 振り向いたときのカメラの高さ(頭の位置)
const SEAT_CAM_HEIGHT_BACK := 1.45
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
## 鬼がもう一周してくるまで(約46秒)に気づかなければ見逃し
const BOT_NOTICE_TIME_MIN := 1.5
const BOT_NOTICE_TIME_MAX := 55.0

# --- 追いかけるときのカメラ ---
## 自分が追いかけるとき、カメラを輪の外側のどれだけ後ろ・上に置くか(メートル)
const CHASE_CAM_DISTANCE := 3.0
const CHASE_CAM_HEIGHT := 3.2
## 自分が鬼のときのカメラ(追いかける人より近く。鬼の背中ごしに輪が見えるくらい)
const ONI_CAM_DISTANCE := 1.9
const ONI_CAM_HEIGHT := 2.0
## 鬼のカメラが見る高さ(鬼の足もとからの高さ)。座っている人の頭と名札まで映るように、少し上を見る
const ONI_CAM_LOOK_HEIGHT := 1.5

# --- スタンプ ---
## 1人に同時に表示されるスタンプの数(早い者勝ち。空きができたら次が届く)
const STAMP_SLOTS := 3
## 届いたスタンプは、鬼がこの周数だけ歩いたら消える(0.5 = 半周)
const STAMP_EXPIRE_LAPS := 0.5
## 1人が1ラウンドに送れる数。-1 = 何回でも送れる(同じ相手には1ラウンド1回まで)
const STAMPS_PER_ROUND := -1
## 席がこの数以上のとき(8人で遊ぶとき)は、両どなりにはスタンプを送れない
const STAMP_NEIGHBOR_BLOCK_MIN_SEATS := 6
## 普通のボットが、見える相手に本当のことを言う確率(0〜1)
const BOT_NORMAL_HONEST_CHANCE := 0.9
## 普通のボットが、後ろが見えない相手(5人のときの両どなり)に当てずっぽうで「落ちてる!」と言う確率
const BOT_GUESS_LOOK_CHANCE := 0.3
## 手下ボットが本当のことを言う確率(怪しまれないように、ときどき本当も混ぜる)
const BOT_MINION_HONEST_CHANCE := 0.3
## 鬼ボットが本当のことを言う確率と、スタンプを送る間隔(秒)
const BOT_ONI_HONEST_CHANCE := 0.3
const BOT_ONI_STAMP_INTERVAL_MIN := 10.0
const BOT_ONI_STAMP_INTERVAL_MAX := 20.0
## ボットが届いたスタンプを信じて振り向く確率のもと(性格でかわる)
const BOT_TRUST_CHANCE := 0.7
## ボットが、前のラウンドで手下だった人のスタンプを数えるときの重さ(1 = ふつう)
const BOT_PREV_MINION_WEIGHT := 0.3
## ボットがスタンプを送る間隔(秒)。この範囲でランダム(性格でかわる)
const BOT_STAMP_INTERVAL_MIN := 8.0
const BOT_STAMP_INTERVAL_MAX := 18.0
## ボットは、鬼がこの秒数以内に後ろを通った人にだけスタンプを送る
## (鬼が通ってもいないのに「落ちてる!」と言わないように)
const BOT_STAMP_RECENT_PASS := 10.0 # STAMP_SCORE_RECENT_PASS と同じにしておく
## ボットが振り向いてから前を向くまで(秒)
const BOT_LOOK_TIME := 0.8
## ボットは、鬼が自分の後ろを通ってからこの秒数がたつまで振り向かない(気づいたとき・声やスタンプでも)。
## 鬼が一度も後ろを通っていないときも振り向かない。置いた瞬間に振り向かれると、逃げる鬼に
## バナナを置く間がなくなるため
const BOT_TURN_MIN_AFTER_PASS := 5.0

# --- 人が鬼をやるとき ---
## 歩く速さの範囲(メートル/秒)。スティック左でゆっくり、右で速く。何もしなければ ONI_WALK_SPEED
const ONI_WALK_SPEED_MIN := 0.3
const ONI_WALK_SPEED_MAX := 1.2
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
## スタンプの点数(教えた・だました)は、鬼が相手の後ろを通ってからこの秒数以内に送ったものだけ
const STAMP_SCORE_RECENT_PASS := 10.0
## スタンプの点数(送った人の役ごと)。
## 教えた: 本当の「落ちてる!」などで相手が振り向けた / 本当の「まだ平気」で相手が振り向かずにすんだ
## だました: 嘘の「落ちてる!」などで相手がお手つき / 嘘の「まだ平気」で相手が振り向かなかった
const SCORE_HELP_NORMAL := 1
const SCORE_DECEIVE_NORMAL := 0
const SCORE_HELP_MINION := 0
const SCORE_DECEIVE_MINION := 1
const SCORE_HELP_ONI := 0
const SCORE_DECEIVE_ONI := 1
## 鬼が勝った(席に座れた・最後まで気づかれなかった)とき、手下の点数(手下が負けた本人のときはもらえない)
const SCORE_MINION_ONI_WIN := 2
## 1ラウンドに振り向ける回数(「拾う」も1回使う)。追いかけっこ中・勝敗が出た後は数えない
const LOOKS_PER_ROUND := 2
## 外れの振り向き(後ろに何もないのに振り向く)は減点しない。振り向きの回数制限(LOOKS_PER_ROUND)だけ。
## 外れの回数は、表情(困り眉→汗だく→放心)と、だました人の点数に使う
## この回数外れると、顔が放心顔になる(見た目だけ)
const OTETSUKI_DAZED_COUNT := 3

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

# --- 鬼の影 ---
## 鬼が自分の後ろのこの距離(メートル)以内に来ると、自分の前の床に影が映る
const ONI_SHADOW_RANGE := 3.0
## 影のいちばん濃いときの濃さ(0〜1)
const ONI_SHADOW_ALPHA := 0.55

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

# --- 開発用 ---
## ⚙メニューに「撮影モード」(SNS 画像や宣伝素材の見本を撮る画面)を出すか。本番では false にして隠す
const SHOW_PHOTO_MODE := true

# --- 見た目(A案「放課後ポップ」) ---
## 空・壁の上のほうの色
const COLOR_SKY := Color("8FD3E8")
## 床の色(あとでホストが舞台を選ぶときに変えられるように、ここで持つ)
const COLOR_FLOOR := Color("F6C945")
## 主要ボタンなどのアクセントの色
const COLOR_ACCENT := Color("FF6B4A")
## 文字・輪郭線の色
const COLOR_INK := Color("1E1B18")
## 名札やボタンの地の色
const COLOR_PAPER := Color("FFFFFF")
## キャラ・小物・家具の輪郭線の太さ(メートル)
const OUTLINE_WIDTH := 0.025
