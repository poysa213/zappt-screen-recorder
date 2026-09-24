# Changelog

All notable changes to Zappt are documented here. This project follows
[Semantic Versioning](https://semver.org).

## [Unreleased]

### Added
- Screen, window, area, and camera-only recording via ScreenCaptureKit.
- System-audio + microphone capture, mixed into a single AAC track.
- Floating, resizable camera bubble (circle / rounded), mirrored, live preview.
- 3-2-1 countdown, floating control bar (pause/resume/restart/delete/stop),
  seamless pause, and global hotkeys (⌘⇧R, ⌘⇧P).
- Library with thumbnails, search, sort, preview, rename, trim, and Trash.
- Settings (quality, frame rate, cursor, countdown, default devices, save folder).
- Permissions onboarding with live status.
- Unit tests for timeline/pause math, audio mixing, output sizing, and models.
- Error handling: no zero-byte/corrupt files, partial-recording salvage,
  device-disconnect recovery, and safe quit while recording.
- Signed + notarized universal DMG build pipeline (`scripts/build-dmg.sh`).

## [1.0] — unreleased
- Initial version.
