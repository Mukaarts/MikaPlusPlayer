#!/bin/bash
# build-macos.sh — Baut die macOS-App (Release) und legt sie unter build/ ab.
# Xcode bettet Sparkle.framework automatisch ein und signiert es (SPM-Dependency).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DD="$ROOT/build/dd"

if command -v xcodegen >/dev/null 2>&1; then
    echo "==> xcodegen generate"
    xcodegen generate >/dev/null
fi

echo "==> xcodebuild (Release, macOS)"
xcodebuild build \
    -project MikaPlusPlayer.xcodeproj \
    -scheme MikaPlusPlayer-macOS \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DD" | tail -3

APP="$DD/Build/Products/Release/MikaPlusPlayer.app"
[ -d "$APP" ] || { echo "FEHLER: App nicht gefunden: $APP"; exit 1; }

mkdir -p "$ROOT/build"
rm -rf "$ROOT/build/MikaPlusPlayer.app"
cp -R "$APP" "$ROOT/build/MikaPlusPlayer.app"

VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/build/MikaPlusPlayer.app/Contents/Info.plist")
echo "==> Fertig: build/MikaPlusPlayer.app (v$VER)"
