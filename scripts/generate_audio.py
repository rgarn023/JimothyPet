#!/usr/bin/env python3
"""Regenerate Jimothy nighttime ambience + raccoon SFX WAVs."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
rng = random.Random(42)
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


def mix(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    peak = max(1e-6, max(abs(x) for x in out))
    if peak > 0.95:
        out = [x * 0.95 / peak for x in out]
    return out


def tone(freq: float, dur: float, amp: float = 0.3, bend: float = 0.0) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + bend * (i / max(1, n - 1)))
        env = math.sin(math.pi * min(1.0, i / max(1, n - 1))) ** 0.6
        out.append(math.sin(2 * math.pi * f * t) * amp * env)
    return out


def night_ambience(seconds: float = 10.0) -> list[float]:
    n = int(seconds * SR)
    wind = [w * 0.22 for w in lowpass(noise(n, 0.35), 0.02)]
    pad = []
    for i in range(n):
        t = i / SR
        v = (
            0.04 * math.sin(2 * math.pi * 110 * t)
            + 0.03 * math.sin(2 * math.pi * 164.8 * t + 0.4)
            + 0.025 * math.sin(2 * math.pi * 220 * t + 1.1)
        )
        v *= 0.55 + 0.45 * math.sin(2 * math.pi * t / seconds)
        pad.append(v)
    crickets = [0.0] * n
    t = 0.15
    while t < seconds - 0.2:
        chirp_len = rng.uniform(0.04, 0.09)
        f0 = rng.uniform(3800, 5200)
        base = int(t * SR)
        cn = int(chirp_len * SR)
        for j in range(cn):
            if base + j >= n:
                break
            tt = j / SR
            env = math.sin(math.pi * j / max(1, cn - 1))
            am = 0.5 + 0.5 * math.sin(2 * math.pi * 55 * tt)
            crickets[base + j] += math.sin(2 * math.pi * f0 * tt) * 0.045 * env * am
        t += rng.uniform(0.08, 0.16) if rng.random() < 0.55 else rng.uniform(0.35, 1.1)
    owls = [0.0] * n
    for start in (2.8, 7.1):
        hn = int(0.55 * SR)
        b = int(start * SR)
        for j in range(hn):
            if b + j >= n:
                break
            tt = j / SR
            env = math.sin(math.pi * j / max(1, hn - 1)) ** 1.2
            f = 320 + 40 * math.sin(2 * math.pi * 3 * tt)
            owls[b + j] += math.sin(2 * math.pi * f * tt) * 0.035 * env
    out = mix(wind, pad, crickets, owls)
    xf = int(0.25 * SR)
    for i in range(xf):
        k = i / xf
        out[i] = out[i] * k + out[n - xf + i] * (1 - k)
    return out[:-xf]


def chitter() -> list[float]:
    parts: list[float] = []
    for k in range(5):
        f = 900 + k * 120 + rng.uniform(-40, 40)
        parts.extend(tone(f, 0.055, amp=0.28, bend=0.15))
        parts.extend([0.0] * int(rng.uniform(0.02, 0.04) * SR))
    return fade(parts, 0.005, 0.04)


def chirp() -> list[float]:
    a = tone(720, 0.08, amp=0.32, bend=0.25)
    b = tone(980, 0.1, amp=0.28, bend=-0.1)
    return fade(a + [0.0] * int(0.03 * SR) + b, 0.005, 0.05)


def grumble() -> list[float]:
    n = int(0.45 * SR)
    base = lowpass(noise(n, 0.7), 0.08)
    out = []
    for i, x in enumerate(base):
        t = i / SR
        f = 140 + 30 * math.sin(2 * math.pi * 6 * t)
        tone_v = math.sin(2 * math.pi * f * t) * 0.35
        env = math.sin(math.pi * i / max(1, n - 1))
        out.append((x * 0.45 + tone_v) * env * 0.55)
    return fade(out, 0.01, 0.06)


def rustle() -> list[float]:
    n = int(0.55 * SR)
    raw = highpass(lowpass(noise(n, 0.9), 0.35), 0.2)
    out = []
    for i, x in enumerate(raw):
        env = (math.sin(math.pi * i / max(1, n - 1)) ** 0.7) * (0.7 + 0.3 * math.sin(i * 0.37))
        out.append(x * env * 0.4)
    return fade(out, 0.005, 0.08)


def crunch() -> list[float]:
    parts: list[float] = []
    for _ in range(4):
        n = int(rng.uniform(0.03, 0.05) * SR)
        click = highpass(noise(n, 0.9), 0.4)
        click = [c * (1 - i / n) * 0.5 for i, c in enumerate(click)]
        parts.extend(click)
        parts.extend([0.0] * int(0.02 * SR))
    return fade(parts, 0.001, 0.03)


def ascend() -> list[float]:
    n = int(2.8 * SR)
    out = []
    for i in range(n):
        t = i / SR
        u = i / max(1, n - 1)
        f1 = 220 * (1 + 1.8 * u)
        f2 = 330 * (1 + 1.8 * u)
        f3 = 440 * (1 + 1.6 * u)
        v = (
            0.16 * math.sin(2 * math.pi * f1 * t)
            + 0.12 * math.sin(2 * math.pi * f2 * t)
            + 0.08 * math.sin(2 * math.pi * f3 * t)
        )
        shimmer = rng.uniform(-1, 1) * 0.04 * u
        env = (u ** 0.45) * (1 - u) ** 0.35 * 2.2
        out.append((v + shimmer) * env)
    whoosh = lowpass(noise(int(0.6 * SR), 0.5), 0.05)
    for i, w in enumerate(whoosh):
        env = math.sin(math.pi * i / max(1, len(whoosh) - 1))
        out[i] += w * env * 0.25
    return fade(out, 0.02, 0.25)


def soft_hoot() -> list[float]:
    return fade(
        tone(280, 0.35, amp=0.18, bend=-0.08)
        + [0.0] * int(0.08 * SR)
        + tone(250, 0.28, amp=0.14, bend=-0.05),
        0.02,
        0.08,
    )


def main() -> None:
    files = {
        "night_ambience.wav": night_ambience(10.0),
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
