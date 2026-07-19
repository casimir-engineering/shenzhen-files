# package/ — Shenzhen Files.app + DMG packaging (PLAN.md §5 Phase 5)

Build a relocatable `dist/Shenzhen Files.app` and a styled
`dist/ShenzhenFiles-mac-arm64.dmg`
from the installed prefix at `<repo>/install`.

## Build pipeline

Run from the repo root, in order (re-run all three whenever the binary or the
install prefix changes — e.g. after other agents rebuild and `meson install`):

```bash
meson install -C build --no-rebuild   # refresh install/ if the build changed
./package/make-app.sh                 # assemble "dist/Shenzhen Files.app"
./package/bundle-dylibs.sh            # bundle dylib closure + rewrite + sign
./package/make-dmg.sh                 # styled UDZO DMG (needs a GUI session)
```

| Script | What it does |
|---|---|
| `make-app.sh` | Assembles the bundle: binary + compiled C launcher (`nautilus-launcher.c`), Info.plist (PlistBuddy-stamped), AppIcon, share payload (nautilus data/ontology, compiled gsettings schemas, Adwaita+hicolor icon themes with regenerated caches, shared-mime-info db, gtk-4.0 emoji data, trimmed locales), gdk-pixbuf loaders with a relocatable `loaders.cache`, GIO modules with `giomodule.cache`, minimal fontconfig config. |
| `bundle-dylibs.sh` | Transitive `otool -L` walker: copies the dylib closure into `Contents/Frameworks`, rewrites ids/references to `@executable_path/../Frameworks/…`, strips absolute rpaths, audits the result, then codesigns every Mach-O and the bundle (ad-hoc by default). |
| `make-dmg.sh` | Staging dir → UDRW image → Finder layout via osascript (background art, 128 px icons, 150/450 slots) → UDZO compression. `--check` for a dry-run. |
| `make-icon.sh` | Regenerates `AppIcon.icns` + `dmg-logo.png` from the Shenzhen Files logo mark (`make-logo.swift`, same 深圳-over-subtitle composition as shenzhen-pdf's icon). |
| `nautilus-launcher.c` | Source of the exec wrapper; sets `XDG_DATA_DIRS`, `GSETTINGS_SCHEMA_DIR`, `GDK_PIXBUF_MODULE_FILE`, `GIO_MODULE_DIR`, `FONTCONFIG_FILE` relative to the bundle, then execs `Contents/MacOS/nautilus`. |

## Standalone vs. Finder integration (installer-facing)

The DMG install is **standalone by default**: dragging Shenzhen Files.app to
Applications changes nothing about macOS. On the very first launch, the app
asks once — "Use as a Standalone App" (default) or "Set Up Finder
Integration…", which merely opens Settings ▸ Finder Integration. There the
user can individually enable: opening folders in Shenzhen Files by default,
syncing Finder's sidebar favorites, and hiding the Finder desktop. Every
toggle is opt-in, off by default, and revertible at any time (the app
records the pre-change system values in
`~/.config/nautilus/macos-integration.ini` and restores them, plus a
"Revert All Integrations" button). The Info.plist also declares a passive
"Open in Shenzhen Files" Services-menu entry, which is harmless in standalone use.

## Release signing + notarization (optional, env-gated)

By default everything is signed **ad-hoc** (`codesign -s -`), which is enough to
run locally. For public distribution, follow the shenzhen-pdf
`portable/build-mac-release.sh` pattern:

One-time setup:

1. Create a **Developer ID Application** certificate (CSR via Keychain Access →
   developer.apple.com → Certificates → Developer ID Application → download and
   double-click the `.cer`). Only the account holder can create these.
2. Store notarization credentials in the keychain:

```bash
xcrun notarytool store-credentials <profile-name> \
  --apple-id <your-apple-id> --team-id <TEAMID> \
  --password <app-specific-password>   # from appleid.apple.com
```

Per release:

```bash
export MAC_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./package/make-app.sh
./package/bundle-dylibs.sh     # signs with hardened runtime + timestamp when
                               # MAC_SIGN_IDENTITY is set, ad-hoc otherwise
./package/make-dmg.sh

xcrun notarytool submit dist/ShenzhenFiles-mac-arm64.dmg \
  --keychain-profile <profile-name> --wait
xcrun stapler staple  dist/ShenzhenFiles-mac-arm64.dmg
xcrun stapler validate dist/ShenzhenFiles-mac-arm64.dmg

# verification
codesign --verify --deep --strict "dist/Shenzhen Files.app"
spctl -a -t open --context context:primary-signature dist/ShenzhenFiles-mac-arm64.dmg
```

## Known relocatability limitations (current binary)

* `NAUTILUS_DATADIR` is baked at compile time to `<repo>/install/share/nautilus`;
  on machines without that path the tag-manager (starring) fails to find its
  ontology and starring is disabled (app otherwise unaffected). Fix belongs in
  the source port (resolve via `XDG_DATA_DIRS`), not in packaging.
* `libtinysparql` hardcodes its loadable-module dir inside the Homebrew Cellar
  (no env override exists). Its modules (FTS parser, HTTP) are not loaded during
  normal starring operation, so this only matters if FTS search over tags is
  ever exercised on a Homebrew-less machine.
* Bundled dylibs still contain `/opt/homebrew` strings in **data** sections
  (compile-time default search paths, all overridden by the launcher env or
  simply absent on clean machines). Mach-O **load commands** are 100 % clean —
  `bundle-dylibs.sh` fails the build otherwise.
