#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

bundle="$PWD/dist/Mactamatone.app/Contents/Resources/Mactamatone_Mactamatone.bundle"
if [[ ! -d "$bundle" ]]; then
  echo 'Build the app with ./build.sh first.' >&2
  exit 1
fi
framework="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/module.modulemap" <<MODULE
module AudioControls {
  header "$PWD/Sources/AudioControls/include/AudioControls.h"
  export *
}
MODULE
clang -c Sources/AudioControls/AudioControls.c -I Sources/AudioControls/include -o "$work/AudioControls.o"
swiftc -O -D THEME_CHECKS -parse-as-library -I "$work" -F "$framework" \
  Sources/Mactamatone/*.swift scripts/capture-readme-screenshots.swift \
  "$work/AudioControls.o" -framework AVFoundation -framework IOKit -framework Sparkle -Xlinker -rpath -Xlinker "$framework" -o "$work/capture-readme"
"$work/capture-readme" "$bundle" "$PWD/docs/images"
