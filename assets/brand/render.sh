#!/usr/bin/env bash
# Renders the README banner and the marketplace preview from brand.html.
# Needs Chromium plus the Inter and JetBrains Mono fonts.
set -euo pipefail
cd "$(dirname "$0")"
root=../..
shot() {
  chromium --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --window-size="$2,$3" \
    --screenshot="$1" "file://$PWD/brand.html?w=$2&h=$3" 2>/dev/null
}
shot "$root/assets/banner.png" 1280 640
shot "$root/preview.png" 1600 900
