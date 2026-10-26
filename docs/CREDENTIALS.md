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

You already have a valid Developer ID Application certificate for the team used by both apps. Do not create a new certificate now.

In Keychain Access, export that certificate with its private key as a password-protected `.p12` file. Choose a password. Save the password in `.env`. Make Base64 text without printing it to the terminal:

```sh
base64 -i /private/path/DeveloperID.p12 | tr -d '\n' > /private/path/DeveloperID.p12.base64
```

Open the new file and copy its text to `DEVELOPER_ID_CERTIFICATE_P12_BASE64` in each app's `.env`.

Create an App Store Connect **Team API key** under **Users and Access → Integrations → App Store Connect API → Team Keys**. An Account Holder or Admin may need to create it. If API access is off, the Account Holder must request access. Download the `.p8` file once and keep a safe backup. Individual API keys do not work with Apple's notarization tool. See [Apple API key help](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).

Encode the `.p8` file in the same way. Copy its text to `APPLE_NOTARY_KEY_P8_BASE64` in both `.env` files. Copy the Key ID and Issuer ID from App Store Connect to `APPLE_NOTARY_KEY_ID` and `APPLE_NOTARY_ISSUER_ID`.

See [Apple certificate help](https://developer.apple.com/help/account/certificates/certificates-overview/) for Developer ID certificates.

## Get the Sparkle key

The AeroSpace Tabs Sparkle key is in your Keychain. Its public key matches this app's `Config/App.xcconfig`. No new AeroSpace Tabs key is needed.

The value in GitHub is hidden, so I could not check it. Export the Keychain key to a private file if you need a local copy:

```sh
.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account aerospace-tabs -x /private/path/aerospace-tabs-sparkle-key
```

Copy that file's text to `SPARKLE_PRIVATE_KEY` in this `.env` file. Keep a private backup.

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

AeroSpace Tabs already has all four secret names. It has the two Apple IDs under Secrets by mistake. Add the IDs as Variables, then remove their old Secret entries.

## Current status

Checked on 26 October 2026. This is a snapshot. It becomes out of date after you change GitHub settings.

- The six release values in this local `.env` are empty.
- GitHub has all four secret names. The values are hidden, so they are not verified.
- GitHub has no repository variables. Move the two Apple IDs from Secrets to Variables.
- The local Developer ID certificate is valid for this team.
- The local Sparkle key matches the public key in this app.

You can check names without viewing values:

```sh
gh secret list --repo pedrotmr/aerospace-tabs
gh variable list --repo pedrotmr/aerospace-tabs
```

## Keep the values safe

The `.env` file is plain text. Keep it on this Mac. Its GitHub ignore rule is already set. Keep its file permission at `600`. Store the original `.p12`, `.p8`, passwords, and private keys in encrypted storage. Base64 does not protect a secret.

Other local app keys may also be in `.env`. They are not part of these six GitHub release settings.

If you lose the `.p8` file, create a new Team key. Update the `.p8`, Key ID, and Issuer ID in both app repositories. If the Developer ID certificate expires, export a new `.p12` and update its password in both repositories. Keep a different Sparkle key for each app.

`GITHUB_TOKEN` is created by GitHub Actions. Do not add it. `CODESIGN_IDENTITY` is an optional local setting. It is not a GitHub secret.

## Test the settings

Normal `make check` does not need release credentials. Local `make release-check APP_BUILD_NUMBER=<new-number>` uses your Keychain certificate and the Apple and Sparkle values in `.env`. GitHub uses the `.p12` and its password. The check sends the app to Apple and checks the Sparkle feed. It creates local files only.

After this PR is merged, open **Actions → CI → Run workflow**. Set `signed_distribution` to `true`. Enter a build number higher than the latest published build. The job checks the credentials and stores a short-lived artifact. It does not publish a release.

If Apple accepts the app but Sparkle reports an unsigned update, check that `SPARKLE_PRIVATE_KEY` matches the public key in `Config/App.xcconfig`.
