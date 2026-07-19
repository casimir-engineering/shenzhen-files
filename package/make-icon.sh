#!/usr/bin/env bash
#
# make-icon.sh — generate package/AppIcon.icns (and package/dmg-logo.png) from
# the Shenzhen Files logo mark rendered by make-logo.swift.
#
# The mark follows shenzhen-pdf's icon composition ("深圳" over a product
# subtitle, transparent background); each iconset size is rendered natively
# by the Swift script (text scales cleanly, no raster upscaling).
#
# Usage:
#   ./make-icon.sh
#
# Re-runnable: regenerates the iconset from scratch on every invocation.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

logo_script="$script_dir/make-logo.swift"
out_icns="$script_dir/AppIcon.icns"
out_logo="$script_dir/dmg-logo.png"
iconset="$script_dir/build/AppIcon.iconset"

command -v iconutil >/dev/null 2>&1 || { echo "error: iconutil not found" >&2; exit 1; }
command -v swift >/dev/null 2>&1 || { echo "error: swift not found" >&2; exit 1; }
[[ -f "$logo_script" ]] || { echo "error: $logo_script not found" >&2; exit 1; }

rm -rf "$iconset"
mkdir -p "$iconset"

# Standard macOS iconset: each point size at 1x and @2x.
declare -a specs=(
  "16  icon_16x16.png"
  "32  icon_16x16@2x.png"
  "32  icon_32x32.png"
  "64  icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
  "1024 icon_512x512@2x.png"
)
for spec in "${specs[@]}"; do
  size="${spec%% *}"
  name="${spec##* }"
  swift "$logo_script" "$iconset/$name" "$size"
done

iconutil -c icns "$iconset" -o "$out_icns"
echo "wrote $out_icns"

# The DMG background generator (dmg-background.swift) draws this mark above
# the wordmark; render a comfortable 512-px master.
swift "$logo_script" "$out_logo" 512
echo "wrote $out_logo"
