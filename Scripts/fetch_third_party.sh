#!/usr/bin/env bash
# Clones the upstream Go repos at the tags pinned in PATCHES.md.
# Idempotent — already-cloned repos at the right tag are left alone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY="$ROOT/ThirdParty"
mkdir -p "$THIRD_PARTY"

clone_at_tag() {
  local url="$1" tag="$2" dest="$3"
  local path="$THIRD_PARTY/$dest"
  if [[ -d "$path/.git" ]]; then
    local current
    current="$(git -C "$path" describe --tags --exact-match 2>/dev/null || echo "")"
    if [[ "$current" == "$tag" ]]; then
      echo "✓ $dest @ $tag (cached)"
      return
    fi
    echo "↻ $dest at $current → $tag (rm + reclone)"
    rm -rf "$path"
  fi
  echo "⤓ $dest @ $tag"
  git clone --depth 1 --branch "$tag" "$url" "$path"
}

clone_at_tag https://github.com/XTLS/Xray-core.git       v26.3.27 Xray-core
clone_at_tag https://github.com/SagerNet/sing-box.git    v1.13.11 sing-box
clone_at_tag https://github.com/MetaCubeX/mihomo.git     v1.19.24 mihomo

# yacd dashboard. The fork has no gh-pages branch / Pages site / release
# tarball, so we clone master and run the Vite build ourselves. The
# resulting `dist/` is what ControllerView serves over the yacd:// URL
# scheme — Scripts/wire_project.rb registers ThirdParty/yacd-gh-pages
# as a "blue folder" resource.
YACD_REPO=https://github.com/hiDandelion/Yacd-meta.git
YACD_SRC="$THIRD_PARTY/yacd-source"
YACD_DIST="$THIRD_PARTY/yacd-gh-pages"

if [[ ! -d "$YACD_SRC/.git" ]]; then
  echo "⤓ yacd-source (hiDandelion/Yacd-meta master)"
  git clone --depth 1 "$YACD_REPO" "$YACD_SRC"
else
  echo "✓ yacd-source (cached)"
fi

if [[ ! -d "$YACD_DIST" || -z "$(ls -A "$YACD_DIST" 2>/dev/null)" ]]; then
  echo "→ pnpm install + build (yacd)"
  ( cd "$YACD_SRC" && pnpm install --frozen-lockfile && pnpm build )
  # vite.config.ts overrides outDir to `public/`, not the default `dist/`
  rm -rf "$YACD_DIST"
  cp -R "$YACD_SRC/public" "$YACD_DIST"
  echo "✓ yacd build → $YACD_DIST"
else
  echo "✓ yacd-gh-pages (cached)"
fi
