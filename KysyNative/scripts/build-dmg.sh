#!/bin/bash
# Builds a Release Kysy.app and packages it into a distributable Kysy.dmg.
#
#   ./scripts/build-dmg.sh
#
# Output: KysyNative/build/Kysy.dmg
#
# Note: the app is signed with your Apple Development identity, NOT notarized,
# so the first launch on another Mac needs a right-click → Open (or run
# `xattr -dr com.apple.quarantine /Applications/Kysy.app`). For frictionless
# distribution you'd need a Developer ID certificate + notarization.
set -euo pipefail

cd "$(dirname "$0")/.."          # KysyNative/
ROOT="$(pwd)"
BUILD="$ROOT/build"
DD="$BUILD/dd"
STAGE="$BUILD/dmg"
DMG="$BUILD/Kysy.dmg"

echo "▸ Building Release…"
xcodebuild -project Kysy.xcodeproj -scheme Kysy -configuration Release \
  -derivedDataPath "$DD" build >/dev/null

APP="$DD/Build/Products/Release/Kysy.app"
[ -d "$APP" ] || { echo "✗ App not found at $APP"; exit 1; }

echo "▸ Staging…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

echo "▸ Creating DMG…"
hdiutil create -volname "Kysy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "✓ Done: $DMG"
