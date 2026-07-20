#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/GrokDesk.app"
CONTENTS="$APP_DIR/Contents"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

cd "$PROJECT_DIR"
SWIFT_BUILD_ARGS=(-c release --product GrokDesk)
if [[ -n "${SWIFT_BUILD_ARCH:-}" ]]; then
  SWIFT_BUILD_ARGS+=(--arch "$SWIFT_BUILD_ARCH")
fi
swift build "${SWIFT_BUILD_ARGS[@]}"
SWIFT_BIN_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$SWIFT_BIN_DIR/GrokDesk" "$CONTENTS/MacOS/GrokDesk"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$CONTENTS/Resources/AppIcon.png"
for localization in "$PROJECT_DIR"/Resources/*.lproj; do
  [[ -d "$localization" ]] && cp -R "$localization" "$CONTENTS/Resources/"
done

# Sparkle is a dynamic binary framework. SwiftPM links it but our hand-built
# app bundle must copy and sign the framework explicitly.
SPARKLE_FRAMEWORK="$(find "$PROJECT_DIR/.build" -path '*/Sparkle.framework' -type d -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found after swift build" >&2
  exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/Sparkle.framework"
if ! /usr/bin/otool -l "$CONTENTS/MacOS/GrokDesk" | /usr/bin/grep -q '@executable_path/../Frameworks'; then
  /usr/bin/install_name_tool -add_rpath '@executable_path/../Frameworks' "$CONTENTS/MacOS/GrokDesk"
fi

codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework"
codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_DIR"
echo "Created $APP_DIR"
