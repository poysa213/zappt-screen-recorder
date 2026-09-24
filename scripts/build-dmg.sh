#!/bin/bash
#
# Builds Zappt.app (Release) and packages it into a drag-to-install DMG.
#
#   ./scripts/build-dmg.sh
#
# Ad-hoc signing (default): the DMG runs on THIS Mac and on others only via
# right-click -> Open. Not suitable for public distribution.
#
# Proper distribution -- set these and re-run to get a signed + notarized DMG:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE="zappt-notary"   # created once with:
#     xcrun notarytool store-credentials zappt-notary \
#       --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Zappt"
CONFIG="Release"
APP_NAME="Zappt.app"
VOL_NAME="Zappt"
DIST="dist"
ENTITLEMENTS="scripts/Zappt.entitlements"
DERIVED="build/dd"

echo "==> Generating project"
xcodegen generate >/dev/null

echo "==> Building ${CONFIG}"
xcodebuild -project Zappt.xcodeproj -scheme "${SCHEME}" -configuration "${CONFIG}" \
    -derivedDataPath "${DERIVED}" CODE_SIGNING_ALLOWED=NO build >/dev/null

APP="${DERIVED}/Build/Products/${CONFIG}/${APP_NAME}"
if [ ! -d "${APP}" ]; then
    echo "Build product not found at ${APP}"
    exit 1
fi

rm -rf "${DIST}"
mkdir -p "${DIST}"
STAGE="${DIST}/stage"
mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/"

if [ -n "${SIGN_IDENTITY:-}" ]; then
    echo "==> Signing with Developer ID + hardened runtime"
    codesign --force --deep --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" --sign "${SIGN_IDENTITY}" "${STAGE}/${APP_NAME}"
    codesign --verify --strict --verbose=2 "${STAGE}/${APP_NAME}"
else
    echo "==> No SIGN_IDENTITY: ad-hoc signing (local use only; Gatekeeper warns elsewhere)"
    codesign --force --deep --sign - "${STAGE}/${APP_NAME}"
fi

# Notarize + staple the .app itself (robust: launches offline, even copied out
# of the DMG) BEFORE packaging.
if [ -n "${SIGN_IDENTITY:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "==> Notarizing app (can take a few minutes)"
    ZIP="${DIST}/Zappt-app.zip"
    ditto -c -k --keepParent "${STAGE}/${APP_NAME}" "${ZIP}"
    xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
    rm -f "${ZIP}"
    echo "==> Stapling app"
    xcrun stapler staple "${STAGE}/${APP_NAME}"
    xcrun stapler validate "${STAGE}/${APP_NAME}"
fi

echo "==> Creating DMG"
ln -s /Applications "${STAGE}/Applications"
DMG="${DIST}/Zappt.dmg"
hdiutil create -volname "${VOL_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}" >/dev/null
rm -rf "${STAGE}"

if [ -n "${SIGN_IDENTITY:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "Done: signed + notarized DMG (app stapled) at ${DMG}"
else
    echo "Done: ad-hoc DMG at ${DMG}"
    echo "On another Mac, first launch needs right-click -> Open, or run:"
    echo "  xattr -dr com.apple.quarantine /Applications/Zappt.app"
fi

du -h "${DMG}"
