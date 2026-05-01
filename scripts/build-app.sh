#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TodoDesk"

APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icns"
ICON_BUNDLE_NAME="AppIconNoBorder"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [[ ! -f "$ICON_SOURCE" ]]; then
    "$ROOT_DIR/scripts/generate-icon.sh"
fi

CORE_SOURCES=("$ROOT_DIR"/Sources/TodoDeskCore/*.m)
APP_SOURCES=("$ROOT_DIR"/Sources/TodoDeskApp/*.m)

clang -fobjc-arc -Wall -Wextra -Werror \
    -I"$ROOT_DIR/Sources/TodoDeskCore" \
    -I"$ROOT_DIR/Sources/TodoDeskApp" \
    "${CORE_SOURCES[@]}" \
    "${APP_SOURCES[@]}" \
    -framework Cocoa \
    -framework QuartzCore \
    -framework UniformTypeIdentifiers \
    -framework UserNotifications \
    -o "$MACOS_DIR/$APP_NAME"

chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_Hant</string>
    <key>CFBundleExecutable</key>
    <string>TodoDesk</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.0xscot.tododesk</string>
    <key>CFBundleIconFile</key>
    <string>AppIconNoBorder</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TodoDesk</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cp "$ICON_SOURCE" "$RESOURCES_DIR/$ICON_BUNDLE_NAME.icns"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
xattr -cr "$APP_DIR"

echo "Built $APP_DIR"
