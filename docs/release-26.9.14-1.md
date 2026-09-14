# Shenzhen Files 26.9.14-1

- Fixes “The update installer exited before it was ready.” The helper now
  handles Foundation's production process-group launch semantics without
  weakening failures from any other `setsid()` condition.
- Adds a mandatory signed-candidate updater test that exercises the actual
  Foundation `Process`/`NSTask` path, readiness handshake, move-aside swap,
  exact-path relaunch, release identity, executable, and application icon.
- Runs that test both before notarization and against the quarantined app copied
  from the final notarized DMG.
- Makes full updater validation and README/status/release-note updates explicit
  repository release gates.
- Repackages the DMG background as a native multi-representation TIFF with
  exact 600×400 1x and 1200×800 2x artwork, so Finder uses a sharp Retina image
  instead of scaling the low-resolution representation.

## One-time bootstrap note

Published builds through `26.9.12-1` execute their already-installed helper
during replacement. That helper exits before it can install its successor, so
no downloaded payload can repair it. Install this DMG manually once by replacing
Shenzhen Files in Applications. Future automatic updates then run through the
fixed helper shipped here.

## Release validation record

The exact signed and notarized `26.9.14-1` payload must pass before publication:

1. `ninja -C build` and clean aggregate-patch replay.
2. `package/test-updater-helper-e2e.sh` on the signed candidate.
3. Developer ID signing, notarization, stapling, DMG Gatekeeper acceptance, and
   the same helper test on the quarantined app copied from that DMG.
4. Manual replacement from the final DMG, with tag `26.9.14-1`, build
   `26091401`, executable hash, and `AppIcon.icns` hash verified.
5. Regression proof that the installed `26.9.12-1` helper fails the same
   Foundation-path test with `setsid(): Operation not permitted`.

Exact results and hashes are recorded here after the gates complete and before
the release tag is created.

**Full Changelog:** https://github.com/casimir-engineering/shenzhen-files/compare/26.9.12-1...26.9.14-1
