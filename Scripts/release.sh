#!/bin/bash
# Builds the DMG installer and creates a GitHub Release using GitHub CLI (gh).
#
# Usage:
#   ./Scripts/release.sh [version]
# Example:
#   ./Scripts/release.sh 1.0
set -euo pipefail

cd "$(dirname "$0")/.."
source Scripts/env.sh

VERSION="${1:-1.0}"
TAG="v$VERSION"
DMG_FILE="Atlas-$VERSION.dmg"
SHA_FILE="Atlas-$VERSION.dmg.sha256"

echo "=== Building Atlas v$VERSION ==="
export VERSION
./Scripts/make-dmg.sh

echo "=== Generating SHA256 Checksum ==="
shasum -a 256 "$DMG_FILE" > "$SHA_FILE"
cat "$SHA_FILE"

echo ""
echo "DMG package ready at: $DMG_FILE"
echo "Checksum file:        $SHA_FILE"
echo ""

if command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) detected."
  read -r -p "Do you want to publish this release to GitHub as $TAG? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Creating GitHub Release $TAG..."
    gh release create "$TAG" "$DMG_FILE" "$SHA_FILE" \
      --title "Atlas $TAG" \
      --generate-notes
    echo "✓ Published release $TAG to GitHub!"
  else
    echo "Release creation skipped. You can manually create it with:"
    echo "  gh release create $TAG $DMG_FILE $SHA_FILE --title \"Atlas $TAG\" --generate-notes"
  fi
else
  echo "To publish via GitHub CLI, install gh and run:"
  echo "  gh release create $TAG $DMG_FILE $SHA_FILE --title \"Atlas $TAG\" --generate-notes"
fi
