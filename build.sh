#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

swift build -c release
app="dist/Mactamatone.app"
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources"
cp .build/release/Mactamatone "$app/Contents/MacOS/Mactamatone"
cp -R .build/release/Mactamatone_Mactamatone.bundle "$app/Contents/Resources/"
cp Sources/Mactamatone/Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built: $app"
