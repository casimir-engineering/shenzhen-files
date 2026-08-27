# Shenzhen Files 26.8.27-2

- Reworked in-place updates around persistent, owner-only staging so the
  installer survives the app quitting.
- Added a verified helper-ready handshake, exact release-tag checks, checked
  rollback, actionable error reporting, and exact-path relaunch confirmation.
- Made `CFBundleVersion` globally increasing and force-refresh LaunchServices
  registration so the updated app and its icon replace cached versions.
- Restored the approved native-scaled folder icon with the large, contained
  white **深圳** signature.

The release is Developer ID signed, hardened-runtime enabled, notarized, and
stapled. Shenzhen Files verifies the downloaded app again immediately before
and after the atomic bundle swap.

## One-time upgrade note

Version `26.8.27-1` performs the final swap with its own installed helper. That
helper can retain a stale LaunchServices record after the app exits and abort
before replacement, so an already-installed `26.8.27-1` cannot reliably repair
itself using only a newer downloaded bundle. If the automatic update leaves the
old version installed, install this DMG once by dragging **Shenzhen Files** to
Applications and replacing the existing copy. Automatic updates after
`26.8.27-2` use the repaired installer path.

**Full Changelog:** https://github.com/casimir-engineering/shenzhen-files/compare/26.8.27-1...26.8.27-2
