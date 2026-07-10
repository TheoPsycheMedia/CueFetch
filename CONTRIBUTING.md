# Contributing To CueFetch

CueFetch is intentionally narrow: it reviews one local `yt-dlp` operation before
execution. Contributions should make that workflow safer, clearer, or more
reliable without turning the app into a browser, media library, or queue manager.

## Set Up

Requirements are macOS 14 or newer, Xcode command line tools or Xcode, and Swift
6. Install `yt-dlp` and FFmpeg when testing the real workflow:

```bash
brew install yt-dlp ffmpeg
git clone https://github.com/TheoPsycheMedia/CueFetch.git
cd CueFetch
swift test
./script/build_and_run.sh
```

## Make A Change

1. Open an issue for behavior changes whose product fit is not obvious.
2. Create a focused branch from current `main`.
3. Keep dependency-free logic in `CueFetchCore` when practical.
4. Add focused tests for input, command, state, or mapping behavior.
5. Update user, architecture, privacy, or release documentation when its contract
   changes.
6. Submit a pull request with the visible result and exact verification evidence.

Ask before adding a production dependency, changing a public API, altering the
minimum macOS version, or changing signing and release policy.

## Required Verification

```bash
git diff --check
swift test
swift build --configuration release
```

CI also enforces at least 80% line coverage for `CueFetchCore`, where URL,
planning, metadata, and command trust decisions live.

For packaging changes, also run `./script/build_and_run.sh --dmg` from a clean
worktree. The command builds and verifies a universal local DMG; it does not
authorize publishing a release.

## Privacy And Test Data

Never commit real cookies, credentials, private media URLs, personal filesystem
paths, or downloaded copyrighted media. Use `https://example.com/` and neutral
temporary paths in tests. Inspect logs, screenshots, receipts, and fixtures before
attaching them to an issue or pull request.

Report vulnerabilities through the private path in [SECURITY.md](SECURITY.md),
not through a public issue or pull request.

## Pull Request Scope

Keep commits and pull requests small enough to review as one product decision.
Generated build output, `.build/`, `dist/`, downloaded media, and local app state
do not belong in source control. A maintainer still decides whether and when a
verified change is merged or released.
