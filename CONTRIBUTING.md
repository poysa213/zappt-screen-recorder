# Contributing to Zappt

Thanks for your interest in improving Zappt! Contributions of all kinds are
welcome — bug reports, features, docs, and design.

## Getting set up

Zappt has **no third-party dependencies**. You only need Xcode and XcodeGen.

```bash
# 1. Install XcodeGen (once)
brew install xcodegen

# 2. Generate the Xcode project (the .xcodeproj is git-ignored)
xcodegen generate

# 3. Build from the command line…
xcodebuild -scheme Zappt -configuration Debug build

# …or just open it in Xcode
open Zappt.xcodeproj
```

The project targets **macOS 14+**, is written in **Swift (SwiftUI + AppKit)**,
and builds in the Swift 5 language mode.

## Project layout

See the "Project structure" section in the [README](README.md). In short:
`App/` (coordination), `Capture/` (ScreenCaptureKit + AVFoundation pipeline),
`UI/` (SwiftUI views and panels), `Models/`, and `Utilities/`.

## Ground rules

- **Keep it dependency-free.** Please don't add third-party packages without
  opening an issue to discuss it first.
- **Match the surrounding style.** Small, focused PRs are much easier to review.
- **The build must pass.** Run the `xcodebuild` command above before pushing.
- **Respect the design language.** Zappt is light-mode-only, minimal, and uses
  the tokens in `Utilities/Theme.swift` — reuse them instead of hardcoding
  colors and metrics.

## Opening a pull request

1. Fork the repo and create a branch (`git checkout -b feature/my-thing`).
2. Make your change and confirm the build succeeds.
3. Open a PR describing **what** changed and **why**. Screenshots or a short
   screen recording are hugely appreciated for anything UI-related.

## Reporting bugs

Use the bug report template. macOS version, hardware, and a crash log (if any)
make issues far easier to fix.

## A note on scope

Zappt is a local-first, privacy-respecting screen recorder. Features that phone
home, require accounts, or add telemetry are out of scope by design.
