class_name AudioDirector
extends Node
## BGM と、場所のない効果音(ボタン・チャイム・ジングル・自分の振り向きなど)を鳴らす。
## - BGM は2つのプレイヤーで、なめらかに切りかえる(ロビー・ラウンド中・追いかけっこ・結果)
## - ラウンド中の BGM は、試合の進み具合(ラウンド)だけで変える。鬼との距離では変えない(鬼の場所がわかってしまうため)
## 場所のある音(落とし物・足音など)は WorldView が 3D で鳴らす。

## どこからでも呼べるように(main が1つだけ作る)
static var instance: AudioDirector

## BGM の大きさ(dB)。ラウンド中は、落とし物の音や足音が聞こえるように小さめ
const BGM_DB := {"bgm_lobby": -10.0, "bgm_round_1": -17.0, "bgm_round_2": -17.0, "bgm_round_3": -16.0, "bgm_chase": -11.0}
const FADE_TIME := 0.8

var _bgm: Array[AudioStreamPlayer] = []
var _bgm_now := ""
var _active := 0
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	instance = self
	Sfx.setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = Sfx.BUS_BGM
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		p.volume_db = -80.0
		add_child(p)
		_bgm.append(p)
	for i in 6:
		_pool.append(Sfx.player_2d(self))


## BGM を切りかえる(同じ曲なら何もしない。"" で止める)
func play_bgm(bgm_name: String) -> void:
	if bgm_name == _bgm_now:
		return
	_bgm_now = bgm_name
	var old := _bgm[_active]
	_active = 1 - _active
	var nw := _bgm[_active]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, FADE_TIME)
	if bgm_name == "":
		return
	nw.stream = Sfx.get_stream(bgm_name)
	if nw.stream == null:
		return
	nw.volume_db = -40.0
	nw.play()
	tw.tween_property(nw, "volume_db", float(BGM_DB.get(bgm_name, -12.0)), FADE_TIME)


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
	if instance:
		instance.play("ui_click", -8.0, randf_range(0.95, 1.05))


## どこからでも効果音を鳴らす
static func sfx(sound_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if instance:
		instance.play(sound_name, vol_db, pitch)
