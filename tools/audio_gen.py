#!/usr/bin/env python3
"""Generator aset audio Reablox (W1-D) — SFX + musik loop.

Mensintesis seluruh aset audio game ke assets/audio/ memakai STDLIB Python
saja (wave, struct, math, random). Deterministik: seed tetap, jadi hasil
byte-identik antar mesin.

Format:
  - SFX  : 44100 Hz, 16-bit, mono, durasi 0.08-0.6 dtk.
  - Musik: 22050 Hz, 16-bit, mono, loop 12-16 dtk. (Deviasi disengaja dari
           44.1 kHz demi total aset < 2 MB — lihat docs/rea/core.md §3.)

Jalankan dari root proyek: python3 tools/audio_gen.py
"""

import math
import os
import random
import struct
import sys
import wave

SR_SFX = 44100
SR_MUSIC = 22050
SEED = 20240901
PEAK_MUSIC = 0.6
MAX_TOTAL_BYTES = 2 * 1024 * 1024

TWO_PI = 2.0 * math.pi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


# ---------------------------------------------------------------------------
# Primitif sintesis
# ---------------------------------------------------------------------------

def sine(freq, t):
    return math.sin(TWO_PI * freq * t)


def square(freq, t, duty=0.5):
    phase = (freq * t) % 1.0
    return 1.0 if phase < duty else -1.0


def midi_hz(m):
    """Nomor MIDI -> frekuensi (A4 = 440 Hz)."""
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


class LowPass:
    """Filter one-pole sederhana untuk melembutkan noise."""

    def __init__(self, cutoff_hz, sample_rate):
        self.set_cutoff(cutoff_hz, sample_rate)
        self.y = 0.0

    def set_cutoff(self, cutoff_hz, sample_rate):
        self.a = 1.0 - math.exp(-TWO_PI * cutoff_hz / sample_rate)

    def step(self, x):
        self.y += self.a * (x - self.y)
        return self.y


def ramp_attack(t, seconds):
    """Ramp linear singkat di awal nada supaya tidak ada klik."""
    if seconds <= 0.0:
        return 1.0
    return min(1.0, t / seconds)


def finalize(samples, peak):
    """Normalisasi ke peak target + soft-clip tanh (volume aman, tanpa distorsi keras)."""
    loudest = 1e-9
    for s in samples:
        a = abs(s)
        if a > loudest:
            loudest = a
    gain = (peak * 1.3) / loudest
    clipped = [math.tanh(s * gain) for s in samples]
    loudest2 = 1e-9
    for s in clipped:
        a = abs(s)
        if a > loudest2:
            loudest2 = a
    gain2 = peak / loudest2
    return [s * gain2 for s in clipped]


def write_wav(path, samples, sample_rate):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767.0)
        data += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(bytes(data))


def arp_tone(dur, sr, freqs, spacing, k, vol=1.0, square_mix=0.2, attack=0.003):
    """Deretan nada berurutan (arpeggio SFX) dengan decay eksponensial per nada."""
    n = int(dur * sr)
    out = [0.0] * n
    for idx, f in enumerate(freqs):
        i0 = int(idx * spacing * sr)
        for i in range(i0, n):
            t = (i - i0) / sr
            v = sine(f, t) + square_mix * square(f, t, 0.4)
            out[i] += vol * v * ramp_attack(t, attack) * math.exp(-k * t)
    return out


# ---------------------------------------------------------------------------
# SFX (44100 Hz) — karakter ala Roblox, lihat docs/rea/core.md §1
# ---------------------------------------------------------------------------

def sfx_jump():
    """Lompat: sapuan nada naik ala "hup" (action_jump)."""
    dur = 0.22
    n = int(dur * SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 220.0 * (560.0 / 220.0) ** (t / dur)
        v = 0.62 * sine(f, t) + 0.22 * square(f, t, 0.35)
        out.append(v * ramp_attack(t, 0.003) * math.exp(-9.0 * t))
    return out


def sfx_land():
    """Mendarat: dentum rendah + desis singkat (action_jump_land)."""
    dur = 0.18
    n = int(dur * SR_SFX)
    lp = LowPass(600.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 110.0 - 40.0 * (t / dur)
        v = 0.85 * sine(f, t) * math.exp(-16.0 * t)
        v += 0.5 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-42.0 * t)
        out.append(v * ramp_attack(t, 0.001))
    return out


def sfx_footstep_grass():
    """Langkah di rumput: dua letusan noise lembut (tumit-jari)."""
    dur = 0.13
    n = int(dur * SR_SFX)
    lp = LowPass(900.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        v = lp.step(random.uniform(-1.0, 1.0))
        env = math.exp(-30.0 * t)
        if t >= 0.06:
            env += 0.45 * math.exp(-35.0 * (t - 0.06))
        out.append(v * env * ramp_attack(t, 0.002))
    return out


def sfx_footstep_stone():
    """Langkah di batu: noise tajam + klik frekuensi tinggi."""
    dur = 0.11
    n = int(dur * SR_SFX)
    lp = LowPass(3000.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        v = lp.step(random.uniform(-1.0, 1.0)) * math.exp(-45.0 * t)
        v += 0.3 * sine(1900.0, t) * math.exp(-90.0 * t)
        if t >= 0.05:
            v += 0.4 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-55.0 * (t - 0.05))
        out.append(v * ramp_attack(t, 0.001))
    return out


def sfx_coin():
    """Koin: chime dua nada naik B5 -> E6 (klasik arcade/obby)."""
    return arp_tone(0.32, SR_SFX, [987.77, 1318.51], 0.08, 12.0, 1.0, 0.25)


def sfx_sword_swing():
    """Ayunan pedang: whoosh noise dengan filter menyapu turun (swordslash)."""
    dur = 0.28
    n = int(dur * SR_SFX)
    lp = LowPass(5500.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        lp.set_cutoff(300.0 + 5200.0 * math.exp(-9.0 * t), SR_SFX)
        whoosh = lp.step(random.uniform(-1.0, 1.0))
        if t < 0.1:
            amp = t / 0.1
        else:
            amp = math.exp(-11.0 * (t - 0.1))
        out.append(whoosh * amp * 0.8)
    return out


def sfx_sword_hit():
    """Kena pedang: denting logam (square ter-detune) + benturan noise."""
    dur = 0.22
    n = int(dur * SR_SFX)
    partials = [1180.0, 1567.0, 2344.0]
    detune = [1.0 + random.uniform(-0.008, 0.008) for _ in partials]
    lp = LowPass(4200.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        v = 0.0
        for idx in range(len(partials)):
            f = partials[idx] * detune[idx]
            v += 0.28 * square(f, t, 0.5) + 0.18 * sine(f, t)
        v *= math.exp(-13.0 * t)
        v += 0.55 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-55.0 * t)
        out.append(v * ramp_attack(t, 0.001))
    return out


def sfx_hurt():
    """Terluka: blip square turun cepat."""
    dur = 0.18
    n = int(dur * SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 330.0 * (170.0 / 330.0) ** (t / dur)
        v = 0.4 * square(f, t, 0.45) + 0.5 * sine(f, t)
        out.append(v * ramp_attack(t, 0.002) * math.exp(-12.0 * t))
    return out


def sfx_die():
    """Tewas: sapuan nada turun + getar (nuansa "oof" klasik)."""
    dur = 0.5
    n = int(dur * SR_SFX)
    lp = LowPass(300.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 300.0 * (55.0 / 300.0) ** (t / dur) + 18.0 * math.sin(TWO_PI * 7.0 * t)
        v = 0.8 * sine(f, t) + 0.25 * lp.step(random.uniform(-1.0, 1.0))
        out.append(v * ramp_attack(t, 0.004) * math.exp(-4.5 * t))
    return out


def sfx_respawn():
    """Respawn: arpeggio 4 nada naik (C5-E5-G5-C6)."""
    return arp_tone(0.42, SR_SFX, [523.25, 659.25, 784.0, 1046.5], 0.09, 11.0, 1.0, 0.2)


def sfx_ui_click():
    """Klik UI: keping pendek + tik noise (button)."""
    dur = 0.08
    n = int(dur * SR_SFX)
    lp = LowPass(6000.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        v = 0.9 * sine(1150.0, t) * math.exp(-60.0 * t)
        v += 0.35 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-180.0 * t)
        out.append(v * ramp_attack(t, 0.001))
    return out


def sfx_ui_hover():
    """Hover UI: blip lembut lebih tinggi, lebih pelan dari klik."""
    dur = 0.08
    n = int(dur * SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        v = 0.6 * sine(1650.0, t) + 0.08 * square(1650.0, t, 0.4)
        out.append(v * ramp_attack(t, 0.002) * math.exp(-55.0 * t))
    return out


def sfx_place_block():
    """Taruh blok: gedoran rendah + tik pendek."""
    dur = 0.15
    n = int(dur * SR_SFX)
    lp = LowPass(3000.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 205.0 - 45.0 * (t / dur)
        v = 0.9 * sine(f, t) * math.exp(-22.0 * t)
        v += 0.5 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-130.0 * t)
        out.append(v * ramp_attack(t, 0.002))
    return out


def sfx_remove_block():
    """Hapus blok: blip turun + noise terpotong."""
    dur = 0.12
    n = int(dur * SR_SFX)
    lp = LowPass(2500.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 520.0 * (260.0 / 520.0) ** (t / dur)
        v = 0.5 * square(f, t, 0.45) * math.exp(-20.0 * t)
        v += 0.6 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-35.0 * t)
        out.append(v * ramp_attack(t, 0.001))
    return out


def sfx_checkpoint():
    """Checkpoint: chime sukses 3 nada naik (G5-C6-E6)."""
    return arp_tone(0.5, SR_SFX, [784.0, 1046.5, 1318.5], 0.13, 8.0, 1.0, 0.18)


def sfx_splash():
    """Cipakan air: noise lowpass menyapu + gedoran rendah (impact_water)."""
    dur = 0.4
    n = int(dur * SR_SFX)
    lp = LowPass(700.0, SR_SFX)
    out = []
    for i in range(n):
        t = i / SR_SFX
        lp.set_cutoff(700.0 + 3200.0 * math.exp(-8.0 * t), SR_SFX)
        v = lp.step(random.uniform(-1.0, 1.0))
        v *= ramp_attack(t, 0.015) * math.exp(-7.0 * t)
        v += 0.4 * sine(120.0, t) * math.exp(-15.0 * t)
        out.append(v)
    return out


def sfx_npc_growl():
    """Geraman NPC: harmonik rendah bergelombang + desis gelap."""
    dur = 0.45
    n = int(dur * SR_SFX)
    lp = LowPass(240.0, SR_SFX)
    harmonics = [(1, 0.5), (2, 0.28), (3, 0.15), (4, 0.08)]
    out = []
    for i in range(n):
        t = i / SR_SFX
        f = 82.0 + 10.0 * math.sin(TWO_PI * 5.5 * t)
        v = 0.0
        for mult, amp in harmonics:
            v += amp * sine(f * mult, t)
        v *= ramp_attack(t, 0.03) * math.exp(-4.5 * t)
        v += 0.22 * lp.step(random.uniform(-1.0, 1.0)) * math.exp(-5.0 * t)
        out.append(v)
    return out


SFX_SPECS = [
    ("jump", sfx_jump, 0.80),
    ("land", sfx_land, 0.80),
    ("footstep_grass", sfx_footstep_grass, 0.60),
    ("footstep_stone", sfx_footstep_stone, 0.70),
    ("coin", sfx_coin, 0.80),
    ("sword_swing", sfx_sword_swing, 0.80),
    ("sword_hit", sfx_sword_hit, 0.80),
    ("hurt", sfx_hurt, 0.80),
    ("die", sfx_die, 0.80),
    ("respawn", sfx_respawn, 0.80),
    ("ui_click", sfx_ui_click, 0.80),
    ("ui_hover", sfx_ui_hover, 0.55),
    ("place_block", sfx_place_block, 0.80),
    ("remove_block", sfx_remove_block, 0.80),
    ("checkpoint", sfx_checkpoint, 0.80),
    ("splash", sfx_splash, 0.80),
    ("npc_growl", sfx_npc_growl, 0.75),
]


# ---------------------------------------------------------------------------
# Musik (22050 Hz) — loop mulus via wrap-around ekor nada
# ---------------------------------------------------------------------------

def render_music(total_dur, sr, events):
    """Render event ke buffer dengan indeks modulo panjang loop.

    Ekor nada terakhir terdengar di awal track, sehingga loop tanpa jahitan.
    event = (start, dur, freq_hz, kind, vol, decay_k, attack)
    kind: "sine" (pad) | "pluck" (arpeggio) | "bass".
    """
    total = int(total_dur * sr)
    buf = [0.0] * total
    for start, dur, freq, kind, vol, k, attack in events:
        n = int(dur * sr)
        i0 = int(start * sr)
        for i in range(n):
            t = i / sr
            if kind == "sine":
                v = sine(freq, t)
            elif kind == "bass":
                v = sine(freq, t) + 0.18 * sine(2.0 * freq, t)
            else:
                v = 0.8 * sine(freq, t) + 0.25 * square(freq, t, 0.45)
            env = ramp_attack(t, attack) * math.exp(-k * t)
            buf[(i0 + i) % total] += v * vol * env
    return buf


def music_menu_events():
    """Menu (16 dtk, 120 BPM, 8 bar): Am-F-C-G add9 — "ceria minor".

    Pad lembut + arpeggio 8th-note + bass per bar.
    """
    bar = 2.0
    chords = [
        [57, 60, 64, 71],  # Am add9
        [53, 57, 60, 67],  # F add9
        [55, 60, 62, 64],  # C add9 (voicing rapat)
        [55, 59, 62, 69],  # G add9
    ]
    roots = [45, 41, 36, 43]
    pattern = [0, 1, 2, 3, 2, 1]
    events = []
    for ci in range(4):
        start = ci * 2.0 * bar
        chord = chords[ci]
        for m in chord:
            events.append((start, 4.0, midi_hz(m), "sine", 0.075, 0.22, 0.7))
        steps = int(2.0 * bar / 0.25)
        for s in range(steps):
            m = chord[pattern[s % len(pattern)]] + 12
            events.append((start + s * 0.25, 0.25, midi_hz(m), "pluck", 0.10, 7.0, 0.004))
        for b in range(2):
            events.append((start + b * bar, 1.5, midi_hz(roots[ci]), "bass", 0.16, 3.0, 0.012))
    return events


def music_world_events():
    """Dunia (12 dtk): pad lambat Cmaj7-Am7-Fmaj7 + arpeggio sparse — tenang."""
    chords = [
        [48, 52, 55, 59],  # Cmaj7
        [45, 48, 52, 55],  # Am7
        [41, 45, 48, 52],  # Fmaj7
    ]
    roots = [48, 45, 41]
    pattern = [3, 1, 2, 0]
    events = []
    for ci in range(3):
        start = ci * 4.0
        chord = chords[ci]
        for m in chord:
            events.append((start, 4.0, midi_hz(m), "sine", 0.085, 0.12, 1.2))
        for s in range(4):
            m = chord[pattern[s]] + 12
            events.append((start + s * 1.0, 1.0, midi_hz(m), "pluck", 0.055, 3.5, 0.01))
        events.append((start, 3.6, midi_hz(roots[ci]), "bass", 0.11, 0.5, 0.3))
    return events


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    random.seed(SEED)
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    files = []

    for name, builder, peak in SFX_SPECS:
        path = os.path.join(SFX_DIR, name + ".wav")
        write_wav(path, finalize(builder(), peak), SR_SFX)
        files.append(path)

    menu_path = os.path.join(MUSIC_DIR, "menu.wav")
    write_wav(menu_path, finalize(render_music(16.0, SR_MUSIC, music_menu_events()), PEAK_MUSIC), SR_MUSIC)
    world_path = os.path.join(MUSIC_DIR, "world.wav")
    write_wav(world_path, finalize(render_music(12.0, SR_MUSIC, music_world_events()), PEAK_MUSIC), SR_MUSIC)
    files.append(menu_path)
    files.append(world_path)

    print("")
    total = 0
    for p in files:
        size = os.path.getsize(p)
        total += size
        rate = SR_SFX if "/sfx/" in p else SR_MUSIC
        print("%-52s %8.1f KiB  (%.2f dtk)" % (os.path.relpath(p, ROOT), size / 1024.0, size / 2.0 / rate))
    print("")
    print("Total: %d file, %.2f MiB (batas %.2f MiB)" % (len(files), total / 1048576.0, MAX_TOTAL_BYTES / 1048576.0))
    if total >= MAX_TOTAL_BYTES:
        print("GAGAL: total aset melebihi batas 2 MiB.")
        return 1
    if len(files) != 19:
        print("GAGAL: jumlah file tidak 19 (17 SFX + 2 musik).")
        return 1
    print("OK: semua aset audio berhasil dibuat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
