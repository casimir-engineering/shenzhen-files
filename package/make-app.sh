#!/usr/bin/env bash
#
# make-app.sh — assemble a relocatable dist/Nautilus.app from the installed
# prefix at <repo>/install (PLAN.md §5 Phase 5 task 1).
#
# What goes where:
#   Contents/MacOS/nautilus            real meson-built binary (from install/bin)
#   Contents/MacOS/nautilus-launcher   tiny compiled exec-wrapper (CFBundleExecutable);
#                                      exports XDG_DATA_DIRS / GSETTINGS_SCHEMA_DIR /
#                                      GDK_PIXBUF_MODULE_FILE / GIO_MODULE_DIR /
#                                      FONTCONFIG_FILE relative to the bundle, then
#                                      execs the real binary (see nautilus-launcher.c)
#   Contents/Frameworks/               libnautilus-extension + (later) the full dylib
#                                      closure written by bundle-dylibs.sh
#   Contents/Resources/share/          nautilus data + ontology + icons + COMPILED
#                                      gsettings schemas + adwaita/hicolor themes with
#                                      regenerated icon caches + shared-mime-info db +
#                                      gtk-4.0 data (emoji) + trimmed locales
#   Contents/Resources/lib/            gdk-pixbuf loaders (regenerated relocatable
#                                      loaders.cache) + GIO modules (giomodule.cache)
#   Contents/Resources/etc/fonts/      minimal fontconfig config (safety net only;
#                                      GTK4 on macOS uses CoreText)
#
# Run order for a full package:  make-app.sh -> bundle-dylibs.sh -> make-dmg.sh
#
# Usage: ./package/make-app.sh [app-path]  (default: <repo>/dist/Shenzhen Files.app)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

BREW="${HOMEBREW_PREFIX:-/opt/homebrew}"
INSTALL="$repo_root/install"
APP="${1:-$repo_root/dist/Shenzhen Files.app}"

# Identity stamped into Info.plist. Shenzhen-product conventions (mirrors
# shenzhen-pdf): bundle id com.intuition.<product>, date-based version
# YY.M.DD with CFBundleVersion as the same-day build number — together they
# form the release tag YY.M.DD-BUILD the self-updater compares against.
BUNDLE_ID="com.intuition.shenzhenfiles"
SHORT_VERSION="26.7.19"
BUNDLE_VERSION="1"

# Locales kept in the bundle (nautilus ships ~120; trim to a reasonable set).
LOCALES=(ar ca cs da de el en_GB es eu fi fr gl he hi hu id it ja ko nb nl pl
         pt pt_BR ro ru sk sv th tr uk vi zh_CN zh_TW)

# gettext domains pulled from Homebrew's share/locale for the bundled libs.
BREW_DOMAINS=(glib20 gtk40 libadwaita gdk-pixbuf gsettings-desktop-schemas
              shared-mime-info json-glib-1.0 glib-networking tinysparql3)

for f in "$INSTALL/bin/nautilus" "$INSTALL/lib/libnautilus-extension.4.dylib" \
         "$script_dir/Info.plist.template" "$script_dir/AppIcon.icns" \
         "$script_dir/nautilus-launcher.c"; do
  [[ -e "$f" ]] || { echo "error: missing input: $f" >&2; exit 1; }
done

echo "==> assembling $APP"
rm -rf "$APP"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$MACOS" "$RES" "$FRAMEWORKS"

# --- executables ---------------------------------------------------------------
cp "$INSTALL/bin/nautilus" "$MACOS/nautilus"
cc -O2 -Wall -Wextra -o "$MACOS/nautilus-launcher" "$script_dir/nautilus-launcher.c"
cp "$INSTALL/lib/libnautilus-extension.4.dylib" "$FRAMEWORKS/"
chmod -R u+w "$MACOS" "$FRAMEWORKS"

# --- Info.plist + icon -----------------------------------------------------------
cp "$script_dir/Info.plist.template" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleIdentifier $BUNDLE_ID" \
  -c "Set :CFBundleShortVersionString $SHORT_VERSION" \
  -c "Set :CFBundleVersion $BUNDLE_VERSION" \
  "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$script_dir/AppIcon.icns" "$RES/AppIcon.icns"

# --- share payload ---------------------------------------------------------------
mkdir -p "$RES/share"

# Nautilus data (ontology is required by the tag manager / starring).
cp -R "$INSTALL/share/nautilus" "$RES/share/nautilus"

# Locales: nautilus's own domain (trimmed) + Homebrew domains for bundled libs.
for loc in "${LOCALES[@]}"; do
  src="$INSTALL/share/locale/$loc"
  [[ -d "$src" ]] || continue
  mkdir -p "$RES/share/locale/$loc/LC_MESSAGES"
  cp "$src/LC_MESSAGES/nautilus.mo" "$RES/share/locale/$loc/LC_MESSAGES/" 2>/dev/null || true
  for dom in "${BREW_DOMAINS[@]}"; do
    mo="$BREW/share/locale/$loc/LC_MESSAGES/$dom.mo"
    [[ -f "$mo" ]] && cp -L "$mo" "$RES/share/locale/$loc/LC_MESSAGES/"
  done
done

# GSettings schemas: nautilus + gtk4 + gsettings-desktop-schemas, compiled into
# ONE cache inside the bundle (TRAP: gschemas.compiled must be regenerated here —
# a copied cache from install/ or brew would carry that machine's paths/mix).
mkdir -p "$RES/share/glib-2.0/schemas"
cp "$INSTALL/share/glib-2.0/schemas/"*.xml "$RES/share/glib-2.0/schemas/"
cp -L "$BREW/share/glib-2.0/schemas/"*.xml "$RES/share/glib-2.0/schemas/"
"$BREW/bin/glib-compile-schemas" "$RES/share/glib-2.0/schemas"

# Icon themes: Adwaita + hicolor (brew) merged with nautilus's own hicolor icons.
# TRAP: icon-theme.cache staleness — regenerate caches after merging.
mkdir -p "$RES/share/icons"
cp -RL "$BREW/share/icons/Adwaita" "$RES/share/icons/Adwaita"
cp -RL "$BREW/share/icons/hicolor" "$RES/share/icons/hicolor"
ditto "$INSTALL/share/icons/hicolor" "$RES/share/icons/hicolor"
chmod -R u+w "$RES/share/icons"
rm -f "$RES/share/icons/Adwaita/icon-theme.cache" "$RES/share/icons/hicolor/icon-theme.cache"
"$BREW/bin/gtk4-update-icon-cache" -q -t -f "$RES/share/icons/Adwaita"
"$BREW/bin/gtk4-update-icon-cache" -q -t -f "$RES/share/icons/hicolor"

# shared-mime-info: ship the XML source and regenerate the binary db in place.
mkdir -p "$RES/share/mime/packages"
cp -L "$BREW/share/mime/packages/freedesktop.org.xml" "$RES/share/mime/packages/"
"$BREW/bin/update-mime-database" "$RES/share/mime" 2>/dev/null

# GTK4's own share data. GTK4's css/media are compiled-in gresources; on this
# brew install share/gtk-4.0 holds only the emoji data + builder schema (there is
# no /opt/homebrew/lib/gtk-4.0 module dir at all — nothing else to bundle).
mkdir -p "$RES/share/gtk-4.0"
cp -RL "$BREW/share/gtk-4.0/emoji" "$RES/share/gtk-4.0/emoji"
cp -L "$BREW/share/gtk-4.0/gtk4builder.rng" "$RES/share/gtk-4.0/" 2>/dev/null || true

# Minimal fontconfig config (see launcher comment; normally unused on macOS).
mkdir -p "$RES/etc/fonts"
cat > "$RES/etc/fonts/fonts.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/System/Library/Fonts</dir>
  <dir>/Library/Fonts</dir>
  <dir>~/Library/Fonts</dir>
  <cachedir prefix="xdg">fontconfig</cachedir>
</fontconfig>
EOF

# --- loadable modules ------------------------------------------------------------
# gdk-pixbuf loaders. TRAP: loaders.cache is generated with absolute paths; a
# cache copied from brew would point at /opt/homebrew. Also, query-loaders can't
# run against the raw bundled copies (their @rpath deps, e.g. the SVG loader's
# librsvg, aren't rewritten until bundle-dylibs.sh) — so generate the cache from
# a staging dir of symlinks into Homebrew (where deps still resolve), then
# rewrite the paths to @executable_path (dlopen resolves it relative to
# Contents/MacOS/nautilus — verified to work on this host).
PIXBUF_DIR="$RES/lib/gdk-pixbuf-2.0/2.10.0"
mkdir -p "$PIXBUF_DIR/loaders"
# .so only: brew also ships libpixbufloader_svg.dylib as a duplicate of the .so.
cp -L "$BREW/lib/gdk-pixbuf-2.0/2.10.0/loaders/"*.so "$PIXBUF_DIR/loaders/"
chmod -R u+w "$PIXBUF_DIR"
stage="$(mktemp -d /tmp/nautilus-loaders.XXXXXX)"
for f in "$BREW/lib/gdk-pixbuf-2.0/2.10.0/loaders/"*.so; do
  ln -s "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f")" \
        "$stage/$(basename "$f")"
done
GDK_PIXBUF_MODULEDIR="$stage" \
  "$BREW/opt/gdk-pixbuf/bin/gdk-pixbuf-query-loaders" > "$PIXBUF_DIR/loaders.cache"
rm -rf "$stage"
sed -i '' "s|\"$stage/|\"@executable_path/../Resources/lib/gdk-pixbuf-2.0/2.10.0/loaders/|g" \
  "$PIXBUF_DIR/loaders.cache"
if grep -qE '^"/.*\.(so|dylib)"' "$PIXBUF_DIR/loaders.cache"; then
  echo "error: absolute paths left in loaders.cache" >&2
  exit 1
fi

# GIO modules (TLS backend). TRAP: giomodule.cache — regenerate in the bundle;
# entries are basenames, so the cache itself is relocatable.
GIO_DIR="$RES/lib/gio/modules"
mkdir -p "$GIO_DIR"
cp -L "$BREW/lib/gio/modules/"*.so "$GIO_DIR/"
chmod -R u+w "$GIO_DIR"
"$BREW/bin/gio-querymodules" "$GIO_DIR"

echo "==> app assembled: $APP"
echo "    next: ./package/bundle-dylibs.sh \"$APP\""
