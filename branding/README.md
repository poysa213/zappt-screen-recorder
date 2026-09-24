# Zappt brand assets

The Zappt mark is a **record dot inside an open "C" ring** — it reads as both the
letter C and a record button, with the gap giving it motion.

## Files

| File | Use |
|------|-----|
| `icon-1024.png` | macOS app icon master (squircle, indigo gradient). Source for `Assets.xcassets/AppIcon.appiconset`. |
| `mark.png` | Standalone mark, indigo, transparent background. |
| `mark-white.png` | Standalone mark, white, for dark/colored backgrounds. |
| `wordmark-light.png` | Horizontal lockup (mark + "Zappt") for light backgrounds. |
| `wordmark-dark.png` | Horizontal lockup for dark backgrounds. |

## Palette

| Token | Hex |
|-------|-----|
| Indigo (accent) | `#5B5BD6` |
| Gradient light | `#7A7BF0` |
| Gradient deep | `#493FD4` |
| Ink (text) | `#1A1A1E` |

## Regenerating

The assets are rendered with CoreGraphics for pixel-exact output:

```bash
swift branding/logo.swift branding      # writes the PNGs
# then regenerate the app icon set:
for s in 16 32 64 128 256 512 1024; do
  sips -z $s $s branding/icon-1024.png \
    --out Zappt/Resources/Assets.xcassets/AppIcon.appiconset/icon_${s}.png
done
```

Font in the wordmark is the system font (SF Pro), bold.
