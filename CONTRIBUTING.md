# Contributing

Development is paused. Issues and pull requests are welcome on a best-effort basis; there is no response time or release promise.

## Report a problem

Open a [GitHub issue](https://github.com/pedrotmr/aerospace-tabs/issues) with macOS and AeroSpace versions, expected and actual behavior, reproduction steps, and relevant error messages. Remove personal window titles, file paths, and private repository details from logs and screenshots.

## Prepare and verify

Install Xcode 26.6 or newer with the macOS platform. Git is required for source work. Homebrew is optional. Run the same commands used by CI:

```sh
make setup
make build
make run
make test
make bundle
make check
```

`make setup` resolves Sparkle 2.10.1. `make check` runs the test suite and verifies a universal app bundle, including its icon and Sparkle framework. These commands need no signing credentials. `make release-check APP_BUILD_NUMBER=<new-number>` creates local signed, notarized artifacts and never publishes them. See [Build and release](docs/BUILD-AND-RELEASE.md) for requirements and credential setup.

Open a pull request against `main`. Describe the visible behavior change and the checks you ran. For UI changes, capture the real app with fictional local data; do not include personal or private repository information. Keep changes within the companion's scope: Aerospace Tabs reads and focuses AeroSpace windows, while AeroSpace owns tiling and layout. See the [specification](docs/SPEC.md) and [project charter](docs/CHARTER.md).
