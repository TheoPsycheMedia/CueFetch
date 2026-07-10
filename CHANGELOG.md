# Changelog

Notable user-facing changes are recorded here. CueFetch follows semantic
versioning for the numeric release and appends `-preview` while the distribution
contract is still stabilizing.

## 0.2.0-preview

Trust and release stabilization preview.

### Added

- Validated single-URL intake with explicit playlist handling
- Structured download plans, run states, and immutable completion records
- Deterministic process adapters and broader core behavior tests
- Minimum-window, no-metadata, tool-failure, active-run, and output-integrity tests
- Session-only recent-link history and redacted completion receipts
- Per-job Safari cookie access instead of a persistent global choice
- macOS GitHub Actions checks for whitespace, tests, coverage, release build,
  and universal packaging
- Universal `arm64` and `x86_64` DMG packaging
- Separate `0.2.0` marketing version, `0.2.0-preview` release label, and numeric
  build number
- SHA-256 and release-note generation for packaged artifacts
- Optional Developer ID signing and Keychain-backed Apple notarization flow
- Architecture, roadmap, release, security-design, contribution, and community
  documentation

### Changed

- The reviewed selection and the executed command now share one validated plan
- Plan-affecting controls freeze during an active run, and fixed presets no
  longer highlight a detected row they do not execute
- Best Video selects the highest-resolution detected video, with compatibility
  used only as a tie-breaker
- Successful completion now requires both the exact final-path marker and an
  existing non-directory output at that path
- Ambient `yt-dlp` configuration is ignored and URLs follow an option terminator
- Cancellation, failure, and success remain distinct through receipt generation
- Legal notices ship inside both the app bundle and DMG
- Subprocesses receive a constrained environment
- CI enforces at least 80% line coverage for `CueFetchCore`

### Security

- Malformed, non-HTTP(S), option-like, and ambiguous multi-link input is rejected
- Full private URLs are not persisted; receipt URL query values are redacted
- Release packaging now requires a clean tree and passing tests
- Cancelling link analysis terminates the underlying `yt-dlp` process

## 0.1.0-preview

Initial public preview.

- Native macOS preflight workflow for `yt-dlp`
- Real URL analysis through local `yt-dlp`
- Format, subtitles, destination, and command review before download
- Download progress, cancellation, and Finder reveal
- Apache-2.0 license, third-party notices, and responsible-use documentation
- Release DMG build path with optional code-sign identity support
