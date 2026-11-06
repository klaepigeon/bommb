#!/usr/bin/env python3
"""Placeholder party music for MEAT PARTY (assets/music/*.wav), made from scratch.

    python3 tools/make_music.py

chairs.wav  a wheezing fairground waltz (Musical Chairs: it stops without warning)
potato.wav  a polka that is slightly too fast (Hot Potato)
fanfare_short.wav  the Caller's sting
Replace any of them by dropping a file of the same name in assets/music/ (or point
assets/data/assets.json at another file)."""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")


def note(n):  # MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12.0)


def organ(f, t):
    # a reedy calliope: a few odd harmonics and a wobble
    w = 1 + 0.004 * math.sin(t * 6.0)
    return (math.sin(2 * math.pi * f * w * t) * 0.6 + math.sin(2 * math.pi * f * 2 * w * t) * 0.25
            + math.sin(2 * math.pi * f * 3 * w * t) * 0.12 + (1 if math.sin(2 * math.pi * f * t) > 0 else -1) * 0.08)


def render(events, length, path, vol=0.3):
    n = int(length * RATE)
    buf = [0.0] * n
    for start, dur, midi, amp, kind in events:
        f = note(midi)
        s0 = int(start * RATE)
        s1 = min(n, int((start + dur) * RATE))
        for i in range(s0, s1):
            t = (i - s0) / RATE
            env = min(1.0, t * 60) * max(0.0, 1.0 - t / dur) ** 0.6
            if kind == "bass":
                v = math.sin(2 * math.pi * f * t) * 0.9 + math.sin(2 * math.pi * f * 2 * t) * 0.2
            elif kind == "drum":
                v = (random.random() * 2 - 1) * math.exp(-t * 40) + math.sin(2 * math.pi * 60 * t) * math.exp(-t * 25)
            else:
                v = organ(f, t)
            buf[i] += v * env * amp
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1, min(1, x * vol)) * 32767)) for x in buf)
        w.writeframes(frames)


def waltz():
    bpm = 150
    beat = 60.0 / bpm
    melody = [72, 76, 79, 79, 77, 76, 74, 77, 81, 81, 79, 77, 76, 79, 84, 83, 81, 79, 77, 74, 71, 72, 74, 72,
              72, 76, 79, 79, 77, 76, 74, 77, 81, 81, 79, 77, 76, 72, 79, 77, 74, 71, 72, 72, 72, 72, 0, 0]
    chords = [48, 48, 43, 43, 50, 50, 43, 43, 48, 48, 45, 45, 50, 43, 48, 48]
    ev = []
    for i, m in enumerate(melody):
        if m:
            ev.append((i * beat, beat * 0.95, m, 0.5, "organ"))
    for bar, root in enumerate(chords):
        t = bar * 3 * beat
        ev.append((t, beat, root, 0.6, "bass"))
        for k in (1, 2):
            ev.append((t + k * beat, beat * 0.5, root + 16, 0.22, "organ"))
            ev.append((t + k * beat, beat * 0.5, root + 19, 0.18, "organ"))
    return ev, len(melody) * beat


def polka():
    bpm = 210
    beat = 60.0 / bpm
    mel = [67, 71, 74, 71, 72, 69, 66, 69, 67, 71, 74, 79, 78, 74, 72, 69,
           67, 71, 74, 71, 72, 76, 74, 72, 71, 69, 67, 66, 67, 0, 67, 0]
    ev = []
    for i, m in enumerate(mel):
        if m:
            ev.append((i * beat, beat * 0.8, m, 0.5, "organ"))
    for i in range(len(mel)):
        root = 43 if (i // 8) % 2 == 0 else 50
        if i % 2 == 0:
            ev.append((i * beat, beat * 0.7, root, 0.6, "bass"))
            ev.append((i * beat, 0.08, 0, 0.25, "drum"))
        else:
            ev.append((i * beat, beat * 0.4, root + 16, 0.2, "organ"))
            ev.append((i * beat, beat * 0.4, root + 19, 0.2, "organ"))
    return ev, len(mel) * beat


def fanfare():
    ev = [(0.0, 0.15, 72, 0.6, "organ"), (0.15, 0.15, 76, 0.6, "organ"), (0.3, 0.15, 79, 0.6, "organ"),
          (0.45, 0.7, 84, 0.6, "organ"), (0.45, 0.7, 48, 0.5, "bass"), (1.0, 0.25, 83, 0.5, "organ"),
          (1.15, 0.6, 71, 0.4, "organ")]  # the last note goes wrong
    return ev, 1.9


if __name__ == "__main__":
    random.seed(7)
    os.makedirs(OUT, exist_ok=True)
    e, l = waltz(); render(e, l, os.path.join(OUT, "chairs.wav"))
    e, l = polka(); render(e, l, os.path.join(OUT, "potato.wav"))
    e, l = fanfare(); render(e, l, os.path.join(OUT, "fanfare_short.wav"), 0.35)
    print("ok")
