#!/usr/bin/env bash
# Builds dist/EyeLine.app (universal: Apple silicon + Intel), plus a .zip and a .dmg.
#
# Works with Xcode or just the Command Line Tools; SwiftPM is not required.
#
# Optional environment:
#   VERSION        version string (default: contents of VERSION)
#   ARCHS          "arm64 x86_64" (default) or a single arch
#   SIGN_ID        "Developer ID Application: Name (TEAMID)" for a real signature.
#                  Without it the app is ad-hoc signed.
#   NOTARY_PROFILE keychain profile from `xcrun notarytool store-credentials`;
#                  when set together with SIGN_ID the zip and dmg are notarized and stapled.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
ARCHS="${ARCHS:-arm64 x86_64}"
MIN_OS=14.0
OUT=dist
WORK=.build/app
APP="$OUT/EyeLine.app"

rm -rf "$WORK" "$APP" "$OUT"/EyeLine*.zip "$OUT"/EyeLine*.dmg
mkdir -p "$WORK" "$OUT"

# Some Command Line Tools installs ship a stale duplicate module map that breaks every
# Swift build ("redefinition of module 'SwiftBridging'"). Hide it if it's there.
EXTRA=()
STALE=/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
if [[ -f "$STALE" && -f "$(dirname "$STALE")/bridging.modulemap" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
  : > "$WORK/empty.modulemap"
  cat > "$WORK/overlay.yaml" <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file", "name": "$STALE", "external-contents": "$PWD/$WORK/empty.modulemap" } ] }
EOF
  EXTRA=(-vfsoverlay "$WORK/overlay.yaml" -Xcc -ivfsoverlay -Xcc "$WORK/overlay.yaml")
fi

BINS=()
for ARCH in $ARCHS; do
  echo "==> Compiling for $ARCH"
  D="$WORK/$ARCH"; mkdir -p "$D"
  TARGET="$ARCH-apple-macosx$MIN_OS"
  swiftc ${EXTRA[@]+"${EXTRA[@]}"} -target "$TARGET" -O -whole-module-optimization -parse-as-library \
    -module-name EyeLineCore -emit-module -emit-module-path "$D/EyeLineCore.swiftmodule" \
    -emit-library -static -o "$D/libEyeLineCore.a" Sources/EyeLineCore/*.swift
  swiftc ${EXTRA[@]+"${EXTRA[@]}"} -target "$TARGET" -O -whole-module-optimization \
    -module-name EyeLine -I "$D" -L "$D" -lEyeLineCore \
    -o "$D/EyeLine" Sources/EyeLine/*.swift
  BINS+=("$D/EyeLine")
done

echo "==> Assembling $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/EyeLine"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing"
if [[ -n "${SIGN_ID:-}" ]]; then
  codesign --force --timestamp --options runtime --entitlements Resources/EyeLine.entitlements --sign "$SIGN_ID" "$APP"
else
  codesign --force --sign - --entitlements Resources/EyeLine.entitlements "$APP"
fi
codesign --verify --strict "$APP"

echo "==> Packaging"
ZIP="$OUT/EyeLine.zip"
DMG="$OUT/EyeLine.dmg"
ditto -c -k --keepParent "$APP" "$ZIP"

STAGE="$WORK/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "EyeLine" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

if [[ -n "${SIGN_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing"
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APP"
  rm -f "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
fi

lipo -archs "$APP/Contents/MacOS/EyeLine"
ls -lh "$ZIP" "$DMG"
