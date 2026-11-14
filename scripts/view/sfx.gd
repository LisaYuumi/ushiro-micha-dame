class_name Sfx
extends RefCounted
## 音の読みこみと、音量のバス(全体・BGM・効果音)。
## 音は tools/audio/make_sounds.py で作った assets/sounds/<名前>.ogg(プログラムで合成したオリジナルの音)。
## 同じ名前のファイルを置きかえれば、ゲームはその音を使う(Kenney の音などに差しかえられる。.wav でもよい)。

const DIR := "res://assets/sounds/"
## 音量のバス(Master = 全体)
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"

static var _cache := {}


## 名前の音(なければ null)。BGM・環境音はくり返す
static func get_stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var st: AudioStream = null
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(DIR + sound_name + ext):
			st = load(DIR + sound_name + ext)
			break
	if st != null and (sound_name.begins_with("bgm_") or sound_name.begins_with("amb_")):
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		elif st is AudioStreamWAV:
			(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	_cache[sound_name] = st
	return st


## 音量のバス(BGM・効果音)を用意して、Profile の音量を当てる
static func setup_buses() -> void:
	for bus in [BUS_BGM, BUS_SFX]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	apply_volumes()


## Profile の音量(0〜1)を、バスの大きさにする
static func apply_volumes() -> void:
	_set_bus("Master", Profile.vol_master)
	_set_bus(BUS_BGM, Profile.vol_bgm)
	_set_bus(BUS_SFX, Profile.vol_sfx)


static func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## 効果音の 2D のプレイヤー(効果音のバス)
static func player_2d(parent: Node, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_SFX
	p.volume_db = vol_db
	# Godot が自分で混ぜる方式(STREAM)で鳴らす。ブラウザの「サンプル再生」は Android の Chrome で鳴らなかった。
	# 震え(音のとぎれ)は、出力の余裕を大きくし(project.godot の output_latency.web)、効果音を WAV にして減らす
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	parent.add_child(p)
	return p


## 効果音の 3D のプレイヤー(鳴った場所から聞こえる。後ろの左右がわかる)
static func player_3d(parent: Node, vol_db: float = 0.0, unit: float = 2.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SFX
	p.volume_db = vol_db
	p.unit_size = unit
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	parent.add_child(p)
	return p
