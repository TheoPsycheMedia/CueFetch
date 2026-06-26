# CueFetch Design QA

## Scope

- Product Design source: Option 2 download-workflow mockup.
- Source visual truth: local product-design mockup used during initial build.
- Implementation screenshot: `artifacts/cuefetch-window-final.png` in local QA output, not checked into the public source tree.
- Tested window: `1040x720` logical points, captured at `2304x1664` pixels.
- State: default preflight workflow with sample recent links and a ready candidate.

## Full-View Comparison

- The app preserves the chosen two-pane workflow: link intake/history on the left, download preflight on the right.
- The native top header is visible inside the default window, including CueFetch, History, Settings, and Up to date status.
- The right workflow now fits at the default window size: header, destination, preset, available formats, subtitle toggle, Download, and command preview are visible together.
- The format table adapts to a compact row layout at this width so the workflow stays usable without horizontal clipping.

## Focused Regions

- Top header: moved into a transparent full-size titlebar and padded past the traffic-light controls.
- Input pane: reduced URL editor, button, and recent-link row heights while preserving scanability.
- Destination and preset controls: label widths adjusted so labels do not wrap.
- Format picker: bounded to a compact, scroll-capable area; all default format rows are visible.
- Primary action row: Download remains the strongest call to action and stays visible without resizing.

## Findings

- P0: none.
- P1: none.
- P2: none.
- P3: compact format rows differ from the wider mockup table at constrained width; this is intentional for native window fit.

## Patches Made

- Replaced the unreliable SwiftUI window lifecycle with an AppKit-owned main window.
- Disabled stale restored-window behavior in the run script.
- Added transparent full-size titlebar behavior so the custom header is visible at launch.
- Tightened vertical spacing, media preview size, URL editor height, recent-link rows, and action controls.
- Converted the format picker to responsive compact rows with bounded height.

## Result

final result: passed
