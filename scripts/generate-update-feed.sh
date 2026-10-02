#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
archive="dist/Mactamatone_${version}_aarch64.dmg"
tools="$PWD/.build/artifacts/sparkle/Sparkle/bin"
if [[ ! -f "$archive" ]]; then
  echo 'Package the app with ./scripts/package-dmg.sh first.' >&2
  exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$archive" "$work/"
args=(--download-url-prefix "https://github.com/yurseria/mactamatone/releases/download/v${version}/"
      --link 'https://github.com/yurseria/mactamatone'
      --maximum-deltas 0 --maximum-versions 1 -o "$work/appcast.xml")
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  # Keep the CI secret in stdin rather than arguments or a file.
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tools/generate_appcast" --ed-key-file - "${args[@]}" "$work"
else
  "$tools/generate_appcast" --account app.mactamatone.updates "${args[@]}" "$work"
fi
cp "$work/appcast.xml" dist/appcast.xml
echo 'Prepared: dist/appcast.xml'
