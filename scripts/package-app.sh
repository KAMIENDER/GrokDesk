#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/GrokDesk.app"
CONTENTS="$APP_DIR/Contents"

cd "$PROJECT_DIR"
swift build -c release --product GrokDesk
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp ".build/release/GrokDesk" "$CONTENTS/MacOS/GrokDesk"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$CONTENTS/Resources/AppIcon.png"
for localization in "$PROJECT_DIR"/Resources/*.lproj; do
  [[ -d "$localization" ]] && cp -R "$localization" "$CONTENTS/Resources/"
done
codesign --force --deep --sign - "$APP_DIR"
echo "Created $APP_DIR"
