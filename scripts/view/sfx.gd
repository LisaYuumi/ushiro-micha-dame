class_name Sfx
extends RefCounted
## 仮の効果音を、音声ファイルなしでプログラムで作る。
## あとで本物の音に差しかえるときは、ここで load() したものを返せばよい。

const RATE := 22050

static var _footstep: AudioStreamWAV
static var _drop: AudioStreamWAV
static var _beep: AudioStreamWAV
static var _stamp := {}


## 「ざっ」という足音(スマホのスピーカーでも聞こえるよう、高めでくっきり)
static func footstep() -> AudioStreamWAV:
	if _footstep == null:
		_footstep = _make(0.10, 0.6, 35.0, 0.0, 0.0, 1.0)
	return _footstep


## 「ぽさっ」というハンカチを置いた音
static func drop() -> AudioStreamWAV:
	if _drop == null:
		_drop = _make(0.22, 0.35, 16.0, 420.0, 0.35, 1.0)
	return _drop


## スタンプが届いた音(種類ごとに少しちがう、仮の音)
static func stamp(kind: String) -> AudioStreamWAV:
	if not _stamp.has(kind):
		match kind:
			Stamps.NOW:
				# 手拍子っぽい「パン」
				_stamp[kind] = _make(0.08, 0.9, 50.0, 0.0, 0.0, 1.0)
			Stamps.TRUST:
				_stamp[kind] = _make(0.3, 0.0, 6.0, 520.0, 1.0, 0.7)
			Stamps.SAFE:
				_stamp[kind] = _make(0.2, 0.0, 10.0, 660.0, 1.0, 0.6)
			_:
				_stamp[kind] = _make(0.2, 0.0, 10.0, 990.0, 1.0, 0.6)
	return _stamp[kind]


## 音テスト用の「ピー」
static func beep() -> AudioStreamWAV:
	if _beep == null:
		_beep = _make(0.35, 0.0, 4.0, 880.0, 1.0, 0.8)
	return _beep


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
