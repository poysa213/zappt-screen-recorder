<p align="center">
  <img src="branding/wordmark.png" width="300" alt="Zappt">
</p>

<p align="center">A native macOS screen recorder. Fast, local, no account.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-111111">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138">
  <img src="https://img.shields.io/badge/license-MIT-3B5BDB">
</p>

## Download

**[Download Zappt (.dmg)](https://github.com/poysa213/zappt-screen-recorder/releases/latest/download/Zappt.dmg)** — universal (Apple Silicon + Intel), signed and notarized.

Open the DMG and drag Zappt to Applications. macOS asks for Screen Recording, Camera, and Microphone access on first use.

Latest: **v1.0** · [all releases](https://github.com/poysa213/zappt-screen-recorder/releases)

## Features

- Record the full screen, a window, a custom area, or just the camera
- System audio + microphone, mixed into one track
- Floating camera bubble — resizable, circle or rounded, mirrored
- Countdown, pause/resume, restart, global shortcuts (⌘⇧R, ⌘⇧P)
- Library with thumbnails, search, preview, trim, and rename
- Saves `.mp4` (H.264 + AAC) to `~/Movies/Zappt`

## Build from source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme Zappt -configuration Debug build
```

Packaging a signed release DMG is documented in [docs/RELEASING.md](docs/RELEASING.md).

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © Youcef Hanaia
