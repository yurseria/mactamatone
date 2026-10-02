#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

packaged_input="${1:-$PWD/dist/Mactamatone.app}"
packaged_input="${packaged_input:A}"
work=$(mktemp -d)
mounted=0
cleanup() {
  if (( mounted )); then hdiutil detach -quiet "$work/Mounted" || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
if [[ "$packaged_input" == *.dmg ]]; then
  mkdir "$work/Mounted"
  hdiutil attach "$packaged_input" -readonly -nobrowse -quiet -mountpoint "$work/Mounted"
  mounted=1
  packaged_input="$work/Mounted/Mactamatone.app"
fi
installed_app="$work/Installed App/Mactamatone.app"
ditto "$packaged_input" "$installed_app"
codesign --verify --deep --strict "$installed_app"
# Run the real production binary in an independent installation, never the
# Swift checks' substitute Bundle.module or the source/build directory.
cd "$work"
env -u PACKAGE_RESOURCE_BUNDLE_PATH -u PACKAGE_RESOURCE_BUNDLE_URL \
  "$installed_app/Contents/MacOS/Mactamatone" --verify-bundled-resources
