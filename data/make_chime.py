"""Synthesises the Levlofit notification sound, "heartbeat to level up": two soft heartbeat thumps
(lub-dub), then a smooth rising major arpeggio (G4 C5 E5 G5) that lands on a held chord with a light
echo. Training effort, then a step up a level. Soft attacks and a warm tone keep it smooth, not shrill.
Pure synthesis, so the sound is ours outright (no samples, no licence).

Run: python data/make_chime.py  -> app/assets/sounds/levlo_chime.wav (+ Android raw and iOS copies)
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44_100
LENGTH = 1.9  # seconds


def thump(t: float, start: float, f0: float, f1: float, amp: float) -> float:
    """A heartbeat beat: a short sine whose pitch falls, with a 2nd harmonic so phone speakers can carry it."""
    x = t - start
    if x < 0 or x > 0.16:
        return 0.0
    k = (f1 - f0) / 0.16
    phase = 2 * math.pi * (f0 * x + 0.5 * k * x * x)
    env = min(1.0, x / 0.006) * math.exp(-x / 0.045)
    return amp * env * (math.sin(phase) + 0.5 * math.sin(2 * phase))


def note(t: float, start: float, freq: float, amp: float, decay: float) -> float:
    """A soft mallet tone: warm sine plus a quiet octave and 4th partial, gentle 12 ms attack, slight vibrato."""
    x = t - start
    if x < 0:
        return 0.0
    env = min(1.0, x / 0.012) * math.exp(-x / decay)
    vib = 1 + 0.003 * math.sin(2 * math.pi * 5.5 * x) * min(1.0, x / 0.3)
    w = 2 * math.pi * freq * vib * x
    return amp * env * (math.sin(w) + 0.18 * math.sin(2 * w) + 0.06 * math.sin(4 * w) * math.exp(-x / 0.08))


ARP = [(0.34, 392.00, 0.32), (0.43, 523.25, 0.32), (0.52, 659.25, 0.34), (0.61, 783.99, 0.75)]


def dry(t: float) -> float:
    beat = thump(t, 0.0, 150, 95, 0.55) + thump(t, 0.17, 140, 90, 0.42)
    arp = sum(note(t, s, f, 0.42, d) for s, f, d in ARP)
    # The landing chord: C5 under the top G and a soft high C for sparkle.
    land = note(t, 0.61, 523.25, 0.22, 0.8) + note(t, 0.63, 1046.5, 0.10, 0.5)
    return beat + arp + land


def main():
    root = Path(__file__).resolve().parents[1]
    n = int(RATE * LENGTH)
    raw = [dry(i / RATE) for i in range(n)]
    # One soft echo for space.
    delay = int(RATE * 0.14)
    out = [raw[i] + (0.22 * raw[i - delay] if i >= delay else 0.0) for i in range(n)]
    tail = int(RATE * 0.35)
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
