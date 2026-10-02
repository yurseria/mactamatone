# Development

[README](../README.md) · English / [한국어](DEVELOPMENT_KO.md)

## Build and run

Install Xcode Command Line Tools. From the repository root:

```sh
./build.sh
open dist/Mactamatone.app
```

For development, `swift run Mactamatone` also works. The build script assembles the app bundle, copies its resources and icon, and applies an ad hoc signature.

## Installation and signing

Published DMGs target Apple Silicon and require macOS 14 or later. The app is ad hoc signed and is not Apple notarized. The [Homebrew cask](https://github.com/yurseria/homebrew-tap) removes the installed app's quarantine attribute, following the tap's existing setup. Install it only if you trust this project and its source.

If the lid-angle sensor is unavailable, the app switches to manual play; see [Implementation](IMPLEMENTATION.md) for compatibility details.

## Verification

Build the app first, then run:

```sh
./scripts/verify-themes.sh
./scripts/verify-updates.sh
```

The native checks cover language persistence and translations, six themes and five mouth positions, light settings controls under Dark Mode, the 25°–130° pitch range, the mute boundary, offline audio metering, and playback glow behavior. UI previews are written to `dist/theme-previews/`. Audio checks use offline rendering without playing through the speakers.

## README screenshots

```sh
./scripts/capture-readme-screenshots.sh
```

The capture tool loads the app's actual widget and settings views using isolated preferences. It shows the Galaxy theme in manual play, captures English and Korean versions separately, places the widget on a neutral dark surface for readability, and writes the four PNGs to `docs/images/`. The audio visualization is driven by offline-rendered audio, without changing your saved settings or making sound.

It first attempts native window screenshots with `screencapture`. If screen capture is unavailable, it saves native AppKit/SwiftUI view snapshots instead. The committed images were captured with this fallback; WindowServer effects such as Liquid Glass may be absent. On a desktop with screen-capture access, rerun the command to capture those effects too.

## Artwork and app icon

- [App icon](../design/AppIcon/README.md): the supplied logo, ICNS generation, and earlier alternatives.
- [Themes](../design/Themes/README.md): source artwork and cutout generation.
- [Backgrounds](../design/Backgrounds/README.md): separate scene assets.

Verify the actual production app or DMG in a temporary installation, without starting audio or windows:

```sh
./scripts/verify-packaged-app.sh
./scripts/verify-packaged-app.sh dist/Mactamatone_VERSION_aarch64.dmg
```

This checks the app icon, both languages, and every theme using the packaged executable. Release CI runs the DMG check before publication. Packaged apps resolve resources inside `Contents/Resources`; development executables retain SwiftPM resource lookup.

## Releases

Set `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`. A pushed `vX.Y.Z` tag must match the short version string. The release workflow builds an Apple Silicon DMG and publishes it to [GitHub Releases](https://github.com/yurseria/mactamatone/releases).

To package a DMG locally:

```sh
./scripts/package-dmg.sh
```

The [Homebrew tap](https://github.com/yurseria/homebrew-tap) checks stable releases and updates the cask version and checksum automatically.

## In-app updates

See [Update distribution](UPDATES.md) for installation routing, Sparkle signing keys, and the release feed. To generate a feed locally, package a DMG and run `./scripts/generate-update-feed.sh`. Private signing keys are kept in Keychain and must never be committed.
