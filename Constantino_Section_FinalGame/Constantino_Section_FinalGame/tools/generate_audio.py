"""Generates the NEW original sound effects and the ambient music loop for Shadow Swap.
Run:  python3 tools/generate_audio.py   (needs numpy). Output goes to assets/audio/.
No third-party audio is used: everything is synthesized from sine waves."""
import wave, numpy as np, os

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

def save(name, data):
    data = np.clip(data, -1.0, 1.0)
    pcm = (data * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm.tobytes())

def tone(freq, dur, vol=0.5, attack=0.004, decay=None):
    t = np.arange(int(RATE * dur)) / RATE
    env = np.minimum(1.0, t / attack) * np.exp(-t * (decay if decay else 4.0 / dur))
    return np.sin(2 * np.pi * freq * t) * env * vol

# --- UI sounds -------------------------------------------------------------
save("ui_hover.wav", tone(880, 0.05, 0.25, decay=60))
click = tone(520, 0.09, 0.45, decay=40) + tone(780, 0.09, 0.25, decay=40)
save("ui_click.wav", click)
t = np.arange(int(RATE * 0.22)) / RATE
buzz = (np.sign(np.sin(2 * np.pi * 110 * t)) * 0.25 + np.sin(2 * np.pi * 82 * t) * 0.35) * np.exp(-t * 12)
save("blocked.wav", buzz)

# --- Ambient loop (24 s). Every frequency is a multiple of 1/24 Hz so the loop is seamless.
LOOP = 24.0
n = int(RATE * LOOP)
t = np.arange(n) / RATE
def snap(f): return round(f * LOOP) / LOOP
pad = np.zeros(n)
for f, v in ((110.0, 0.20), (164.81, 0.14), (220.0, 0.12), (261.63, 0.09), (329.63, 0.06)):
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * snap(0.125 + f / 2000) * t + f)
    pad += np.sin(2 * np.pi * snap(f) * t) * v * lfo
# soft pluck melody (A minor pentatonic), wraps around the loop end
notes = [(0.0, 440.0), (3.0, 523.25), (6.0, 392.0), (9.0, 329.63), (12.0, 440.0), (15.0, 587.33), (18.0, 523.25), (21.0, 329.63)]
mel = np.zeros(n)
for start, f in notes:
    tt = np.arange(int(RATE * 2.5)) / RATE
    pluck = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 1.8) * 0.16 * np.minimum(1, tt / 0.01)
    i0 = int(start * RATE)
    idx = (np.arange(len(pluck)) + i0) % n
    mel[idx] += pluck
mix = pad + mel
mix = mix / np.max(np.abs(mix)) * 0.55
save("music_ambient.wav", mix)
print("audio generated")
