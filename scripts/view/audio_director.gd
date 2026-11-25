class_name AudioDirector
extends Node
## BGM と、場所のない効果音(ボタン・チャイム・ジングル・自分の振り向きなど)を鳴らす。
## - BGM は2つのプレイヤーで、なめらかに切りかえる(ロビー・ラウンド中・追いかけっこ・結果)
## - ラウンド中の BGM は、試合の進み具合(ラウンド)だけで変える。鬼との距離では変えない(鬼の場所がわかってしまうため)
##   (鬼が自分のうしろ3m以内に来たときの心臓の音は、ここで鳴らす(set_heart)。影がのびるのと同じときだけ。鳴っている間は BGM を下げる)
## 場所のある音(落とし物・足音など)は WorldView が 3D で鳴らす。

## どこからでも呼べるように(main が1つだけ作る)
static var instance: AudioDirector

## BGM の大きさ(dB)。ラウンド中は、落とし物の音や足音が聞こえるように小さめ
const BGM_DB := {"bgm_lobby": -10.0, "bgm_round_1": -15.0, "bgm_round_2": -15.0, "bgm_round_3": -14.0, "bgm_chase": -11.0,
		"bgm_school_1": -15.0, "bgm_school_2": -15.0, "bgm_school_3": -14.0,
		"bgm_beach_1": -15.0, "bgm_beach_2": -15.0, "bgm_beach_3": -14.0,
		"bgm_night_1": -15.0, "bgm_night_2": -15.0, "bgm_night_3": -14.0,
		"bgm_ending": -11.0, "bgm_photo": -10.0}
const FADE_TIME := 0.8

var _bgm: Array[AudioStreamPlayer] = []
var _bgm_now := ""
var _active := 0
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
## BGM の切りかえの途中のフェード(すぐ次に切りかえたら止めて、音が消えたままにならないように)
var _fade: Tween
## ボタンの「ポッ」専用(ほかの効果音のプレイヤーを横取りして、鳴っている音を切らないように)
var _click_player: AudioStreamPlayer


func _ready() -> void:
	instance = self
	Sfx.setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = Sfx.BUS_BGM
		p.playback_type = Sfx.playback_type()
		p.volume_db = -80.0
		add_child(p)
		_bgm.append(p)
	for i in 6:
		_pool.append(Sfx.player_2d(self))
	_click_player = Sfx.player_2d(self)
	_click_player.stream = Sfx.get_stream("ui_click")


## BGM を切りかえる(同じ曲なら何もしない。"" で止める)
func play_bgm(bgm_name: String) -> void:
	if bgm_name == _bgm_now:
		return
	_bgm_now = bgm_name
	_active = 1 - _active
	var nw := _bgm[_active]
	if _fade and _fade.is_valid():
		_fade.kill()
	var tw := create_tween().set_parallel(true)
	_fade = tw
	# 新しい曲を鳴らすプレイヤー以外は、小さくして消す(途中で止めたフェードの曲も残さない)
	for p in _bgm:
		if p != nw or bgm_name == "":
			tw.tween_property(p, "volume_db", -80.0, FADE_TIME)
	if bgm_name == "":
		return
	nw.stream = Sfx.get_stream(bgm_name)
	if nw.stream == null:
		return
	nw.volume_db = -40.0
	nw.play()
	tw.tween_property(nw, "volume_db", float(BGM_DB.get(bgm_name, -12.0)), FADE_TIME)


# --- 心臓の音「ドク・ドクン」(鬼がうしろに近いとき。WorldView が近さを set_heart で毎フレーム渡す) ---
var _heart_level := 0.0
var _heart_at := 0
var _heart_wait := 0.0
var _heart_players: Array[AudioStreamPlayer] = []
var _heart_next := 0
var _duck := 0.0
## 試しに鳴らす(音の大きさの画面のボタン): 残りの秒数
var _heart_test := 0.0


## 鬼がうしろに近い強さ(0〜1。0 で止まる)
func set_heart(level: float) -> void:
	_heart_level = clampf(level, 0.0, 1.0)
	_heart_at = Time.get_ticks_msec()


## 「心臓の音を試しに鳴らす」: 遠い(小さく・ゆっくり)→ 近い(大きく・速く)を数秒で
func test_heart(seconds: float = 5.0) -> void:
	_heart_test = seconds


func _process(delta: float) -> void:
	var level := _heart_level
	# (しばらく届かなければ止める: ロビーにもどったときなど)
	if Time.get_ticks_msec() - _heart_at > 400:
		level = 0.0
	if _heart_test > 0.0:
		_heart_test -= delta
		level = clampf(1.0 - _heart_test / 5.0, 0.15, 1.0) if _heart_test > 0.0 else 0.0
	# BGM を下げる(鳴っている間は半分くらいまで。なめらかに)
	var want_duck := GameConfig.HEART_BGM_DUCK_DB * smoothstep(0.0, 0.3, level)
	_duck = move_toward(_duck, want_duck, delta * 12.0)
	Sfx.set_bgm_duck(_duck)
	if level <= 0.01:
		_heart_wait = 0.0
		return
	if _heart_players.is_empty():
		for i in 2:
			var p := Sfx.player_2d(self)
			p.stream = Sfx.get_stream("heartbeat")
			_heart_players.append(p)
	_heart_wait -= delta
	if _heart_wait <= 0.0:
		var bpm := lerpf(GameConfig.HEART_BPM_FAR, GameConfig.HEART_BPM_NEAR, level)
		_heart_wait = 60.0 / bpm
		var p := _heart_players[_heart_next]
		_heart_next = (_heart_next + 1) % _heart_players.size()
		# (1拍ごとに、ほんの少し大きさと高さを変えて、機械っぽくならないように)
		p.volume_db = lerpf(GameConfig.HEART_DB_FAR, GameConfig.HEART_DB_NEAR, level) + randf_range(-1.0, 1.0)
		p.pitch_scale = lerpf(1.0, 1.06, level) * randf_range(0.97, 1.03)
		p.play()


func current_bgm() -> String:
	return _bgm_now


## 場所のない効果音を1つ鳴らす
func play(sound_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var st := Sfx.get_stream(sound_name)
	if st == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## ボタンを押したときの「ポッ」(どこからでも)
static func click() -> void:
	if instance and instance._click_player:
		var p := instance._click_player
		p.volume_db = -8.0
		p.pitch_scale = randf_range(0.95, 1.05)
		p.play()


## どこからでも効果音を鳴らす
static func sfx(sound_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if instance:
		instance.play(sound_name, vol_db, pitch)
