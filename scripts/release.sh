#!/bin/bash
# release.sh — Kompletter Release: Build -> DMG -> appcast.xml (signiert).
#
# Voraussetzung: Sparkle-EdDSA-Privatkey liegt in der macOS-Keychain
# (einmalig via 'generate_keys' erzeugt; der Public Key steht in Info.plist).
#
# Ergebnis:
#   dist/MikaPlusPlayer-v<version>.dmg   -> als GitHub-Release-Asset hochladen
#   appcast.xml (Repo-Root)              -> committen & pushen (main-Branch)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GH_REPO="Mukaarts/MikaPlusPlayer"   # ggf. anpassen (muss zur SUFeedURL passen)

bash "$ROOT/scripts/build-macos.sh"
bash "$ROOT/scripts/make-dmg.sh"

APP="$ROOT/build/MikaPlusPlayer.app"
VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

# Sparkle-Tool finden (liegt in den aufgelösten SPM-Artefakten).
GEN=$(find "$ROOT/build/dd/SourcePackages/artifacts" -name generate_appcast -type f 2>/dev/null | head -1)
[ -n "$GEN" ] || { echo "FEHLER: generate_appcast nicht gefunden."; exit 1; }

echo "==> appcast.xml erzeugen (signiert mit Keychain-Key)"
"$GEN" "$ROOT/dist" \
    --download-url-prefix "https://github.com/$GH_REPO/releases/download/v$VER/"

cp "$ROOT/dist/appcast.xml" "$ROOT/appcast.xml"

cat <<EOF

==> Release v$VER vorbereitet.

Nächste Schritte:
  1) GitHub-Release "v$VER" im Repo $GH_REPO anlegen
  2) dist/MikaPlusPlayer-v$VER.dmg als Release-Asset hochladen
  3) appcast.xml committen & auf 'main' pushen
     (SUFeedURL: https://raw.githubusercontent.com/$GH_REPO/main/appcast.xml)

Für öffentliche Distribution: vorher mit Developer ID signieren + notarisieren
(siehe README, Abschnitt "Release & Auto-Update").
EOF
