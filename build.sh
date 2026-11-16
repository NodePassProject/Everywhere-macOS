#!/usr/bin/env bash
# Wires the Xcode project; pass --build-app for a macOS smoke build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ruby -e "require 'xcodeproj'" 2>/dev/null || gem install --user-install xcodeproj

ruby Scripts/wire_project.rb

if [[ "${1:-}" == "--build-app" ]]; then
  echo "→ xcodebuild macOS smoke test"
  xcodebuild \
    -project Everywhere.xcodeproj \
    -scheme Everywhere \
    -destination 'generic/platform=macOS' \
    -configuration Debug \
    -skipPackagePluginValidation \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

echo "✓ done"
