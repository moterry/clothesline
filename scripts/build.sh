#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -parse-as-library -O Sources/Core/*.swift Sources/App/*.swift -o build/Clothesline
