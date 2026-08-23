#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/env.sh
mkdir -p Resources
xcrun swift Scripts/make-icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf Resources/AppIcon.iconset
echo "✓ Resources/AppIcon.icns ($(du -h Resources/AppIcon.icns | cut -f1))"
