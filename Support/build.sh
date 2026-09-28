#!/bin/zsh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
app="$root/Wake.app"
sdk=$(xcrun --show-sdk-path)

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$root/build/AppIcon.iconset"

swiftc -O -parse-as-library -target arm64-apple-macos26.0 -sdk "$sdk" \
  -framework AppKit -framework SwiftUI \
  -o "$app/Contents/MacOS/Wake" \
  "$root/Sources/Icon.swift" \
  "$root/Sources/Packet.swift" \
  "$root/Sources/Store.swift" \
  "$root/Sources/Panel.swift" \
  "$root/Sources/WakeApp.swift"

swiftc -O -target arm64-apple-macos26.0 -sdk "$sdk" -framework AppKit \
  -o "$root/build/export-icon" \
  "$root/Sources/Icon.swift" \
  "$root/Support/ExportMain.swift"
"$root/build/export-icon" "$root/build/AppIcon.iconset"

iconutil -c icns "$root/build/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp "$root/Support/Info.plist" "$app/Contents/Info.plist"
codesign --force --sign - "$app" >/dev/null
echo "$app"
