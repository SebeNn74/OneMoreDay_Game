"""Original chiptune music and sound effects for One More Day.

Everything is synthesized here (square, triangle, sine and noise voices with envelopes), so the
audio is an original creation: no samples, no third-party assets.
Usage: python tools/generate_audio.py   ->   assets/audio/bgm/*.wav and assets/audio/sfx/*.wav
Deterministic: each track uses its own fixed seed, so running it again gives the same files.
"""
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BGM = os.path.join(ROOT, "assets", "audio", "bgm")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]


def freq(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def envelope(n, attack=0.01, decay=0.08, sustain=0.6, release=0.05):
    env = np.full(n, sustain, dtype=np.float64)
    a, d, r = int(attack * SR), int(decay * SR), int(release * SR)
    a = max(1, min(a, n))
    env[:a] = np.linspace(0.0, 1.0, a)
    d_end = min(n, a + d)
    if d_end > a:
        env[a:d_end] = np.linspace(1.0, sustain, d_end - a)
    r = min(r, n)
    if r > 0:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def osc(kind, f, seconds, duty=0.5, sweep_to=None):
    n = max(1, int(seconds * SR))
    t = np.arange(n) / SR
    if sweep_to is not None:
        f_t = np.linspace(f, sweep_to, n)
        phase = np.cumsum(f_t) / SR
    else:
        phase = f * t
    frac = phase % 1.0
    if kind == "square":
        return np.where(frac < duty, 1.0, -1.0)
    if kind == "triangle":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    if kind == "sine":
        return np.sin(2.0 * np.pi * phase)
    if kind == "noise":
        return np.random.default_rng(int(f * 1000) % 2**32).uniform(-1.0, 1.0, n)
    raise ValueError(kind)


def add(buffer, start, sound, gain):
    i = int(start * SR)
    end = min(len(buffer), i + len(sound))
    if i < len(buffer):
        buffer[i:end] += sound[: end - i] * gain


def note(kind, midi, seconds, duty=0.5, **env):
    return osc(kind, freq(midi), seconds, duty) * envelope(int(seconds * SR) or 1, **env)


def kick(seconds=0.18):
    return osc("sine", 120.0, seconds, sweep_to=40.0) * envelope(int(seconds * SR), 0.002, 0.12, 0.0, 0.02)


def snare(seconds=0.14):
    return osc("noise", 3.3, seconds) * envelope(int(seconds * SR), 0.001, 0.1, 0.0, 0.02)


def hat(seconds=0.04):
    noise = osc("noise", 7.7, seconds)
    noise = np.diff(noise, prepend=0.0)  # Brighter: high-pass by differencing.
    return noise * envelope(int(seconds * SR), 0.001, 0.03, 0.0, 0.005)


def chord_notes(root, quality):
    third = 3 if quality == "m" else 4
    return [root, root + third, root + 7]


def compose(name, key, scale, bpm, progression, bars, seed, lead="square", duty=0.25,
            drums="full", lead_gain=0.22, swing=0.0, density=0.6):
    """Loop of `bars` bars over a repeating chord `progression` [(degree, quality)]."""
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = np.zeros(int(total * SR) + SR)
    patterns = [[1, 0, 1, 0, 1, 1, 1, 0], [1, 1, 0, 1, 1, 0, 1, 0], [1, 0, 0, 1, 1, 0, 1, 1], [1, 0, 1, 1, 0, 1, 1, 0]]
    motif = None
    for bar in range(bars):
        degree, quality = progression[bar % len(progression)]
        root = key + scale[degree % 7] + 12 * (degree // 7)
        tones = chord_notes(root, quality)
        t0 = bar * 4 * beat
        # Bass: root and fifth, eighth notes.
        for k in range(8):
            midi = (tones[0] if k % 4 != 2 else tones[2]) - 24
            add(out, t0 + k * beat / 2, note("triangle", midi, beat / 2 * 0.9, attack=0.005, decay=0.05, sustain=0.7), 0.30)
        # Pad: soft chord on the first beat.
        for midi in tones:
            add(out, t0, note("triangle", midi - 12, 4 * beat * 0.95, attack=0.08, decay=0.3, sustain=0.35, release=0.3), 0.06)
        # Lead: a motif reused every 4 bars with variations, built on chord and scale tones.
        if bar % 4 == 0 or motif is None:
            pattern = patterns[rng.integers(len(patterns))]
            motif = []
            for step in range(8):
                if pattern[step] and rng.random() < density + 0.3:
                    motif.append(int(rng.integers(0, 5)))
                else:
                    motif.append(None)
        for step, idx in enumerate(motif):
            if idx is None:
                continue
            octave_up = 12 if idx >= 3 else 0
            pitch = tones[idx % 3] + octave_up + 12
            if rng.random() < 0.2:  # Passing tone from the scale.
                pitch = key + 12 + scale[int(rng.integers(0, 7))] + 12 * (1 if idx >= 3 else 0)
            offset = swing * beat / 2 if step % 2 else 0.0
            add(out, t0 + step * beat / 2 + offset, note(lead, pitch, beat / 2 * 0.85, duty, attack=0.005, decay=0.06, sustain=0.5, release=0.04), lead_gain)
        # Drums.
        for k in range(8):
            t = t0 + k * beat / 2
            if drums in ("full", "light"):
                add(out, t, hat(), 0.06 if drums == "full" else 0.04)
            if drums == "full":
                if k in (0, 4):
                    add(out, t, kick(), 0.5)
                if k in (2, 6):
                    add(out, t, snare(), 0.18)
            elif drums == "light" and k == 0:
                add(out, t, kick(), 0.3)
    out = out[: int(total * SR)]
    # Seamless loop: fade the very edges a few milliseconds.
    edge = int(0.004 * SR)
    out[:edge] *= np.linspace(0, 1, edge)
    out[-edge:] *= np.linspace(1, 0, edge)
    write(os.path.join(BGM, name + ".wav"), out, 0.7)


def jingle(name, notes_list, step, kind="square", gain=0.3):
    total = step * len(notes_list) + 1.2
    out = np.zeros(int(total * SR))
    for i, chord in enumerate(notes_list):
        last = i == len(notes_list) - 1
        for midi in chord:
            add(out, i * step, note(kind, midi, step * (4 if last else 1.2), 0.25, attack=0.005, decay=0.1, sustain=0.5, release=0.4 if last else 0.05), gain)
    write(os.path.join(BGM, name + ".wav"), out, 0.7)


def write(path, data, peak):
    data = data / max(1e-9, np.max(np.abs(data))) * peak
    pcm = (data * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def sfx(name, data, peak=0.8):
    write(os.path.join(SFX, name + ".wav"), data, peak)


def make_sfx():
    s = lambda kind, f, sec, **kw: osc(kind, f, sec, **{k: v for k, v in kw.items() if k in ("duty", "sweep_to")})
    env = lambda sec, **kw: envelope(int(sec * SR), **kw)
    sfx("hit", s("square", 220, 0.18, duty=0.5, sweep_to=70) * env(0.18, attack=0.002, decay=0.15, sustain=0.0, release=0.02) * 0.7
        + osc("noise", 1.1, 0.18) * env(0.18, attack=0.001, decay=0.08, sustain=0.0, release=0.01) * 0.5)
    crash = osc("noise", 2.2, 0.45) * env(0.45, attack=0.001, decay=0.35, sustain=0.0, release=0.05)
    sfx("crash", crash + s("sine", 90, 0.45, sweep_to=35) * env(0.45, attack=0.002, decay=0.3, sustain=0.0, release=0.05) * 0.8)
    honk = (s("square", 349, 0.16, duty=0.5) + s("square", 440, 0.16, duty=0.5)) * env(0.16, attack=0.01, decay=0.02, sustain=0.8, release=0.02)
    gap = np.zeros(int(0.06 * SR))
    sfx("honk", np.concatenate([honk, gap, honk]) * 0.6)
    up = [note("square", m, 0.06, 0.25, attack=0.002, decay=0.03, sustain=0.6, release=0.01) for m in (72, 76, 79, 84)]
    sfx("pickup", np.concatenate(up))
    sfx("coin", np.concatenate([note("square", 83, 0.06, 0.5, attack=0.002, decay=0.03, sustain=0.6, release=0.01),
                                note("square", 88, 0.18, 0.5, attack=0.002, decay=0.1, sustain=0.3, release=0.05)]))
    sfx("ui_move", note("square", 79, 0.04, 0.5, attack=0.001, decay=0.02, sustain=0.3, release=0.01), 0.4)
    sfx("ui_confirm", np.concatenate([note("square", 76, 0.05, 0.25, attack=0.001, decay=0.02, sustain=0.6, release=0.01),
                                      note("square", 83, 0.1, 0.25, attack=0.001, decay=0.05, sustain=0.4, release=0.03)]), 0.6)
    sfx("ui_open", s("triangle", 300, 0.12, sweep_to=600) * env(0.12, attack=0.005, decay=0.08, sustain=0.3, release=0.02), 0.6)
    ping = note("sine", 88, 0.09, attack=0.002, decay=0.05, sustain=0.4, release=0.02)
    sfx("notify", np.concatenate([ping, np.zeros(int(0.05 * SR)), note("sine", 93, 0.16, attack=0.002, decay=0.1, sustain=0.3, release=0.05)]), 0.6)
    sfx("fall", s("square", 500, 0.4, duty=0.25, sweep_to=120) * env(0.4, attack=0.002, decay=0.3, sustain=0.2, release=0.08))
    sfx("jolt", s("sine", 70, 0.2, sweep_to=45) * env(0.2, attack=0.002, decay=0.15, sustain=0.0, release=0.03)
        + osc("noise", 4.4, 0.2) * env(0.2, attack=0.001, decay=0.05, sustain=0.0, release=0.01) * 0.3)
    sfx("countdown", note("square", 72, 0.12, 0.5, attack=0.002, decay=0.05, sustain=0.5, release=0.03), 0.5)
    sfx("go", note("square", 84, 0.3, 0.5, attack=0.002, decay=0.1, sustain=0.5, release=0.1), 0.5)
    sfx("tick", hat(0.05) * 2.0, 0.5)


def main():
    os.makedirs(BGM, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)
    # Key: midi of the tonic (60 = C4). Progressions as (scale degree, quality).
    compose("home", 60, MAJOR, 92, [(0, ""), (5, "m"), (3, ""), (4, "")], 16, 11, lead="triangle", drums="light", lead_gain=0.28, density=0.45)
    compose("commute", 55, MAJOR, 118, [(0, ""), (4, ""), (5, "m"), (3, "")], 16, 23, swing=0.15)
    compose("work", 62, MINOR, 124, [(0, "m"), (5, ""), (2, ""), (6, "")], 16, 37, duty=0.125)
    compose("boss", 57, MINOR, 150, [(0, "m"), (3, "m"), (4, ""), (0, "m")], 16, 41, duty=0.5, density=0.8)
    compose("return", 53, MAJOR, 96, [(0, ""), (2, "m"), (3, ""), (4, "")], 16, 53, lead="triangle", drums="light", lead_gain=0.26, density=0.5)
    compose("minigame", 64, MAJOR, 140, [(0, ""), (3, ""), (4, ""), (0, "")], 8, 67, density=0.85)
    jingle("victory", [[72], [76], [79], [72, 76, 79, 84]], 0.14)
    jingle("defeat", [[67], [63], [60], [55, 58, 62]], 0.22, kind="triangle", gain=0.35)
    make_sfx()
    print("ok:", sorted(os.listdir(BGM)), sorted(os.listdir(SFX)))


if __name__ == "__main__":
    main()
