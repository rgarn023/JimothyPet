#!/usr/bin/env python3
"""Regenerate Jimothy nighttime ambience + more realistic raccoon SFX WAVs."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
rng = random.Random(77)
ROOT = Path(__file__).resolve().parents[1]
OUT_DIRS = [ROOT / "audio", ROOT / "godot" / "audio"]


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def write_wav(path: Path, samples: list[float], sr: int = SR) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(clamp(s) * 32767))
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / sr:.2f}s)")


def fade(samples: list[float], attack: float = 0.01, release: float = 0.05) -> list[float]:
    n = len(samples)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    out = samples[:]
    for i in range(min(a, n)):
        out[i] *= i / a
    for i in range(min(r, n)):
        out[n - 1 - i] *= i / r
    return out


def noise(n: int, amp: float = 1.0) -> list[float]:
    return [rng.uniform(-amp, amp) for _ in range(n)]


def lowpass(samples: list[float], alpha: float = 0.1) -> list[float]:
    out = []
    y = 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples: list[float], alpha: float = 0.1) -> list[float]:
    out = []
    prev_x = 0.0
    y = 0.0
    for x in samples:
        y = alpha * (y + x - prev_x)
        prev_x = x
        out.append(y)
    return out


def bandpass(samples: list[float], low_a: float = 0.05, high_a: float = 0.25) -> list[float]:
    return highpass(lowpass(samples, high_a), low_a)


def mix(*layers: list[float], peak: float = 0.92) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    mx = max(1e-6, max(abs(x) for x in out))
    if mx > peak:
        out = [x * peak / mx for x in out]
    return out


def sine(freq: float, t: float, phase: float = 0.0) -> float:
    return math.sin(2 * math.pi * freq * t + phase)


def env_ad(i: int, n: int, attack: float = 0.08, release: float = 0.35) -> float:
    u = i / max(1, n - 1)
    if u < attack:
        return (u / attack) ** 0.7
    return max(0.0, ((1 - u) / max(1e-6, 1 - attack)) ** release)


def formant(t: float, f0: float, f1: float, f2: float, amp: float) -> float:
    """Rough vocal-ish stack for animal chatter."""
    return amp * (
        0.55 * sine(f0, t)
        + 0.28 * sine(f1, t)
        + 0.17 * sine(f2, t)
        + 0.08 * sine(f0 * 2.02, t)
    )


def night_ambience(seconds: float = 14.0) -> list[float]:
    n = int(seconds * SR)
    # Soft night wind (layered pink-ish beds)
    wind_raw = noise(n, 0.6)
    wind = [w * 0.16 for w in lowpass(wind_raw, 0.01)]
    wind2 = [w * 0.08 for w in lowpass(noise(n, 0.5), 0.006)]
    for i in range(n):
        t = i / SR
        gust = 0.7 + 0.3 * math.sin(2 * math.pi * t / 9.0 + 0.4)
        gust2 = 0.85 + 0.15 * math.sin(2 * math.pi * t / 3.7)
        wind[i] = (wind[i] + wind2[i]) * gust * gust2

    # Distant low hush / air
    hush = []
    for i in range(n):
        t = i / SR
        v = (
            0.028 * sine(72, t)
            + 0.018 * sine(104, t, 0.7)
            + 0.012 * sine(148, t, 1.3)
            + 0.008 * sine(210, t, 0.2)
        )
        v *= 0.55 + 0.45 * math.sin(2 * math.pi * t / seconds)
        hush.append(v)
    hush = lowpass(hush, 0.035)

    # Cricket chorus: overlapping short trills at staggered depths
    crickets = [0.0] * n
    t = 0.15
    while t < seconds - 0.2:
        trill_len = rng.uniform(0.1, 0.34)
        f0 = rng.uniform(3800, 6200)
        rate = rng.uniform(40, 78)
        amp = rng.uniform(0.016, 0.034)
        base = int(t * SR)
        cn = int(trill_len * SR)
        for j in range(cn):
            if base + j >= n:
                break
            tt = j / SR
            pulse = max(0.0, 0.5 + 0.5 * math.sin(2 * math.pi * rate * tt)) ** 2.2
            env = math.sin(math.pi * j / max(1, cn - 1))
            f = f0 * (1.0 + 0.03 * math.sin(2 * math.pi * 22 * tt))
            # Thin harmonic for insect bite
            crickets[base + j] += (sine(f, tt) + 0.25 * sine(f * 1.01, tt)) * amp * env * pulse
        t += rng.uniform(0.22, 1.1)

    # Occasional leaf / twig ticks
    ticks = [0.0] * n
    for _ in range(22):
        start = int(rng.uniform(0.2, seconds - 0.08) * SR)
        ln = int(rng.uniform(0.006, 0.022) * SR)
        burst = highpass(noise(ln, 0.55), 0.5)
        for j, v in enumerate(burst):
            if start + j < n:
                ticks[start + j] += v * (1 - j / ln) ** 0.7 * 0.07

    # Soft distant owls buried in the bed
    owls = [0.0] * n
    for start in (2.8, 7.4, 11.2):
        hn = int(0.85 * SR)
        b = int(start * SR)
        for j in range(hn):
            if b + j >= n:
                break
            tt = j / SR
            env = math.sin(math.pi * j / max(1, hn - 1)) ** 1.5
            f = 285 + 40 * math.sin(2 * math.pi * 1.8 * tt)
            owls[b + j] += (0.72 * sine(f, tt) + 0.28 * sine(f * 1.98, tt)) * 0.022 * env

    out = mix(wind, hush, crickets, ticks, owls, peak=0.9)
    xf = int(0.4 * SR)
    for i in range(xf):
        k = i / xf
        out[i] = out[i] * k + out[n - xf + i] * (1 - k)
    return out[:-xf]


def chitter() -> list[float]:
    """Raccoon chatter — breathy, nasal, uneven chirps."""
    parts: list[float] = []
    bursts = rng.randint(7, 10)
    for k in range(bursts):
        dur = rng.uniform(0.028, 0.07)
        n = int(dur * SR)
        f0 = rng.uniform(720, 1250) + k * 28
        chunk = []
        for i in range(n):
            t = i / SR
            u = i / max(1, n - 1)
            env = math.sin(math.pi * u) ** 0.7
            # Nasal formants + aspiration noise
            v = formant(t, f0, f0 * 1.55, f0 * 2.35, 0.38)
            breath = rng.uniform(-1, 1) * 0.18 * env
            breath = bandpass([breath], 0.2, 0.55)[0]
            fbend = f0 * (1.0 + 0.28 * math.sin(math.pi * u) * (1 if k % 2 == 0 else -0.6))
            v = 0.55 * v + 0.3 * sine(fbend, t) * 0.45 + breath
            chunk.append(v * env)
        chunk = bandpass(chunk, 0.07, 0.48)
        parts.extend(fade(chunk, 0.0015, 0.012))
        parts.extend([0.0] * int(rng.uniform(0.012, 0.045) * SR))
    return fade(parts, 0.003, 0.05)


def chirp() -> list[float]:
    """Happy short squeak — two rising, slightly wet notes."""
    def note(f0: float, dur: float, amp: float) -> list[float]:
        n = int(dur * SR)
        out = []
        for i in range(n):
            t = i / SR
            u = i / max(1, n - 1)
            f = f0 * (1.0 + 0.28 * u)
            env = math.sin(math.pi * u) ** 0.7
            v = formant(t, f, f * 1.7, f * 2.45, amp)
            v += rng.uniform(-1, 1) * 0.09 * env
            out.append(v * env)
        return bandpass(out, 0.06, 0.42)

    a = note(610, 0.095, 0.4)
    gap = [0.0] * int(0.035 * SR)
    b = note(980, 0.13, 0.36)
    return fade(a + gap + b, 0.003, 0.055)


def grumble() -> list[float]:
    """Low throaty raccoon protest — rough, pulsed."""
    n = int(0.62 * SR)
    out = []
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        env = math.sin(math.pi * u) ** 1.05
        f = 105 + 55 * math.sin(2 * math.pi * 4.8 * t) + 18 * math.sin(2 * math.pi * 1.7 * t)
        v = (
            0.5 * sine(f, t)
            + 0.28 * sine(f * 1.48, t)
            + 0.14 * sine(f * 2.05, t)
        )
        # Rough glottal noise
        v += rng.uniform(-1, 1) * 0.28
        out.append(v * env * 0.58)
    out = lowpass(out, 0.1)
    for i in range(n):
        t = i / SR
        out[i] *= 0.7 + 0.3 * abs(math.sin(2 * math.pi * 12 * t))
    return fade(out, 0.012, 0.09)


def rustle() -> list[float]:
    """Dry leaf / underbrush rustle with twig snaps."""
    n = int(0.85 * SR)
    layers = []
    for alpha, amp in ((0.5, 0.6), (0.32, 0.42), (0.16, 0.3), (0.1, 0.18)):
        raw = highpass(noise(n, amp), alpha)
        layer = []
        for i, x in enumerate(raw):
            env = (math.sin(math.pi * i / max(1, n - 1)) ** 0.55) * (
                0.5 + 0.5 * abs(math.sin(i * 0.19 + alpha * 12))
            )
            layer.append(x * env)
        layers.append(layer)
    snaps = [0.0] * n
    for _ in range(5):
        s = int(rng.uniform(0.06, 0.7) * SR)
        ln = int(rng.uniform(0.005, 0.016) * SR)
        burst = highpass(noise(ln, 1.0), 0.55)
        for j, v in enumerate(burst):
            if s + j < n:
                snaps[s + j] += v * (1 - j / ln) ** 0.6 * 0.4
    return fade(mix(*layers, snaps, peak=0.86), 0.006, 0.12)


def crunch() -> list[float]:
    """Chewing: crisp crack + wet mouth body."""
    parts: list[float] = []
    for bite in range(6):
        cn = int(rng.uniform(0.014, 0.03) * SR)
        crack = highpass(noise(cn, 1.0), 0.6)
        crack = [c * (1 - i / cn) ** 0.45 * 0.75 for i, c in enumerate(crack)]
        wn = int(rng.uniform(0.045, 0.085) * SR)
        wet = bandpass(noise(wn, 0.75), 0.12, 0.38)
        for i in range(wn):
            t = i / SR
            wet[i] *= math.sin(math.pi * i / max(1, wn - 1)) * (
                0.45 + 0.55 * math.sin(2 * math.pi * 26 * t)
            )
            wet[i] += 0.14 * sine(160 + bite * 18, t) * math.sin(math.pi * i / max(1, wn - 1))
        parts.extend(fade(crack, 0.001, 0.008))
        parts.extend(fade(wet, 0.004, 0.018))
        parts.extend([0.0] * int(rng.uniform(0.03, 0.055) * SR))
    return fade(parts, 0.002, 0.045)


def chew() -> list[float]:
    """Longer munching loop for the eat animation (~2.6s)."""
    parts: list[float] = []
    for bite in range(14):
        cn = int(rng.uniform(0.012, 0.028) * SR)
        crack = highpass(noise(cn, 1.0), 0.58)
        crack = [c * (1 - i / cn) ** 0.5 * 0.7 for i, c in enumerate(crack)]
        wn = int(rng.uniform(0.05, 0.1) * SR)
        wet = bandpass(noise(wn, 0.8), 0.1, 0.4)
        for i in range(wn):
            t = i / SR
            env = math.sin(math.pi * i / max(1, wn - 1))
            wet[i] *= env * (0.4 + 0.6 * math.sin(2 * math.pi * 22 * t))
            wet[i] += 0.12 * sine(150 + (bite % 4) * 20, t) * env
        parts.extend(fade(crack, 0.001, 0.007))
        parts.extend(fade(wet, 0.003, 0.02))
        parts.extend([0.0] * int(rng.uniform(0.035, 0.07) * SR))
    return fade(parts, 0.004, 0.08)


def raccoon_cry(dur: float = 5.0) -> list[float]:
    """Whiny raccoon crying / fussing — hard-capped to exactly `dur` seconds."""
    n = int(dur * SR)
    out = [0.0] * n
    t = 0.0
    while t < dur - 0.2:
        note_dur = min(rng.uniform(0.18, 0.42), dur - t - 0.05)
        if note_dur <= 0.05:
            break
        f0 = rng.uniform(420, 780)
        wobble = rng.uniform(18, 55)
        amp = rng.uniform(0.16, 0.28)
        start = int(t * SR)
        nn = int(note_dur * SR)
        for i in range(nn):
            if start + i >= n:
                break
            u = i / max(1, nn - 1)
            env = (math.sin(math.pi * u) ** 1.1) * (0.7 + 0.3 * (1 - u))
            tt = i / SR
            f = f0 * (1.0 - 0.18 * u) + wobble * math.sin(2 * math.pi * 7 * tt)
            v = (
                0.55 * sine(f, tt)
                + 0.28 * sine(f * 1.98, tt)
                + 0.12 * sine(f * 3.05, tt)
            )
            # Nasal rasp
            v += rng.uniform(-1, 1) * 0.06 * env
            out[start + i] += v * env * amp
        t += note_dur + rng.uniform(0.04, 0.14)
    # Soft sob bed under the cries
    bed = bandpass(noise(n, 0.2), 0.05, 0.2)
    for i in range(n):
        u = i / max(1, n - 1)
        env = math.sin(math.pi * u) ** 0.7
        out[i] = out[i] * 0.92 + bed[i] * 0.12 * env
    # Hard fade-out in the last 0.2s so it never rings past 5s.
    return fade(out[:n], 0.02, 0.2)


def discipline() -> list[float]:
    """Firm scold: short stern chitter burst + soft stamp."""
    parts: list[float] = []
    # Stern descending chirps
    for note_i, (f0, dur, amp) in enumerate(
        [(620, 0.09, 0.28), (480, 0.11, 0.32), (360, 0.14, 0.26)]
    ):
        nn = int(dur * SR)
        note = []
        for i in range(nn):
            t = i / SR
            u = i / max(1, nn - 1)
            env = (math.sin(math.pi * u) ** 0.85) * (1.0 - 0.25 * u)
            f = f0 * (1.0 - 0.12 * u)
            v = 0.65 * sine(f, t) + 0.22 * sine(f * 2.05, t) + 0.1 * sine(f * 3.1, t)
            v += rng.uniform(-1, 1) * 0.05 * env
            note.append(v * env * amp)
        parts.extend(fade(note, 0.004, 0.02))
        parts.extend([0.0] * int(0.035 * SR))
    # Soft paw stamp
    sn = int(0.08 * SR)
    stamp = lowpass(noise(sn, 0.7), 0.12)
    for i in range(sn):
        stamp[i] *= (1 - i / sn) ** 0.5 * 0.35
    parts.extend(fade(stamp, 0.001, 0.03))
    # Closing firm chuff
    cn = int(0.12 * SR)
    chuff = []
    for i in range(cn):
        t = i / SR
        u = i / max(1, cn - 1)
        env = math.sin(math.pi * u) ** 1.2
        v = 0.4 * sine(220, t) + 0.2 * sine(330, t) + rng.uniform(-1, 1) * 0.08
        chuff.append(v * env * 0.22)
    parts.extend(fade(chuff, 0.005, 0.04))
    return fade(parts, 0.008, 0.06)


def ascend() -> list[float]:
    n = int(3.0 * SR)
    out = []
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        f1 = 200 * (1 + 2.0 * u)
        f2 = 300 * (1 + 1.9 * u)
        f3 = 450 * (1 + 1.7 * u)
        v = (
            0.14 * sine(f1, t)
            + 0.1 * sine(f2, t)
            + 0.07 * sine(f3, t)
        )
        shimmer = rng.uniform(-1, 1) * 0.035 * u
        env = (u ** 0.4) * (1 - u) ** 0.32 * 2.1
        out.append((v + shimmer) * env)
    whoosh = lowpass(noise(int(0.7 * SR), 0.55), 0.04)
    for i, w in enumerate(whoosh):
        env = math.sin(math.pi * i / max(1, len(whoosh) - 1))
        out[i] += w * env * 0.22
    return fade(out, 0.03, 0.28)


def soft_hoot() -> list[float]:
    """Softer two-note owl hoot."""
    def hoot_note(f0: float, dur: float, amp: float) -> list[float]:
        n = int(dur * SR)
        out = []
        for i in range(n):
            t = i / SR
            u = i / max(1, n - 1)
            env = math.sin(math.pi * u) ** 1.35
            f = f0 * (1.0 - 0.06 * u)
            v = 0.7 * sine(f, t) + 0.25 * sine(f * 2.01, t) + 0.08 * sine(f * 3.1, t)
            # Soft breath noise
            v += rng.uniform(-1, 1) * 0.04 * env
            out.append(v * env * amp)
        return lowpass(out, 0.2)

    a = hoot_note(275, 0.42, 0.22)
    gap = [0.0] * int(0.1 * SR)
    b = hoot_note(245, 0.36, 0.18)
    return fade(a + gap + b, 0.02, 0.1)


def sick() -> list[float]:
    """Weak congested whimper — short illness cue."""
    parts: list[float] = []
    for f0, dur, amp in ((340, 0.16, 0.22), (300, 0.2, 0.2), (280, 0.18, 0.16)):
        nn = int(dur * SR)
        note = []
        for i in range(nn):
            t = i / SR
            u = i / max(1, nn - 1)
            env = (math.sin(math.pi * u) ** 1.2) * (0.75 + 0.25 * (1 - u))
            f = f0 * (1.0 - 0.1 * u)
            v = 0.55 * sine(f, t) + 0.22 * sine(f * 1.95, t)
            v += rng.uniform(-1, 1) * 0.08 * env
            note.append(v * env * amp)
        parts.extend(fade(bandpass(note, 0.05, 0.35), 0.006, 0.03))
        parts.extend([0.0] * int(0.05 * SR))
    # Soft cough rasp
    cn = int(0.09 * SR)
    cough = highpass(noise(cn, 0.55), 0.35)
    for i in range(cn):
        cough[i] *= (1 - i / cn) ** 0.6 * 0.28
    parts.extend(fade(cough, 0.002, 0.02))
    return fade(parts, 0.01, 0.06)


def heal() -> list[float]:
    """Gentle recovery chime — soft ascending tones."""
    parts: list[float] = []
    for f0, dur, amp in ((420, 0.14, 0.2), (560, 0.16, 0.22), (740, 0.22, 0.18)):
        nn = int(dur * SR)
        note = []
        for i in range(nn):
            t = i / SR
            u = i / max(1, nn - 1)
            env = (math.sin(math.pi * u) ** 0.9) * (1.0 - 0.2 * u)
            f = f0 * (1.0 + 0.08 * u)
            v = 0.55 * sine(f, t) + 0.25 * sine(f * 2.02, t) + 0.1 * sine(f * 3.05, t)
            note.append(v * env * amp)
        parts.extend(fade(lowpass(note, 0.35), 0.008, 0.04))
        parts.extend([0.0] * int(0.028 * SR))
    # Soft warm bed
    bn = int(0.35 * SR)
    bed = lowpass(noise(bn, 0.25), 0.08)
    for i in range(bn):
        u = i / max(1, bn - 1)
        bed[i] *= math.sin(math.pi * u) * 0.18
    parts.extend(fade(bed, 0.02, 0.08))
    return fade(parts, 0.012, 0.08)


def sleep_sfx() -> list[float]:
    """Nest settle: soft leaf rustle + sleepy breath."""
    n = int(1.15 * SR)
    rust = highpass(noise(n, 0.45), 0.28)
    out = []
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        env = (math.sin(math.pi * u) ** 0.65) * (0.55 + 0.45 * abs(math.sin(i * 0.17)))
        v = rust[i] * env * 0.55
        # Slow breath tone
        breath = 0.12 * sine(95 + 12 * math.sin(2 * math.pi * 0.7 * t), t)
        breath *= math.sin(math.pi * u) ** 1.4
        out.append(v + breath)
    # Twig settle taps
    for _ in range(3):
        s = int(rng.uniform(0.12, 0.75) * SR)
        ln = int(rng.uniform(0.008, 0.02) * SR)
        burst = highpass(noise(ln, 0.8), 0.45)
        for j, b in enumerate(burst):
            if s + j < n:
                out[s + j] += b * (1 - j / ln) ** 0.7 * 0.22
    return fade(lowpass(out, 0.22), 0.02, 0.14)


def lights() -> list[float]:
    """Soft lamp-switch click + tiny hum fade."""
    n = int(0.28 * SR)
    out = [0.0] * n
    # Click transient
    cn = int(0.012 * SR)
    click = highpass(noise(cn, 1.0), 0.55)
    for i, c in enumerate(click):
        out[i] += c * (1 - i / cn) ** 0.4 * 0.55
    # Soft electrical settle
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        env = math.exp(-u * 6.5) * (1 - u) ** 0.4
        out[i] += 0.1 * sine(180, t) * env
        out[i] += rng.uniform(-1, 1) * 0.03 * env
    return fade(out, 0.001, 0.05)


def main() -> None:
    files = {
        "night_ambience.wav": night_ambience(12.0),
        "chitter.wav": chitter(),
        "chirp.wav": chirp(),
        "grumble.wav": grumble(),
        "rustle.wav": rustle(),
        "crunch.wav": crunch(),
        "chew.wav": chew(),
        "cry.wav": raccoon_cry(5.0),
        "discipline.wav": discipline(),
        "ascend.wav": ascend(),
        "hoot.wav": soft_hoot(),
        "sick.wav": sick(),
        "heal.wav": heal(),
        "sleep.wav": sleep_sfx(),
        "lights.wav": lights(),
    }
    for out_dir in OUT_DIRS:
        for name, samples in files.items():
            write_wav(out_dir / name, samples)
    (ROOT / "audio" / "README.md").write_text(
        "# Jimothy audio\n\nProcedurally generated nighttime ambience and raccoon SFX (original).\n"
        "Regenerate with `python3 scripts/generate_audio.py`.\n"
    )
    print("done")


if __name__ == "__main__":
    main()
