# Personal Homebrew tap

## Decision and release contract

Use a personal tap for the first Homebrew distribution. Homebrew's shared Package Acceptance Policy says software that does not meet the official-tap criteria can generally be maintained in a third-party tap; that tap is maintained by its owner and is not endorsed or supported by Homebrew. The official self-submission notability threshold is 225 stars, 90 forks, or 90 watchers, with case-by-case exceptions. See [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy) and [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks).

Issue [#10](https://github.com/pedrotmr/aerospace-tabs/issues/10) remains open for install and run acceptance. The first stable GitHub Release is now published as [v0.1.1](https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.1.1), with `AerospaceTabs.zip` as its asset. The checked SHA-256 is `69bbad1776bb5a49d8efcbcf8f65607bb032f3de908d5d5866b9bf5f846e2e5f`. Use this release contract for future cask updates:

- Publish a non-prerelease GitHub Release with a `v<version>` tag and `AerospaceTabs.zip` as an asset. The published app version is `0.1.1`; update the cask's version and checksum together for each later release.
- Put `AerospaceTabs.app` at the root of the zip. Sign and notarize the app before packaging it.
- The v0.1.1 release app is universal for Apple silicon and Intel. Local `make build` output remains architecture-specific, so use the release workflow artifact for the cask.
- Keep the asset filename stable across releases. Update the tap cask's version and SHA-256 for each release so ordinary `brew upgrade` can detect and install updates.

The public tap repository is [pedrotmr/homebrew-aerospace-tabs](https://github.com/pedrotmr/homebrew-aerospace-tabs). Homebrew maps its name from `brew tap pedrotmr/aerospace-tabs`.

## Cask file for the tap

Save as `Casks/pedrotmr-aerospace-tabs.rb` in `pedrotmr/homebrew-aerospace-tabs`. The username prefix gives the cask a globally distinctive token, as recommended by Homebrew's tap naming guide. This cask is pinned to the published v0.1.1 tag and its verified asset checksum. Update `version`, URL, and checksum together for every release.

```ruby
cask "pedrotmr-aerospace-tabs" do
  version "0.1.1"
  sha256 "69bbad1776bb5a49d8efcbcf8f65607bb032f3de908d5d5866b9bf5f846e2e5f"

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

CI extracts this block into a temporary local tap and runs `brew audit --cask --strict`. That checks cask syntax and style; it does not download or verify the v0.1.1 asset, checksum, signing, or notarization. Those release artifact checks were performed separately.

## README install line

Use this in the README's Install section:

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

The fully qualified cask name installs the requested item from the third-party tap. A separate `brew tap pedrotmr/aerospace-tabs` is optional. Homebrew's tap naming and trust behavior are documented in [Taps](https://docs.brew.sh/Taps) and [Tap Trust](https://docs.brew.sh/Tap-Trust). Cask definitions are Ruby code and can run with the user's privileges, so users should only install a tap they trust.

## Gatekeeper and notarization

[Acceptable Casks](https://docs.brew.sh/Acceptable-Casks) requires macOS apps in the official cask tap to pass Gatekeeper checks and forbids requiring Gatekeeper or System Integrity Protection to be disabled or bypassed. That is an official-tap acceptance rule, but the same Gatekeeper behavior affects people installing from a personal tap. Do not ask users to remove quarantine or turn off Gatekeeper to launch this app.

The local [Makefile](../../Makefile) signs with the first local codesigning identity it finds, or ad-hoc (`-`) if none is installed; that path is for development. The release workflow signs with Developer ID, notarizes, staples the ticket, and builds the distribution zip. The v0.1.1 asset passed signature, stapler, and Gatekeeper checks. For future release updates, keep this process:

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
