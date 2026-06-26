# Security Policy

## Supported Versions

CueFetch is currently an early preview project. Security fixes target the
latest `main` branch unless release branches are introduced later.

## Reporting A Vulnerability

Please report security-sensitive issues privately before public disclosure.
If this repository does not yet list a security contact, open a minimal
GitHub issue asking for a private disclosure channel without including
exploit details.

Do not include credentials, private cookies, private media URLs, or personal
access tokens in public issues.

## Local Data

CueFetch runs locally and invokes tools installed on the user's Mac. When the
Safari cookies option is enabled, CueFetch passes `--cookies-from-browser safari`
to `yt-dlp`; cookie access and site behavior are handled by `yt-dlp` and the
user's local browser profile. Users should only enable cookies for content they
are authorized to access.
