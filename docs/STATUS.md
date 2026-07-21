# Shenzhen Files (Nautilus → macOS) — Integrated Build Status

**Date:** 2026-07-19 · **Version:** 26.7.19 build 1 (upstream 51.beta) · arm64,
`debugoptimized`, `-Dmacos_port=true` · Homebrew GTK 4.22.4 / GLib 2.88.2.

Single integrated tree at `nautilus/` (uncommitted working-tree patches).
Deliverables: `build/src/nautilus`, `install/`, `dist/Shenzhen Files.app`,
`dist/ShenzhenFiles-mac-arm64.dmg` (44 MB), patch record in `patches/`.
Published: https://github.com/casimir-engineering/shenzhen-files
(releases carry the DMG; the self-updater consumes `releases/latest`).

---

## Rebrand + self-update + first public release (2026-07-19, W14)

The app now ships as **Shenzhen Files**, styled after the Shenzhen PDF
product line (`~/Projects/shenzhen-pdf`), with its auto-update mechanism
ported over:

| Item | State |
|---|---|
| Identity | `Shenzhen Files.app`, bundle id `com.intuition.shenzhenfiles` (mirrors `com.intuition.shenzhenpdf`), CFBundleName/DisplayName "Shenzhen Files"; version scheme is shenzhen-pdf's date-based `YY.M.DD` + `CFBundleVersion` build (tag `26.7.19-1`) |
| Menu bar | Verified via System Events on the installed bundle: Apple · **Shenzhen Files** · File · Edit · View · Go · Window · Help; app menu = About Shenzhen Files / Check Permissions… / Finder Integration… / **Check for Updates…** / Settings… / … / Quit Shenzhen Files |
| Logo / icon | `package/make-logo.swift` re-creates shenzhen-pdf's mark ("深圳" in #005C9C over a dark subtitle) with subtitle **Files**; `make-icon.sh` renders the full iconset natively per size → `AppIcon.icns` + `dmg-logo.png`; DMG background wordmark + accent switched to the Shenzhen blue |
| Self-updater | `src/nautilus-macos-updater.m` — port of shenzhen-pdf `SPDFUpdater.mm` (silent daily check with flock'd 24h gate in `~/Library/Application Support/Shenzhen Files/update.json`, hourly re-arm + wake/day-change catch-ups, Install/Skip/Later alert, download panel, DMG mount + extract, detached `--post-update` helper doing the move-aside two-rename swap + relaunch + `.old` rollback handshake). Compiled **with ARC** as its own static lib (`libnautilus-macos-updater.a`) — the MRC bridge flags crash it (verified: SIGSEGV in the JSON parse without ARC). Trust model now matches shenzhen-pdf: offline Developer ID + notarization verification (Team ID pin 66LJ4BV7Q3, hardened-runtime + bundle-id pins); the GitHub sha256 digest is a corruption heuristic |
| Update check verified | Fresh install → `update.json` gains `lastUpdateCheck` + the GitHub `ETag` after the 5-s idle check (HTTP 200, release JSON parsed, tag `26.7.19-1` == running version → up-to-date, silent). `releases/latest/download/ShenzhenFiles-mac-arm64.dmg` 302-resolves to the tag; published digest matches the local DMG sha256 |
| Repo / release | Public repo `casimir-engineering/shenzhen-files` (package/, patches/, docs/, tools/ — upstream tree reproduced via `patches/macos-port-full.patch`); first release `26.7.19-1` ("26.7.19-1 - First release", shenzhen-pdf's format) with the DMG attached |
| Installed | `/Applications/Shenzhen Files.app` (**Developer ID signed + notarized**, team 66LJ4BV7Q3); old `/Applications/Nautilus.app` **removed**. ⚠ New bundle id + name = TCC resets: **Full Disk Access (and Accessibility for the save-panel handoff) must be re-granted** to Shenzhen Files. Config still lives under `~/.config/nautilus` (internal name unchanged) so preferences/integration state carry over |

Port-controlled user-visible strings (FDA walkthrough, Finder-integration
first-run + prefs, services error) now say "Shenzhen Files"; the GLib
application id stays `org.gnome.Nautilus` (D-Bus, gschema paths) —
`MACOS_BUNDLE_ID` in `nautilus-macos-integration.m` carries the
LaunchServices-facing id for the default-handler integration.

---

## What works (verified this pass)

| Area | Status | How verified |
|---|---|---|
| Integrated build | **Clean** `ninja -C build` | No warnings from port code; W7's `-Wno-error=missing-prototypes` **not needed** (removed — W5's prototypes compile clean) |
| Launch (dev + bundle) | **PASS** | Clean stderr except the one known `gdk_macos_monitor_get_workarea` GTK critical per window |
| Native menu bar | **PASS** | System Events dump: Apple · nautilus · File · Edit · View · Go · Window · Help |
| FDA first-launch prompt | **PASS** | Shows over first window on both dev and **bundle** first launch (`docs/phase6-bundle-fda-prompt.png`); bundle TCC probe returns "denied" → prompt shows |
| FDA menu item + `app.fda-prompt` | **PASS** | "Grant Full Disk Access…" present in Help menu; action fires the dialog via `gdbus … org.gtk.Actions.Activate fda-prompt` |
| Paste from Finder | **Wired** | `paste_files()` now falls back to `text/uri-list`→`GDK_TYPE_FILE_LIST` on darwin; composes with W5's URI-repair deserializer (needs human drag/paste QA, see below) |
| Copy into `$HOME` (W7 fix) | **PASS** | `FileOperations2.CopyURIs` into `$HOME` succeeds — no "destination is read-only" dialog (firmlink readonly fix holds) |
| FileOperations2 D-Bus | **PASS** | `CopyURIs` into a temp dir and into `$HOME` both land files |
| QuickLook thumbnails | **PASS** | Grid shows real thumbnails; 10/10 cached to `thumbnails/x-large/`; warm relaunch issues 0 QL requests |
| Spotlight search | **PASS** | `spotlight:` provider starts/queries/stops per keystroke against the correct scope; hits stream into the view (searched "STATUS" in the repo dir) |
| QuickLook space-bar preview | **PASS** | `QLPreviewPanel` opens on selection + space; no crash |
| Trash / Show in Finder (W2) | **PASS (bridge)** | `nautilus_macos_trash_open_in_finder`, `show_in_finder`, `show_in_finder_files` all return TRUE and drive Finder |
| Open With chooser icons (.icns) | **PASS** | New NSWorkspace→GdkTexture bridge renders real app icons (Safari/TextEdit verified) instead of generic ones |
| Starring / ontology in bundle | **PASS** | Bundle honors launcher-set `NAUTILUS_DATADIR`; tag DB (`meta.db`) created from bundled ontology — the relocatability fix works |
| Finder-like Dock lifecycle | **PASS (scripted E2E)** | `scratch-fonts/verify-lifecycle.sh` on the installed bundle: close last window (Cmd-W) → window gone, process alive (still alive 14 s later, past the upstream 12 s inactivity timeout); `reopen` Apple event (= Dock-icon click) and `open -a Nautilus` both open a NEW window; `quit` Apple event (= Dock ▸ Quit) and the Cmd-Q accelerator both exit the process within seconds. 10/10 checks + 2 extra-path checks pass |
| Reopen window centered on Dock's screen | **PASS (scripted E2E, 2 displays)** | `scratch-fonts/verify-center.sh`: mouse on external display → reopened window centered there (Δ 0/15.5 px, Dock-migration inset); mouse on built-in display → Δ 0.0/0.0 px. Screen = the one under `[NSEvent mouseLocation]`; move via `gdk_macos_surface_get_native_window()` + `setFrameOrigin:` one idle after `map` |
| Cold-launch first window on mouse's screen | **PASS (scripted E2E, 2 displays)** | `scratch-fonts/verify-coldlaunch.sh` (`open -g`, no focus steal): external Δ 0/0.5 px, built-in Δ 0/0 px, file-open launch Δ 15/29.5 px — all on the correct screen. Root cause: GDK's placement feeds AppKit bottom-left mouse coords into a top-left-coords monitor lookup (y flipped → wrong screen). Fix: mouse screen captured at startup, first window armed with the shared centering machinery (one-shot) |
| Font rendering (13 pt Medium fix) | **PASS (pixel evidence)** | Before/after/native comparison `scratch-fonts/evidence_before_after.png`; "Starred" @1x ink coverage: before 167 lit / 73 solid px → after 230 lit / 109 solid px (Finder-normalized sizes). See "Font rendering root cause" below |
| LaunchServices file-type icons (W11) | **PASS (headless)** | `scratch-fileicon/test-fileicon`: `.kicad_pro` renders the KiCad document icon (PNG dump verified); per-extension cache — 6 AppKit calls for 6 types, second pass 100% hits (1 µs vs 75 ms); themed/thumbnail precedence honored (txt/zip/pdf/py untouched) |
| W11 icon scaling fix (HiDPI) | **PASS (headless)** | Reported bug: `.drawio` grid icon rendered scale× oversized, overflowing the cell over the label. Root cause: the hook returned the size×scale device-pixel texture directly; its intrinsic size was consumed as logical points by `NautilusImage`'s fallback path. Fixed in `nautilus-file.c` by snapshotting into a size-pt logical box (same technique as thumbnails). Harness: full grid (48/64/96/168/256) + list (16/32/64) ladder × scale 1/2 — bridge px exact and wrapped intrinsic == logical pt on all 16 rungs, plus default-grid-zoom regression checks |
| "Open in Terminal" (W11) | **PASS (bridge)** | `nautilus_macos_open_in_terminal` resolved Terminal.app and opened one window cd'd at the target (closed immediately); menu wiring static-verified, GUI click needs eyes-on |
| Session-bus routing (dev) | **PASS** | `run-nautilus.sh` now derives `DBUS_SESSION_BUS_ADDRESS` from the launchd socket (Homebrew GLib ignores the launchd var); CLI verbs + D-Bus introspection work |
| Per-folder view metadata persists (sort, columns, zoom…) | **PASS (full loop, installed bundle)** | Full write→quit→relaunch→restore loop verified against `/Applications/Nautilus.app` (scrambled mtimes so name/size/date orders all differ): header click wrote `user.nautilus-metadata-nautilus-icon-view-sort-by=date_modified` to the folder; a fresh process restored the Modified sort indicator + row order. Earlier "doesn't work" report root-caused: the tested Nautilus **process** predated the fix (started Jul 16 19:52, fix installed Jul 17 16:54) — the Dock-lifecycle keeps the old process alive across window close/reopen, so a full Cmd-Q quit is required to pick up a new binary after install. | Root cause: upstream persists per-folder state in the GIO `metadata::` namespace, which is backed by gvfsd-metadata — a daemon that doesn't exist on macOS, so every write failed silently ("Setting attribute … not supported") and every session fell back to defaults. Fix (darwin-gated, centralized in `nautilus-vfs-file.c` set + `nautilus-file.c` read): metadata now round-trips through GIO's `xattr::` namespace → native `user.nautilus-metadata-*` extended attributes. xattrs survive same-volume moves/renames and are copied with files; list-valued keys (visible columns, column order, emblems) are stored `;`-joined since xattrs are plain strings (`nautilus_metadata_key_is_list()` drives the split). `NAUTILUS_FILE_DEFAULT_ATTRIBUTES` gains `xattr::*` on darwin so folder loads fetch it. **Everything using nautilus_file_[gs]et_metadata now persists**: sort column + direction (list & grid), list-view visible columns + column order, custom icons/emblems. Sort restore goes through `real_set_sort_state` (blocked handler) → does NOT trigger the header-click scroll-to-top. Verified: header click → `user.nautilus-metadata-nautilus-icon-view-sort-by=date_modified` on the folder; relaunch → Modified column restored as sort indicator; user confirmed on their machine |
| List view: date/size columns sort descending on first click | **PASS (scripted)** | First click on Modified/Created/Accessed/Recency/Trashed On/Size/Starred header now sorts descending (newest/largest first, Finder behavior); second click toggles to ascending. Mechanism: `on_sorter_changed` in `nautilus-list-view.c` detects "switched to a new column whose NautilusColumn :default-sort-order is DESCENDING while GTK made it ascending" and re-sets the direction (handler blocked). `size` and `trashed_on` gained the DESCENDING declaration in `nautilus-column-utilities.c` (dates/recency/starred already had it, previously unused). Restores/menu go through `real_set_sort_state` (never inverted, exact); indicator arrow matches order. Verified scripted: click 1 → newest-first (⌄), click 2 → oldest-first (^), persisted xattr tracked (true→false) |
| List view: header-click sort scrolls to top | **PASS (scripted, both directions)** | Clicking a column header (Name/Size/Modified) jumps the list to row 0 instead of staying on an arbitrary slice of the re-sorted list (Finder behavior). Hook: `on_sorter_changed` in `nautilus-list-view.c` — fires only for user header clicks; programmatic sort changes (directory load / sort-state restore) go through `real_set_sort_state`, which blocks the handler, so navigation position-restore is unaffected. The jump is deferred to an idle callback: scrolling synchronously inside the sorter's "changed" emission anchored the view on the OLD position-0 item, which could land at the bottom of the new order (user-reported bottom-jump bug, fixed). Verified scripted: scroll mid-list → Size click (asc) → top; scroll again → Size click (desc) → top. Unconditional (not darwin-gated) |
| DMG | **PASS** | Mounts with `.background/`, `Applications` symlink, `Nautilus.app` |
| Bundle relocatability | **PASS** | Launches under `env -i HOME=$HOME …/nautilus-launcher`; `bundle-dylibs.sh` audit: all load commands `@executable_path`/system |

### Performance (regression check vs `docs/perf.md` baseline)

| Metric | Baseline | This build | Δ | Verdict |
|---|---|---|---|---|
| Cold start → window | 481 ms | 509 ms | +5.8% | OK (<20%) |
| Warm start → window | 275 ms | 321 ms | +16.6% | OK (<20%) |
| 10k listing quiesce | 1175 ms | 1320 ms | +12.3% | OK (<20%); still 0.63× Finder (2098 ms) |
| Thumbnail throughput | 0 (stub) | **129 thumbs/s** (500 imgs, real QL backend) | n/a | new capability |

No >20% regression. Snapshot refreshed to the integrated binary
(`bench/snapshot-install/bin/nautilus`, sha `44c619c9…`). New result files in
`bench/results/`. Warm start's +16.6% is within noise for n=5 on a shared
machine; not optimized (out of scope).

---

## Finder Integration (W12) — opt-in, fully revertible

New darwin-only module (`src/nautilus-macos-integration.m`) with a
Settings ▸ **Finder Integration** page, an app-name-menu "Finder
Integration…" item (below "Check Permissions…"), and a one-time first-run
choice dialog. **Everything defaults to OFF; nothing applies at startup**
(startup only registers the passive NSServices provider and reads status).
State keyfile: `~/.config/nautilus/macos-integration.ini` — it records both
what was changed *and* the pre-change system value, so revert restores the
user's original configuration, not a hardcoded default.

| Toggle | Apply | Revert |
|---|---|---|
| **Open Folders by Default** | Saves the current `public.folder` handler bundle id, then `-[NSWorkspace setDefaultApplicationAtURL:toOpenContentType:]` (UTTypeFolder). Errors from recent macOS (parameter/permission refusals were reported on 26.x) surface verbatim in the UI; nothing is recorded as enabled on failure. | Restores the saved previous handler (Finder if none was recorded — the factory state). |
| **Sync Sidebar Favorites** | One-shot two-way sync: Finder favorites (LSSharedFileList, read) → `~/.config/gtk-3.0/bookmarks` (file:// items only), and Nautilus bookmarks → shared favorites (`LSSharedFileListInsertItemURL`; never raw `.sfl3/.sfl4` writes). Records exactly the URIs it added on each side. If the shared-list API is write-broken it degrades to import-only and reports that in the status line. Re-toggle to re-sync (no continuous daemon). | Removes **only** the recorded URIs from both sides; user-created entries (before or after the sync) are never touched. |
| **Hide Finder Desktop** | Reads and saves `com.apple.finder CreateDesktop` (including "key absent"), sets it FALSE via CFPreferences, relaunches Finder (SIGTERM — what `killall Finder` sends). Finder is relaunched *only* on an explicit toggle, never at install/startup. | Restores the saved value (or removes the key if it was absent) + relaunches Finder. |

Plus: **Revert All** button, a live status line (LaunchServices +
CFPreferences reads, not stored state), and a passive `NSServices`
"Open in Nautilus" entry in Info.plist (provider registered at startup;
routes Finder's Services-menu selections through `GApplication::open`).

**First-run choice (DMG installs):** one AdwAlertDialog, once ever
(`integration-choice-made` flag written *before* the dialog is scheduled,
same crash-safe pattern as the FDA prompt): "Use as a Standalone App"
(default, does nothing) vs "Set Up Finder Integration…" (opens the
preferences page; user still flips individual toggles — nothing
auto-applies).

**Test facilities:** `NAUTILUS_INTEGRATION_DRY_RUN=1` logs every system
mutation ("DRY-RUN: …") instead of executing it; keyfile/bookmarks
bookkeeping (inside `$XDG_CONFIG_HOME`) still runs so harnesses can verify
round trips. `NAUTILUS_INTEGRATION_MOCK_FAVORITES=<file>` substitutes a
text file for the shared favorites list. Harness:
`scratch-integration/build-and-run.sh` (26 checks, all passing; read-only
probe on this machine: LSSharedFileList favorites readable, 7 items).

**Known limits (by design / platform):** Finder's "Reveal in …" from other
apps, the Dock's Trash, and system Open/Save panels cannot be replaced —
those are hardwired to Finder. The favorites sync is one-shot, not
continuous. The default-handler write may be refused by recent macOS
policy; the error is shown and nothing is left half-applied.

**LIVE STATE ON THIS MACHINE (applied 2026-07-14, user-requested "do the
swap", via `scratch-integration/integration-cli` — real engine compiled
standalone, no GUI launched):**

- **Favorites sync: ON.** 7 Finder favorites imported into
  `~/.config/gtk-3.0/bookmarks`; 1 bookmark (`file:///Users/raph/Projects`)
  exported to the shared list before the export API errored on a
  symlinked-path bookmark, so the engine degraded to import-only
  (`export-supported=false` recorded). Revert data (imported/exported URI
  lists) is in the keyfile.
- **Default folder handler: FAILED — still `com.apple.finder`.** Both
  `-[NSWorkspace setDefaultApplicationAtURL:toOpenContentType:]`
  (NSCocoaErrorDomain 256, underlying NSOSStatusErrorDomain −50 paramErr)
  and legacy `LSSetDefaultRoleHandlerForContentType` (−50) refuse
  `public.folder` on this macOS (26.x hardwires Finder; no consent dialog
  is ever shown). Not a bundle problem — `org.gnome.Nautilus` IS in
  `LSCopyAllRoleHandlersForContentType("public.folder")`. The keyfile keeps
  `previous-handler=com.apple.finder` but `enabled` stays off; the UI
  surfaces the same error if the user flips the toggle.
- **Hide Finder desktop: ON.** `com.apple.finder CreateDesktop=0`, Finder
  relaunched (pid 695 → 28407). Pre-change state "key absent" recorded
  (`had-previous-value=false`), so revert deletes the key.

Keyfile: `~/.config/nautilus/macos-integration.ini`. Revert per-toggle in
Settings ▸ Finder Integration, Revert All, or
`scratch-integration/integration-cli revert <favorites|desktop|all>`.

---

## "Choose in Nautilus" Save/Open-panel handoff (W13) — PROTOTYPE, opt-in, Accessibility-gated

New darwin-only module (`src/nautilus-macos-savepanel-handoff.m`, bridge
section W13). When another app shows a native NSSavePanel/NSOpenPanel, a
system-wide hotkey lets the user pick a destination folder in Nautilus;
Nautilus then drives that panel to the chosen folder via the Accessibility
API (the panel's built-in "Go to Folder"). **The user still completes
Save/Open in the native panel** — this NAVIGATES the panel only, so the
sandbox/Powerbox security model is untouched (we never read or write the
file on the app's behalf). This is the Accessibility approach from the
multi-model review finding #12; the rejected visual-reskin/overlay idea is
NOT attempted.

**Status: prototype, proven end-to-end against TextEdit's Save panel only.**
Off by default. Two gates must both hold before the hotkey does anything:
the `[savepanel-handoff] enabled` toggle in
`~/.config/nautilus/macos-integration.ini`, and the Accessibility
(`AXIsProcessTrusted`) permission the USER grants in System Settings.

**Architecture**

| Piece | Choice | Notes |
|---|---|---|
| Global hotkey | Carbon `RegisterEventHotKey` (⌃⌥⌘G, hardcoded for the prototype) | Chosen over a CGEventTap: `RegisterEventHotKey` needs no extra permission beyond being a normal app, fires reliably even when another app is frontmost, and is still functional on macOS 26. A CGEventTap would duplicate what the OS hotkey API already does and can be silently disabled by the system. Armed ONLY when the toggle is ON (launch-time `..._init()` reads the keyfile; the prefs switch arms/disarms live). |
| Panel detection | `AXUIElementCreateApplication(frontPid)` → scan `AXWindows` and each window's `AXSheet` children | TextEdit's save panel is a **sheet** (`AXRole=AXSheet`) whose **`AXIdentifier="save-panel"`** (NSOpenPanel → `"open-panel"`). Secondary signature used as a fallback when the panel window carries no identifier: presence of the **`OKButton`** and the **`where popup`** (the "Where:" `AXPopUpButton`). Distinctive save-panel children observed: `saveAsNameTextField`, `where popup`, `NS_OPEN_SAVE_DISCLOSURE_TRIANGLE`, `CancelButton`/`OKButton`, `ContentTypesPopup`. |
| Folder chooser | GTK's `GtkFileDialog` select-folder (prototype) | Returns a POSIX path with the least fragility. The intended real UX is a full Nautilus browsing window whose "Choose" returns the displayed folder — the `GtkFileDialog` is a documented stand-in, not the final design. |
| AX drive sequence | activate target → expand panel (`NS_OPEN_SAVE_DISCLOSURE_TRIANGLE` if collapsed) → open "Go to Folder" (⌘⇧G) → type path → guarded Return | See below. |

**AX drive sequence (the load-bearing part)**

1. `activateWithOptions:` the target app so keystrokes land on its panel.
2. If the panel is collapsed, `AXPress` its disclosure triangle.
3. Post **⌘⇧G** as a proper modifier **chord** (Cmd down → Shift down → G
   down/up → Shift up → Cmd up). A bare G-with-combined-flags shortcut
   leaves the window-server modifier state inconsistent and silently
   swallows the path keystrokes that follow — this was the single biggest
   gotcha found during bring-up.
4. Type the path as **CGEvent unicode-string** keystrokes (chunked; no
   per-key layout dependence). Setting `AXValue` on the field directly
   fills it visually but the panel's completion logic never sees it and
   Return then does nothing — the text must arrive as real key events.
   The Go-to-Folder field (`AXIdentifier="PathTextField"` inside the
   `GoToWindow` sheet) is first responder the instant the sheet opens, so
   we do **not** re-focus it (re-focusing resets the field editor).
5. **Guard:** read the app's `AXFocusedUIElement` and post Return **only**
   if it is the `PathTextField`. This makes it impossible for Return to hit
   the panel's default Save/Open button by mistake.
6. Commit with a Return keystroke.

**End-to-end result (TextEdit, this pass)**

Verified twice — once with a standalone AX prototype, once through the
**compiled bridge** linked into a headless harness
(`scratch-savepanel/test-handoff` → the real
`nautilus_macos_savepanel_drive`). Harness launched TextEdit, opened the
Save panel (Cmd-S on an untitled doc), called the bridge with target
`~/Projects`, and asserted navigation:

```
frontmost-panel-pid=74599
DRIVE OK: Where: popup = "Projects"
== independent AX re-read of Where popup
where-popup: value=Projects
```

Both the bridge's own evidence and an independent AX re-read of the panel's
"Where:" popup report **`Projects`** (was `Documents` before). One proof
screenshot was captured. TextEdit was then closed without saving and the
process killed; `pgrep` confirms nothing left running. Disabled-state
verified: with the toggle OFF, `..._init()` arms nothing (no "armed" log);
only after enabling does the hotkey register.

**USER steps to use it**

1. Install/launch the bundled `Nautilus.app` (Accessibility is checked
   against the *responsible* process — see the dev-vs-bundle caveat below).
2. Grant Accessibility: System Settings ▸ Privacy & Security ▸
   Accessibility ▸ enable **Nautilus**. (Toggling the feature on opens this
   pane automatically if the permission is missing.)
3. Settings ▸ Finder Integration ▸ **Choose in Nautilus (Prototype)** ▸
   turn on **Enable Save/Open Panel Handoff**.
4. In any app, invoke Save/Open so its native panel appears, then press
   **⌃⌥⌘G**. Pick a folder in the Nautilus chooser. The native panel jumps
   to that folder. Finish Save/Open in the native panel as usual.

**Dev-vs-bundle caveat (same shape as the FDA work):** `AXIsProcessTrusted`
and CGEvent posting are attributed to the *responsible process*. A dev
build run from a terminal/IDE inherits the terminal's Accessibility grant,
not "Nautilus"'s; the test harness this pass ran AX-trusted for exactly
that reason. The permission the USER sees and grants is for the
Finder/LaunchServices-launched `.app`. With ad-hoc signing the recorded
identity can change across rebuilds, so macOS may ask for the grant again
after a reinstall.

**Honest fragility assessment (what will break beyond TextEdit)**

- **Sandboxed apps (the common case for App Store apps):** their Save/Open
  panel is hosted out-of-process by
  `com.apple.appkit.xpc.openAndSavePanelService`. The panel is still
  reachable through the *owning* app's AX element in the cases tested, but
  this is NOT validated here — the AX tree shape, the identifiers, and
  whether ⌘⇧G/keystrokes route correctly to a remote-view panel are all
  unproven. **Assume sandboxed apps may not work** until tested.
- **Non-AppKit panels:** Electron/Chromium, Qt, Java, and other toolkits
  draw their own file dialogs that are NOT NSSavePanel and carry none of
  the `save-panel`/`PathTextField`/`where popup` identifiers. The detector
  will simply not find a panel and the hotkey no-ops. iOS-style/Catalyst
  panels are also untested.
- **Sheet vs window panels:** handled for the sheet case (TextEdit) and the
  standalone-window case (detector checks both), but apps that host the
  panel in a nonstandard container may be missed.
- **Timing/races:** the sequence uses fixed `usleep` settle delays
  (activation, disclosure animation, sheet open, keystroke pacing). On a
  slow/loaded machine these can be too short; there is no
  wait-for-condition polling yet. Focus stealers (a notification grabbing
  focus mid-sequence) can also derail it — observed during testing when an
  unrelated app took focus between steps.
- **Localization/layout:** ⌘⇧G is the Go-to-Folder shortcut on English
  systems; a different keyboard layout or a remapped shortcut would break
  step 3. Path typing is unicode-string based so it is layout-independent,
  but the shortcut is not.
- **Permission not granted:** every AX read/write fails closed —
  `nautilus_macos_savepanel_drive` returns an error, the hotkey effectively
  no-ops, and nothing crashes. The prefs toggle detects this and points the
  user at the Accessibility pane.
- **"Go to Folder" quirks:** a nonexistent path leaves the panel where it
  was (the field just won't accept it); the prototype does not pre-validate
  the chosen path (the GTK chooser only returns real folders, so this is
  moot in the hotkey path but relevant if the API is reused).

---

## Finder-like Dock lifecycle (user request, 2026-07-15)

Requirement: "if I close nautilus it stays open in the dock (unless cmd+q),
and when I click on the icon it opens a new window."

**Mechanism (all in existing files; no new sources):**

- **Survive last-window-close:** `nautilus_application_startup` takes one
  `g_application_hold()` on darwin (`macos_lifecycle_take_hold`), so the
  GApplication use count never reaches zero when the last `NautilusWindow`
  is destroyed. The Dock icon stays active, D-Bus services stay up.
- **Explicit quit still quits:** `action_quit` (the `app.quit` GAction —
  reached by the Cmd-Q accelerator, the app-menu Quit item, and Dock ▸
  Quit: GTK's quartz delegate maps `applicationShouldTerminate:` to the
  `quit` action) now releases that hold and zeroes the inactivity timeout
  before closing windows, so the process exits as soon as the last window
  dies — but any in-flight file-operation holds still finish first
  (upstream persistence semantics preserved).
- **Dock-icon click opens a window:** GTK's `GtkApplicationQuartzDelegate`
  does NOT implement `applicationShouldHandleReopen:hasVisibleWindows:`
  (verified against gtk 4.22.4 sources), so the reopen Apple event did
  nothing with zero windows. `nautilus_macos_lifecycle_install_reopen_handler`
  (`nautilus-macos-menu.m`, W1 seam) `class_addMethod`s the missing
  selector onto the installed delegate's class — no swizzling needed since
  nothing is overridden, and it defers to a future GTK implementation if
  one appears. With zero GTK windows it calls `g_application_activate()`
  (Nautilus's activate opens a new window at `$HOME`) and returns NO; with
  windows present it returns YES so AppKit deminiaturizes/raises normally.

**Verified E2E** (`scratch-fonts/verify-lifecycle.sh`, installed bundle):
launch → Cmd-W → window gone + process alive (>14 s, i.e. the hold, not
the 12 s inactivity grace) → `reopen` event opens a fresh window →
Cmd-W again → `quit` Apple event exits. Plus: `open -a Nautilus` reopen
path and the Cmd-Q accelerator path. 12/12 checks pass; `pgrep` clean
after each run.

**Reopen-window placement (follow-up, 2026-07-16):** the window opened by
a Dock-icon click appears CENTERED on the screen the Dock was clicked on.

- *Which screen:* at reopen time the pointer is by definition on the Dock
  icon just clicked, so the target is the `NSScreen` whose frame contains
  `[NSEvent mouseLocation]` (`macos_mouse_screen_visible_frame`, captured
  BEFORE `g_application_activate()` so later focus changes can't skew it).
  Single-display setups degrade to "center on the only screen"; the
  multi-display case is the same code path (mouse↔screen matching).
- *How it moves:* GTK4 has no `gtk_window_move`, so positioning is done at
  the AppKit level. NSWindow timing: GDK creates/places the NSWindow
  during realize/present, so the handler hooks the new `GtkWindow`'s
  `map` signal (one-shot, destroy-notify guards the never-mapped leak
  case) and then defers the actual move by ONE GLib idle — after GDK's
  own cascade placement (`_gdk_macos_display_position_toplevel`) has
  finished, with no fixed sleeps. The idle fetches the `NSWindow` via the
  public `gdk_macos_surface_get_native_window()` and `setFrameOrigin:`s
  it centered in the target screen's `visibleFrame` (menu bar/Dock insets
  respected). GDK observes the move via `windowDidMove:` →
  `_gdk_macos_surface_configure`, so its coordinate bookkeeping stays
  consistent. Only the reopen-with-no-windows path does this (`open -a`
  with the app running lands on the same reopen event); normal window
  placement is untouched.
- *Verified E2E* (`scratch-fonts/verify-center.sh`, installed bundle, real
  two-display setup): close last window → warp mouse to the external
  display (3440×1440 at CG −1928,−1440) → `reopen` event → window center
  (−208,−704.5) vs screen visibleFrame center (−208,−720): Δx=0,
  Δy=15.5 px (Dock had migrated displays with the pointer, shifting the
  comparison snapshot's inset — the app centered exactly on the
  visibleFrame it saw). Repeat on the built-in display (1800×1169):
  Δx=0.0, Δy=0.0. Quit event exits; `pgrep` clean.

**Cold-launch placement (follow-up, 2026-07-16):** user report: "cold
launch opens the window on a different screen; afterwards it is ok." The
reopen-path centering only armed on the reopen Apple event; a FRESH
process's first window was placed by GDK itself, and GDK picks the wrong
monitor on multi-display setups: `_gdk_macos_display_position_toplevel`
(gdkmacosdisplay-wm.c, gtk 4.22.4) feeds raw AppKit bottom-left-origin
`[NSEvent mouseLocation]` into
`_gdk_macos_display_get_monitor_at_display_coords()`, which expects GDK
top-left display coords — the y axis is flipped, so the lookup lands on
the wrong screen whenever displays are stacked/offset vertically.

- Fix: same placement rule, same machinery, armed for the first window.
  `nautilus_macos_launch_placement_capture()` (W1 seam) snapshots the
  mouse screen's visibleFrame at the TOP of `nautilus_application_startup`
  — before GTK startup takes its time, so a moving pointer can't skew the
  target — and `nautilus_macos_launch_placement_apply()` in
  `nautilus_application_create_window` arms the shared map+idle centering
  for that window. One-shot per process: later windows (Cmd-N, tabs,
  session paths) keep normal placement; the reopen path keeps its own
  fresh capture. Position only — maximized/fullscreen windows are left
  untouched (guard in the centering idle). File-open launches (`open`
  with a path / Services) funnel through the same `create_window`, so
  they center too.
- *Verified E2E* (`scratch-fonts/verify-coldlaunch.sh`, installed bundle,
  two displays, low-disruption `open -g` — placement logic runs without
  activating/stealing focus): mouse on external display → cold launch →
  window center (−208,−719.5) vs visibleFrame center (−208,−720):
  Δ 0/0.5 px; mouse on built-in display → Δ 0.0/0.0 px; file-open cold
  launch (`open -g -a Nautilus ~/Downloads`, external display) →
  Δ 15/29.5 px (GDK cascade offset absorbed within tolerance, correct
  screen). All sessions quit cleanly; `pgrep` clean.

**Placement flash fix (follow-up, 2026-07-16 pm):** user report: the
window briefly (~50 ms) appeared at GDK's wrong-screen position before
jumping to the centered one. Root cause: the centering ran one GLib idle
after `map`, but GDK's delayed orderFront (first buffer swap) wins that
race. Fix: the move is now SYNCHRONOUS in the `map` handler — at that
point GtkWindow.map's class closure has already run `gdk_toplevel_present`
(NSWindow exists at final size, GDK placement applied) but the NSWindow is
only ordered front at the FIRST BUFFER SWAP (`show_on_next_swap`,
gdkmacossurface.c), which happens later in the frame cycle. The reopen
path additionally arms via a one-shot `GtkApplication::window-added`
handler BEFORE `g_application_activate()` (activation paints the window
before returning, so post-activate arming was itself too late). Evidence:
the placement debug line logs `[nswindow isVisible]` at move time —
`was visible before move: no` on BOTH paths on the installed bundle
(cold launch Δ 0/0 px built-in; reopen Δ 0/15.5 px external), i.e. the
first frame the user ever sees is the centered one. No transparency
tricks needed; windows never start hidden.

---

## Font rendering root cause (user report: "like they are not antialiased")

**What it is NOT (each empirically excluded, `scratch-fonts/`):**

- *Wrong Pango backend* — `pango_cairo_font_map_get_default()` is
  `PangoCairoCoreTextFontMap`; `.AppleSystemUIFont 12` loads as a
  `PangoCairoCoreTextFont` (real SF Pro; string widths match native AppKit
  rendering to 0.4%).
- *Missing antialiasing* — glyphs are grayscale-antialiased (GTK requests
  `CAIRO_ANTIALIAS_GRAY`; intermediate alpha levels present in captures).
- *Scale/resolution bug* — 1 px hairlines render pixel-sharp at 1x and 2x;
  no resampling blur anywhere.
- *GSK renderer* — ngl (default) and cairo renderers produce pixel-identical
  text (same lit/solid counts on the same glyph runs).
- *xft settings* — `gtk-font-rendering` defaults to AUTOMATIC, which
  ignores the `gtk-xft-*` keys entirely; a manual-mode experiment with
  metric hinting made spacing worse (integer-rounded advances), not better.

**What it IS (two compounding causes):**

1. **12 pt vs the native 13 pt.** GDK's macOS settings backend hardcodes
   the system font as `"<family> 12"` (the AppKit "views" size, with a
   source comment admitting it may need tweaking); real macOS UI text
   (Finder sidebar/lists) is 13 pt. Every label rendered one point smaller
   than the OS look.
2. **CoreText font smoothing (stem darkening) is off.** cairo's quartz
   glyph rasterizer calls `CGContextSetShouldSmoothFonts(FALSE)` for
   `CAIRO_ANTIALIAS_GRAY` — smoothing is only enabled for
   `CAIRO_ANTIALIAS_SUBPIXEL`, which GTK never requests (GSK doesn't do
   subpixel AA). AppKit text gets stem darkening; GTK text does not, so SF
   Pro renders visibly thinner/wispier — on a non-Retina display it reads
   as "not antialiased". This cannot be turned on app-wide through public
   GTK API (per-widget `gtk_widget_set_font_options` doesn't inherit).

**Fix shipped (darwin-gated, `macos_setup_font_rendering()` in
`nautilus-application.c` startup):**

- `gtk-font-name = ".AppleSystemUIFont 13"` set **programmatically** —
  required, because an application-set GtkSettings value outranks the GDK
  backend xsetting while a bundled `settings.ini` loses to it (verified:
  an ini override changed nothing; `g_object_set` works).
- Default text weight Medium (500) via a `window { font-weight: 500; }`
  CSS provider, as weight compensation for the missing stem darkening.
  Set on the window node so it *inherits*; theme rules that set
  font-weight directly (headings, `.title-*`, bold labels) still override
  inherited values, so bold stays bold.

**Result** (1x display, where the problem is worst): "Starred" sidebar
label ink 167 lit / 73 solid px → 230 lit / 109 solid px; native Finder
equivalent ≈ same-size text with comparable solidity. Visual strip:
`scratch-fonts/evidence_before_after.png` (before / after / Finder).
Retina rendering was already acceptable and simply scales up. Remaining
gap vs AppKit (true stem darkening) is a GTK/cairo stack limitation,
documented above.

---

## macOS window chrome — Finder-style traffic lights (2026-07-16)

User request: "make the app a bit more mac os like" (mockup: traffic
lights top-left above the sidebar, toolbar spanning only the content
area). Changes:

- **Window controls moved to the sidebar header, top-left.** The sidebar
  `AdwHeaderBar` (in `nautilus-window.blp`) now hosts ONLY the window
  controls (`show-title: false`, `.flat`); `gtk-decoration-layout` is set
  to `close,minimize,maximize:` at startup (`macos_setup_window_chrome()`
  in `nautilus-application.c`), which also puts dialog buttons on the
  left, per platform convention.
- **Main menu + "Search Everywhere" moved into the content toolbar** as
  new `NautilusToolbar` end children (hamburger rightmost), behind new
  properties `show-app-menu-button` / `show-global-search-button` /
  `app-menu-model` (all off/NULL by default so the file chooser's toolbar
  is unaffected).
- **Traffic-light styling (CSS provider, darwin startup):** still
  GTK-drawn (`use-native-controls` stays FALSE — the GTK #7964 deadlock
  was re-checked against GTK 4.22.4 release notes; upstream !9354 landed
  but the hang persisted in the previous pass, so no native re-enable).
  Metrics were measured off a native window at 1x: **14 px circle
  (12 px + 1 px ring), 23 px center-to-center, 13 px edge inset** —
  verified pixel-exact at 1x and 2x by screenshot measurement
  (`scratch-fonts/measure-lights.swift`). Colors #ff5f57/#febc2e/#28c840,
  glyphs only on cluster hover, neutral gray on `:backdrop` (matches
  native unfocused windows). **The circle must stay on the button's inner
  image node** — styling the button node stretches with the headerbar and
  distorts the circles into tall ellipses (regression caught and reverted
  during this pass).
- **Collapsed/narrow fallback:** the `max-width: 682sp` breakpoint keeps
  working — at 600 px the sidebar becomes an overlay and the controls stay
  in its header (screenshot-verified); with the sidebar hidden libadwaita's
  split-header coordination recreates the controls in the content header
  (this is the same recreate path the existing
  `macos_split_view_controls_notify_cb` hook already re-disables native
  controls on, so they stay GTK-drawn there too). Eyes-on item added to
  the QA checklist below.
- **Click behavior verified scripted** (window-server clicks on the
  GTK-drawn buttons, dev build): green zoom → window zoomed to full
  screen-frame and back; yellow → miniaturized; red → window closed,
  process stayed alive (Dock lifecycle hold) and exited within 1 s of
  SIGTERM — **main loop not wedged**, i.e. the GTK-drawn buttons do not
  reproduce the native-controls deadlock.
- Not attempted: NSVisualEffectView vibrancy (future polish, fragile).

---

## What's degraded / limitations

- **Trash browsing:** the sidebar Trash item opens Finder's Trash (no
  `trash:///` GVfs backend; `~/.Trash` is TCC-blocked without FDA). Trashing
  files works.
- **Network view:** hidden on darwin (no GVfs).
- **Window buttons are GTK-drawn, not native traffic lights:** deliberate
  workaround for GTK #7964 — on macOS 26.5 a click on the native AppKit
  buttons wedges the main thread in `NSButtonCell trackMouse` (app left
  running with no window, unable to relaunch). Native controls are force-
  disabled per window in `nautilus-application.c`; revisit when GTK fixes
  the hit-test (still broken on GTK 4.22.4 — upstream !9354 shipped but
  does not cure it, so native controls were NOT re-enabled in the
  2026-07-16 chrome pass; the traffic lights are CSS-styled GTK controls,
  see the "macOS window chrome" section). See `docs/phase6-known-issues.md` #4.
- **No NSVisualEffectView translucency/vibrancy** behind the sidebar —
  deliberately not attempted (fragile with GTK-rendered surfaces); possible
  future polish.
- **Stateful menu checkmarks:** Show Hidden / sort radios work but show no
  checkmark in the native menu (GTK quartz limitation). See
  `docs/phase6-known-issues.md` #5.
- **One GTK critical per window** on launch (harmless; issue #1).
- **Set-as-default in Open With:** hidden on darwin — `GOsxAppInfo` cannot
  change the LaunchServices default handler.
- **Early-SIGTERM segfault:** could **not** be reproduced (22/22 clean TERM
  exits); documented as a watch item in `docs/phase6-known-issues.md` #2.
  (Note: the user-reported "quit unexpectedly" dialogs turned out to be a
  different, now-fixed startup crash — see issue #6, not this one.)

---

## Human-QA checklist (consolidated — items no agent could verify)

These need real eyes/hands: AX cannot see AdwDialog internals, cross-process
drags are TCC-blocked for automation, and some flows need a real bundle
install. Run the **bundle** (`dist/Nautilus.app`) where noted.

### A. Menu bar & shortcuts (W1 — solo QA)

- [ ] **Cmd-Shift-W** (Close Window) key equivalent — menu click verified;
      key combo unverified under automation.
- [ ] Cmd-, (Preferences dialog opens), Cmd-T (new tab), Cmd-F (search
      focus), Cmd-R (reload), Get Info (Cmd-I), Cmd-1/Cmd-2 (icon/list view
      switch), Enter Location (Cmd-Shift-G / Cmd-L popover) — all actions
      registered; AX-invisible dialogs/popovers need eyes-on.
- [ ] Cmd-Z / Cmd-Shift-Z inside a rename/location text entry keeps GtkText
      undo (not file undo).

### B. Selection actions (W2 — GUI items)

- [ ] Double-click opens a file with the LaunchServices default app.
- [ ] Right-click → Open With shows real app icons (now bridged) and opens
      the chosen app.
- [ ] "Show in Finder" reveals the selection in Finder.
- [ ] Sidebar Trash opens Finder's Trash window.
- [ ] Space-bar QuickLook toggles the panel; arrow keys page selection.
- [ ] Get Info / Properties dialog populates.
- [ ] Star / unstar a file, restart, confirm the star persists (tag DB).

### C. Finder drag & drop (W5 — real-drag checklist)

Full matrix in `docs/phase3-w5-qa-checklist.md`. Byte-level behavior is
proven; the actual inter-app drags are not. Priorities:

- [ ] **Drag OUT single file** to Finder Desktop — copied, name intact
      (incl. spaces / `%` / `#`).
- [ ] **Drag OUT multiple files** — all copied (legacy `NSFilenamesPboardType`
      augmentation; most-likely-to-regress case).
- [ ] **Drag IN single/multiple** from Finder onto the view — copied with
      correct names (URI-repair path; 2.1/2.5 in the W5 checklist).
- [ ] Drag IN onto a folder item, sidebar place, path-bar crumb.
- [ ] In-app drags (view→subfolder, →sidebar, →tab) still move/copy correctly.

### D. Paste from Finder (integration item — new)

- [ ] Copy files in **Finder** (Cmd-C), focus Nautilus, **Cmd-V** — files
      land in the current folder with correct names (composes the darwin
      `paste_files` fallback with W5's `text/uri-list` deserializer).
- [ ] In-app copy/paste still works (fast local path unchanged).

### E. FDA flow (restart-after-grant)

- [ ] Bundle first launch shows the "Grant Full Disk Access" prompt
      (verified via screenshot; confirm the full flow by hand).
- [ ] "Open System Settings…" deep-links to Privacy & Security → Full Disk
      Access.
- [ ] Enable Nautilus there, **quit and relaunch**, confirm the prompt no
      longer appears and Trash/Desktop/Documents are readable.
- [ ] "Don't Ask Again" persists (`~/.config/nautilus/macos-fda.ini`);
      Help → "Grant Full Disk Access…" still reopens the dialog afterward.

### F. File-type icons & Open in Terminal (W11 — GUI items)

- [ ] Browse a folder containing a `.kicad_pro` file (e.g.
      `/tmp/icons-test`) — the file shows the **KiCad document icon** (grid
      and list view), not the generic blank-file icon.
- [ ] A file with a made-up extension (`.qwoiejqwe`) shows the native macOS
      generic document icon (white page) instead of the flat themed one.
- [ ] Plain `.txt` / `.zip` files keep their themed icons; images/PDFs keep
      QuickLook thumbnails (no regression from the icon fallback).
- [ ] **Icon scaling at all zoom levels (regression QA for the oversized
      `.drawio` icon bug):** on a Retina display, view a `.drawio` (or other
      LaunchServices-icon) file in grid view and step through every zoom
      level (Cmd-minus/Cmd-plus, 48→256 pt) and list view sizes — the icon
      must stay inside its cell, same footprint as themed icons/thumbnails,
      label below (never overlapping). Verified headless for scale 1 and 2
      (`scratch-fileicon/test-fileicon` sections 5–6); eyes-on GUI pass
      still wanted.
- [ ] Scroll a large directory (~10k files) — no per-row stutter (icons are
      cached per extension+size).
- [ ] Right-click the view **background** → "Open in Terminal" opens
      Terminal.app cd'd at the current folder.
- [ ] Right-click a **single selected folder** → "Open in Terminal" opens
      Terminal.app cd'd at that folder; item hidden for files/multi-selection
      and for non-local locations.

### G2. "Choose in Nautilus" Save/Open-panel handoff (W13 — prototype, eyes-on)

Automated E2E against TextEdit passed (see the W13 section); these need a
real bundle + the user's Accessibility grant, which no agent can supply:

- [ ] Launch the **bundle**, grant Accessibility (Settings ▸ Privacy &
      Security ▸ Accessibility ▸ Nautilus), then Settings ▸ Finder
      Integration ▸ enable **Save/Open Panel Handoff**.
- [ ] In **TextEdit**: new doc → Cmd-S → press **⌃⌥⌘G** → pick a folder in
      the Nautilus chooser → confirm the native Save panel now shows that
      folder. Finish the save in the native panel; the file lands there.
- [ ] Repeat with an **Open** panel (e.g. TextEdit → Cmd-O) — folder
      navigation should work the same.
- [ ] With the toggle **OFF**, ⌃⌥⌘G does nothing (hotkey not armed).
- [ ] With Accessibility **not** granted, enabling the toggle opens the
      Accessibility pane and the hotkey no-ops (no crash) until granted.
- [ ] Try a **sandboxed** app's Save panel (e.g. a Mac App Store app,
      Preview, or Pages) — EXPECTED TO BE FRAGILE/UNPROVEN; record whether
      it works, partially works, or does nothing.
- [ ] Try a **non-AppKit** app (VS Code / any Electron app, a Qt/Java app) —
      EXPECTED: detector finds no panel, hotkey no-ops. Confirm it fails
      gracefully.

### H. Dock lifecycle & font rendering (2026-07-15 fixes — eyes-on)

- [ ] Close the last window with the **red close button** (not Cmd-W) —
      app stays in the Dock; click the Dock icon — a new window opens at
      Home. (Cmd-W, `reopen`/`open -a`, Cmd-Q, and the quit Apple event
      are already script-verified.)
- [ ] With two displays: close the last window, click the Dock icon on
      the OTHER display — the new window opens centered on that display
      (script-verified via mouse-warp + reopen event on both displays;
      confirm with a real Dock click).
- [ ] With two displays and Nautilus NOT running: click the Dock icon —
      the first window opens centered on the display the Dock was clicked
      on (cold-launch path; script-verified on both displays, confirm
      with a real Dock click).
- [ ] Preferences ▸ General ▸ Starting Folder: pick a folder — quit,
      relaunch from the Dock: the window opens there; Cmd-N opens there
      too. Reset button restores Home. Delete the chosen folder on disk,
      relaunch — opens Home (fallback, script-verified).
- [ ] Right-click the Dock icon ▸ Quit — app quits (script-verified via
      the quit Apple event; confirm the actual menu click).
- [ ] Cmd-Q while a large copy is in progress — the windows close and the
      app finishes the operation before exiting (operation holds are
      honored).
- [ ] Text everywhere (sidebar, list view, dialogs, menus) reads at
      Finder-like size/weight; nothing looks fake-bold. Check that real
      bold text (dialog headings, `.title` labels) is still visibly
      bolder than body text.
- [ ] Check on both the Retina laptop panel and the 1x ultrawide; the 1x
      display was where the old thin/fuzzy rendering was most visible.

### I. macOS window chrome (2026-07-16 — eyes-on)

- [ ] Traffic lights (top-left, in the sidebar header) look native: same
      size/spacing as a Finder window next to it, crisp circles on the 1x
      ultrawide, red/yellow/green when focused, all gray when the window
      is unfocused, glyphs appear when hovering the cluster.
- [ ] Click each: red closes the window (app stays in Dock), yellow
      minimizes, green zooms/restores (script-verified via synthetic
      clicks; confirm by hand — this is the GTK #7964-sensitive path,
      buttons must never freeze the app).
- [ ] Narrow the window below ~680 px: the sidebar collapses to an
      overlay; with the overlay dismissed the traffic lights must appear
      in the main toolbar (left of back/forward) and keep working.
- [ ] Hamburger menu (top-right of the toolbar) opens the main menu;
      "Search Everywhere" toggle next to it starts a global search.
- [ ] Dialogs (Preferences, Properties, About) show their window buttons
      on the LEFT (mac convention) and styled as traffic lights.

### G. DMG drag-install (packaging)

- [ ] Open `dist/Nautilus-mac-arm64.dmg`: window shows background art, app
      icon, and Applications-symlink slot.
- [ ] Drag `Nautilus.app` to Applications; launch from **/Applications** (or
      a clean second account / VM) — app opens to `$HOME`.
- [ ] Finder "Open With → Nautilus" and `open -a Nautilus ~/somedir` route a
      folder into a Nautilus window (LaunchServices `::open` path).

---

## Integration changes applied (this pass)

1. **FDA onboarding** — one-shot deferred idle in
   `nautilus_application_window_added` + `app.fda-prompt` `GSimpleAction` +
   "Grant Full Disk Access…" in the Help menu (app-name menu is synthesized
   by GTK's quartz backend from a fixed template with no public extension
   point, so the documented Help-menu fallback was used).
2. **Paste from Finder** — darwin `text/uri-list` fallback branch in
   `paste_files()`, calling the idempotent `nautilus_dnd_init_macos()` so the
   URI-repair deserializer is registered even before any drag.
3. **`NAUTILUS_DATADIR` relocatability** — darwin runtime env override in
   `nautilus-tag-manager.c` `setup_database()`; launcher exports
   `NAUTILUS_DATADIR` at `Resources/share/nautilus`.
4. **Open With .icns icons** — `nautilus_macos_app_icon_texture()` bridge
   (NSWorkspace `iconForFile:` → `GdkTexture`), consumed in
   `nautilus-app-chooser-widget.c` for `GOsxAppInfo` rows (cached per app).
5. **Dev bus wiring** — `run-nautilus.sh` derives `DBUS_SESSION_BUS_ADDRESS`
   from the launchd socket (Homebrew GLib has no launchd bus support).
6. Dropped W7's isolated `-Wno-error=missing-prototypes` — shared build is
   clean without it.
7. **LaunchServices file-type icons (W11)** — files whose themed icon would
   resolve to the generic `application-x-generic` (plus `.app` bundles) get
   the NSWorkspace `iconForFile:` icon instead, cached per
   extension+size (`nautilus-macos-fileicon.m`; hook in `nautilus-file.c`
   `nautilus_file_get_icon_paintable`, generic-ness test in
   `nautilus-icon-info.c`). Thumbnails and specific themed icons keep
   precedence.
8. **"Open in Terminal" (W11)** — darwin context-menu items (background +
   single-folder selection) mirroring the Copy Path pattern in
   `nautilus-files-view.c`; bridge `nautilus_macos_open_in_terminal()`
   (`nautilus-macos-terminal.m`) hands Terminal.app the directory URL via
   LaunchServices.
10. **"Choose in Nautilus" Save/Open-panel handoff (W13, prototype)** —
    `nautilus-macos-savepanel-handoff.m`: Carbon ⌃⌥⌘G global hotkey (armed
    only when the opt-in toggle is ON), AX panel detection, GTK folder
    chooser, and an AX "Go to Folder" drive sequence that navigates another
    app's native Save/Open panel to the chosen folder. Opt-in, off by
    default, Accessibility-gated; toggle in Settings ▸ Finder Integration ▸
    "Choose in Nautilus (Prototype)", persisted in the `[savepanel-handoff]`
    group of `macos-integration.ini`. Startup arms via
    `nautilus_macos_savepanel_handoff_init()` in
    `nautilus_application_startup`. Added `ApplicationServices` + `Carbon`
    frameworks. Proven E2E against TextEdit only — see the W13 section for
    the fragility assessment.
11. **Finder-like Dock lifecycle (2026-07-15)** — startup
    `g_application_hold()` + quit-action release/zero-timeout in
    `nautilus-application.c`; missing
    `applicationShouldHandleReopen:hasVisibleWindows:` added to GTK's
    NSApp delegate at runtime in `nautilus-macos-menu.m` (bridge seam
    `nautilus_macos_lifecycle_install_reopen_handler`). Follow-ups
    (2026-07-16): the reopened window is centered on the screen under the
    mouse (= the Dock the user clicked) via
    `gdk_macos_surface_get_native_window()` + `setFrameOrigin:`, applied
    synchronously in the window's `map` handler (before GDK's
    first-buffer-swap orderFront, so the first visible frame is already
    centered — no wrong-screen flash; the reopen path arms via a one-shot
    `window-added` handler before activate); and the FIRST window of a
    cold launch gets the same treatment (`launch_placement_capture` at
    startup + one-shot `launch_placement_apply` in `create_window`),
    fixing GDK's y-flipped monitor-under-mouse lookup. See the dedicated
    section above.
14. **Context-menu layout tweaks (2026-07-16 pm, user request)** — in
    `nautilus-files-view.c` (darwin blocks, shared .ui untouched):
    upstream "Copy to…" removed from the selection menu ("Move to…"
    stays); "Copy Path" moved out of the cut/copy sections into its own
    one-item separator-delimited GMenu section directly below — selection
    menu: Cut / Copy / Move to… | **Copy Path** | Rename…-group;
    background menu: Paste / Paste as Link / Select All / Visible
    Columns… | **Copy Path** | Properties-group. Screenshot-verified
    (`scratch-fonts/selmenu_new.png`, `bgmenu_new.png`).
12. **Font rendering fix (2026-07-15)** — `macos_setup_font_rendering()`
    in `nautilus-application.c`: programmatic `gtk-font-name
    ".AppleSystemUIFont 13"` + inherited Medium default weight. Root
    cause (12 pt default + cairo-quartz disabling CoreText stem
    darkening for grayscale AA) documented in the dedicated section above.
13. **Startup Back/Forward crash fix (2026-07-16)** — the intermittent
    "Nautilus quit unexpectedly" SIGSEGV (4 crash reports; all within
    0.4–2.4 s of launch) was an upstream Nautilus bug: the slot's
    Back/Forward `GSimpleAction`s are enabled-by-default before the first
    location finishes its async load, and
    `nautilus_window_slot_back_or_forward()` dereferences the still-NULL
    `content_view` via `nautilus_files_view_is_searching()`. Fixed in
    `nautilus-window-slot.c` (sync the enabled state at slot init +
    NULL-guard `content_view`); deterministic lldb repro before/after.
    See `docs/phase6-known-issues.md` #6.
15. **Custom starting folder (2026-07-16 pm, user request)** — new
    GSettings key `starting-location` (org.gnome.nautilus.preferences,
    type 's', default '' = home; `NAUTILUS_PREFERENCES_STARTING_LOCATION`)
    resolved by `nautilus_application_get_starting_location()` in
    `nautilus-application.c` and honored by all no-explicit-location
    window paths: `nautilus_application_activate` (cold launch, Dock
    reopen), `action_new_window` (Cmd-N), and `--new-window`. Paths that
    don't exist or aren't folders fall back to home with a warning
    (folder deleted later = safe). Explicit-location paths (CLI args,
    Services, file-open) untouched. UI: darwin-gated "Starting Folder"
    AdwActionRow in Preferences ▸ General (subtitle shows the choice,
    `~`-abbreviated; folder-picker via GtkFileDialog select-folder;
    reset-to-Home button appears only for a custom value) —
    `setup_starting_folder_row()` in `nautilus-preferences-dialog.c`,
    shared .blp untouched. Verified against the isolated install prefix
    (keyfile backend): key `~/Downloads` → first window titled
    "Downloads"; key `/nonexistent/xyz` → window titled "Home" plus the
    fallback warning in the log.
13. **macOS window chrome (2026-07-16)** — Finder-style layout: window
    controls in the sidebar header top-left (`nautilus-window.blp`),
    decoration layout `close,minimize,maximize:`, native-metric CSS
    traffic lights (14 px / 23 px c2c, hover glyphs, gray backdrop) via
    `macos_setup_window_chrome()` in `nautilus-application.c`; main menu
    + Search Everywhere moved into the content toolbar behind new
    opt-in `NautilusToolbar` properties. Controls remain GTK-drawn
    (native ones still deadlock, see #9). Details in the dedicated
    section above.
9. **Native window-controls hang fix (GTK #7964)** — force
   `use-native-controls = FALSE` on every `GtkWindowControls` per toplevel
   (`macos_setup_native_window_controls` in `nautilus-application.c`,
   re-applied on map and on sidebar show/collapse). Cures the "stuck
   running with no window, cannot close or reopen" zombie: on macOS 26.5 a
   click on the native traffic lights wedged the main thread in AppKit's
   `NSButtonCell trackMouse` modal loop (GDK steals the mouse-up), and the
   wedged process kept the bundle ID registered so relaunches were blocked.
   Window buttons are now GTK-drawn. See `docs/phase6-known-issues.md` #4.

## Notarized release (2026-07-20)

Gatekeeper hard-blocked the first (ad-hoc) download ("Apple could not verify…").
Fixed by adopting shenzhen-pdf's actual release signing: Developer ID
Application (INTUITION Robotique & Technologies, 66LJ4BV7Q3, login keychain)
+ `notarytool` keychain profile `shenzhenpdf-notary`, no entitlements,
hardened runtime + secure timestamp on every Mach-O. One command now does the
whole chain: `package/sign-and-notarize.sh` (prompt-probe → sign 80 Mach-Os →
DMG → notarize → staple → Gatekeeper-simulate on a quarantined copy → clobber
release asset → digest re-check → install). Verified 2026-07-20: notary
submission `8b882586-68c2-47a8-97ed-e08176e9dc4f` **Accepted**; `spctl` says
"accepted / Notarized Developer ID" for the DMG, for a quarantined app copy
(0081 flag), and for the installed app; GitHub digest matches the local DMG.

Keychain lesson (cost a prompt-loop): the Developer ID private key is labeled
"Raphaël Casimir" in the login keychain; its partition list was fine but its
application ACL lacked `/usr/bin/codesign`, so every codesign call prompted
and password entry never stuck. Fix was one-time, via Keychain Access ▸ key ▸
Access Control (no CLI exists for app ACLs). The sign-and-notarize.sh probe
(10-s timeout on a throwaway binary) guards against ever looping on this again.

TCC note: the identity change (ad-hoc → Developer ID) resets TCC once more —
re-grant Full Disk Access (and Accessibility for the save-panel handoff).
Future updates keep the same identity, so grants now persist across releases.

## Hardened-runtime startup crash fixed (2026-07-21)

The first notarized 26.7.19-1 download crashed at startup (SIGABRT in
libtinysparql `ensure_init_parser`, via `nautilus_tag_manager_init`). Root
cause: libtinysparql loads its parser/collation module
(`libtracker-parser-libicu.so`) from a compile-time-baked absolute Homebrew
path with no env override, and the port never bundled it — so it relied on
the dev machine's Homebrew, and under the hardened runtime's Library
Validation the ad-hoc-signed Homebrew module can't be dlopen'd at all. Fix:
bundle the module (`make-app.sh`), binary-patch libtinysparql's baked path to
`@executable_path/../Resources/lib/tinysparql-3.0` and re-sign the module with
our Team ID (`bundle-dylibs.sh`), plus a darwin preflight in
`nautilus-tag-manager.c` that degrades to "starring disabled" instead of
aborting if the module is ever unloadable. `sign-and-notarize.sh` now runs a
launch smoke test on the quarantined copy so this class of bug can't ship
again. Re-notarized (submission `b666c1f7-…`, Accepted) and re-released; the
quarantined download launches cleanly and the tag DB initializes. See
docs/phase6-known-issues.md §7.
