#!/bin/zsh
# Builds the direct-download Mac app (ElmScannerDirect) and packs it into a standard installer
# disk image: open it, drag ElmScanner onto the Applications folder.
#
#   scripts/make-dmg.sh                      -> dist/ElmScanner-<version>.dmg
#
# For a disk image other people can open without Gatekeeper warnings, the app has to be signed
# with a "Developer ID Application" certificate and notarized by Apple. Set these first:
#
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"   # signs the app and the image
#   NOTARY_PROFILE="elmscanner-notary"                             # from: xcrun notarytool store-credentials
#
# Without them the app keeps its development signature and the image only opens cleanly on this Mac.
#
# With a Developer ID managed by Xcode (no certificate in the keychain), notarize the app first and
# then pack it:
#   xcodebuild -exportArchive -archivePath build/ElmScannerDirect.xcarchive -exportPath build/devid-upload \
#     -exportOptionsPlist <plist: method developer-id, destination upload, teamID, signingStyle automatic>
#   (when Apple has finished) xcodebuild -exportArchive … with destination export to get the signed app,
#   xcrun stapler staple ElmScanner.app, then:  APP_PATH=path/to/ElmScanner.app scripts/make-dmg.sh
set -euo pipefail
cd "${0:A:h}/.."

if [[ -n "${APP_PATH:-}" ]]; then
  # A finished app, for example the notarized one from `xcodebuild -exportArchive` (method developer-id,
  # destination upload) and `xcrun stapler staple`. Nothing is built or re-signed.
  APP="$APP_PATH"
  rm -rf build/dmg
else
  xcodegen generate >/dev/null
  ARCHIVE="build/ElmScannerDirect.xcarchive"
  rm -rf build/dmg "$ARCHIVE"
  xcodebuild archive -scheme ElmScannerDirect -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates | tail -1
  APP="$ARCHIVE/Products/Applications/ElmScanner.app"
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
NAME="ElmScanner-$VERSION"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --entitlements ElmScannerDirect.entitlements --sign "$DEVELOPER_ID" "$APP"
fi

STAGE="build/dmg/stage"
mkdir -p "$STAGE/.background" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/dmg-background.png "$STAGE/.background/background.png"

# A writable image first, so Finder can lay the window out; then compressed and read-only.
RW="build/dmg/$NAME-rw.dmg"
hdiutil create -volname "ElmScanner" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEVICE=$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | awk '/Apple_HFS/ {print $1}')
sleep 2
osascript <<APPLESCRIPT || echo "(window layout skipped: Finder automation not allowed)"
tell application "Finder"
  tell disk "ElmScanner"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 800, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:background.png"
    set position of item "ElmScanner.app" of container window to {150, 200}
    set position of item "Applications" of container window to {450, 200}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$DEVICE" -force -quiet
OUT="dist/$NAME.dmg"
rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null

if [[ -n "${DEVELOPER_ID:-}" ]]; then codesign --force --sign "$DEVELOPER_ID" --timestamp "$OUT"; fi
if [[ -n "${NOTARY_PROFILE:-}" && -n "${DEVELOPER_ID:-}" ]]; then
  xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUT"
fi
echo "Built $OUT (version $VERSION, build $BUILD)"
