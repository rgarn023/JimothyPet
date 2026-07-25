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


def night_ambience(seconds: float = 12.0) -> list[float]:
    n = int(seconds * SR)
    # Soft night wind (pink-ish)
    wind_raw = noise(n, 0.55)
    wind = [w * 0.18 for w in lowpass(wind_raw, 0.012)]
    for i in range(n):
        t = i / SR
        gust = 0.75 + 0.25 * math.sin(2 * math.pi * t / 7.5 + 0.4)
        wind[i] *= gust

    # Distant low hum / creek hush
    hush = []
    for i in range(n):
        t = i / SR
        v = (
            0.03 * sine(78, t)
            + 0.02 * sine(112, t, 0.7)
            + 0.015 * sine(156, t, 1.3)
        )
        v *= 0.6 + 0.4 * math.sin(2 * math.pi * t / seconds)
        hush.append(v)
    hush = lowpass(hush, 0.04)

    # Realistic cricket bursts: short trills, not constant tone
    crickets = [0.0] * n
    t = 0.2
    while t < seconds - 0.25:
        trill_len = rng.uniform(0.12, 0.28)
        f0 = rng.uniform(4200, 5600)
        rate = rng.uniform(45, 70)
        base = int(t * SR)
        cn = int(trill_len * SR)
        for j in range(cn):
            if base + j >= n:
                break
            tt = j / SR
            pulse = 0.5 + 0.5 * math.sin(2 * math.pi * rate * tt)
            pulse = max(0.0, pulse) ** 2
            env = math.sin(math.pi * j / max(1, cn - 1))
            # Slight FM for insect texture
            f = f0 * (1.0 + 0.02 * math.sin(2 * math.pi * 18 * tt))
            crickets[base + j] += sine(f, tt) * 0.028 * env * pulse
        t += rng.uniform(0.35, 1.4)

    # Occasional leaf tick
    ticks = [0.0] * n
    for _ in range(14):
        start = int(rng.uniform(0.3, seconds - 0.1) * SR)
        ln = int(rng.uniform(0.008, 0.02) * SR)
        burst = highpass(noise(ln, 0.5), 0.45)
        for j, v in enumerate(burst):
            if start + j < n:
                ticks[start + j] += v * (1 - j / ln) * 0.08

    # Soft distant owl
    owls = [0.0] * n
    for start in (3.2, 8.6):
        hn = int(0.7 * SR)
        b = int(start * SR)
        for j in range(hn):
            if b + j >= n:
                break
            tt = j / SR
            env = math.sin(math.pi * j / max(1, hn - 1)) ** 1.4
            f = 290 + 35 * math.sin(2 * math.pi * 2.2 * tt)
            owls[b + j] += (
                0.7 * sine(f, tt) + 0.3 * sine(f * 1.97, tt)
            ) * 0.03 * env

    out = mix(wind, hush, crickets, ticks, owls, peak=0.9)
    # Crossfade loop seam
    xf = int(0.35 * SR)
    for i in range(xf):
        k = i / xf
        out[i] = out[i] * k + out[n - xf + i] * (1 - k)
    return out[:-xf]


def chitter() -> list[float]:
    """Raccoon chatter — rapid noisy chirps with formants."""
    parts: list[float] = []
    bursts = rng.randint(6, 8)
    for k in range(bursts):
        dur = rng.uniform(0.035, 0.06)
        n = int(dur * SR)
        f0 = rng.uniform(780, 1100) + k * 40
        chunk = []
        for i in range(n):
            t = i / SR
            u = i / max(1, n - 1)
            env = math.sin(math.pi * u) ** 0.8
            # Noisy vocal
            v = formant(t, f0, f0 * 1.7, f0 * 2.4, 0.42)
            v += rng.uniform(-1, 1) * 0.12 * env
            # Quick pitch flip
            fbend = f0 * (1.0 + 0.18 * (u - 0.3))
            v = 0.65 * v + 0.35 * sine(fbend, t) * 0.4
            chunk.append(v * env)
        chunk = bandpass(chunk, 0.08, 0.45)
        parts.extend(fade(chunk, 0.002, 0.01))
        parts.extend([0.0] * int(rng.uniform(0.018, 0.04) * SR))
    return fade(parts, 0.004, 0.04)


def chirp() -> list[float]:
    """Happy short squeak — two rising notes."""
    def note(f0: float, dur: float, amp: float) -> list[float]:
        n = int(dur * SR)
        out = []
        for i in range(n):
            t = i / SR
            u = i / max(1, n - 1)
            f = f0 * (1.0 + 0.22 * u)
            env = math.sin(math.pi * u) ** 0.75
            v = formant(t, f, f * 1.85, f * 2.6, amp)
            v += rng.uniform(-1, 1) * 0.06 * env
            out.append(v * env)
        return bandpass(out, 0.07, 0.4)

    a = note(640, 0.1, 0.38)
    gap = [0.0] * int(0.04 * SR)
    b = note(900, 0.12, 0.34)
    return fade(a + gap + b, 0.004, 0.05)


def grumble() -> list[float]:
    """Low throaty raccoon grumble / protest."""
    n = int(0.55 * SR)
    out = []
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        env = math.sin(math.pi * u) ** 1.1
        f = 120 + 45 * math.sin(2 * math.pi * 5.5 * t) + 20 * math.sin(2 * math.pi * 2.1 * t)
        v = (
            0.45 * sine(f, t)
            + 0.25 * sine(f * 1.5, t)
            + 0.15 * sine(f * 2.1, t)
        )
        # Throat noise
        v += rng.uniform(-1, 1) * 0.2
        out.append(v * env * 0.55)
    out = lowpass(out, 0.12)
    # Soft growl pulse
    for i in range(n):
        t = i / SR
        out[i] *= 0.75 + 0.25 * math.sin(2 * math.pi * 14 * t)
    return fade(out, 0.015, 0.08)


def rustle() -> list[float]:
    """Dry leaf / underbrush rustle."""
    n = int(0.7 * SR)
    layers = []
    for alpha, amp in ((0.45, 0.55), (0.28, 0.4), (0.18, 0.28)):
        raw = highpass(noise(n, amp), alpha)
        layer = []
        for i, x in enumerate(raw):
            env = (math.sin(math.pi * i / max(1, n - 1)) ** 0.65) * (
                0.55 + 0.45 * abs(math.sin(i * 0.21 + alpha * 10))
            )
            layer.append(x * env)
        layers.append(layer)
    # Occasional twig snaps
    snaps = [0.0] * n
    for _ in range(3):
        s = int(rng.uniform(0.08, 0.55) * SR)
        ln = int(rng.uniform(0.006, 0.014) * SR)
        burst = highpass(noise(ln, 0.9), 0.5)
        for j, v in enumerate(burst):
            if s + j < n:
                snaps[s + j] += v * (1 - j / ln) * 0.35
    return fade(mix(*layers, snaps, peak=0.85), 0.008, 0.1)


def crunch() -> list[float]:
    """Chewing: hard crack + wet mouth noise."""
    parts: list[float] = []
    for bite in range(5):
        # Hard crack
        cn = int(rng.uniform(0.018, 0.032) * SR)
        crack = highpass(noise(cn, 1.0), 0.55)
        crack = [c * (1 - i / cn) ** 0.5 * 0.7 for i, c in enumerate(crack)]
        # Wet chew body
        wn = int(rng.uniform(0.05, 0.08) * SR)
        wet = bandpass(noise(wn, 0.7), 0.15, 0.35)
        for i in range(wn):
            t = i / SR
            wet[i] *= math.sin(math.pi * i / max(1, wn - 1)) * (
                0.5 + 0.5 * math.sin(2 * math.pi * 28 * t)
            )
            wet[i] += 0.12 * sine(180 + bite * 20, t) * math.sin(math.pi * i / max(1, wn - 1))
        parts.extend(fade(crack, 0.001, 0.01))
        parts.extend(fade(wet, 0.005, 0.02))
        parts.extend([0.0] * int(rng.uniform(0.035, 0.06) * SR))
    return fade(parts, 0.002, 0.04)


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


def main() -> None:
    files = {
        "night_ambience.wav": night_ambience(12.0),
        "chitter.wav": chitter(),
        "chirp.wav": chirp(),
        "grumble.wav": grumble(),
        "rustle.wav": rustle(),
        "crunch.wav": crunch(),
        "ascend.wav": ascend(),
        "hoot.wav": soft_hoot(),
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
