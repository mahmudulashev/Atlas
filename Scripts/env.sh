#!/bin/bash
# Atlas build environment.
# NOTE: the project lives on an iCloud-synced Desktop, which stamps
# com.apple.FinderInfo onto files and breaks codesign. All build output
# therefore goes to a local, non-synced cache directory.
# Use existing DEVELOPER_DIR if set, otherwise default to CommandLineTools if available
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
export SDK="$(xcrun --show-sdk-path)"
export APP_NAME="Atlas"
export BUNDLE_ID="uz.atlas.Atlas"
export WIDGET_ID="uz.atlas.Atlas.Widget"
export TARGET="arm64-apple-macosx14.0"
export SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BUILD_ROOT="${BUILD_ROOT:-$HOME/Library/Caches/uz.atlas.build}"
export APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"

