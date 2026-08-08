"""Synthesize the MeridianCare urgent-alert notification sound.

A fast, alternating two-tone klaxon (like a smoke detector, not a chime) —
deliberately not the default iOS notification sound, because the whole point
is that a caregiver recognizes "that's a Meridian fall alert" by ear before
they've even looked at the phone. Two full up/down cycles fit in ~1.8s.

    python tools/generate_alert_sound.py

Writes a WAV (for auditioning) and a CAF (what actually ships in the app,
per Apple's recommended format for UNNotificationSound) to
meridian_care/MeridianCare/Resources/urgent_alert.caf.

That path is not incidental: it must sit directly in Resources/ to match
the PBXFileReference path Xcode was given (a group-relative path with no
subfolder component) — dropping it into a Sounds/ subfolder here without
also adding that subgroup to project.pbxproj produces a file Xcode can't
find at build time.
"""

from __future__ import annotations

import math
import struct
import subprocess
import wave
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "meridian_care" / "MeridianCare" / "Resources"
SAMPLE_RATE = 44100

# Two alternating tones, four repeats -- distinctive and short enough that
# it doesn't outlast a quick glance at the lock screen. Frequencies chosen
# to sit above typical ambient/HVAC noise without being painfully shrill.
TONE_HIGH_HZ = 1046.5  # C6
TONE_LOW_HZ = 830.6  # G#5
TONE_MS = 220
GAP_MS = 30
REPEATS = 4


def _tone(freq: float, duration_ms: int) -> list[float]:
    n = int(SAMPLE_RATE * duration_ms / 1000)
    # A short linear fade in/out on every tone avoids the audible click a
    # hard-edged square burst would otherwise produce.
    fade = max(1, int(n * 0.08))
    samples = []
    for i in range(n):
        envelope = 1.0
        if i < fade:
            envelope = i / fade
        elif i > n - fade:
            envelope = (n - i) / fade
        samples.append(envelope * math.sin(2 * math.pi * freq * i / SAMPLE_RATE))
    return samples


def _silence(duration_ms: int) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * duration_ms / 1000)


def build_waveform() -> list[float]:
    waveform: list[float] = []
    for _ in range(REPEATS):
        waveform += _tone(TONE_HIGH_HZ, TONE_MS)
        waveform += _silence(GAP_MS)
        waveform += _tone(TONE_LOW_HZ, TONE_MS)
        waveform += _silence(GAP_MS)
    return waveform


def write_wav(path: Path, waveform: list[float]) -> None:
    # Peak-normalized to just under full scale, not maxed -- headroom keeps
    # it loud without inviting the DAC/speaker clipping that reads as noise
    # on small phone speakers.
    peak = max(abs(s) for s in waveform) or 1.0
    scale = 0.92 / peak
    with wave.open(str(path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-32768, min(32767, s * scale * 32767))))
            for s in waveform
        )
        wav.writeframes(frames)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    waveform = build_waveform()

    wav_path = OUT_DIR / "urgent_alert.wav"
    caf_path = OUT_DIR / "urgent_alert.caf"
    write_wav(wav_path, waveform)

    # CAF/linear-PCM is Apple's recommended format for UNNotificationSound;
    # afconvert is the standard macOS tool for this conversion and ships
    # with every Mac, so no extra dependency is needed here.
    subprocess.run(
        ["afconvert", "-f", "caff", "-d", "LEI16", str(wav_path), str(caf_path)],
        check=True,
    )

    duration_s = len(waveform) / SAMPLE_RATE
    print(f"Wrote {wav_path.relative_to(REPO_ROOT)} and {caf_path.relative_to(REPO_ROOT)}")
    print(f"Duration: {duration_s:.2f}s (Apple's UNNotificationSound limit is 30s)")


if __name__ == "__main__":
    main()
