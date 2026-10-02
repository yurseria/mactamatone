# Update distribution

[README](../README.md) · English / [한국어](UPDATES_KO.md)

## User flow

Settings show the app version and build number from `Info.plist`. Checking for updates requests the latest stable release from the repository's GitHub API. Drafts, prereleases, invalid version tags, releases without the expected Apple Silicon DMG, and download URLs outside this repository are rejected. Numeric version comparison prevents 0.10.0 from being treated as older than 0.9.0.

Checks happen only when requested. Offline or failed requests leave a retry button. A newer release exposes **Update and restart** and a link to its release page. Development executables can check releases but cannot replace themselves; use a built `.app` to install updates.

## Installation routing

- **Homebrew:** resolve the running bundle's symlinks and inspect `Caskroom/mactamatone` receipts, including links back to apps moved into `/Applications`. Run `brew update` followed by `brew upgrade --cask yurseria/tap/mactamatone`, without invoking a shell. Verify the installed version before relaunching `/Applications/Mactamatone.app`. Homebrew retains ownership of its installation and metadata. If the tap has not caught up to the release yet, installation stays retryable.
- **Direct app installation:** use [Sparkle 2](https://sparkle-project.org/documentation/). Its native flow downloads the signed DMG, verifies the update, installs it, and relaunches the app. The installer handles application replacement and any required authorization.

Only the user-initiated install action can start installation. Automatic checks and automatic installation are disabled in `Info.plist`.

## Signing and release feed

The Sparkle dependency is pinned in `Package.swift` and `Package.resolved`. `build.sh` embeds its framework, preserving symlinks and helper permissions. `SUPublicEDKey` contains the public Ed25519 key; `SUFeedURL` points to the stable release's `appcast.xml` asset.

The app-specific private key is held in the login Keychain under account `app.mactamatone.updates`. Back it up securely; replacing or losing it can prevent existing installations from trusting new updates. Only the public key belongs in this repository.

The release workflow requires a GitHub Actions secret named `SPARKLE_PRIVATE_KEY`. Configuring that secret involves exporting the private key to the project repository's secret store and requires explicit authorization. It is not configured by the local build or feed-generation scripts.

On an authorized CI run, `generate-update-feed.sh` passes the key to Sparkle through standard input, generates a signed enclosure for the DMG, and publishes `appcast.xml` beside the archive. Neither the key nor a key file is placed in release assets. The feed URL follows GitHub's latest stable release, so each future stable release must include the feed asset.

For local packaging with the Keychain key:

```sh
./scripts/package-dmg.sh
./scripts/generate-update-feed.sh
```

This creates `dist/appcast.xml`; it does not publish a release. Existing 0.4.0 and earlier downloads do not include the updater. Their first upgrade to a release containing this feature must be installed through Homebrew or a DMG.

## Verification

```sh
./scripts/verify-updates.sh
# Optional live GitHub check:
./scripts/verify-updates.sh --live
```

Checks use synthetic release responses and temporary fixtures to cover version ordering, release validation, update states, duplicate checks, Homebrew symlinks, and subprocess success/failure with large output. They never run a real Homebrew upgrade or replace an installed app.
