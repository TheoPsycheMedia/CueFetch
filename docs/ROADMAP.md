# CueFetch Roadmap

This roadmap records sequence and exit criteria, not promised dates.

## Current: `0.2.0-preview` Trust Release

Goal: make the reviewed operation, executed operation, final state, receipt, and
distributed artifact agree.

Exit criteria:

- Validated single HTTP(S) URL intake and explicit playlist handling
- One immutable plan shared by command preview and runner
- Distinct idle, running, succeeded, failed, and cancelled states
- Completion records tied to the current run's machine-readable final path
- Session-only private-link history, redacted receipts, and per-job Safari cookies
- Deterministic tests for input, commands, state, cancellation, and stale receipts
- Minimum-window, no-metadata, and missing-tool UI-state contracts
- Universal `arm64` and `x86_64` package with licenses and checksum
- Green GitHub Actions checks
- Developer ID signed, Apple-notarized DMG verified on an installed app
- GitHub private vulnerability reporting and required CI checks verified by the
  repository owner

The last two items depend on external Apple and GitHub state and cannot be
claimed from source changes alone.

## Next: `0.3.x-preview` Workflow Depth

Goal: improve confidence and recovery without widening the product lane.

- Accessibility review for keyboard flow, labels, focus, contrast, and reduced motion
- Screenshot-driven layout checks across supported window sizes and text scaling
- Clearer tool-version and manual-update status
- More deterministic progress and final-path parsing fixtures
- Installed-app smoke matrix across current macOS, Apple silicon, and Intel
- Performance measurements for launch, analysis, and large metadata responses

## Later: `1.0`

Goal: a supportable stable release rather than a larger feature list.

- Repeatable signed and notarized release procedure with rollback artifact
- Stable local-data migration and deletion behavior
- Documented compatibility policy for `yt-dlp`, FFmpeg, and macOS
- No open high-priority security or state-integrity findings
- Real-world installed-app verification on representative public test media

## Explicit Non-Goals

- Bypassing DRM or platform access controls
- Bundling or silently updating `yt-dlp` or FFmpeg
- A hosted download service, account system, or cloud media library
- A general browser or automated scraping platform
- Multi-user queues until the single reviewed operation is trustworthy end to end
