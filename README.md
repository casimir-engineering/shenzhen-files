<h1 align="center">Shenzhen Files</h1>
<p align="center"><b>GNOME Files (Nautilus), ported to macOS as a fast native-feeling file manager.</b></p>

<div align="center">

<a href="https://github.com/casimir-engineering/shenzhen-files/releases/latest/download/ShenzhenFiles-mac-arm64.dmg"><img src="https://img.shields.io/badge/Download%20for%20macOS-Apple%20Silicon-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS (Apple Silicon)" height="46"></a>

<sub>Latest <b>26.7.19-1</b> · Apple Silicon</sub>

<a href="https://github.com/casimir-engineering/shenzhen-files/releases/latest">All releases</a> · <a href="https://github.com/casimir-engineering/shenzhen-files">Source</a>

</div>

<p align="center">Browse with tabs, grid and list views, starring, and batch rename — with native macOS thumbnails, Spotlight search, and a Finder-like Dock lifecycle. <b>Based on GNOME Files (Nautilus), a separate project, not affiliated with it.</b></p>

---

## What the port adds on macOS

- **Native menu bar** — the full GNOME Files menu rendered as a real NSMenu bar (File · Edit · View · Go · Window · Help), with working key equivalents.
- **Finder-like Dock lifecycle** — closing the last window keeps the app alive; clicking the Dock icon opens a new window centered on the screen you clicked from.
- **QuickLook everywhere** — real macOS thumbnails in the grid, space-bar preview, and LaunchServices file-type icons for anything QuickLook can't draw.
- **Spotlight-backed search** — the search field streams results from Spotlight, scoped to the folder you're in.
- **System integration, strictly opt-in** — open folders by default, sync Finder's sidebar favorites, hide the Finder desktop. Everything is off by default, revertible, and records the prior system state before changing anything.
- **Trash, Show in Finder, Open in Terminal, "Open With" with real app icons** — all bridged to the native macOS services.
- **Full Disk Access onboarding** — a one-time walkthrough for the TCC grant that browsing the Trash needs.
- **Auto-update** — a silent daily check against GitHub releases plus a "Check for Updates…" menu item; updates download, verify (sha256 from the GitHub API), swap the bundle and relaunch in place.

## Install

Download the DMG above, drag **Shenzhen Files** onto **Applications**, done. The app is ad-hoc signed: on first launch, right-click ▸ Open (or allow it under System Settings ▸ Privacy & Security) to pass Gatekeeper.

For Trash browsing, grant Full Disk Access when the app offers the walkthrough (System Settings ▸ Privacy & Security ▸ Full Disk Access).

## Build from source

The port is maintained as a patch against upstream GNOME Nautilus plus a packaging pipeline:

```bash
git clone https://gitlab.gnome.org/GNOME/nautilus.git
cd nautilus && git apply ../patches/macos-port-full.patch

# Homebrew deps: gtk4 libadwaita glib meson ninja pkg-config gettext \
#   gdk-pixbuf librsvg tinysparql json-glib libportal desktop-file-utils \
#   shared-mime-info
meson setup build -Dbuildtype=debugoptimized -Dmacos_port=true
ninja -C build
meson install -C build --no-rebuild

./package/make-app.sh          # assemble dist/Shenzhen Files.app
./package/bundle-dylibs.sh     # bundle dylib closure + rewrite + sign
./package/make-dmg.sh          # styled installer DMG
```

See [`package/README.md`](package/README.md) for the packaging details and [`docs/STATUS.md`](docs/STATUS.md) for the current state of the port.

## Updater trust model

Releases are ad-hoc signed (no Developer ID). The self-updater therefore pins its trust to TLS against `api.github.com`/`github.com` and the release asset's sha256 digest from the GitHub API, plus a bundle-id and version pin on the extracted app — an update without a digest is rejected. The swap is a move-aside two-rename with rollback, and the relaunched app confirms the version before the previous bundle is discarded.

## License

GPL-2.0-or-later, same as upstream Nautilus. The port patch and packaging scripts are under the same license.
