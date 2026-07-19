#!/usr/bin/env bash
#
# make-dmg.sh — build the styled Shenzhen Files installer DMG (PLAN.md §4.5).
#
# Pipeline: staging dir (Nautilus.app + /Applications symlink + hidden
# .background/) → hdiutil UDRW image → mount → Finder view options via
# osascript (icon size 128, background picture, icon positions 150/450) →
# detach → hdiutil convert to compressed UDZO.
#
# Usage:
#   ./make-dmg.sh [--check] [path/to/app] [out.dmg]
#
#   --check   dry-run: validate tool + asset availability, then exit.
#
# Defaults: app = <repo>/dist/Shenzhen Files.app,
#           out = <repo>/dist/ShenzhenFiles-mac-<arch>.dmg
#           (asset name matches shenzhen-pdf's ShenzhenPDF-mac-arm64.dmg
#           convention; the self-updater looks for exactly this name).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

vol_name="Shenzhen Files"
bg_png="$script_dir/dmg-background.png"
bg_png_2x="$script_dir/dmg-background@2x.png"

check_only=0
if [[ "${1:-}" == "--check" ]]; then
  check_only=1
  shift
fi

app_path="${1:-$repo_root/dist/Shenzhen Files.app}"
out_dmg="${2:-$repo_root/dist/ShenzhenFiles-mac-$(uname -m).dmg}"

# --- validation (both modes) -------------------------------------------------
fail=0
for tool in hdiutil osascript sips; do
  if command -v "$tool" >/dev/null 2>&1; then
    [[ $check_only -eq 1 ]] && echo "ok: $tool ($(command -v "$tool"))"
  else
    echo "error: required tool not found: $tool" >&2
    fail=1
  fi
done
for asset in "$bg_png" "$bg_png_2x"; do
  if [[ -f "$asset" ]]; then
    [[ $check_only -eq 1 ]] && echo "ok: $(basename "$asset")"
  else
    echo "error: missing background art: $asset" >&2
    echo "       generate it with: swift $script_dir/dmg-background.swift '$bg_png' '$bg_png_2x'" >&2
    fail=1
  fi
done

if [[ $check_only -eq 1 ]]; then
  if [[ -d "$app_path" ]]; then
    echo "ok: app bundle present: $app_path"
  else
    echo "note: app bundle not built yet: $app_path (fine for --check)"
  fi
  [[ $fail -eq 0 ]] && echo "check passed"
  exit "$fail"
fi

[[ $fail -eq 0 ]] || exit 1
if [[ ! -d "$app_path" ]]; then
  echo "error: app bundle not found: $app_path" >&2
  exit 1
fi

app_name="$(basename "$app_path")"

# --- staging -----------------------------------------------------------------
staging="$(mktemp -d /tmp/nautilus-dmg-staging.XXXXXX)"
rw_dmg="$(mktemp -u /tmp/nautilus-dmg-rw.XXXXXX).dmg"
device=""

cleanup() {
  if [[ -n "$device" ]]; then
    hdiutil detach "$device" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$staging" "$rw_dmg"
}
trap cleanup EXIT

cp -R "$app_path" "$staging/$app_name"
ln -s /Applications "$staging/Applications"
mkdir "$staging/.background"
cp "$bg_png" "$bg_png_2x" "$staging/.background/"

# --- read-write image, Finder layout ----------------------------------------
# Size the image with headroom for the Finder metadata (.DS_Store).
hdiutil create -volname "$vol_name" -srcfolder "$staging" -ov \
  -format UDRW -fs HFS+ "$rw_dmg" >/dev/null

attach_out="$(hdiutil attach "$rw_dmg" -readwrite -noverify -noautoopen)"
device="$(echo "$attach_out" | awk '/^\/dev\// { print $1; exit }')"
mount_point="$(echo "$attach_out" | grep -o '/Volumes/.*$' | head -1)"
if [[ -z "$device" || -z "$mount_point" ]]; then
  echo "error: failed to attach $rw_dmg" >&2
  exit 1
fi
echo "mounted $device at $mount_point"

osascript <<EOF
tell application "Finder"
    tell disk "$vol_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:dmg-background.png"
        set position of item "$app_name" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync
hdiutil detach "$device" >/dev/null
device=""

# --- compress to final UDZO --------------------------------------------------
mkdir -p "$(dirname "$out_dmg")"
rm -f "$out_dmg"
hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$out_dmg" >/dev/null

echo "wrote $out_dmg"
