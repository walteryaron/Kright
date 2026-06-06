#!/bin/bash
# Builds a Release Kysy.app and packages it into a distributable Kysy.dmg.
#
#   ./scripts/build-dmg.sh
#
# Output: KysyNative/build/Kysy.dmg
#
# If a "Developer ID Application" certificate AND a stored notary profile
# (default name: kysy-notary) are present, the DMG is Developer-ID signed,
# notarized by Apple, and stapled — so it opens with a normal double-click on
# any Mac. Otherwise it falls back to a plain dev-signed DMG (first launch on
# another Mac then needs a right-click → Open). See the one-time setup at the
# bottom of this file.
set -euo pipefail

cd "$(dirname "$0")/.."          # KysyNative/
ROOT="$(pwd)"
BUILD="$ROOT/build"
DD="$BUILD/dd"
STAGE="$BUILD/dmg"
DMG="$BUILD/Kysy.dmg"
NOTARY_PROFILE="${KYSY_NOTARY_PROFILE:-kysy-notary}"
APPLE_ID="${KYSY_APPLE_ID:-walter_yaron@hotmail.com}"   # Apple Developer account
TEAM_ID="${KYSY_TEAM_ID:-NFQL267669}"

# Auto-detect a Developer ID Application identity (for notarized distribution).
DEVID="$(security find-identity -v -p codesigning \
          | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"

# Common gotcha: the cert is installed but its PRIVATE KEY isn't on this Mac, so
# it's not a usable signing identity. Detect that and explain.
if [ -z "$DEVID" ] && security find-certificate -a -c "Developer ID Application" >/dev/null 2>&1; then
  echo "⚠ A 'Developer ID Application' certificate is in your keychain but has no"
  echo "  matching private key, so it can't sign. Recreate it via Xcode (which"
  echo "  generates the key locally): Xcode → Settings → Accounts → Manage"
  echo "  Certificates → + → Developer ID Application. Continuing un-notarized…"
fi

echo "▸ Building Release…"
xcodebuild -project Kysy.xcodeproj -scheme Kysy -configuration Release \
  -derivedDataPath "$DD" build >/dev/null

APP="$DD/Build/Products/Release/Kysy.app"
[ -d "$APP" ] || { echo "✗ App not found at $APP"; exit 1; }

if [ -n "$DEVID" ]; then
  echo "▸ Signing with: $DEVID (hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "Sources/Kysy.entitlements" \
    --sign "$DEVID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "▸ No Developer ID cert found — using the existing dev signature."
fi

echo "▸ Staging…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

echo "▸ Creating styled DMG…"
export KYSY_APP="$APP"
export KYSY_DMG_BG="/tmp/kysy-dmg-bg.png"
swift scripts/gen-dmg-bg.swift "$KYSY_DMG_BG" >/dev/null

# dmgbuild lays out the "drag to Applications" window headlessly (no Finder /
# Automation permission needed). Falls back to a plain DMG if it isn't installed
# (pip3 install --user dmgbuild).
DMGBUILD="$(python3 -m site --user-base 2>/dev/null)/bin/dmgbuild"
[ -x "$DMGBUILD" ] || DMGBUILD="$(command -v dmgbuild || true)"
rm -f "$DMG"
if [ -n "$DMGBUILD" ] && [ -x "$DMGBUILD" ]; then
  "$DMGBUILD" -s scripts/dmgbuild-settings.py "Kysy" "$DMG" >/dev/null
else
  echo "  (dmgbuild not found — plain DMG. Install: pip3 install --user dmgbuild)"
  hdiutil create -volname "Kysy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
fi

if [ -n "$DEVID" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "▸ Signing DMG…"
  codesign --force --sign "$DEVID" --timestamp "$DMG"
  echo "▸ Notarizing (this can take a few minutes)…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ Stapling…"
  xcrun stapler staple "$DMG"
  echo "✓ Done (notarized): $DMG"
else
  echo "✓ Done (not notarized): $DMG"
  if [ -z "$DEVID" ]; then
    echo "  → No Developer ID cert: create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application."
  else
    echo "  → No notary profile '$NOTARY_PROFILE'. Create an app-specific password at appleid.apple.com, then run:"
    echo "      xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id $APPLE_ID --team-id $TEAM_ID --password <app-specific-password>"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# ONE-TIME SETUP for notarized distribution (Apple Developer Program required):
#
# 1) Create a "Developer ID Application" certificate:
#      Xcode → Settings → Accounts → (your Apple ID) → Manage Certificates…
#      → click "+" → "Developer ID Application".
#
# 2) Create an app-specific password at https://appleid.apple.com
#    (Sign-In and Security → App-Specific Passwords), then store notary creds:
#      xcrun notarytool store-credentials kysy-notary \
#        --apple-id walter_yaron@hotmail.com \
#        --team-id NFQL267669 \
#        --password <the-app-specific-password>
#
# Then just re-run this script — it auto-detects both and notarizes.
# ─────────────────────────────────────────────────────────────────────────────
