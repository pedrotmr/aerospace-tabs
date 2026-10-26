# Release credentials

## The short answer

Each app repository needs six GitHub settings:

- Four secrets. GitHub hides their values after you save them.
- Two variables. These are public Apple IDs.

The apps share three Apple secrets and both Apple IDs. Each app has its own Sparkle key. Across both apps, that is five secret values and two public IDs.

Each app has an ignored `.env` file with the same six release names. Fill the files before you add values to GitHub. Keep each file private. GitHub cannot show a saved secret again.

## The six settings

| Name | GitHub type | What it is | Shared? |
| --- | --- | --- | --- |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Secret | Base64 text from a `.p12` file. It holds your Developer ID certificate and private key. | Yes |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Secret | Password used when you export that certificate file. | Yes |
| `APPLE_NOTARY_KEY_P8_BASE64` | Secret | Base64 text from the private `.p8` file for your App Store Connect Team key. | Yes |
| `SPARKLE_PRIVATE_KEY` | Secret | Private key that signs this app's update feed. | No |
| `APPLE_NOTARY_KEY_ID` | Variable | Public ID for the App Store Connect key. | Yes |
| `APPLE_NOTARY_ISSUER_ID` | Variable | Public ID for your Apple team. | Yes |

## Get the Apple values

The two local `.env` files now contain a password-protected export of your valid Developer ID certificate. The export came from your Keychain. You do not need a new certificate.

A local `Apple Auth Key.p8` file was found. Its Base64 copy is now in both `.env` files. In App Store Connect, check that the file belongs to a **Team API key**. A Team key works with Apple's notarization tool; an individual key does not. If this is not a Team key, create one under **Users and Access → Integrations → App Store Connect API → Team Keys**. An Account Holder or Admin may need to create it. The Account Holder must request access if API access is off. Download the Team `.p8` file once and keep a safe backup. See [Apple API key help](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).

Copy the matching Key ID to `APPLE_NOTARY_KEY_ID`. Copy the Issuer ID shown near the top of **Users and Access → Integrations → App Store Connect API** to `APPLE_NOTARY_ISSUER_ID`. Use the same two IDs in both apps. See [Apple certificate help](https://developer.apple.com/help/account/certificates/certificates-overview/).

## Get the Sparkle key

The AeroSpace Tabs Sparkle key is in your Keychain. Its public key matches this app's `Config/App.xcconfig`. A private copy is now saved in this ignored `.env` file. Use this value for the GitHub secret. Do not use it for GitBar.

GitHub hides the old secret value, so I could not compare it. If you need to export the Keychain key again, use:

```sh
.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account aerospace-tabs -x /private/path/aerospace-tabs-sparkle-key
```

The command writes the private key to the file. Keep that file private.

Do not use this key for GitBar. The public key is already in `Config/App.xcconfig`. It is not a GitHub secret. See [Sparkle's key and update guide](https://sparkle-project.org/documentation/publishing/).

## Put the six values in GitHub

Open **Settings → Secrets and variables → Actions** in this repository.

Add these four names under **Secrets**:

- `DEVELOPER_ID_CERTIFICATE_P12_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_NOTARY_KEY_P8_BASE64`
- `SPARKLE_PRIVATE_KEY`

Add these two names under **Variables**:

- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`

## Keep the values safe

The `.env` file is plain text. Keep it on this Mac. Its GitHub ignore rule is already set. Keep its file permission at `600`. Store the original `.p12`, `.p8`, passwords, and private keys in encrypted storage. Base64 does not protect a secret.

Other local app keys may also be in `.env`. They are not part of these six GitHub release settings.

If you lose the `.p8` file, create a new Team key. Update the `.p8`, Key ID, and Issuer ID in both app repositories. If the Developer ID certificate expires, export a new `.p12` and update its password in both repositories. Keep a different Sparkle key for each app.

`GITHUB_TOKEN` is created by GitHub Actions. Do not add it. `CODESIGN_IDENTITY` is an optional local setting. It is not a GitHub secret.

## Check the settings

Before a signed check, confirm that all six values are set in `.env`. The Key ID must belong to the `.p8` file. If both apps use the same Team API key, use the same Key ID and Issuer ID in both repositories.

`make check` does not need release credentials. `make release-check APP_BUILD_NUMBER=<new-number>` signs a test build and sends it to Apple for notarization. It checks the Sparkle feed and does not publish a release.

Check setting names without viewing secret values:

```sh
gh secret list --repo pedrotmr/aerospace-tabs
gh variable list --repo pedrotmr/aerospace-tabs
```
