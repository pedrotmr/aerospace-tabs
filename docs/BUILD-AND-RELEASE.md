# Build and release

## Toolchain

- macOS 14 or later to run AeroSpaceTabs.
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

These commands work without distribution credentials. `make setup` resolves Sparkle. `make run` signs the Debug app with the first available Apple Development identity before opening it, so macOS can keep its permissions across rebuilds. This development identity is separate from the Developer ID signature used by Homebrew, so the Debug app may need its own one-time permission grant. If no Apple Development identity is installed, `make run` opens the unsigned Debug app and warns that macOS may re-prompt after each build. `make bundle` builds and checks an unsigned universal Release app in `.build/DerivedData`. `make check` is the CI command; it runs tests and verifies the app's metadata, icon, Sparkle framework, runtime path, and architecture slices.

To validate local Developer ID distribution without publishing, provide a new increasing build number:

```sh
make release-check APP_BUILD_NUMBER=18
```

This requires a Developer ID Application identity in Keychain, Apple notary credentials, and AeroSpaceTabs' EdDSA private key in Keychain or ignored `.env`. It creates a ZIP, DMG, appcast, and validation logs under `.build/release`. It sends the DMG to Apple for notarization, but does not upload files to GitHub or publish a release. See [Credentials](CREDENTIALS.md). Base64 is encoding, not encryption.

## Version and release flow

Release Please reads `.release-please-manifest.json` and `CHANGELOG.md`; Conventional Commit messages drive the next marketing version. Its `extra-files` updater writes the same version into `Config/App.xcconfig`, which feeds Xcode and the Makefile. `make setup` fails if those values drift. `CFBundleVersion` is the monotonically increasing workflow run number. Local release checks must receive an explicit number greater than previous published builds.

On `main`, Release Please opens or updates a draft version PR. Merging it creates a draft GitHub release and tag in that workflow. The workflow checks out the tag, runs `make check`, signs Sparkle's nested updater and framework from the inside out, signs the app, notarizes the DMG, validates Apple's result and log, staples the app and DMG, and tests the app extracted from the final ZIP. It attaches the versioned ZIP, DMG, and `appcast.xml` to the draft. It does not publish. A manual workflow run may rebuild only an existing draft.

GitHub gates signing jobs with the `signed-distribution` environment. Its deployment branch policy allows `main`; signing credentials stay in repository secrets.

Review the draft and publish it manually in GitHub when it is ready. The app uses the stable feed URL `https://github.com/pedrotmr/aerospace-tabs/releases/latest/download/appcast.xml`. Drafts are not returned as the latest public release, so a draft appcast cannot move the public feed. When you publish a stable release, the Homebrew workflow checks that release's ZIP, calculates its SHA-256, audits the cask, and pushes it to the tap. It needs `HOMEBREW_TAP_TOKEN` with write access to that tap.

The direct ZIP contains the stapled app bundle; the ZIP itself is not stapled. The cask downloads that same ZIP and uses its real SHA-256. Do not replace assets after a release is published; make a new version. The app release workflow avoids running from both tag push and release-published events.

## Update paths

Homebrew users can update the cask in Terminal or choose an in-app Sparkle update when one is available. The tap has a cask for the latest stable release:

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
brew update
brew upgrade --cask --greedy-auto-updates pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

The cask sets `auto_updates true`. Homebrew's [`--greedy-auto-updates` option](https://docs.brew.sh/Manpage#upgrade-options-installed_formulainstalled_cask-) includes this cask while the command targets only AeroSpaceTabs. The cask writes a Homebrew marker. Sparkle stays idle on launch, but **Check for Updates…** can probe the feed when requested.

Direct downloads can check for updates from **Check for Updates…** in the app. The v0.1.2 direct build has no Sparkle updater, so users on that version must install v0.2.0 or later manually once. Later direct releases can update with Sparkle.

To switch the same app copy from Homebrew to a direct download, uninstall the cask first:

```sh
brew uninstall --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

Then install the downloaded app. The cask removes its Homebrew marker when it uninstalls.
