#!/bin/bash
# Generates / updates the Sparkle appcast for a released Kright.dmg.
#
#   ./scripts/gen-appcast.sh <version> [path/to/Kright.dmg]
#
# Example:
#   ./scripts/gen-appcast.sh 1.1.0
#   ./scripts/gen-appcast.sh 1.1.0 build/Kright.dmg
#
# What it does:
#   1. Copies the DMG into a clean staging folder.
#   2. Runs Sparkle's `generate_appcast`, which EdDSA-signs the DMG with the
#      PRIVATE key stored in your login keychain (created by `generate_keys`)
#      and writes the signature + version info into appcast.xml.
#   3. Points each download URL at that version's GitHub Release asset.
#
# Output: <repo-root>/appcast.xml  (commit it to `main` — that's the SUFeedURL).
#
# Release flow:
#   1) Bump MARKETING_VERSION (+ CURRENT_PROJECT_VERSION) in Mac/project.yml,
#      then `xcodegen generate`.
#   2) ./scripts/build-dmg.sh                      # signed + notarized DMG
#   3) gh release create vX.Y.Z … && gh release upload vX.Y.Z build/Kright.dmg
#   4) ./scripts/gen-appcast.sh X.Y.Z              # updates appcast.xml
#   5) git add appcast.xml && git commit && git push   # publishes the feed
set -euo pipefail

cd "$(dirname "$0")/.."                 # Mac/
ROOT="$(pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"

VERSION="${1:-}"
DMG="${2:-$ROOT/build/Kright.dmg}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version> [path/to/Kright.dmg]" >&2; exit 1
fi
[ -f "$DMG" ] || { echo "✗ DMG not found: $DMG" >&2; exit 1; }

# GitHub owner/repo + tag → release download URL prefix.
OWNER_REPO="walteryaron/Kright"
TAG="v$VERSION"
DL_PREFIX="https://github.com/$OWNER_REPO/releases/download/$TAG/"
WEBSITE="https://github.com/$OWNER_REPO"

# Locate Sparkle's generate_appcast + sign_update (downloaded by SPM into DerivedData).
find_tool() { find "$HOME/Library/Developer/Xcode/DerivedData" -path "*artifacts/sparkle/Sparkle/bin/$1" 2>/dev/null | head -1; }
GA="$(find_tool generate_appcast)"
SU="$(find_tool sign_update)"
[ -x "$GA" ] || { echo "✗ generate_appcast not found — open the project in Xcode or run a build to fetch Sparkle." >&2; exit 1; }

STAGE="$ROOT/build/appcast"
rm -rf "$STAGE"; mkdir -p "$STAGE"
# The asset on the GitHub Release is named Kright.dmg, so keep that filename:
# the appcast URL becomes <DL_PREFIX>Kright.dmg.
cp "$DMG" "$STAGE/Kright.dmg"

echo "▸ Generating appcast for $TAG …"
"$GA" \
  --download-url-prefix "$DL_PREFIX" \
  --link "$WEBSITE" \
  -o "$REPO_ROOT/appcast.xml" \
  "$STAGE"

# generate_appcast deliberately omits sparkle:edSignature for notarized
# Developer-ID DMGs (Sparkle can validate those via the Apple code signature).
# We add the EdDSA signature anyway — belt-and-suspenders, and required if a
# client has SUPublicEDKey set. sign_update reads the private key from the
# Keychain (the first run prompts "Always Allow"); for headless/CI runs set
# KRIGHT_EDDSA_KEY_FILE to an exported key file (`generate_keys -x <file>`).
if ! grep -q "sparkle:edSignature" "$REPO_ROOT/appcast.xml"; then
  echo "▸ Adding EdDSA signature (DMG was code-signature-only)…"
  if [ -n "${KRIGHT_EDDSA_KEY_FILE:-}" ]; then
    SIG_LINE="$("$SU" --ed-key-file "$KRIGHT_EDDSA_KEY_FILE" "$DMG")"
  else
    SIG_LINE="$("$SU" "$DMG")"
  fi
  # sign_update prints: sparkle:edSignature="…" length="…"  — keep just the attr.
  SIG="$(printf '%s' "$SIG_LINE" | grep -o 'sparkle:edSignature="[^"]*"')"
  [ -n "$SIG" ] || { echo "✗ Could not obtain EdDSA signature from sign_update." >&2; exit 1; }
  # Inject it into the <enclosure …/> tag (awk avoids sed delimiter clashes with base64).
  awk -v sig="$SIG" '/<enclosure / && $0 !~ /sparkle:edSignature/ { sub(/\/>/, " " sig "/>") } { print }' \
      "$REPO_ROOT/appcast.xml" > "$REPO_ROOT/appcast.xml.tmp" && mv "$REPO_ROOT/appcast.xml.tmp" "$REPO_ROOT/appcast.xml"
fi

echo "✓ Wrote $REPO_ROOT/appcast.xml"
echo "  → review it, then: git add appcast.xml && git commit && git push"
