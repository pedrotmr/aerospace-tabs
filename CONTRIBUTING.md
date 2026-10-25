# Contributing

Development is paused. Issues and pull requests remain welcome, but review is best effort; there is no response time or release promise.

## Report a problem

Open a [GitHub issue](https://github.com/pedrotmr/aerospace-tabs/issues) with:

- macOS and AeroSpace versions
- what you expected and what happened
- steps to reproduce, plus relevant error messages

Remove personal window titles, file paths, and other private details before sharing logs or screenshots.

## Build and verify

The app requires macOS 14 or later and a running AeroSpace installation. For source work, install the Xcode Command Line Tools, then run:

```sh
swift build -c release
swift test
```

To assemble and launch the app bundle locally, run `make run`. CI runs the release build and Swift test suite on macOS.

Keep changes focused on the companion's scope: Aerospace Tabs reads and focuses AeroSpace windows; AeroSpace remains responsible for tiling and layout. See [the charter](CHARTER.md) and [Window Overview behavior](WINDOW-OVERVIEW.md).
