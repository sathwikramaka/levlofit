"""Synthesises the Levlofit notification sound, "air pop": a soft rising whoosh of air, a bubbly pop,
then two bright kalimba plucks a fifth apart (C6 to G6) with a high sparkle and a light echo.
Playful and airy like a modern learning-app chime, but our own. Pure synthesis, no samples, no licence.

Run: python data/make_chime.py  -> app/assets/sounds/levlo_chime.wav (+ Android raw and iOS copies)
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44_100
LENGTH = 1.2  # seconds


def whoosh(n: int) -> list[float]:
    """Noise through a band-pass filter whose centre sweeps 600 Hz to 3.2 kHz over 140 ms: a breath of air."""
    rnd = random.Random(7)  # fixed seed, so every build makes the same file
    out = [0.0] * n
    y1 = y2 = x1 = x2 = 0.0
    dur = int(RATE * 0.14)
    for i in range(dur):
        p = i / dur
        f = 600 * (3200 / 600) ** p
        w = 2 * math.pi * f / RATE
        alpha = math.sin(w) / (2 * 2.5)  # Q 2.5
        b0, a0, a1, a2 = alpha, 1 + alpha, -2 * math.cos(w), 1 - alpha
        x = rnd.uniform(-1, 1)
        y = (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x, y1, y
        out[i] = 0.5 * y * math.sin(math.pi * p) ** 1.5
    return out


def pop(t: float, start: float) -> float:
    """A 45 ms sine that leaps up an octave, like a bubble popping."""
    x = t - start
    if x < 0 or x > 0.045:
        return 0.0
    f0, f1 = 700.0, 1400.0
    k = (f1 - f0) / 0.045
    return 0.45 * math.sin(math.pi * x / 0.045) * math.sin(2 * math.pi * (f0 * x + 0.5 * k * x * x))


def pluck(t: float, start: float, freq: float, amp: float, decay: float) -> float:
    """Kalimba-like tine: fundamental, an inharmonic 5.4x overtone that dies fast, 3 ms attack."""
    x = t - start
    if x < 0:
        return 0.0
    env = min(1.0, x / 0.003)
    w = 2 * math.pi * freq * x
    return amp * env * (math.exp(-x / decay) * math.sin(w) + 0.35 * math.exp(-x / 0.03) * math.sin(5.4 * w) + 0.12 * math.exp(-x / decay) * math.sin(2 * w))


def main():
    root = Path(__file__).resolve().parents[1]
    n = int(RATE * LENGTH)
    air = whoosh(n)
    dry = [
        air[i]
        + pop(i / RATE, 0.11)
        + pluck(i / RATE, 0.15, 1046.5, 0.55, 0.22)
        + pluck(i / RATE, 0.27, 1567.98, 0.55, 0.36)
        + pluck(i / RATE, 0.29, 2637.0, 0.12, 0.25)  # E7 sparkle over the second note
        for i in range(n)
    ]
    delay = int(RATE * 0.12)
    out = [dry[i] + (0.25 * dry[i - delay] if i >= delay else 0.0) for i in range(n)]
    tail = int(RATE * 0.3)
    for i in range(n - tail, n):
        out[i] *= (n - i) / tail
    peak = max(abs(v) for v in out)
    assert peak > 0
    frames = b"".join(struct.pack("<h", int(v / peak * 0.707 * 32767)) for v in out)  # about -3 dBFS
    targets = [
        root / "app" / "assets" / "sounds" / "levlo_chime.wav",
        root / "app" / "android" / "app" / "src" / "main" / "res" / "raw" / "levlo_chime.wav",
        root / "app" / "ios" / "Runner" / "levlo_chime.wav",
    ]
    for path in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(frames)
        print("wrote", path.relative_to(root), path.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
