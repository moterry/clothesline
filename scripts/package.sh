#!/bin/bash
# Builds 晾衣绳.app, ad-hoc signs it, and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
APP="build/晾衣绳.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Clothesline "$APP/Contents/MacOS/Clothesline"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/晾衣绳.app"
cp -R "$APP" "$HOME/Applications/"
echo "installed $HOME/Applications/晾衣绳.app"
