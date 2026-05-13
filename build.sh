#!/usr/bin/env bash
# Top-level: fetch upstreams → build core → wire project.
# Pass `--build-app` as a final step to also run `xcodebuild` for macOS
# as a smoke test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

bash Scripts/fetch_third_party.sh
bash Scripts/build_core.sh
ruby Scripts/wire_project.rb

if [[ "${1:-}" == "--build-app" ]]; then
  echo "→ xcodebuild macOS smoke test"
  xcodebuild \
    -project Everywhere.xcodeproj \
    -scheme Everywhere \
    -destination 'generic/platform=macOS' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

echo "✓ done"
