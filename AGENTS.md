# Shenzhen Files repository rules

## Updater is critical code

The updater is a release-critical subsystem. These rules apply to
`nautilus-macos-updater.m`, the `--post-update` dispatch in `nautilus-main.c`,
the launcher, bundle/version metadata, signing and notarization, DMG assembly,
and the release scripts.

No updater-affecting change may be tagged, uploaded, or published until all of
the following gates pass with the exact signed and notarized release payload:

1. Perform a real update from the previously published app to the candidate.
   Exercise download, digest/signature/notarization verification, DMG mount and
   extraction, persistent staging, helper readiness, parent exit, atomic swap,
   exact-path relaunch, version handshake, and old-bundle cleanup.
2. Exercise the candidate's own updater against a disposable installed copy so
   the helper shipped in this release is proven able to install the next one.
   Run `package/test-updater-helper-e2e.sh` against the final signed candidate;
   this automated gate is mandatory, but it does not replace gate 1.
3. Spawn the helper through the same Foundation `NSTask` path used in
   production and observe its readiness marker. Invoking `--post-update`
   directly from a shell is useful supplemental coverage but does **not** count
   as the helper-launch test.
4. Verify that the final executable, `SZFReleaseTag`, `CFBundleVersion`, and
   `AppIcon.icns` match the staged payload after relaunch.
5. Record the exact commands and results in the release notes. “Static
   verification,” a build-only check, or a direct-helper-only test must never
   be reported as end-to-end updater validation.

Any failure blocks the release. Do not bypass, weaken, or relabel these gates.
If an older public updater cannot install the candidate, document the manual
bootstrap requirement prominently and do not claim that automatic updating
works from that version.

Every release must update the root README, `docs/STATUS.md`, and its release
notes in the same clean tagged commit state as the code. Public releases must
be normal releases, not drafts or prereleases, unless the user explicitly asks
otherwise.
