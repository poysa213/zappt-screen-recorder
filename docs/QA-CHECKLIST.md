# Zappt — Manual QA Checklist

Automated tests cover the deterministic logic (see `ZapptTests/`). The capture
pipeline depends on system permissions and real hardware, so it must be checked
by hand before a release. Run through this on a real Mac.

Legend: ⬜ not tested · ✅ pass · ❌ fail (file an issue)

## 0. Environment
- ⬜ Fresh build: `xcodegen generate && xcodebuild -scheme Zappt test` → all green
- ⬜ App launches; menu-bar icon appears

## 1. Permissions & onboarding
- ⬜ First launch shows onboarding
- ⬜ Each "Enable" opens the correct System Settings pane
- ⬜ Granting a permission flips its row to a green check (live, without restart of onboarding)
- ⬜ Denying Screen Recording → Start shows a friendly alert, no crash
- ⬜ Denying Camera → camera toggle behaves; bubble stays empty gracefully (no crash)
- ⬜ Denying Microphone → mic toggle behaves; no crash

## 2. Source selection
- ⬜ Full screen: correct display recorded (test each display on multi-monitor)
- ⬜ Window: chosen window recorded; window list excludes Zappt's own windows
- ⬜ Area: overlay appears on all screens; drag selects; Esc cancels; dimensions label correct
- ⬜ Area on a secondary/scaled display maps to the correct region
- ⬜ Camera-only: records just the webcam

## 3. Audio
- ⬜ System audio only → audible in file
- ⬜ Mic only → audible in file
- ⬜ Both on → both audible, roughly in sync, no doubling/echo
- ⬜ Live level meter reacts to mic input before recording
- ⬜ Switching mic device in the dropdown updates the meter
- ⬜ A/V stays in sync across a 2–3 min recording

## 4. Camera bubble
- ⬜ Bubble previews as soon as the panel opens (camera authorized)
- ⬜ Draggable anywhere; stays on top
- ⬜ S / M / L resize live and stay on screen
- ⬜ Circle ↔ rounded rect switches shape live
- ⬜ Mirror toggle works
- ⬜ Switching camera device updates the preview (no permanent black)
- ⬜ Bubble is captured in the recording (full screen & area modes)

## 5. Recording flow
- ⬜ Countdown shows 3-2-1 (when enabled) and is skipped when disabled
- ⬜ Control bar appears; timer counts up
- ⬜ Pause → timer stops; Resume → continues; **file has no gap/jump at the seam**
- ⬜ Restart discards and starts fresh
- ⬜ Delete discards with no file left behind
- ⬜ Stop finalizes and opens the Library preview
- ⬜ Control bar / countdown are NOT visible in the recorded file
- ⬜ Hotkeys: ⌘⇧R start/stop, ⌘⇧P pause/resume (from another app in the foreground)

## 6. Saving
- ⬜ File saved to configured folder as `Zappt YYYY-MM-DD at HH.mm.ss.mp4`
- ⬜ File plays in QuickTime with correct duration, audio, and no corruption
- ⬜ Changing the save folder in Settings takes effect

## 7. Library
- ⬜ Grid shows thumbnails, title, duration, date, size
- ⬜ Search filters; sort (newest/oldest/name) works
- ⬜ Preview plays via AVPlayer
- ⬜ Rename renames the file on disk
- ⬜ Trim exports a correctly-trimmed copy; original untouched
- ⬜ Reveal in Finder / Copy / Move to Trash all work

## 8. Settings
- ⬜ Quality (720/1080/native) reflected in output resolution
- ⬜ Frame rate (30/60) reflected in output
- ⬜ Show cursor toggle honored
- ⬜ Countdown toggle honored
- ⬜ Default camera/mic remembered across launches

## 9. Robustness / edge cases
- ⬜ Unplug the camera mid-recording → no crash; recording still finalizes
- ⬜ Unplug/switch audio device mid-recording → no crash
- ⬜ Disk full / unwritable folder → friendly error, no crash
- ⬜ Start with no camera and no mic (screen only) → works
- ⬜ Very long recording (10+ min) → stable memory, file intact
- ⬜ Quitting while recording → prompt or clean stop (no zero-byte file)
- ⬜ Light appearance enforced everywhere (no dark-mode leakage)
