#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="GMGN 选币评分"
APP="$DIST/$APP_NAME.app"
DMG_ROOT="$DIST/dmg-root"
DMG_TMP="$DIST/$APP_NAME.tmp.dmg"
DMG="$DIST/$APP_NAME.dmg"
VOLUME_NAME="$APP_NAME"

"$ROOT/scripts/build-app.sh" >/dev/null

rm -rf "$DMG_ROOT" "$DMG_TMP" "$DMG"
mkdir -p "$DMG_ROOT"

ditto "$APP" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  "$DMG_TMP" >/dev/null

hdiutil convert "$DMG_TMP" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG" >/dev/null

rm -rf "$DMG_ROOT" "$DMG_TMP"

codesign --force --sign - "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null

echo "$DMG"
