# Releasing CueFetch

Public release is a maintainer action. CI verifies an ad-hoc-signed package but
does not create tags, publish GitHub Releases, change repository settings, or use
Apple credentials.

## Version Contract

The default preview metadata is:

| Field | Value |
|---|---|
| Release label and artifact | `0.2.0-preview` |
| `CFBundleShortVersionString` | `0.2.0` |
| `CFBundleVersion` | `2` |
| Minimum macOS | `14.0` |
| Architectures | `arm64`, `x86_64` |

Override these only as a coherent set with `CUEFETCH_VERSION`,
`CUEFETCH_MARKETING_VERSION`, and `CUEFETCH_BUILD_NUMBER`. The script rejects a
non-numeric build number or a release label that does not begin with the marketing
version.

## Local Package Gate

From a clean release commit:

```bash
git status --short
git diff --check
swift test
swift build --configuration release
./script/build_and_run.sh --dmg
```

`--dmg` independently checks the clean tree and reruns tests. It then creates and
verifies:

```text
dist/CueFetch-0.2.0-preview.dmg
dist/CueFetch-0.2.0-preview.dmg.sha256
dist/CueFetch-0.2.0-preview-release-notes.md
```

The default app and DMG are ad-hoc signed. That is suitable for CI validation,
not for describing a public release as Developer ID signed or notarized.

## Developer ID And Notarization

Prerequisites:

1. Active Apple Developer Program membership.
2. A `Developer ID Application` certificate and private key in the login Keychain.
3. Xcode command line tools containing `notarytool` and `stapler`.
4. Notarization credentials stored in the Keychain under a named profile.

Inspect signing identities:

```bash
security find-identity -v -p codesigning
```

Create the Keychain profile interactively so credentials are not stored in the
repository or shell history:

```bash
xcrun notarytool store-credentials CueFetch-notary
```

Run the signed flow:

```bash
CUEFETCH_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
CUEFETCH_NOTARY_PROFILE="CueFetch-notary" \
./script/build_and_run.sh --notarize
```

The script submits the signed app archive, staples and validates the app, creates
and signs the DMG, submits it, staples and validates it, runs Gatekeeper
assessment, verifies the DMG, then generates the final checksum. A failure in any
step stops the release.

## Artifact Proof

Before publication, verify the actual final files:

```bash
(cd dist && shasum -a 256 -c CueFetch-0.2.0-preview.dmg.sha256)
hdiutil verify dist/CueFetch-0.2.0-preview.dmg
xcrun stapler validate dist/CueFetch-0.2.0-preview.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 \
  dist/CueFetch-0.2.0-preview.dmg
```

Mount the DMG, install the app into `/Applications`, and verify one authorized
public test URL through analyze, review, download, receipt, and Finder reveal.
Record the app version/build, macOS version, Mac architecture, tool versions,
final media codecs, and exact artifact checksum.

## External GitHub Gates

Before calling the release public-ready, verify on GitHub itself:

- CI is green for the exact release commit.
- Required status checks and branch protection are enabled as intended.
- Private vulnerability reporting is enabled and its form opens.
- The tag points to the verified commit.
- The DMG, checksum, and factual notes are attached to a draft release.

Publishing the draft requires explicit maintainer approval. If post-release proof
fails, remove or mark the affected release, preserve its checksum for diagnosis,
and direct users to the last verified artifact; do not silently replace a file
under the same version.
