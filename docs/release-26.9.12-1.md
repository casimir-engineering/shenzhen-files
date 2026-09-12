# Shenzhen Files 26.9.12-1

- Shows the startup disk, external disks, disk images, and network volumes in
  the sidebar, with eject/unmount controls and hot-plug refresh.
- Makes Cmd-T open a new starting-location window when the app is running
  without windows, while retaining normal new-tab behavior in an open window.
- Treats plain text entered in the location field as a search scoped to the
  current folder; recognizable paths and URI addresses still navigate.
- Restores real macOS application icons in Open With.
- Adds a private, bounded Frequently Used section for applications explicitly
  selected for each file type.

Validation covers the full executable build, clean aggregate-patch replay,
mounted-volume enumeration and sidebar selection, native icon rendering from
both paths and `file://` URLs, and frequency ordering with `0600` persistence.

**Full Changelog:** https://github.com/casimir-engineering/shenzhen-files/compare/26.8.27-2...26.9.12-1
