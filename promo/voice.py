"""Voice-over for the Clothesline promo using macOS `say`.

Picks the best installed voice for the language (Premium > Enhanced > built-in), speaks each script line,
and raises the speaking rate only as much as needed for every line to finish before the next one starts.
Writes <out-dir>/<lang>-<i>.aiff and <out-dir>/<lang>-voice.json (the manifest `film mux` reads).

Usage: python3 promo/voice.py <script.json> <zh|en> <out-dir> [voice name]
"""
import json
import os
import re
import subprocess
import sys

script_path, lang, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
forced = sys.argv[4] if len(sys.argv) > 4 else None
script = json.load(open(script_path))
os.makedirs(out_dir, exist_ok=True)

listing = subprocess.run(["say", "-v", "?"], capture_output=True, text=True).stdout
installed = [re.split(r"\s{2,}", line.strip())[0] for line in listing.splitlines() if line.strip()]

PREFS = {
    "zh": ["Tingting (Premium)", "Tingting (Enhanced)", "Lili (Premium)", "Lili (Enhanced)", "Yu-shu (Enhanced)", "Tingting"],
    "en": ["Ava (Premium)", "Zoe (Premium)", "Evan (Premium)", "Ava (Enhanced)", "Zoe (Enhanced)", "Samantha (Enhanced)", "Samantha"],
}
voice = forced or next((v for v in PREFS[lang] if v in installed), None)
if voice is None:
    sys.exit(f"no {lang} voice installed")
print(f"{lang}: voice = {voice}")

BASE_RATE = {"zh": 168, "en": 165}[lang]


def speak(text, rate, path):
    subprocess.run(["say", "-v", voice, "-r", str(rate), "-o", path, text], check=True)
    info = subprocess.run(["afinfo", path], capture_output=True, text=True).stdout
    return float(re.search(r"estimated duration: ([\d.]+)", info).group(1))


lines = script["lines"]
manifest = []
for i, line in enumerate(lines):
    end = lines[i + 1]["start"] if i + 1 < len(lines) else script["duration"] - 0.3
    window = end - line["start"] - 0.2
    path = os.path.join(out_dir, f"{lang}-{i}.aiff")
    rate = BASE_RATE
    dur = speak(line[lang], rate, path)
    while dur > window and rate < 240:
        rate += 8
        dur = speak(line[lang], rate, path)
    flag = "" if dur <= window else "  (!) still too long"
    print(f"  line {i}: {dur:.2f}s of {window:.2f}s at rate {rate}{flag}")
    manifest.append({"file": os.path.abspath(path), "start": line["start"], "duration": dur})

json.dump(manifest, open(os.path.join(out_dir, f"{lang}-voice.json"), "w"), ensure_ascii=False, indent=1)
