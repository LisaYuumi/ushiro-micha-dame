class_name Sfx
extends RefCounted
## 仮の効果音を、音声ファイルなしでプログラムで作る。
## あとで本物の音に差しかえるときは、ここで load() したものを返せばよい。

const RATE := 22050

static var _footstep: AudioStreamWAV
static var _drop: AudioStreamWAV
static var _beep: AudioStreamWAV
static var _stamp := {}
static var _voice := {}


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
	# 言葉ではない声(仮の音)
	if not _stamp.has(kind):
		match kind:
			Stamps.DROPPED:
				# 「ハッ!」: 息まじりの短い声が、上がって止まる
				_stamp[kind] = _make_fn(0.2, func(t: float, n: float) -> float:
					var f := 330.0 + 260.0 * t / 0.2
					var v := sin(TAU * f * t) + 0.4 * sin(TAU * 2.0 * f * t)
					return (v * 0.45 + n * 0.25) * minf(t * 40.0, 1.0) * maxf(1.0 - t / 0.2, 0.0))
			Stamps.SAFE:
				# 「シーッ」: 高い息の音
				_stamp[kind] = _make_fn(0.5, func(t: float, n: float) -> float:
					var hiss := n - 0.6 * sin(TAU * 40.0 * t) * n
					return hiss * 0.5 * minf(t * 15.0, 1.0) * maxf(1.0 - t / 0.5, 0.0))
			Stamps.FAKE:
				# 「ん?」: 口を閉じた声が、くいっと上がる
				_stamp[kind] = _make_fn(0.35, func(t: float, _n: float) -> float:
					var f := 200.0 + (160.0 * pow(t / 0.35, 2.0))
					var v := sin(TAU * f * t) + 0.25 * sin(TAU * 3.0 * f * t)
					return v * 0.5 * minf(t * 20.0, 1.0) * maxf(1.0 - t / 0.35, 0.0))
			_:
				# 「うるっ」: 高めの声がふるえる
				_stamp[kind] = _make_fn(0.45, func(t: float, _n: float) -> float:
					var f := 420.0 + 35.0 * sin(TAU * 11.0 * t)
					var v := sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t)
					return v * 0.42 * minf(t * 18.0, 1.0) * maxf(1.0 - t / 0.45, 0.0))
	return _stamp[kind]


## 鬼の声(仮の音)
static func voice(kind: String) -> AudioStreamWAV:
	if not _voice.has(kind):
		match kind:
			Voices.COUGH:
				# 「ゴホッゴホッ」: こもったノイズを2回
				_voice[kind] = _make_fn(0.45, func(t: float, n: float) -> float:
					var k := fmod(t, 0.22)
					return n * exp(-k * 25.0) * (1.0 if t < 0.4 else 0.0) * 0.9)
			Voices.WHISTLE:
				# 「ヒューッ」: 高い音がすべり上がる
				_voice[kind] = _make_fn(0.6, func(t: float, _n: float) -> float:
					var f := 1300.0 + 900.0 * t / 0.6
					return sin(TAU * f * t) * minf(t * 20.0, 1.0) * maxf(1.0 - t / 0.6, 0.0) * 0.5)
			Voices.CLAP:
				# 「パンパン」
				_voice[kind] = _make_fn(0.35, func(t: float, n: float) -> float:
					var k := fmod(t, 0.17)
					return n * exp(-k * 60.0))
			_:
				# 「あーっ!」: 声っぽい低めの音に、ゆれ
				_voice[kind] = _make_fn(0.7, func(t: float, _n: float) -> float:
					var f := 240.0 + 10.0 * sin(TAU * 6.0 * t)
					var v := sin(TAU * f * t) + 0.5 * sin(TAU * 2.0 * f * t) + 0.3 * sin(TAU * 3.0 * f * t)
					return v * minf(t * 15.0, 1.0) * maxf(1.0 - t / 0.7, 0.0) * 0.4)
	return _voice[kind]


## 時刻 t とノイズ n から音の高さを決める関数で、音を作る
static func _make_fn(duration: float, f: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 777
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += 0.5 * (noise_rng.randf_range(-1.0, 1.0) - y)
		var v: float = f.call(t, y * 2.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


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
