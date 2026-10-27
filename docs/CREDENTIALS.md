# Release credentials

Normal local work needs no credentials. Signed release checks use Apple keys. Sparkle and Homebrew need extra keys when those modules are enabled.

## Settings for one app

| Name | GitHub type | Scope | What it does | Where to get it |
| --- | --- | --- | --- | --- |
| `APPLE_NOTARY_KEY_P8_BASE64` | Secret | Apple team | Sends the app to Apple's notary service | Base64 text from a Team API `.p8` key |
| `APPLE_NOTARY_KEY_ID` | Variable | Apple team | Names the `.p8` key | App Store Connect API page |
| `APPLE_NOTARY_ISSUER_ID` | Variable | Apple team | Names the Apple team | App Store Connect API page |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Secret | Apple team | Signs the app | Base64 text from a Developer ID `.p12` file |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Secret | Apple team | Opens the `.p12` file | Password used when exporting the certificate |
| `SPARKLE_PRIVATE_KEY` | Secret | This app | Signs this app's update feed | Sparkle `generate_keys` tool |
| `HOMEBREW_TAP_TOKEN` | Secret | This tap | Lets this app update one cask | Fine-grained GitHub token for the tap |

An app with Sparkle uses four secrets and two public variables. Add `HOMEBREW_TAP_TOKEN` as a fifth secret when automatic tap updates are enabled. The five Apple values can be shared by apps on the same Apple team. Each app needs its own Sparkle key. Each tap needs its own Homebrew token.

GitHub creates `GITHUB_TOKEN` for Actions. Do not add that token.

## Keep a local copy

Each project has a private, ignored `.env` file. `make setup` creates it if it is missing. Put one value on each line and use it as your local copy before adding values to GitHub. Do not commit it or send it in chat. Base64 is encoding. It does not encrypt a key.

The wizard lists only the values this app uses:

```text
APPLE_NOTARY_KEY_P8_BASE64=
APPLE_NOTARY_KEY_ID=
APPLE_NOTARY_ISSUER_ID=
DEVELOPER_ID_CERTIFICATE_P12_BASE64=
DEVELOPER_ID_CERTIFICATE_PASSWORD=
SPARKLE_PRIVATE_KEY=
HOMEBREW_TAP_TOKEN=
```

To copy a file as Base64 without printing it in Terminal:

```sh
base64 -i ~/Downloads/AuthKey_<KEY_ID>.p8 | tr -d '\n' | pbcopy
base64 -i ~/Downloads/DeveloperID.p12 | tr -d '\n' | pbcopy
```

Paste the clipboard text into the matching `.env` line. Keep the original `.p8` and `.p12` files in encrypted storage.

## Get Apple values

### Notary key

1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API**.
2. Create or select a **Team API key**. Save its `.p8` file once.
3. Put the file's Base64 text in `APPLE_NOTARY_KEY_P8_BASE64`.
4. Put its Key ID in `APPLE_NOTARY_KEY_ID` and the team Issuer ID in `APPLE_NOTARY_ISSUER_ID`.

Use the same `.p8`, Key ID, and Issuer ID for apps on the same Apple team.

### Developer ID certificate

1. Open Keychain Access. Find the **Developer ID Application** identity with its private key.
2. Export it as a `.p12` file. Set a password and save that password in a password manager.
3. Put the file's Base64 text in `DEVELOPER_ID_CERTIFICATE_P12_BASE64`.
4. Put the export password in `DEVELOPER_ID_CERTIFICATE_PASSWORD`.

Use the same certificate and password for apps signed by that Apple team. Update both values together if you export it again.

## Get optional module values

### Sparkle

Run `make setup`, then use Sparkle's `generate_keys` tool once for this app:

```sh
tool=.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
"$tool" --account <app-slug>
"$tool" --account <app-slug> -x /private/path/<app-slug>-sparkle-key
```

Save the private key in `SPARKLE_PRIVATE_KEY`. Put the matching public key in `Config/App.xcconfig`. Back up the private key. Do not reuse it for another app.

Do not add a `SPARKLE_PUBLIC_KEY` GitHub setting. The public key is named `SPARKLE_PUBLIC_ED_KEY`. Keep it in `Config/App.xcconfig`.

### Homebrew

1. Create the tap repository `homebrew-aerospace-tabs` under `pedrotmr`.
2. On GitHub, open **Settings → Developer settings → Personal access tokens → Fine-grained tokens** and create a token.
3. Choose `pedrotmr` as the owner. Give the token access only to `homebrew-aerospace-tabs`.
4. Give it **Contents: Read and write** permission.
5. Save the token in `HOMEBREW_TAP_TOKEN` and add it to this app repository as a secret.

Each tap needs its own token. The app workflow uses it only to push the cask update after a stable release. It does not need a token in the tap repository.

## Add values to GitHub

Open this app repository. Go to **Settings → Secrets and variables → Actions**.

1. Add secret values under **Secrets**.
2. Add `APPLE_NOTARY_KEY_ID` and `APPLE_NOTARY_ISSUER_ID` under **Variables**.
3. Add `SPARKLE_PRIVATE_KEY` and, when automatic tap updates are enabled, `HOMEBREW_TAP_TOKEN` under **Secrets**.

GitHub hides secret values after you save them. Keep the local `.env` as your copy. Check names without showing values:

```sh
cut -d= -f1 .env
gh secret list --repo <owner>/<app-repo>
gh variable list --repo <owner>/<app-repo>
```

## Back up and replace keys

Keep the `.p8`, `.p12`, export password, Sparkle private key, and tap token in encrypted storage. If an Apple API key changes, update the `.p8`, Key ID, and Issuer ID in each app repository. If the signing certificate changes, update the `.p12` and password together. If a Sparkle key changes, update only that app and plan the change before shipping it. If a tap token expires, create a new token for that tap and replace the secret in the app repository.

`make check` needs no secrets. For a local signed check, import the Developer ID identity into Keychain Access. `make release-check APP_BUILD_NUMBER=<new-number>` reads `APPLE_NOTARY_*` and, when enabled, `SPARKLE_PRIVATE_KEY` from `.env`. GitHub Actions reads the P12 and password from GitHub and imports them into a temporary keychain. The Homebrew token is used only by the stable-release workflow.
