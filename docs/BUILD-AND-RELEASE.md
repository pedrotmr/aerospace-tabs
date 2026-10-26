# Build and release

## Toolchain

- macOS 14 or later to run Aerospace Tabs.
- Xcode 26.6 or newer with the macOS platform. The current project uses Xcode's build system and its bundled Swift toolchain in Swift 5 language mode.
- AeroSpace is required at runtime. Git and Homebrew are optional for the application.
- Sparkle 2.10.1 is pinned in `AerospaceTabs.xcodeproj`; `make setup` resolves it.

The app bundle is universal (`arm64` and `x86_64`). Its minimum system version is 14.0. The app's bundle identifier is `com.pedrotmr.AerospaceTabs`.

The original ICNS and its bundle validation are documented in [App icon](ICONS.md).

## Build system

Xcode is the only app build system. SwiftPM is useful for portable libraries and command-line builds, but it does not own these apps' asset catalogs, app metadata, previews, test schemes, framework embedding, or macOS signing flow. Xcode handles those in one project; SwiftPM only resolves the exact Sparkle 2.10.1 dependency. The trade-off is that app development and builds require macOS and Xcode. The Makefile gives both apps the same local and CI commands, and each checkout keeps its build products under `.build/`.

Xcode owns the app target, resources, Info.plist processing, tests, previews, Sparkle embedding, and code signing. There is no SwiftPM app package or second official build path. Shared compiler, architecture, team, and deployment settings live in `Config/Project.xcconfig`; product metadata lives in `Config/App.xcconfig` and `Config/Info.plist`.

## Standard commands

```sh
make setup
make build
make run
make test
make bundle
make check
```

These commands work without signing credentials. `make setup` resolves Sparkle. `make run` opens the Debug app. `make bundle` builds and checks an unsigned universal Release app in `.build/DerivedData`. `make check` is the CI command; it runs tests and verifies the app's metadata, icon, Sparkle framework, runtime path, and architecture slices.

To validate local Developer ID distribution without publishing, provide a new increasing build number:

```sh
make release-check APP_BUILD_NUMBER=18
```

This requires a Developer ID Application identity in Keychain, Apple notary credentials, and Aerospace Tabs' EdDSA private key in Keychain or ignored `.env`. It creates a ZIP, DMG, appcast, and validation logs under `.build/release`. It never uploads or publishes. See [Credentials](CREDENTIALS.md). Base64 is encoding, not encryption.

## Version and release flow

Release Please reads `.release-please-manifest.json` and `CHANGELOG.md`; Conventional Commit messages drive the next marketing version. Its `extra-files` updater writes the same version into `Config/App.xcconfig`, which feeds Xcode and the Makefile. `make setup` fails if those values drift. `CFBundleVersion` is the monotonically increasing workflow run number. Local release checks must receive an explicit number greater than previous published builds.

On `main`, Release Please opens or updates a draft version PR. Merging it creates a draft GitHub release and tag in that workflow. The workflow checks out the tag, runs `make check`, signs Sparkle's nested updater and framework from the inside out, signs the app, notarizes the DMG, validates Apple's result and log, staples the app and DMG, and tests the app extracted from the final ZIP. It attaches the versioned ZIP, DMG, and `appcast.xml` to the draft. It does not publish. A manual workflow run may rebuild only an existing draft.

Review the draft and publish it manually in GitHub when it is ready. The app uses the stable feed URL `https://github.com/pedrotmr/aerospace-tabs/releases/latest/download/appcast.xml`. Drafts are not returned as the latest public release, so a draft appcast cannot move the public feed. When you publish a stable release, the Homebrew workflow checks that release's ZIP, calculates its SHA-256, audits the cask, and pushes it to the tap. It needs `HOMEBREW_TAP_TOKEN` with write access to that tap.

The direct ZIP contains the stapled app bundle; the ZIP itself is not stapled. The cask downloads that same ZIP and uses its real SHA-256. Do not replace assets after a release is published; make a new version. The app release workflow avoids running from both tag push and release-published events.

## Update paths

Homebrew users should use `brew update && brew upgrade`. The public v0.1.2 cask points to a build without Sparkle, so that cask does not declare `auto_updates` yet. The tap adds that stanza when it syncs a Sparkle-enabled published build. The cask marks its install in a separate UserDefaults domain; the app reads this marker before starting Sparkle and removes it when Homebrew uninstalls the app.

Homebrew 7.0.11 documentation and code confirm that ordinary `brew upgrade` avoids downgrading a readable self-updating app when Sparkle has made it newer than the cask. `brew upgrade --cask pedrotmr-aerospace-tabs`, `--greedy`, and `--greedy-auto-updates` can reinstall an older cask version. Use plain `brew upgrade`.

The published v0.1.2 app has no Sparkle framework, so it cannot self-update. Direct users must download and install a later version manually; a Sparkle-enabled build can update direct installs after it is published.
