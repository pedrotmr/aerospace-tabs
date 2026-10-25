# Releasing (maintainers)

This is a reference for a future maintainer. Development is paused; these steps do not imply a planned release.

## Version and GitHub Release

Release Please reads Conventional Commit messages from `main`:

- `fix:`, `perf:`, and `revert:` request a patch bump.
- `feat:` requests a minor bump.
- A breaking marker such as `feat!:` or a `BREAKING CHANGE:` footer requests a major bump.
- `docs:`, `style:`, `chore:`, `refactor:`, `test:`, `build:`, and `ci:` do not create a release by themselves.

After a release-worthy change reaches `main`, Release Please opens or updates a version PR. Review and merge it when a release is intended. GitHub Actions then builds the universal app, signs and notarizes it, staples the ticket, runs `swift test` at the release tag, and attaches `AerospaceTabs.zip` to a draft GitHub Release. Review and publish the draft when ready; do not create a tag or rewrite the title and notes manually.

The Release Please PR uses GitHub's built-in token, so it does not trigger the `pull_request` CI workflow. Source changes are tested on their PRs; the release workflow tests the tagged commit. If generated release PRs need CI checks before merge, configure Release Please with a GitHub App or personal access token.

If signing, tests, or upload fail after the draft is created, rerun the failed jobs in Actions. A full workflow rerun can skip packaging because the draft already exists.

Before the first release, enable **Allow GitHub Actions to create and approve pull requests** in repository **Settings → Actions → General**. Configure these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_P12_BASE64` and `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_NOTARY_KEY_P8_BASE64`, `APPLE_NOTARY_KEY_ID`, and `APPLE_NOTARY_ISSUER_ID`

## Homebrew

After publishing a release, update `version` and the ZIP's SHA-256 in the tap cask and in [the Homebrew release notes](homebrew-tap.md#after-each-published-release). The install commands stay the same; `brew upgrade` follows the version pinned in the cask.
