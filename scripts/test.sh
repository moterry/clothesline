#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CLT=/Library/Developer/CommandLineTools
FW=$CLT/Library/Developer/Frameworks
LIB=$CLT/Library/Developer/usr/lib
mkdir -p build
swiftc -parse-as-library \
  -plugin-path "$CLT/usr/lib/swift/host/plugins/testing" \
  -F "$FW" -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" \
  Sources/Core/*.swift Tests/*.swift Tests/Support/*.swift -o build/ClotheslineTests
./build/ClotheslineTests "$@"
