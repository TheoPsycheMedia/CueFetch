# Third-Party Notices

CueFetch is intentionally thin: it provides the native macOS review workflow,
then invokes external command-line tools that the user has installed.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- License: Unlicense
- Relationship: external executable discovered on the user's PATH

CueFetch uses `yt-dlp` for URL analysis, format metadata, and downloads. CueFetch
does not vendor, fork, modify, or redistribute `yt-dlp`.

## FFmpeg

- Project: https://ffmpeg.org/
- License: primarily LGPL v2.1+, with optional GPL components depending on build
  configuration
- Relationship: external executable discovered on the user's PATH

`yt-dlp` may use FFmpeg for merging, remuxing, or audio/video processing.
CueFetch detects FFmpeg so users can see whether the local toolchain is ready.
CueFetch does not vendor, fork, modify, or redistribute FFmpeg.

## Apple SDKs

CueFetch is built with Swift, SwiftUI, AppKit, and Foundation from Apple's SDKs.
Those platform SDKs are used under Apple's developer terms and are not
redistributed as third-party source dependencies in this repository.

## Prior Art

CueFetch was designed as a native macOS "review before download" workflow around
`yt-dlp`. Existing open source downloader front-ends such as Open Video
Downloader, MacYTDL, Parabolic, Seal, and YTDLnis informed the broader product
landscape, but CueFetch does not copy their code or assets.
