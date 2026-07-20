#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/GrokDesk.app"
RELEASE_DIR="$ROOT_DIR/dist/releases"
SPARKLE_ACCOUNT="io.github.KAMIENDER.GrokDesk"

"$ROOT_DIR/scripts/package-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ARCHITECTURE="$(/usr/bin/file "$APP_BUNDLE/Contents/MacOS/GrokDesk")"
case "$ARCHITECTURE" in
  *arm64*\ *x86_64*|*x86_64*\ *arm64*) RELEASE_ARCH="universal" ;;
  *arm64*) RELEASE_ARCH="arm64" ;;
  *x86_64*) RELEASE_ARCH="x86_64" ;;
  *) echo "Unsupported GrokDesk binary architecture: $ARCHITECTURE" >&2; exit 1 ;;
esac

/bin/mkdir -p "$RELEASE_DIR"
ZIP_NAME="GrokDesk-v${VERSION}-macos-${RELEASE_ARCH}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$RELEASE_DIR/$ZIP_NAME"

SKIP_PACKAGE_APP=1 "$ROOT_DIR/scripts/package-dmg.sh"

SPARKLE_BIN="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
UPDATE_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/grokdesk-update.XXXXXX")"
cleanup() { /bin/rm -rf "$UPDATE_DIR"; }
trap cleanup EXIT
/bin/cp "$RELEASE_DIR/$ZIP_NAME" "$UPDATE_DIR/$ZIP_NAME"

TAG="${GROKDESK_RELEASE_TAG:-v$VERSION}"
DOWNLOAD_PREFIX="https://github.com/KAMIENDER/GrokDesk/releases/download/${TAG}/"
GENERATE_ARGS=(
  --download-url-prefix "$DOWNLOAD_PREFIX"
  --link "https://github.com/KAMIENDER/GrokDesk/releases/tag/${TAG}"
  --maximum-versions 1
  --maximum-deltas 0
  -o appcast.xml
  "$UPDATE_DIR"
)

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  # CI passes the secret on stdin so it never appears in arguments or files.
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" --ed-key-file - "${GENERATE_ARGS[@]}"
else
  "$SPARKLE_BIN/generate_appcast" --account "$SPARKLE_ACCOUNT" "${GENERATE_ARGS[@]}"
fi

/bin/cp "$UPDATE_DIR/appcast.xml" "$RELEASE_DIR/appcast.xml"
echo "Created $RELEASE_DIR/$ZIP_NAME and $RELEASE_DIR/appcast.xml"
