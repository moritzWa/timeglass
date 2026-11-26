# Releasing Timeglass

Official downloads target Apple Silicon and macOS 26+. No Intel build is currently
published. Normal users should download the ZIP from GitHub Releases, unzip it,
and drag the app into Applications. No shell installer or developer tools are needed.

## Maintainer prerequisites

- A clean checkout of the version to publish, with checks passing.
- Xcode Command Line Tools.
- A Developer ID Application signing certificate and its private key in Keychain.
- A validated notarytool Keychain profile. Create one interactively with
  xcrun notarytool store-credentials. Never commit credentials or put passwords in scripts.

The release script chooses the available Developer ID Application certificate,
uses hardened runtime with a secure timestamp, and refuses ad-hoc release signing.
Set NOTARY_PROFILE to the Keychain profile to use:

    NOTARY_PROFILE=my-notary-profile sh scripts/release.sh

On resource-managed machines, run that finite command through the machine's build
queue. It runs tests, creates an optimized build, signs the bundle, submits to
Apple, requires Accepted status, staples and validates the ticket, and requires a
successful Gatekeeper assessment. Only then does it create the final ZIP and
SHA256SUMS.txt. Existing release output is never overwritten.

Output is under build/distribution/0.1.0/. The staging notarize.zip and
notarization.json are not public assets. Publish only Timeglass-0.1.0-macos-arm64.zip
and SHA256SUMS.txt. The app contains no runtime state, clipboard data or fixtures.

## Publish

1. Check the app's version, minimum OS, architecture and Developer ID identity.
2. Extract the final ZIP into a clean directory; repeat codesign, stapler and
   spctl checks against that extracted app, not only the staging bundle.
3. Run a smoke test in an isolated, muted macOS VM with synthetic data.
4. Tag the checked commit v0.1.0, push the tag, and create a GitHub release with
   the final ZIP, checksums, compatibility requirements and first-use permissions.
5. Download the asset back from GitHub and compare its SHA-256 with the local ZIP.

For later versions, update the bundle/package version, release-script version,
README download link and release output path together. Do not replace a published
asset or rewrite an existing tag to silently ship different contents.
