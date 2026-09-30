#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "An Apple Silicon host is required to package the Homebrew release." >&2
  exit 1
fi

./build.sh
app="dist/Mactamatone.app"
archs=$(lipo -archs "$app/Contents/MacOS/Mactamatone")
if [[ "$archs" != "arm64" ]]; then
  echo "Expected an arm64 app, found: $archs" >&2
  exit 1
fi

asset="dist/Mactamatone_${version}_aarch64.dmg"
hdiutil create -volname Mactamatone -srcfolder "$app" -ov -format UDZO "$asset"
shasum -a 256 "$asset"
echo "Packaged: $asset"
