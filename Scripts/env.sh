#!/bin/bash
# Atlas build environment.
# NOTE: the project lives on an iCloud-synced Desktop, which stamps
# com.apple.FinderInfo onto files and breaks codesign. All build output
# therefore goes to a local, non-synced cache directory.
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDK="$(xcrun --show-sdk-path)"
export APP_NAME="Atlas"
export BUNDLE_ID="uz.atlas.Atlas"
export WIDGET_ID="uz.atlas.Atlas.Widget"
export TARGET="arm64-apple-macosx14.0"
export SRC_ROOT="$HOME/Desktop/Atlas"
export BUILD_ROOT="$HOME/Library/Caches/uz.atlas.build"
export APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"
