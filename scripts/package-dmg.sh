#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/GrokDesk.app"
RELEASE_DIR="$ROOT_DIR/dist/releases"

"$ROOT_DIR/scripts/package-app.sh"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHITECTURE="$(/usr/bin/file "$APP_BUNDLE/Contents/MacOS/GrokDesk")"
case "$ARCHITECTURE" in
  *arm64*) RELEASE_ARCH="arm64" ;;
  *x86_64*) RELEASE_ARCH="x86_64" ;;
  *)
    echo "Unsupported GrokDesk binary architecture: $ARCHITECTURE" >&2
    exit 1
    ;;
esac

STAGING_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/grokdesk-dmg.XXXXXX")"
cleanup() {
  # The path is created by mktemp above and contains only disposable DMG staging files.
  /bin/rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

/bin/cp -R "$APP_BUNDLE" "$STAGING_DIR/GrokDesk.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/mkdir -p "$RELEASE_DIR"

OUTPUT="$RELEASE_DIR/GrokDesk-v${VERSION}-macos-${RELEASE_ARCH}.dmg"
/usr/bin/hdiutil create \
  -volname "GrokDesk" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$OUTPUT"

/usr/bin/hdiutil verify "$OUTPUT"
echo "Created $OUTPUT"
