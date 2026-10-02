#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
bundle="$PWD/dist/Mactamatone.app/Contents/Resources/Mactamatone_Mactamatone.bundle"
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
swiftc -g -D THEME_CHECKS -parse-as-library -I "$work" -F "$framework" \
  Sources/Mactamatone/*.swift Tests/MactamatoneTests/UpdateChecks.swift \
  "$work/AudioControls.o" -framework AVFoundation -framework IOKit -framework Sparkle \
  -Xlinker -rpath -Xlinker "$framework" -o "$work/check-updates"
"$work/check-updates" "$bundle" "$@"
