"""build_music.py - turn the full-quality music masters into small, loopable game files.

Input:  audio/music_src/*.wav   (the ElevenLabs masters, about 200 MB, kept out of git
                                 and out of the Godot export by audio/music_src/.gdignore)
Output: audio/music/<same name>.ogg  (Ogg Vorbis, what autoload/music.gd loads)

For each track it:
  1. trims silence off the start and end (a silent gap would play at every loop),
  2. evens out the loudness so no stage suddenly jumps louder or quieter (LUFS target),
  3. bakes a seamless loop: the last LOOP_XFADE_S seconds are blended into the first
     ones, so when Godot jumps from the end back to the start there is no click or bump,
  4. encodes Ogg Vorbis at VORBIS_QUALITY (about 110 kbit/s), roughly 1/12 of the WAV.

Run from the project root:  python tools/build_music.py
Needs ffmpeg on PATH and numpy. Re-running overwrites the OGGs.
"""
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "audio" / "music_src"
OUT = ROOT / "audio" / "music"

RATE = 48000             # samples per second (the masters are 48 kHz stereo)
SILENCE_DB = -45.0       # quieter than this at the very start or end counts as silence
LUFS_TARGET = -16.0      # loudness every track is evened out to
LOOP_XFADE_S = 2.0       # length of the blend between the end and the start (seconds)
VORBIS_QUALITY = "3"     # ffmpeg -q:a for libvorbis: 3 is about 110 kbit/s stereo


def decode(path: Path) -> np.ndarray:
    """Decode any audio file to float samples, shape (frames, 2), via ffmpeg.
    Loudness is evened out here too, with ffmpeg's loudnorm filter."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path),
           "-af", f"loudnorm=I={LUFS_TARGET}:TP=-1.5:LRA=11",
           "-ac", "2", "-ar", str(RATE), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def trim_silence(a: np.ndarray) -> np.ndarray:
    """Cut quiet frames off both ends (louder of the two channels decides)."""
    level = np.abs(a).max(axis=1)
    loud = np.nonzero(level > 10 ** (SILENCE_DB / 20.0))[0]
    if loud.size == 0:
        return a
    return a[loud[0]:loud[-1] + 1]


def bake_loop(a: np.ndarray) -> np.ndarray:
    """Seamless loop. With X = blend length and L = track length, the result is
         a[X : L-X]  followed by  (a[L-X : L] fading out  +  a[0 : X] fading in).
    Its last sample flows straight into a[X], which is its first sample, so the jump
    from end to start is continuous. Equal-power curves (sine / cosine) keep the
    loudness steady through the blend."""
    x = int(LOOP_XFADE_S * RATE)
    if a.shape[0] < x * 4:
        return a  # too short to blend safely; loop it as it is
    t = np.linspace(0.0, np.pi / 2.0, x, dtype=np.float32)[:, None]
    blend = a[-x:] * np.cos(t) + a[:x] * np.sin(t)
    return np.concatenate([a[x:-x], blend])


def encode(a: np.ndarray, path: Path) -> None:
    """Write float samples as Ogg Vorbis via ffmpeg (samples go in through stdin)."""
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2",
           "-i", "-", "-c:a", "libvorbis", "-q:a", VORBIS_QUALITY, str(path)]
    subprocess.run(cmd, input=np.clip(a, -1.0, 1.0).astype(np.float32).tobytes(), check=True)


def main() -> None:
    """Process every master in audio/music_src. sorted(glob) lists the WAVs in name
    order; each one goes decode -> trim -> loop (the calls nest, innermost first)."""
    OUT.mkdir(parents=True, exist_ok=True)  # exist_ok: no error if it is already there
    for wav in sorted(SRC.glob("*.wav")):
        a = bake_loop(trim_silence(decode(wav)))
        ogg = OUT / (wav.stem + ".ogg")
        encode(a, ogg)
        print(f"{wav.name}: {a.shape[0] / RATE:6.1f} s -> {ogg.name} {ogg.stat().st_size / 1e6:5.2f} MB")


if __name__ == "__main__":
    main()
