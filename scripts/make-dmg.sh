#!/bin/bash
# make-dmg.sh — Verpackt build/MikaPlusPlayer.app in ein DMG unter dist/.
# Nutzt 'create-dmg' (falls installiert) für ein hübsches Layout, sonst hdiutil.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/MikaPlusPlayer.app"
DIST="$ROOT/dist"

[ -d "$APP" ] || { echo "FEHLER: $APP fehlt. Erst scripts/build-macos.sh ausführen."; exit 1; }

VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p "$DIST"
# Nur das aktuelle DMG behalten (sauberer Appcast-Lauf).
rm -f "$DIST"/*.dmg
DMG="$DIST/MikaPlusPlayer-v$VER.dmg"

if command -v create-dmg >/dev/null 2>&1; then
    echo "==> create-dmg (hübsches Layout)"
    create-dmg \
        --volname "MikaPlusPlayer" \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "MikaPlusPlayer.app" 150 200 \
        --app-drop-link 450 200 \
        --hide-extension "MikaPlusPlayer.app" \
        "$DMG" "$APP" >/dev/null
else
    echo "==> hdiutil-Fallback ('brew install create-dmg' für hübscheres Layout)"
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "MikaPlusPlayer" -srcfolder "$STAGE" \
        -ov -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null
    rm -rf "$STAGE"
fi

echo "==> DMG: $DMG ($(du -h "$DMG" | cut -f1))"
