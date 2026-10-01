#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

source="${1:-design/AppIcon/Music-source.png}"
output="${2:-Sources/Mactamatone/Resources/AppIcon.icns}"
preview="${3:-design/AppIcon/Music.png}"
if [[ ! -f "$source" ]]; then
  echo "Missing icon artwork: $source" >&2
  exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
swift scripts/prepare-app-icon.swift "$source" "$work/Normalized.png"
source="$work/Normalized.png"
mkdir -p "${output:h}" "${preview:h}"
cp "$source" "$preview"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$output" "$iconset"
echo "Prepared: $output"
