<p align="center">
  <img src="branding/wordmark-light.png#gh-light-mode-only" alt="Zappt" width="360">
  <img src="branding/wordmark-dark.png#gh-dark-mode-only" alt="Zappt" width="360">
</p>

# Zappt

A native macOS screen recorder — a cleaner, local-first take on Loom. Built in
Swift + SwiftUI with ScreenCaptureKit and AVFoundation. Light mode, minimal,
no third-party dependencies.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

> **Status:** early / work in progress. Everything runs locally — no account, no
> telemetry, no upload. Not affiliated with or endorsed by Loom.

## Features

- **Menu bar app + Library window.** A menu-bar popover holds the compact
  recording panel; a separate Library window browses your recordings.
- **Capture sources:** full screen (pick a display), a specific window, a
  drag-to-select custom area, or camera-only.
- **Audio:** toggle system audio (ScreenCaptureKit, excluding Zappt's own audio)
  and the microphone (device picker + live level meter). Both can be on at once
  and are mixed into a single AAC track.
- **Camera bubble:** a floating, always-on-top, draggable, resizable (S/M/L)
  camera panel — circle or rounded-rect, mirrored. It sits on screen so it's
  captured naturally in the recording.
- **Recording flow:** 3-2-1 countdown (skippable), a floating control bar
  (timer, pause/resume, restart, delete, stop) that is excluded from capture,
  global hotkeys (⌘⇧R start/stop, ⌘⇧P pause/resume), and seamless pause
  (timestamps are re-based so there is no gap in the file).
- **Local saving:** `~/Movies/Zappt/Zappt YYYY-MM-DD at HH.mm.ss.mp4`
  (folder configurable). Recording opens in the Library on stop.
- **Library:** thumbnail grid, search, sort, and per-item preview (AVPlayer),
  rename, trim (export a trimmed copy), reveal in Finder, copy, and move to Trash.
- **Settings:** save folder, quality (720p/1080p/native), frame rate (30/60),
  show cursor, highlight clicks, countdown toggle, default camera and mic.
- **Onboarding:** first-launch, step-by-step permission checks with live status.

## Requirements

- macOS 14 or later (uses macOS 15 APIs where available, with fallbacks)
- Xcode 15+ (built and verified with Xcode 26)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project from project.yml
xcodegen generate

# Build from the command line
xcodebuild -scheme Zappt -configuration Debug build
```

Or open `Zappt.xcodeproj` in Xcode and run.

## Building a DMG (distribution)

```bash
./scripts/build-dmg.sh        # -> dist/Zappt.dmg
```

This produces a **universal** (Intel + Apple Silicon) drag-to-install DMG.

> **Gatekeeper reality:** by default the app is only *ad-hoc* signed, so it runs
> on the machine that built it, and on other Macs only via **right-click → Open**
> (or `xattr -dr com.apple.quarantine /Applications/Zappt.app`). This is **not**
> suitable for public distribution.

For a DMG that installs cleanly on any Mac, you need an **Apple Developer account**
($99/yr) to sign with a Developer ID and **notarize**. One-time setup:

```bash
xcrun notarytool store-credentials zappt-notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Then:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="zappt-notary" \
./scripts/build-dmg.sh
```

The script signs with the hardened runtime + `scripts/Zappt.entitlements`,
submits to Apple, and staples the ticket so the app opens without warnings.

See [`docs/RELEASING.md`](docs/RELEASING.md) for the full release process,
version bumping, and a **pre-push checklist** of things to fill in first.

## Granting permissions

Zappt is **not sandboxed** and needs three privacy permissions. On first launch
the onboarding screen walks you through them; you can also grant them manually:

1. **Screen Recording** — System Settings → Privacy & Security → Screen
   Recording → enable **Zappt**. (macOS requires you to quit and reopen the app
   after granting this the first time.)
2. **Camera** — System Settings → Privacy & Security → Camera → enable **Zappt**.
3. **Microphone** — System Settings → Privacy & Security → Microphone → enable
   **Zappt**.

The onboarding screen has an **Enable** button per permission that opens the
correct System Settings pane and shows a live green checkmark once granted.

## Project structure

```
Zappt/
  App/         ZapptApp, AppDelegate, AppState, PanelController
  Capture/     ScreenRecorder, CameraManager, AudioManager,
               CameraOnlyRecorder, AudioMixer, VideoWriter
  Models/      Enums, AppSettings, Recording
  UI/
    Panels/    RecordingPanel, CameraBubble, ControlBar, Countdown,
               AreaSelection overlay, CameraPreview
    Library/   LibraryView, LibraryStore, PreviewView, TrimView, VideoPlayerView
    Settings/  SettingsView
    Onboarding/OnboardingView
    Components.swift
  Utilities/   Theme, PermissionsManager, HotKeyManager, WindowCloser
  Resources/   Info.plist, Assets.xcassets
```

## How it fits together

- `ScreenRecorder` owns an `SCStream` (screen + system audio). Video frames are
  re-timed to start at zero (with pause gaps subtracted) and appended to a
  `VideoWriter` (AVAssetWriter, H.264 + AAC in `.mp4`).
- `AudioMixer` converts system audio and microphone buffers to a common
  interleaved-Int16 format and sums them into one continuous track, so pauses
  leave no gap and A/V stays aligned via presentation timestamps.
- The camera bubble is a live `AVCaptureVideoPreviewLayer` in a floating panel,
  captured on screen by ScreenCaptureKit. Zappt's own control/countdown windows
  are passed to `SCContentFilter` as excluded windows so they never appear in
  the recording.
- "Camera only" mode bypasses ScreenCaptureKit and records the webcam directly
  with `AVCaptureMovieFileOutput`.

## Notes & limitations

- Global hotkeys use the Carbon Hot Key API, so no extra Input-Monitoring
  permission is required.
- Window capture records only the chosen window; the camera bubble (a separate
  window) is captured in full-screen and area modes.
- Everything is stored locally — there is no upload or account.

## Testing

Deterministic logic (audio mixing math, timestamp/pause normalization, output
sizing, filename generation, settings) is covered by unit tests:

```bash
xcodegen generate
xcodebuild -scheme Zappt test
```

The capture pipeline itself (ScreenCaptureKit, camera, microphone) depends on
system permissions and real hardware, so it's validated with a manual QA pass —
see [`docs/QA-CHECKLIST.md`](docs/QA-CHECKLIST.md).

## Contributing

PRs and issues are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). Please keep Zappt dependency-free and
local-first.

## License

[MIT](LICENSE) © 2026 Youcef Hanaia.
