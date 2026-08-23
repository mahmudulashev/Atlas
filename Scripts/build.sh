#!/bin/bash
# Builds Xarita.app from source using the Command Line Tools toolchain.
#
#   ./Scripts/build.sh          build + sign
#   ./Scripts/build.sh run      build + sign + launch
#   ./Scripts/build.sh install  build + sign + copy to /Applications
#
set -euo pipefail

cd "$(dirname "$0")/.."
source Scripts/env.sh

MODE="${1:-build}"
CONTENTS="$APP_BUNDLE/Contents"

echo "▸ Toolchain : $(xcrun swiftc --version | head -1)"
echo "▸ SDK       : $SDK"
echo "▸ Output    : $APP_BUNDLE"

mkdir -p "$BUILD_ROOT"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# ---- Compile -----------------------------------------------------------
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find Sources/Xarita -name '*.swift' | sort)
echo "▸ Compiling ${#SOURCES[@]} files…"

xcrun swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -parse-as-library \
  -O -whole-module-optimization \
  -framework SwiftUI -framework AppKit -framework UserNotifications -framework WidgetKit \
  -o "$CONTENTS/MacOS/$APP_NAME" \
  "${SOURCES[@]}"

# ---- Bundle metadata ---------------------------------------------------
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT licensed</string>
</dict>
</plist>
PLIST
plutil -lint "$CONTENTS/Info.plist" > /dev/null

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
fi

# ---- Sign --------------------------------------------------------------
# iCloud-synced folders stamp com.apple.FinderInfo onto files, which makes
# codesign refuse the bundle. Strip xattrs first; the build lives outside the
# synced tree precisely so this stays a formality.
xattr -cr "$APP_BUNDLE"
codesign --force --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "▸ Signed    : ad-hoc, verified"
echo "▸ Size      : $SIZE"
echo "✓ Built $APP_BUNDLE"

case "$MODE" in
  run)
    pkill -x "$APP_NAME" 2>/dev/null || true
    open "$APP_BUNDLE"
    ;;
  install)
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
    ;;
esac
