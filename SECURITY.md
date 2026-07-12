# Security Policy

## Supported Versions

Security fixes target the latest `0.2.x-preview` release and current `main`.
Older preview artifacts may not receive backports.

## Report A Vulnerability Privately

Use GitHub's private vulnerability reporting form:

<https://github.com/TheoPsycheMedia/CueFetch/security/advisories/new>

The repository owner must enable that GitHub feature before the form is
available. If it is unavailable, open a minimal public issue asking the
maintainer to establish a private disclosure channel. Do not include the
vulnerability, exploit steps, logs, private URLs, cookies, credentials, tokens,
or personal filesystem paths in that issue.

Include the affected CueFetch version and build, macOS version and architecture,
impact, minimal reproduction conditions, and whether the issue requires a
malicious URL, local access, a compromised external tool, or a tampered release
artifact. Redact user data before attaching evidence.

No response-time or bounty commitment is currently published.

## Local Security Model

CueFetch is a single-user local macOS app without accounts or a network service.
It accepts one HTTP(S) URL, validates the input, constructs arguments as an
array, ignores ambient `yt-dlp` configuration, and places the URL after an
option terminator. It invokes the resolved local `yt-dlp` with a constrained
process environment; `yt-dlp` may invoke the user's installed FFmpeg.

Download preferences use macOS `UserDefaults`. Recent links stay in memory for
the current session, are not persisted, and legacy persisted link history is
removed at launch. Completion receipts redact URL credentials, fragments, and
query values and abbreviate home-directory paths. Safari cookie access is off by
default, scoped to an explicitly enabled job, and delegated to the user's
installed `yt-dlp`; CueFetch does not read or store cookie values.

These controls do not protect a Mac account that is already compromised, a
malicious replacement for a locally installed tool, or media files after they
are written to the chosen destination.

## Release Integrity

Release packaging requires a clean worktree and passing tests, builds for
`arm64` and `x86_64`, performs strict code-signature verification, and generates
a SHA-256 checksum. Developer ID signing and Apple notarization are available
only when a maintainer supplies local Keychain-backed credentials.

GitHub branch protection, required checks, private vulnerability reporting,
release publication, Apple certificate issuance, and notarization acceptance
are external controls. Their status must be verified on the actual GitHub and
Apple surfaces before describing a public artifact as protected, signed, or
notarized.

See [docs/SECURITY-DESIGN.md](docs/SECURITY-DESIGN.md) for the concise threat
model.
