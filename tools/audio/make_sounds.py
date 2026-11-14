#!/usr/bin/env python3
"""ゲームの音を作る(すべてプログラムで合成したオリジナルの音。録音・既存の曲は使っていない)。

numpy で波形を作り、ffmpeg で OGG Vorbis にして assets/sounds/ に書き出す。
同じ名前のファイルを assets/sounds/ に置けば、ゲームはその音を使う(Kenney の音などに差しかえられる)。
このスクリプトは AI(Claude)が書いたもの。できた音は「AI で生成した素材」として扱う(docs/CREDITS.md)。

使い方: python3 tools/audio/make_sounds.py [名前 ...](名前を書かなければ全部作る)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "sounds")
SR = 32000
RNG = np.random.default_rng(20261114)


# --- 部品 ---

def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def silence(dur):
    return np.zeros(int(dur * SR))


def noise(dur):
    return RNG.uniform(-1.0, 1.0, int(dur * SR))


def _shape(x, f_resp):
    """周波数の形 f_resp(周波数の配列) をかける(FFT でフィルター)"""
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec * f_resp(f), n)


def lowpass(x, fc, order=2):
    return _shape(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def highpass(x, fc, order=2):
    return _shape(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x, lo, hi, order=2):
    return highpass(lowpass(x, hi, order), lo, order)


def peak(x, fc, q=6.0):
    """ひとつの山(声のフォルマントなど)"""
    return _shape(x, lambda f: 1.0 / (1.0 + (q * (f / fc - fc / np.maximum(f, 1e-3))) ** 2))


def env_exp(dur, decay, attack=0.002):
    t = t_of(dur)
    a = np.minimum(t / max(attack, 1e-4), 1.0)
    return a * np.exp(-t / decay)


def env_ar(dur, attack, release):
    t = t_of(dur)
    a = np.minimum(t / max(attack, 1e-4), 1.0)
    r = np.clip((dur - t) / max(release, 1e-4), 0.0, 1.0)
    return a * r


def tone(freq, dur, wave_kind="sine"):
    """freq: 数か、長さ dur の配列(音の高さの変化)"""
    n = int(dur * SR)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq)[:n]
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_kind == "sine":
        return np.sin(ph)
    if wave_kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if wave_kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if wave_kind == "saw":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    raise ValueError(wave_kind)


def glide(f0, f1, dur, curve=1.0):
    t = np.linspace(0.0, 1.0, int(dur * SR))
    return f0 + (f1 - f0) * t ** curve


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, start, total=None):
    """x を start 秒の位置に置いた配列"""
    pad = np.zeros(int(start * SR))
    y = np.concatenate([pad, x])
    if total is not None:
        y = np.pad(y, (0, max(0, int(total * SR) - len(y))))[: int(total * SR)]
    return y


def norm(x, level=0.9):
    m = np.max(np.abs(x)) if len(x) else 0
    return x * (level / m) if m > 0 else x


def thud(f0, f1, dur, decay):
    return tone(glide(f0, f1, dur, 0.5), dur) * env_exp(dur, decay)


def click(dur, lo, hi, decay):
    return bandpass(noise(dur), lo, hi) * env_exp(dur, decay)


def bell(freq, dur, decay=0.8, bright=1.0):
    t = t_of(dur)
    out = np.zeros(len(t))
    for ratio, amp, dk in [(1.0, 1.0, 1.0), (2.0, 0.5 * bright, 0.6), (2.76, 0.35 * bright, 0.45),
                           (5.4, 0.18 * bright, 0.25), (8.93, 0.08 * bright, 0.15)]:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay * dk))
    return out * np.minimum(t / 0.003, 1.0)


def pluck(freq, dur, decay=0.25, bright=0.5):
    t = t_of(dur)
    out = np.zeros(len(t))
    for k in range(1, 7):
        out += (bright ** (k - 1)) * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * k / decay / 2.0)
    return out * np.minimum(t / 0.002, 1.0) * np.exp(-t / decay)


def voice(f0_curve, dur, formants, breath=0.15, vib=0.0, vib_rate=6.0):
    """言葉ではない声(「ハッ」「うん」など): 声の高さの変化 + 口の形(フォルマント)"""
    t = t_of(dur)
    f0 = np.asarray(f0_curve)[: len(t)] if not np.isscalar(f0_curve) else np.full(len(t), f0_curve)
    f0 = f0 * (1.0 + vib * np.sin(2 * np.pi * vib_rate * t))
    src = tone(f0, dur, "saw") + breath * noise(dur)
    out = np.zeros(len(t))
    for fc, amp in formants:
        out += amp * peak(src, fc, 5.0)
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


# --- 1. 落とし物の音(本物とフェイクは同じ音) ---

def drop_0():
    # ハンカチ「ふわっ」: 布がふわりと落ちる、やわらかい風の音
    d = 0.55
    swish = lowpass(noise(d), 1400) * env_ar(d, 0.12, 0.38)
    flap = bandpass(noise(0.08), 300, 900) * env_exp(0.08, 0.025)
    return norm(mix(swish, at(flap * 0.5, 0.36)), 0.8)


def drop_1():
    # 上履き「ポトッ」: ゴム底の小さな音と、小さく1回はねる
    hit = mix(thud(190, 110, 0.12, 0.035), click(0.03, 1500, 4000, 0.006) * 0.4)
    bounce = mix(thud(170, 120, 0.08, 0.02), click(0.02, 1500, 4000, 0.004) * 0.25) * 0.35
    return norm(mix(hit, at(bounce, 0.13)))


def drop_2():
    # ランドセル「ドスッ」: 低いドスッと、革のパタンと、金具のチャリ
    body = thud(110, 55, 0.35, 0.09)
    leather = bandpass(noise(0.07), 350, 1600) * env_exp(0.07, 0.018)
    buckle = mix(np.sin(2 * np.pi * 3100 * t_of(0.12)), np.sin(2 * np.pi * 4370 * t_of(0.12)) * 0.5) * env_exp(0.12, 0.03)
    return norm(mix(body, leather * 0.7, at(buckle * 0.18, 0.02)))


def drop_3():
    # 机「ガタン」: 木の天板のゴトッと、金属の脚のガチャッ、もう1回ガタッ
    def wood(scale):
        t = t_of(0.3)
        return sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / dk) for f, a, dk in
                   [(210, 1.0, 0.09), (455, 0.6, 0.06), (780, 0.35, 0.04)]) * scale
    metal = sum(a * np.sin(2 * np.pi * f * t_of(0.18)) for f, a in [(1830, 0.6), (2650, 0.4), (3900, 0.25)]) * env_exp(0.18, 0.04)
    first = mix(wood(1.0), thud(120, 60, 0.25, 0.06) * 0.8, metal * 0.35, click(0.04, 800, 3000, 0.008) * 0.5)
    second = mix(wood(0.5), metal * 0.25)
    return norm(mix(first, at(second, 0.09)))


def drop_4():
    # 教卓「ドーン」: とても低くて長いドーンと、木の箱のひびき、床のゴゴゴ
    d = 0.9
    boom = thud(85, 32, d, 0.28)
    t = t_of(d)
    box = (np.sin(2 * np.pi * 140 * t) * 0.5 + np.sin(2 * np.pi * 285 * t) * 0.3) * np.exp(-t / 0.18)
    rumble = lowpass(noise(d), 180) * env_exp(d, 0.35) * 0.8
    knock = click(0.05, 500, 2500, 0.01) * 0.6
    return norm(mix(boom, box, rumble, knock))


# --- 2. 足音 ---

def step():
    # 鬼の足音: 上履きで床をトッ。スマホのスピーカーやイヤホンでも聞こえるように、少し高めでくっきり
    tap = bandpass(noise(0.08), 700, 3200) * env_exp(0.08, 0.016)
    body = thud(220, 140, 0.07, 0.022) * 0.7
    squeak = tone(glide(1700, 1500, 0.04), 0.04) * env_exp(0.04, 0.01) * 0.12
    return norm(mix(tap, body, squeak), 0.9)


def run_step():
    # 走る足音: 速くて、少しかたい
    return norm(mix(bandpass(noise(0.05), 400, 2500) * env_exp(0.05, 0.012), thud(170, 110, 0.05, 0.015) * 0.5), 0.8)


# --- 3. 座っている人の音 ---

def look():
    # 振り向く「バッ!」: 勢いのある風切り音
    d = 0.2
    sweep = _sweep_noise(d, 500, 3200) * env_ar(d, 0.03, 0.15)
    flap = bandpass(noise(0.05), 200, 800) * env_exp(0.05, 0.015)
    return norm(mix(sweep, at(flap * 0.6, 0.12)))


def _sweep_noise(d, f0, f1):
    """高さが変わっていく風の音(短く区切って、少しずつ帯を動かす)"""
    n = int(d * SR)
    out = np.zeros(n)
    seg = int(0.01 * SR)
    src = noise(d)
    for i in range(0, n, seg):
        k = i / max(n - 1, 1)
        fc = f0 * (f1 / f0) ** k
        part = bandpass(src[max(0, i - seg): i + seg * 2], fc * 0.7, fc * 1.4)
        out[i: i + seg] += part[seg if i >= seg else 0:][: len(out[i: i + seg])]
    return out


def oops():
    # お手つき「シーン…」と、間の抜けた「ぽわわ〜ん」
    d1 = 1.0
    t = t_of(d1)
    shiin = np.sin(2 * np.pi * 2600 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)) * env_ar(d1, 0.2, 0.5) * 0.25
    d2 = 0.8
    f = glide(820, 300, d2, 0.8) * (1 + 0.03 * np.sin(2 * np.pi * 9 * t_of(d2)))
    powan = tone(f, d2, "tri") * env_ar(d2, 0.02, 0.4)
    return norm(mix(shiin, at(powan, 0.55)), 0.75)


def trudge():
    # 体育座りに移る「とぼとぼ」: ゆっくりした、しょんぼりした足音
    one = mix(lowpass(noise(0.12), 500) * env_exp(0.12, 0.04), thud(110, 80, 0.1, 0.035) * 0.7)
    return norm(mix(one, at(one * 0.8, 0.42), at(one * 0.65, 0.86)), 0.7)


def pickup():
    # 拾って立ち上がる「シュッ・ぽん」
    swish = _sweep_noise(0.14, 800, 3000) * env_ar(0.14, 0.02, 0.1)
    pop = tone(glide(500, 1000, 0.1, 0.5), 0.1) * env_exp(0.1, 0.04)
    return norm(mix(swish * 0.7, at(pop, 0.1)))


# --- 4. 追いかけっこの音 ---

def fall():
    # 障害物にぶつかって「ずでーん」: すべる音から、大きなドスン、小さくはねる
    slide = tone(glide(700, 250, 0.25, 1.0), 0.25, "tri") * env_ar(0.25, 0.01, 0.1) * 0.5
    crash = mix(thud(120, 45, 0.45, 0.13), bandpass(noise(0.2), 200, 2500) * env_exp(0.2, 0.05) * 0.6)
    bounce = thud(100, 60, 0.15, 0.04) * 0.35
    return norm(mix(slide, at(crash, 0.18), at(bounce, 0.55)))


def banana():
    # バナナで「つるっ」: きゅっと上がって、すべる
    squeak = tone(glide(600, 1900, 0.16, 0.7), 0.16) * env_ar(0.16, 0.01, 0.05)
    slip = _sweep_noise(0.25, 2500, 700) * env_ar(0.25, 0.02, 0.15) * 0.5
    return norm(mix(squeak, at(slip, 0.1)))


def lap():
    # 2周目に入った合図「ピコーン」
    return norm(mix(bell(midi(84), 0.9, 0.35), at(bell(midi(91), 1.0, 0.45), 0.12)))


def touch():
    # タッチ「パシッ✨」: 手のパシッと、キラキラ
    slap = mix(highpass(noise(0.08), 1500) * env_exp(0.08, 0.012), thud(260, 160, 0.06, 0.015) * 0.5)
    sparkle = mix(*[at(bell(midi(n), 0.5, 0.18, 0.6) * 0.35, 0.06 + i * 0.06) for i, n in enumerate([84, 88, 91, 96])])
    return norm(mix(slap, sparkle))


def sit():
    # 鬼が席に座れた「ストン」
    return norm(mix(thud(160, 90, 0.18, 0.05), at(pluck(midi(79), 0.25, 0.08, 0.3) * 0.4, 0.03)))


# --- 5. スタンプの声(言葉ではない声) ---

def stamp_dropped():
    # 😨「ハッ!」: 息をのむ、短く上がる声
    d = 0.24
    breath = bandpass(noise(0.08), 1200, 5000) * env_exp(0.08, 0.025) * 0.5
    v = voice(glide(380, 560, d, 0.6), d, [(800, 1.0), (1250, 0.6), (2600, 0.2)], breath=0.35) * env_ar(d, 0.01, 0.08)
    return norm(mix(breath, at(v, 0.04)))


def stamp_safe():
    # 👍「うん!」: 口を閉じた明るい「んー↑ん!」
    d1, d2 = 0.14, 0.18
    a = voice(glide(330, 300, d1), d1, [(300, 1.0), (1000, 0.3)], breath=0.05) * env_ar(d1, 0.01, 0.04)
    b = voice(glide(360, 480, d2, 0.5), d2, [(320, 1.0), (1100, 0.35)], breath=0.05) * env_ar(d2, 0.01, 0.07)
    return norm(mix(a, at(b, 0.16)))


def stamp_trust():
    # 🥺「うるうる」: ふるえる、高めの小さな声を2回
    d = 0.28
    def one(f):
        return voice(glide(f, f * 0.85, d), d, [(380, 1.0), (900, 0.5), (2400, 0.15)], breath=0.1, vib=0.04, vib_rate=11) * env_ar(d, 0.02, 0.12)
    return norm(mix(one(560), at(one(520), 0.3)))


# --- 6. 試合の流れの音 ---

def chime():
    # ラウンド開始: 学校のチャイムのような鐘(オリジナルの音の並び)
    notes = [76, 72, 74, 67, 67, 74, 76, 72]
    out = silence(0.1)
    for i, n in enumerate(notes):
        out = mix(out, at(bell(midi(n), 2.2, 0.9, 0.8) * (0.9 if i % 4 else 1.0), 0.05 + i * 0.42 + (0.25 if i >= 4 else 0.0)))
    return norm(out, 0.8)


def _brass(freq, dur):
    t = t_of(dur)
    raw = tone(freq * (1 + 0.004 * np.sin(2 * np.pi * 5 * t)), dur, "saw")
    return lowpass(raw, 1800) * env_ar(dur, 0.02, 0.15)


def reveal():
    # 手下の正体発表「ジャジャーン」
    chord = [60, 64, 67, 72]
    stab = lambda d: mix(*[_brass(midi(n), d) for n in chord])
    cym = highpass(noise(1.4), 4000) * env_exp(1.4, 0.5) * 0.35
    return norm(mix(stab(0.16), at(stab(0.16), 0.22), at(mix(stab(1.3), cym), 0.44)))


def win():
    # ラウンドの勝ち: 明るく上がる
    out = silence(0.1)
    for i, n in enumerate([72, 76, 79, 84]):
        out = mix(out, at(pluck(midi(n), 0.5, 0.25, 0.55) + bell(midi(n + 12), 0.5, 0.25) * 0.2, i * 0.1))
    out = mix(out, at(mix(*[pluck(midi(n), 1.0, 0.5, 0.5) for n in [72, 76, 79, 84]]) * 0.6, 0.42))
    return norm(out)


def lose():
    # ラウンドの負け: しょんぼり下がる「ワ・ワ・ワ・ワ〜ン」
    out = silence(0.1)
    for i, n in enumerate([67, 66, 65]):
        out = mix(out, at(lowpass(tone(midi(n), 0.3, "saw"), 900) * env_ar(0.3, 0.02, 0.1), i * 0.32))
    d = 0.9
    t = t_of(d)
    last = lowpass(tone(midi(64) * (1 + 0.02 * np.sin(2 * np.pi * 6 * t)), d, "saw"), 900) * env_ar(d, 0.02, 0.4)
    return norm(mix(out, at(last, 0.96)), 0.8)


def match_end():
    # 試合の結果発表のファンファーレ
    seq = [(67, 0.0, 0.18), (67, 0.2, 0.18), (67, 0.4, 0.18), (72, 0.6, 0.9)]
    out = silence(0.1)
    for n, s, d in seq:
        out = mix(out, at(mix(_brass(midi(n), d), _brass(midi(n + 4), d) * 0.6, _brass(midi(n - 12), d) * 0.5), s))
    roll = bandpass(noise(0.6), 150, 4000) * env_ar(0.6, 0.3, 0.1) * 0.25
    cym = highpass(noise(1.5), 4000) * env_exp(1.5, 0.6) * 0.3
    return norm(mix(at(roll, 0.0), out, at(cym, 0.6)))


def ui_click():
    # ボタンの「ポッ」
    return norm(tone(glide(700, 1100, 0.06, 0.5), 0.06) * env_exp(0.06, 0.018), 0.7)


# --- 7. BGM(オリジナルの曲。ループする) ---

def _render_song(bpm, bars, parts, beats_per_bar=4):
    """parts: [(拍の位置, 長さ(拍), 鳴らす関数(秒) -> 波形, 音量)]。最後の音のしっぽは頭に戻して、すき間なくループさせる"""
    beat = 60.0 / bpm
    total = int(bars * beats_per_bar * beat * SR)
    out = np.zeros(total)
    for pos, length, fn, vol in parts:
        w = fn(length * beat) * vol
        s = int(pos * beat * SR) % total
        end = s + len(w)
        if end <= total:
            out[s:end] += w
        else:
            k = total - s
            out[s:] += w[:k]
            rest = w[k:]
            out[: len(rest)] += rest[:total]
    return out


def _kick(d):
    return thud(130, 45, min(d, 0.3), 0.08)


def _snare(d):
    dd = min(d, 0.25)
    return mix(bandpass(noise(dd), 1000, 6000) * env_exp(dd, 0.06), tone(190, dd) * env_exp(dd, 0.03) * 0.4)


def _hat(d):
    dd = min(d, 0.08)
    return highpass(noise(dd), 7000) * env_exp(dd, 0.015)


def _chord_notes(root, minor):
    return [root, root + (3 if minor else 4), root + 7]


def bgm_lobby():
    # ロビー・結果: 明るく、はずむ曲(ハ長調、128bpm、8小節)
    bpm, bars = 128, 8
    prog = [(60, False), (67, False), (69, True), (65, False)] * 2
    melody = [72, 76, 79, 76, 74, 79, 74, 71, 72, 76, 81, 79, 77, 76, 74, 72,
              72, 76, 79, 81, 79, 76, 74, 76, 77, 76, 74, 72, 74, 76, 72, 0]
    parts = []
    for b, (root, minor) in enumerate(prog):
        for k in range(8):
            parts.append((b * 4 + k * 0.5, 0.45, lambda d, r=root: pluck(midi(r - 24), d, 0.12, 0.4), 0.55))
        for k in [0.5, 1.5, 2.5, 3.5]:
            for n in _chord_notes(root, minor):
                parts.append((b * 4 + k, 0.4, lambda d, n=n: pluck(midi(n), d, 0.08, 0.5), 0.12))
        parts.append((b * 4 + 0, 0.5, _kick, 0.5))
        parts.append((b * 4 + 2, 0.5, _kick, 0.5))
        parts.append((b * 4 + 1, 0.5, _snare, 0.25))
        parts.append((b * 4 + 3, 0.5, _snare, 0.25))
        for k in range(8):
            parts.append((b * 4 + k * 0.5, 0.25, _hat, 0.08))
    for i, n in enumerate(melody):
        if n:
            parts.append((i * 1.0, 0.9, lambda d, n=n: mix(tone(midi(n), d, "square") * env_ar(d, 0.01, 0.12) * 0.5,
                                                           bell(midi(n), d, 0.3, 0.5) * 0.3), 0.3))
    return norm(_render_song(bpm, bars, parts), 0.8)


def _bgm_round(level):
    # ラウンド中: 控えめで、少し緊張感のある曲(イ短調)。ラウンドが進むほど楽器が増える(level 1〜3)。
    # 鬼との距離では変えない(BGM で鬼の場所がわからないように)
    bpm = [88, 92, 96][level - 1]
    bars = 8
    prog = [(57, True), (53, False), (50, True), (52, False)] * 2
    tip = [69, 0, 72, 0, 71, 0, 69, 0, 65, 0, 69, 0, 68, 0, 64, 0]
    parts = []
    for b, (root, minor) in enumerate(prog):
        # つま先立ちのようなピチカート
        for k, n in enumerate(_chord_notes(root, minor) + [root + 12]):
            parts.append((b * 4 + k, 0.4, lambda d, n=n: pluck(midi(n), d, 0.07, 0.35), 0.35))
        # うすい音のじゅうたん
        for n in _chord_notes(root - 12, minor):
            parts.append((b * 4, 4.0, lambda d, n=n: lowpass(tone(midi(n), d, "tri"), 900) * env_ar(d, 0.6, 0.8), 0.06))
        if level >= 2:
            for k in range(4):
                parts.append((b * 4 + k + 0.5, 0.25, _hat, 0.05))
        if level >= 3:
            for k in range(4):
                parts.append((b * 4 + k, 0.5, lambda d, r=root: pluck(midi(r - 24), d, 0.1, 0.3), 0.35))
    if level >= 2:
        for i, n in enumerate(tip * 2):
            if n:
                parts.append((i * 1.0, 0.3, lambda d, n=n: bell(midi(n + 12), d + 0.4, 0.25, 0.4), 0.08))
    return norm(_render_song(bpm, bars, parts), 0.75)


def bgm_round_1():
    return _bgm_round(1)


def bgm_round_2():
    return _bgm_round(2)


def bgm_round_3():
    return _bgm_round(3)


def bgm_chase():
    # 追いかけっこ: テンポの速い曲(168bpm)
    bpm, bars = 168, 8
    prog = [(57, True), (57, True), (53, False), (55, False)] * 2
    lead = [81, 79, 76, 79, 81, 84, 81, 79, 77, 76, 74, 76, 77, 79, 76, 72,
            81, 79, 76, 79, 81, 84, 86, 84, 83, 81, 79, 81, 83, 84, 83, 79]
    parts = []
    for b, (root, minor) in enumerate(prog):
        for k in range(8):
            n = root - 12 if k % 2 == 0 else root
            parts.append((b * 4 + k * 0.5, 0.45, lambda d, n=n: lowpass(tone(midi(n - 12), d, "saw"), 700) * env_ar(d, 0.005, 0.05), 0.4))
        for k in range(4):
            parts.append((b * 4 + k, 0.5, _kick, 0.55))
        parts.append((b * 4 + 1, 0.5, _snare, 0.35))
        parts.append((b * 4 + 3, 0.5, _snare, 0.35))
        for k in range(8):
            parts.append((b * 4 + k * 0.5, 0.25, _hat, 0.1))
    for i, n in enumerate(lead):
        parts.append((i * 1.0, 0.45, lambda d, n=n: tone(midi(n), d, "square") * env_ar(d, 0.005, 0.06), 0.18))
    return norm(_render_song(bpm, bars, parts), 0.8)


# --- 8. 環境音 ---

def amb_school():
    # 遠くの校庭のざわめき(ループ)。ゆっくり大きくなったり小さくなったりする
    d = 12.0
    t = t_of(d)
    base = bandpass(noise(d), 250, 1400)
    swell = 0.6 + 0.25 * np.sin(2 * np.pi * t / d * 3) + 0.15 * np.sin(2 * np.pi * t / d * 7 + 1.3)
    # 遠くでボールがはずむ音
    balls = np.zeros(len(t))
    for s in [2.1, 2.7, 6.4, 9.3, 9.8]:
        b = lowpass(thud(200, 150, 0.08, 0.02), 1200) * 0.25
        balls[int(s * SR): int(s * SR) + len(b)] += b
    loop = base * swell + balls
    # ループのつなぎ目をなめらかに(最後と最初を重ねる)
    fade = int(0.5 * SR)
    loop[:fade] = loop[:fade] * np.linspace(0, 1, fade) + loop[-fade:] * np.linspace(1, 0, fade)
    return norm(loop[:-fade], 0.6)


def clock_tick():
    # 時計のカチ・コチ(2秒でループ)
    one = lambda f: bandpass(noise(0.03), f, f * 2.5) * env_exp(0.03, 0.004)
    return norm(mix(at(one(2500), 0.0, 2.0), at(one(1900) * 0.8, 1.0, 2.0)), 0.6)


def curtain():
    # カーテンが風でゆれる、やわらかい音(ときどき鳴らす)
    d = 1.8
    return norm(lowpass(noise(d), 1100) * env_ar(d, 0.7, 0.9) * (0.7 + 0.3 * np.sin(2 * np.pi * 2.3 * t_of(d))), 0.5)


SOUNDS = {
    "drop_0": drop_0, "drop_1": drop_1, "drop_2": drop_2, "drop_3": drop_3, "drop_4": drop_4,
    "step": step, "run_step": run_step,
    "look": look, "oops": oops, "trudge": trudge, "pickup": pickup,
    "fall": fall, "banana": banana, "lap": lap, "touch": touch, "sit": sit,
    "stamp_dropped": stamp_dropped, "stamp_safe": stamp_safe, "stamp_trust": stamp_trust,
    "chime": chime, "reveal": reveal, "win": win, "lose": lose, "match_end": match_end, "ui_click": ui_click,
    "bgm_lobby": bgm_lobby, "bgm_round_1": bgm_round_1, "bgm_round_2": bgm_round_2, "bgm_round_3": bgm_round_3,
    "bgm_chase": bgm_chase,
    "amb_school": amb_school, "clock_tick": clock_tick, "curtain": curtain,
}


def write(name, x):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        if name.startswith("bgm") or name.startswith("amb"):
            # BGM・環境音は長いので OGG(小さい)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3",
                            os.path.join(OUT, name + ".ogg")], check=True)
        else:
            # 短い効果音は圧縮しない WAV(22050Hz)。鳴らすたびに OGG をほどく計算がいらないので、スマホで軽い
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-ar", "22050", "-c:a", "pcm_s16le",
                            os.path.join(OUT, name + ".wav")], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(SOUNDS.keys())
    for name in names:
        x = SOUNDS[name]()
        write(name, x)
        print("%-14s %5.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main()
