# Personal Homebrew tap

## Decision and release contract

Use a personal tap for the first Homebrew distribution. Homebrew's shared Package Acceptance Policy says software that does not meet the official-tap criteria can generally be maintained in a third-party tap; that tap is maintained by its owner and is not endorsed or supported by Homebrew. The official self-submission notability threshold is 225 stars, 90 forks, or 90 watchers, with case-by-case exceptions. See [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy) and [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks).

Issue [#10](https://github.com/pedrotmr/aerospace-tabs/issues/10) is still open, and there is no GitHub Release yet. It calls for an `.app` or zip but does not settle the asset name, release tag, checksum, or supported CPU architectures. Use this release contract so the cask URL stays stable:

- Publish a non-prerelease GitHub Release with a `v<version>` tag and `AerospaceTabs.zip` as an asset. The current `Resources/Info.plist` version is `0.1.0`, so `v0.1.0` is the proposed first tag.
- Put `AerospaceTabs.app` at the root of the zip. Sign and notarize the app before packaging it.
- Make the app universal for Apple silicon and Intel, or publish separate architecture-specific assets and use matching cask URL and checksum blocks. The current `make build` builds for the machine running Swift; it does not create a universal binary.
- Keep the asset filename stable across releases. Update the tap cask's version and SHA-256 for each release so ordinary `brew upgrade` can detect and install updates.

The tap repository name is `homebrew-aerospace-tabs`, which Homebrew maps from `brew tap pedrotmr/aerospace-tabs`. This task prepares the cask content only; the tap repository and release remain separate launch steps.

## Cask file for the tap

Save as `Casks/pedrotmr-aerospace-tabs.rb` in `pedrotmr/homebrew-aerospace-tabs`. The username prefix gives the cask a globally distinctive token, as recommended by Homebrew's tap naming guide. This uses the current app version as a starting point and assumes the proposed `v<version>` tag format. The first GitHub Release does not exist yet, so `sha256 :no_check` is only a placeholder for this preparation draft: calculate the SHA-256 from the final release zip and replace it before publishing the tap. Update `version`, URL, and checksum together for every release.

```ruby
cask "pedrotmr-aerospace-tabs" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/pedrotmr/aerospace-tabs/releases/download/v#{version}/AerospaceTabs.zip"
  name "Aerospace Tabs"
  desc "Window tabs and overview for AeroSpace"
  homepage "https://github.com/pedrotmr/aerospace-tabs"

  depends_on macos: :sonoma

  app "AerospaceTabs.app"

  caveats <<~EOS
    Requires AeroSpace to be installed and running.
    Accessibility permission enables global shortcuts and Dock notification badges.
    Screen Recording permission is optional and enables window previews.
  EOS
end
```

This uses the Cask Cookbook's required identity and download stanzas plus an `app` artifact. The versioned cask will be included in ordinary `brew upgrade` when the tap updates its version for each release. If the release uses a different tag format or asset name, update the URL to match it before publishing the tap. If the release is not universal, add architecture-specific URLs and real checksums rather than advertising support for both CPU families.

CI extracts this block into a temporary local tap and runs `brew audit --cask --strict`. That checks the cask definition's syntax and style; it does not verify the future release asset, checksum, signing, or notarization.

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
2. Create a temporary ZIP and submit it with `notarytool`; Apple accepts ZIP archives, but not a bare `.app` bundle:

   ```sh
   ditto -c -k --keepParent AerospaceTabs.app AerospaceTabs-notarization.zip
   xcrun notarytool submit AerospaceTabs-notarization.zip --keychain-profile "<configured-profile>" --wait
   ```

   Continue only after the submission is **Accepted**, and inspect its log with `xcrun notarytool log <submission-id> --keychain-profile "<configured-profile>"`.
3. Staple and validate the ticket on the app bundle, then create the final distribution zip from the stapled app:

   ```sh
   xcrun stapler staple AerospaceTabs.app
   xcrun stapler validate AerospaceTabs.app
   ditto -c -k --keepParent AerospaceTabs.app AerospaceTabs.zip
   ```

4. Check the final release artifact with Gatekeeper on a clean macOS account and calculate its SHA-256 for the cask:

   ```sh
   shasum -a 256 AerospaceTabs.zip
   ```

Apple describes the [Developer ID and notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), the [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), and how [Gatekeeper checks downloaded apps](https://support.apple.com/guide/security/sec5599b66df/web). Notarization is Apple's automated malware and code-signing check; it is not App Review. Stapling the ticket to the app lets Gatekeeper verify the notarization when the Mac is offline; a ZIP itself cannot be stapled.

## References

- Project inputs: [README](../../README.md), [Makefile](../../Makefile), [release issue #10](https://github.com/pedrotmr/aerospace-tabs/issues/10)
- Homebrew: [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy), [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks), [Taps](https://docs.brew.sh/Taps), [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- Apple: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [Gatekeeper and runtime protection](https://support.apple.com/guide/security/sec5599b66df/web)
