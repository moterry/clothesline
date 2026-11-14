#!/bin/bash
# Builds the Clothesline promo films (zh and en) into build/promo/.
# Usage: promo/make-video.sh [zh|en ...]        (default: both)
# Optional: ZH_VOICE / EN_VOICE to force a particular `say` voice.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/promo
mkdir -p "$OUT"
LANGS=("${@:-zh en}")
[ $# -eq 0 ] && LANGS=(zh en)

swiftc -O Sources/Core/*.swift promo/Shared/*.swift promo/film/*.swift -o build/film
DUR=$(python3 -c "import json;print(json.load(open('promo/script.json'))['duration'])")
python3 promo/music.py "$OUT/music.wav" "$DUR"

for L in "${LANGS[@]}"; do
  V=""
  [ "$L" = zh ] && V="${ZH_VOICE:-}"
  [ "$L" = en ] && V="${EN_VOICE:-}"
  python3 promo/voice.py promo/script.json "$L" "$OUT/vo" ${V:+"$V"}
  ./build/film video promo/script.json "$L" "$OUT/$L-silent.mov"
  ./build/film mux "$OUT/$L-silent.mov" "$OUT/music.wav" "$OUT/vo/$L-voice.json" "$DUR" "$OUT/clothesline-$L.mp4"
  echo "done: $OUT/clothesline-$L.mp4"
done
