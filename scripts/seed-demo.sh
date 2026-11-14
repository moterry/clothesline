#!/bin/bash
# Creates a demo library: 7 screenshots on the line and 7 river bundles.
# Usage: scripts/seed-demo.sh <root>
set -euo pipefail
ROOT="${1:?usage: seed-demo.sh <root>}"
# Safety: only ever wipe a folder under this repo's build/ directory.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
case "$(cd "$(dirname "$ROOT")" 2>/dev/null && pwd)/$(basename "$ROOT")" in
  "$REPO/build/"*) ;;
  *) echo "refusing: demo root must be inside $REPO/build/" >&2; exit 1 ;;
esac
rm -rf "$ROOT"
mkdir -p "$ROOT/Rope" "$ROOT/River"

# Source images: procedurally drawn fake screenshots (no real screens, no copyrighted artwork).
mkdir -p "$REPO/build"
swiftc -O "$REPO/promo/Shared/"*.swift "$REPO/promo/fakeshots/main.swift" -o "$REPO/build/fakeshots" 2>/dev/null
SRC="$(mktemp -d)"
"$REPO/build/fakeshots" "$SRC" 40 7
n=0
make() { # make <dest>
  cp "$SRC/$((n % 40)).png" "$1"; n=$((n + 1))
}

for i in 1 2 3 4 5 6 7; do
  make "$ROOT/Rope/截屏 2026-11-14 1$i.00.00.png"
  sleep 0.05
done

for day in "2026-11-13 · I" "2026-11-12 · I" "2026-11-10 · I" "2026-11-08 · I" "2026-11-05 · I" "2026-11-01 · I" "2026-10-28 · I"; do
  mkdir -p "$ROOT/River/$day"
  for j in 1 2 3; do make "$ROOT/River/$day/截屏 $j.png"; done
done
rm -rf "$SRC"
echo "seeded $ROOT"
