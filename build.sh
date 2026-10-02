#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

swift build -c release
app="dist/Mactamatone.app"
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources"
mkdir -p "$app/Contents/Frameworks"
framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
# ditto retains Sparkle's framework symlinks and executable helper permissions.
ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
cp docs/licenses/Sparkle.txt "$app/Contents/Resources/Sparkle-LICENSE.txt"
cp .build/release/Mactamatone "$app/Contents/MacOS/Mactamatone"
resources="$app/Contents/Resources/Mactamatone_Mactamatone.bundle"
rm -rf "$resources"
ditto .build/release/Mactamatone_Mactamatone.bundle "$resources"
cp Sources/Mactamatone/Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built: $app"
