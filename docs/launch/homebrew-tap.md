# Personal Homebrew tap

## Decision and release contract

Use a personal tap for the first Homebrew distribution. Homebrew's shared Package Acceptance Policy says software that does not meet the official-tap criteria can generally be maintained in a third-party tap; that tap is maintained by its owner and is not endorsed or supported by Homebrew. The official self-submission notability threshold is 225 stars, 90 forks, or 90 watchers, with case-by-case exceptions. See [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy) and [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks).

Issue [#10](https://github.com/pedrotmr/aerospace-tabs/issues/10) is still open, and there is no GitHub Release yet. It calls for an `.app` or zip but does not settle the asset name, release tag, checksum, or supported CPU architectures. Use this release contract so the cask URL stays stable:

- Publish a non-prerelease GitHub Release with `AerospaceTabs.zip` as an asset.
- Put `AerospaceTabs.app` at the root of the zip. Sign and notarize the app before packaging it.
- Make the app universal for Apple silicon and Intel, or publish separate architecture-specific assets and use matching cask URL and checksum blocks. The current `make build` builds for the machine running Swift; it does not create a universal binary.
- Keep the asset filename stable across releases. The cask below uses GitHub's latest-release download URL; for a version-pinned cask, use the versioned release URL and the actual SHA-256 instead.

The tap repository name is `homebrew-aerospace-tabs`, which Homebrew maps from `brew tap pedrotmr/aerospace-tabs`. This task prepares the cask content only; the tap repository and release remain separate launch steps.

## Cask file for the tap

Save as `Casks/pedrotmr-aerospace-tabs.rb` in `pedrotmr/homebrew-aerospace-tabs`. The username prefix gives the cask a globally distinctive token. `version :latest` and `sha256 :no_check` make the file independent of an unpublished version and checksum. `:no_check` skips archive checksum verification, so replace it with the published SHA-256 and pin a version before switching to a versioned release workflow.

```ruby
cask "pedrotmr-aerospace-tabs" do
  version :latest
  sha256 :no_check

  url "https://github.com/pedrotmr/aerospace-tabs/releases/latest/download/AerospaceTabs.zip"
  name "Aerospace Tabs"
  desc "Window tabs and overview for AeroSpace"
  homepage "https://github.com/pedrotmr/aerospace-tabs"

  depends_on macos: ">= :sonoma"

  app "AerospaceTabs.app"

  caveats <<~EOS
    Requires AeroSpace to be installed and running.
    Accessibility permission enables global shortcuts and Dock notification badges.
    Screen Recording permission is optional and enables window previews.
  EOS
end
```

This uses the Cask Cookbook's required identity and download stanzas plus an `app` artifact. `version :latest` tracks the latest stable GitHub Release; the Cookbook says `livecheck` is not used with that version value. If the release does not use the asset name and app path above, update the cask to match the published artifact before launch. If the release is not universal, add architecture-specific URLs and real checksums rather than advertising support for both CPU families.

## README install line

Add this to the README's install section after the tap and its first release are available:

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

The fully qualified cask name installs the requested item from the third-party tap. A separate `brew tap pedrotmr/aerospace-tabs` is optional. Homebrew's tap naming and trust behavior are documented in [Taps](https://docs.brew.sh/Taps) and [Tap Trust](https://docs.brew.sh/Tap-Trust). Cask definitions are Ruby code and can run with the user's privileges, so users should only install a tap they trust.

## Gatekeeper and notarization

[Acceptable Casks](https://docs.brew.sh/Acceptable-Casks) requires macOS apps in the official cask tap to pass Gatekeeper checks and forbids requiring Gatekeeper or System Integrity Protection to be disabled or bypassed. That is an official-tap acceptance rule, but the same Gatekeeper behavior affects people installing from a personal tap. Do not ask users to remove quarantine or turn off Gatekeeper to launch this app.

The current [Makefile](../../Makefile) signs the app with the first local codesigning identity it finds, or ad-hoc (`-`) when none is installed. That is suitable for local development, not the release artifact. Its signing command also does not enable the hardened runtime or perform notarization. Before publishing the zip:

1. Sign the app with an Apple Developer ID Application certificate, hardened runtime, and a secure timestamp. Include only the entitlements the app needs.
2. Submit the signed app to Apple's notary service with `notarytool`, wait for acceptance, and review the notary log.
3. Staple the ticket to `AerospaceTabs.app` with `stapler`, validate the stapled app, then create the zip from that app.
4. Check the release artifact with Gatekeeper on a clean macOS account and calculate a SHA-256 for the cask if switching it to a pinned version.

Apple describes the [Developer ID and notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and how [Gatekeeper checks downloaded apps](https://support.apple.com/guide/security/sec5599b66df/web). Notarization is Apple's automated malware and code-signing check; it is not App Review. Stapling the ticket to the app lets Gatekeeper verify the notarization when the Mac is offline.

## References

- Project inputs: [README](../../README.md), [Makefile](../../Makefile), [release issue #10](https://github.com/pedrotmr/aerospace-tabs/issues/10)
- Homebrew: [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy), [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks), [Taps](https://docs.brew.sh/Taps), [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- Apple: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Gatekeeper and runtime protection](https://support.apple.com/guide/security/sec5599b66df/web)
