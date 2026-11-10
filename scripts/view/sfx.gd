class_name Sfx
extends RefCounted
## 仮の効果音を、音声ファイルなしでプログラムで作る。
## あとで本物の音に差しかえるときは、ここで load() したものを返せばよい。

const RATE := 22050

static var _footstep: AudioStreamWAV
static var _drop: AudioStreamWAV


## 「ざっ」という小さな足音
static func footstep() -> AudioStreamWAV:
	if _footstep == null:
		_footstep = _make(0.12, 0.25, 40.0, 0.0, 0.0, 0.8)
	return _footstep


## 「ぽふっ」というハンカチを置いた音
static func drop() -> AudioStreamWAV:
	if _drop == null:
		_drop = _make(0.25, 0.06, 18.0, 110.0, 0.6, 0.9)
	return _drop


## ノイズ(lowpass でこもらせる)+低い音(tone_hz)を、だんだん小さくする。
static func _make(duration: float, lowpass: float, decay: float,
		tone_hz: float, tone_mix: float, volume: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 12345
	for i in n:
		var t := float(i) / RATE
		y += lowpass * (noise_rng.randf_range(-1.0, 1.0) - y)
		var s := y * (1.0 - tone_mix) * 3.0 + sin(TAU * tone_hz * t) * tone_mix
		s *= exp(-t * decay) * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
