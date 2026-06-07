#!/bin/bash
# Builds a Release Kright.app and packages it into a distributable Kright.dmg.
#
#   ./scripts/build-dmg.sh
#
# Output: Mac/build/Kright.dmg
#
# If a "Developer ID Application" certificate AND a stored notary profile
# (default name: kright-notary) are present, the DMG is Developer-ID signed,
# notarized by Apple, and stapled — so it opens with a normal double-click on
# any Mac. Otherwise it falls back to a plain dev-signed DMG (first launch on
# another Mac then needs a right-click → Open). See the one-time setup at the
# bottom of this file.
set -euo pipefail

cd "$(dirname "$0")/.."          # Mac/
ROOT="$(pwd)"
BUILD="$ROOT/build"
DD="$BUILD/dd"
STAGE="$BUILD/dmg"
DMG="$BUILD/Kright.dmg"
# Override these via env vars for your own Apple Developer account.
NOTARY_PROFILE="${KRIGHT_NOTARY_PROFILE:-kright-notary}"
APPLE_ID="${KRIGHT_APPLE_ID:-<your-apple-id-email>}"
TEAM_ID="${KRIGHT_TEAM_ID:-<your-team-id>}"

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
xcodebuild -project Kright.xcodeproj -scheme Kright -configuration Release \
  -derivedDataPath "$DD" build >/dev/null

APP="$DD/Build/Products/Release/Kright.app"
[ -d "$APP" ] || { echo "✗ App not found at $APP"; exit 1; }

if [ -n "$DEVID" ]; then
  echo "▸ Signing with: $DEVID (hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "Sources/Kright.entitlements" \
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
export KRIGHT_APP="$APP"
export KRIGHT_DMG_BG="/tmp/kright-dmg-bg.png"
swift scripts/gen-dmg-bg.swift "$KRIGHT_DMG_BG" >/dev/null
rm -f "$DMG"
STYLED=0

# Preferred: create-dmg drives Finder, which writes a .DS_Store with a modern
# bookmark that macOS resolves (dmgbuild's classic alias no longer renders on
# macOS 26+). NOTE: the first run prompts "Terminal wants to control Finder" —
# you must approve it, so run this script in YOUR Terminal at least once.
if command -v create-dmg >/dev/null 2>&1; then
  # create-dmg wants a source FOLDER containing just the app (it adds the
  # Applications drop-link itself).
  SRC="$BUILD/src"
  rm -rf "$SRC"; mkdir -p "$SRC"
  cp -R "$APP" "$SRC/"
  if create-dmg \
       --volname "Kright" \
       --background "$KRIGHT_DMG_BG" \
       --window-pos 200 120 \
       --window-size 660 440 \
       --icon-size 128 --text-size 13 \
       --icon "Kright.app" 180 250 \
       --app-drop-link 480 250 \
       --hide-extension "Kright.app" \
       --no-internet-enable \
       "$DMG" "$SRC" >/dev/null 2>&1 && [ -f "$DMG" ]; then
    STYLED=1
  else
    echo "  (create-dmg couldn't style — likely needs Finder Automation permission;"
    echo "   run this script in your own Terminal and approve the prompt.)"
    rm -f "$DMG"
  fi
fi

# Fallback: dmgbuild (headless, no permission) — lays out icons but its
# background may not render on macOS 26.
if [ "$STYLED" = 0 ]; then
  DMGBUILD="$(python3 -m site --user-base 2>/dev/null)/bin/dmgbuild"
  [ -x "$DMGBUILD" ] || DMGBUILD="$(command -v dmgbuild || true)"
  if [ -n "$DMGBUILD" ] && [ -x "$DMGBUILD" ]; then
    "$DMGBUILD" -s scripts/dmgbuild-settings.py "Kright" "$DMG" >/dev/null
  else
    hdiutil create -volname "Kright" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  fi
fi

# Always sign the DMG itself when a Developer ID cert is available, so it has a
# usable signature even if notarization can't run.
if [ -n "$DEVID" ]; then
  echo "▸ Signing DMG…"
  codesign --force --sign "$DEVID" --timestamp "$DMG"
fi

if [ -n "$DEVID" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "▸ Notarizing (this can take a few minutes)…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ Stapling…"
  xcrun stapler staple "$DMG"
  echo "✓ Done (notarized): $DMG"
else
  echo "✓ Done (signed, NOT notarized): $DMG"
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
#      xcrun notarytool store-credentials kright-notary \
#        --apple-id <your-apple-id-email> \
#        --team-id <your-team-id> \
#        --password <the-app-specific-password>
#
# Then just re-run this script — it auto-detects both and notarizes.
# ─────────────────────────────────────────────────────────────────────────────
