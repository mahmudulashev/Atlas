#!/bin/bash
# Packages Xarita.app into a distributable disk image.
#
#   ./Scripts/make-dmg.sh
#
# Produces Xarita-<version>.dmg in the project root: drag-to-Applications
# layout, custom background, compressed.
set -euo pipefail

cd "$(dirname "$0")/.."
source Scripts/env.sh

VERSION="${VERSION:-1.0}"
VOLUME_NAME="Xarita"
STAGE="$BUILD_ROOT/dmg-stage"
RAW_DMG="$BUILD_ROOT/Xarita-raw.dmg"
FINAL_DMG="$SRC_ROOT/Xarita-$VERSION.dmg"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# ---- 1. Fresh build -----------------------------------------------------
echo "▸ Building app…"
./Scripts/build.sh > /dev/null

[ -d "$APP_BUNDLE" ] || { echo "✗ no app bundle at $APP_BUNDLE"; exit 1; }

# ---- 2. Stage the contents ---------------------------------------------
echo "▸ Staging…"
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
rm -rf "$STAGE" "$RAW_DMG"
mkdir -p "$STAGE/.background"

cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Resources/dmg-background.png "$STAGE/.background/background.png"
cp Resources/dmg-background@2x.png "$STAGE/.background/background@2x.png"

# ---- 3. Read-write image, so Finder can record the layout ---------------
SIZE_KB=$(du -sk "$STAGE" | cut -f1)
SIZE_MB=$(( SIZE_KB / 1024 + 24 ))
echo "▸ Creating image (${SIZE_MB}MB)…"
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME_NAME" -fs HFS+ \
  -format UDRW -size "${SIZE_MB}m" "$RAW_DMG" -quiet

hdiutil attach "$RAW_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
sleep 1

# ---- 4. Window layout ---------------------------------------------------
# Finder scripting needs Automation permission. If it is refused the image is
# still perfectly usable, just without the arranged window, so a failure here
# is reported and shrugged off rather than aborting the build.
echo "▸ Arranging window…"
if osascript <<APPLESCRIPT 2>/dev/null
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 140, 800, 540}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set background picture of viewOptions to file ".background:background.png"
    set position of item "Xarita.app" of container window to {150, 195}
    set position of item "Applications" of container window to {450, 195}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
then
  echo "  ✓ layout applied"
else
  echo "  ! Finder automation unavailable — image built without arranged layout"
fi

sync
hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force -quiet

# ---- 5. Compress --------------------------------------------------------
echo "▸ Compressing…"
rm -f "$FINAL_DMG"
hdiutil convert "$RAW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet
rm -f "$RAW_DMG"
rm -rf "$STAGE"

# ---- 6. Verify ----------------------------------------------------------
hdiutil verify "$FINAL_DMG" -quiet && echo "▸ Image verified"
FINAL_SIZE=$(du -h "$FINAL_DMG" | cut -f1)
echo "✓ $FINAL_DMG ($FINAL_SIZE)"
