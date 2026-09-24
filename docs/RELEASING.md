# Releasing Zappt

How to cut a distributable, notarized build.

## Prerequisites (one-time)

- **Apple Developer account** ($99/yr) and a **Developer ID Application**
  certificate installed in your login keychain. Verify:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```
- A **notary keychain profile** so the script can submit to Apple non-interactively:
  ```bash
  xcrun notarytool store-credentials zappt-notary \
    --apple-id you@example.com --team-id Y5H42J7AZ8 --password <app-specific-password>
  ```
  (Create the app-specific password at <https://appleid.apple.com> → Sign-In & Security.)

## 1. Bump the version

Edit `project.yml`:

```yaml
MARKETING_VERSION: "1.1"     # user-visible version
CURRENT_PROJECT_VERSION: "2" # build number, increment every upload
```

Add a matching entry at the top of [`CHANGELOG.md`](../CHANGELOG.md).

## 2. Build + sign + notarize + staple

```bash
SIGN_IDENTITY="Developer ID Application: Youcef Hanaia (Y5H42J7AZ8)" \
NOTARY_PROFILE="zappt-notary" \
./scripts/build-dmg.sh
```

The script:
1. builds a **universal** (Intel + Apple Silicon) Release app,
2. signs it with the hardened runtime + `scripts/Zappt.entitlements`,
3. notarizes the app and **staples** the ticket (so it launches offline),
4. packages a drag-to-install `dist/Zappt.dmg`.

## 3. Verify

```bash
MP=$(hdiutil attach dist/Zappt.dmg -nobrowse -readonly | grep Volumes | awk '{print $3}')
spctl -a -vvv "$MP/Zappt.app"          # -> accepted, source=Notarized Developer ID
xcrun stapler validate "$MP/Zappt.app" # -> The validate action worked!
lipo -archs "$MP/Zappt.app/Contents/MacOS/Zappt"  # -> x86_64 arm64
hdiutil detach "$MP"
```

## 4. Publish

Attach `dist/Zappt.dmg` to a GitHub Release tagged `vX.Y` (matching
`MARKETING_VERSION`). Users install by opening the DMG and dragging Zappt to
Applications — no Gatekeeper warnings.

## Without a Developer ID

Running `./scripts/build-dmg.sh` with no env vars still produces a DMG, but it's
only **ad-hoc** signed: it runs on the build machine and elsewhere only via
right-click → Open. Fine for testers, not for public release.

---

## Before the first public push

Resolved: copyright set to Youcef Hanaia, Code-of-Conduct contact set, donation
links removed for now.

Still your call (optional, do anytime):

| Item | Action |
|------|--------|
| Screenshots | Add a screenshot/GIF of the app to `README.md`. |
| Domain | `zappt.app` is taken; pick e.g. `getzappt.com` before marketing. |
| Donations | Re-add a `.github/FUNDING.yml` once you have Sponsors/Ko-fi accounts. |

Then: create the GitHub repo and push (`git init` if not done yet).
