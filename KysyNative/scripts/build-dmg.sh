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

# Auto-detect a Developer ID Application identity (for notarized distribution).
DEVID="$(security find-identity -v -p codesigning \
          | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"

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

echo "▸ Creating DMG…"
hdiutil create -volname "Kysy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

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
  [ -z "$DEVID" ] && echo "  → To produce a notarized DMG, see the setup steps in this script."
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
#        --apple-id <your-apple-id-email> \
#        --team-id NFQL267669 \
#        --password <the-app-specific-password>
#
# Then just re-run this script — it auto-detects both and notarizes.
# ─────────────────────────────────────────────────────────────────────────────
