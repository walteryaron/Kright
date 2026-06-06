#!/bin/bash
# Regenerates Sources/Assets.xcassets/AppIcon.appiconset from the keyboard icon
# renderer. Run from KysyNative/:  ./scripts/make-appicon.sh
set -euo pipefail
cd "$(dirname "$0")/.."        # KysyNative/

MASTER="/tmp/kysy-icon-1024.png"
SET="Sources/Assets.xcassets/AppIcon.appiconset"

echo "▸ Rendering master…"
swift scripts/gen-appicon.swift "$MASTER" >/dev/null

echo "▸ Slicing sizes…"
mkdir -p "$SET"
for px in 16 32 64 128 256 512 1024; do
  sips -z "$px" "$px" "$MASTER" --out "$SET/icon_${px}.png" >/dev/null
done

cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom":"mac", "size":"16x16",   "scale":"1x", "filename":"icon_16.png" },
    { "idiom":"mac", "size":"16x16",   "scale":"2x", "filename":"icon_32.png" },
    { "idiom":"mac", "size":"32x32",   "scale":"1x", "filename":"icon_32.png" },
    { "idiom":"mac", "size":"32x32",   "scale":"2x", "filename":"icon_64.png" },
    { "idiom":"mac", "size":"128x128", "scale":"1x", "filename":"icon_128.png" },
    { "idiom":"mac", "size":"128x128", "scale":"2x", "filename":"icon_256.png" },
    { "idiom":"mac", "size":"256x256", "scale":"1x", "filename":"icon_256.png" },
    { "idiom":"mac", "size":"256x256", "scale":"2x", "filename":"icon_512.png" },
    { "idiom":"mac", "size":"512x512", "scale":"1x", "filename":"icon_512.png" },
    { "idiom":"mac", "size":"512x512", "scale":"2x", "filename":"icon_1024.png" }
  ],
  "info" : { "version":1, "author":"xcode" }
}
JSON

# Top-level asset catalog manifest (created once).
cat > "Sources/Assets.xcassets/Contents.json" <<'JSON'
{ "info" : { "version":1, "author":"xcode" } }
JSON

echo "✓ Wrote $SET"
