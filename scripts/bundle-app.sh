#!/bin/bash
# Bundle the built Tauri binary into a standalone macOS .app (and .dmg).
#
# Usage: scripts/bundle-app.sh [--dmg]
#   --dmg   also create a disk image next to the .app
#
# The .app is signed ad-hoc (no Apple Developer account required). Because it
# is built locally there is no quarantine attribute, so it opens normally on
# this machine; copies shared with others may need `xattr -dr com.apple.quarantine`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_TAURI="$ROOT/app/src-tauri"
BIN="$SRC_TAURI/target/release/pake"
APP_NAME="DeepSeek Harness"
APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/$APP_NAME.dmg"
IDENTIFIER="com.deepseek-harness.desktop"
VERSION="0.1.0"
EXEC="pake"

if [[ ! -x "$BIN" ]]; then
  echo "error: $BIN not found — run the cargo build first" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --- Binary ---------------------------------------------------------------
cp "$BIN" "$APP/Contents/MacOS/$EXEC"
chmod +x "$APP/Contents/MacOS/$EXEC"

# --- Icon -----------------------------------------------------------------
cp "$SRC_TAURI/icons/icon.icns" "$APP/Contents/Resources/icon.icns"

# --- Bundled runtime (node + @deepseek-ai/dsh install) --------------------
cp -R "$SRC_TAURI/resources/runtime" "$APP/Contents/Resources/runtime"

# --- Info.plist ------------------------------------------------------------
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$IDENTIFIER</string>
  <key>CFBundleExecutable</key>
  <string>$EXEC</string>
  <key>CFBundleIconFile</key>
  <string>icon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSCameraUsageDescription</key>
  <string>Request camera access</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Request microphone access</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

# --- Ad-hoc code signature (required on Apple Silicon) ----------------------
codesign --force --deep --sign - "$APP" 2>/dev/null || codesign --force --sign - "$APP"

echo "==> codesign verification:"
codesign --verify --verbose=2 "$APP" 2>&1 || true
codesign -dv "$APP" 2>&1 | head -5 || true

echo
echo "==> bundle created: $APP"
du -sh "$APP"

# --- Optional DMG -----------------------------------------------------------
if [[ "${1:-}" == "--dmg" ]]; then
  rm -f "$DMG"
  hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null
  echo "==> dmg created: $DMG"
  du -sh "$DMG"
fi
