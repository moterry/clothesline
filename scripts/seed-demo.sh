#!/bin/bash
# Creates a demo library: 7 screenshots on the line and 7 river bundles.
# Usage: scripts/seed-demo.sh <root>
set -euo pipefail
ROOT="${1:?usage: seed-demo.sh <root>}"
rm -rf "$ROOT"
mkdir -p "$ROOT/Rope" "$ROOT/River"

# Source images: desktop pictures and app icons that ship with macOS.
shopt -s nullglob
SOURCES=(/System/Library/Desktop\ Pictures/*.heic /System/Applications/{Calendar,Maps,Notes,Photos,Safari,Music,Books,Weather}.app/Contents/Resources/AppIcon.icns)
[ ${#SOURCES[@]} -gt 0 ] || { echo "no source images found" >&2; exit 1; }

n=0
make() { # make <dest> <maxpx>
  local src="${SOURCES[$((n % ${#SOURCES[@]}))]}"; n=$((n + 1))
  sips -s format png -Z "$2" "$src" --out "$1" >/dev/null 2>&1
}

for i in 1 2 3 4 5 6 7; do
  make "$ROOT/Rope/截屏 2026-11-14 1$i.00.00.png" $(( i % 3 == 0 ? 600 : 900 ))
  sleep 0.05
done

for day in "2026-11-13 · I" "2026-11-12 · I" "2026-11-10 · I" "2026-11-08 · I" "2026-11-05 · I" "2026-11-01 · I" "2026-10-28 · I"; do
  mkdir -p "$ROOT/River/$day"
  for j in 1 2 3; do make "$ROOT/River/$day/截屏 $j.png" 700; done
done
echo "seeded $ROOT"
