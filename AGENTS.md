# AGENTS.md

## Project

Aerospace Tabs is a companion for AeroSpace. It displays, focuses, and groups windows managed by AeroSpace; it does not own tiling or native macOS Spaces.

## Structure

- `Sources/AerospaceTabs/`: application code.
- `Sources/SessionPolicy/`: isolated session and permission logic.
- `Tests/`: unit tests.
- `Config/`: shared build settings and the app's `Info.plist`.
- `Resources/`: original icons and bundled third-party notices.
- `scripts/`: setup, bundle validation, and local release validation.
- `docs/`: product specification, usage, distribution, and credential guidance.
- `.github/workflows/`: CI and Release Please automation.

## Build and verification

Use Xcode 26.6 or newer and the Makefile interface. Xcode is the only app build system; Swift Package Manager is used by Xcode only to resolve the pinned Sparkle dependency.

```sh
make setup
make build
make run
make test
make bundle
make check
make release-check APP_BUILD_NUMBER=<new-increasing-number>
```

The first six commands require no distribution credentials. `make release-check` requires a Developer ID Application identity, Apple notarization credentials, and this app's Sparkle EdDSA key. It only creates files under `.build/release`; it does not publish.

## Compatibility and scope

- Preserve bundle ID `com.pedrotmr.AerospaceTabs`, the Accessibility requirement, and persisted settings.
- The app requires a running AeroSpace. It temporarily adjusts the AeroSpace top outer gap; keep recovery behavior covered.
- Treat the private MultitouchSupport integration as fragile and document its limits.
- Keep Sparkle keys app-specific. Do not share them with another product.
- Do not add a second build system or copy private windows, paths, repositories, or credentials into docs or screenshots.

## Contribution practices

Make focused changes, add tests for critical logic, and run `make check`. Follow [CONTRIBUTING.md](CONTRIBUTING.md) for issue reports and pull requests. Keep documentation plain and brief, and preserve the project's best-effort maintenance status.
