# Shenzhen Files 26.9.14-1

- Fixes “The update installer exited before it was ready.” The helper now
  handles Foundation's production process-group launch semantics without
  weakening failures from any other `setsid()` condition.
- The amended asset also fixes final verification after a real version change.
  Update identity is read directly from the `Info.plist` currently on disk,
  avoiding `NSBundle`'s stale path cache after the atomic rename.
- Adds a mandatory signed-candidate updater test that exercises the actual
  Foundation `Process`/`NSTask` path, readiness handshake, move-aside swap,
  exact-path relaunch, release identity, executable, and application icon.
- The disposable source is stamped with a deliberately older tag and build;
  same-version swaps are rejected as invalid updater coverage.
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

The exact signed and notarized `26.9.14-1` payload passed before publication:

1. `ninja -C build` completed successfully, and
   `patches/macos-port-full.patch` applied cleanly to a fresh upstream archive;
   every replayed file matched the integrated tree byte for byte.
2. `package/test-updater-helper-e2e.sh "dist/Shenzhen Files.app"` passed on
   the Developer ID signed candidate: `READY_MARKER=observed`, `HELPER_EXIT=0`,
   `EXACT_RELAUNCH=observed`, tag `26.9.14-1`, and build `26091401`.
3. Apple notarization submission `6828fd8f-e496-4b4e-94a6-237c4c3c821f`
   was accepted. Stapling and validation passed, the quarantined app copied
   from the DMG was accepted as Notarized Developer ID, the same production-path
   updater test passed on that copy, and the eight-second launch smoke test
   stayed alive without a new crash report.
4. A manual bootstrap fixture replaced a copied installed `26.8.27-2` app with
   the app from the final DMG. The result passed Developer ID/Gatekeeper checks
   and reported tag `26.9.14-1`, build `26091401`; its executable and icon hashes
   matched the mounted DMG payload.
5. The same Foundation-path test rejected the real installed `26.8.27-2`
   helper before readiness and logged `helper detach failed: Operation not
   permitted`, proving the regression test catches the published defect.
6. The mounted final DMG contains a two-representation background TIFF: 600×400
   at 72 dpi and 1200×800 at 144 dpi; Finder's `.DS_Store` selects that TIFF.

Final artifact identities:

- DMG SHA-256: `f6df67fa06d9afab0533acb3db46b2b1717d463a2a1576a87f2523a9d309674b`
- `Contents/MacOS/nautilus` SHA-256: `1096f1da3440357757be76956186b7b84d0bba8039a78bcaca02dbf640610b27`
- `Contents/Resources/AppIcon.icns` SHA-256: `6197e99853013428c68195815f5939b22d11bec5e9496e5de86c963cea801739`

**Full Changelog:** https://github.com/casimir-engineering/shenzhen-files/compare/26.9.12-1...26.9.14-1
