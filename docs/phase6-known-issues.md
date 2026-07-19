# Phase 6 — Known issues (integrated build)

Carried-forward and newly-investigated issues after the integration pass.
Binary: `build/src/nautilus` (arm64, `debugoptimized`, `-Dmacos_port=true`).

## 1. `Gdk-CRITICAL: gdk_macos_monitor_get_workarea assertion 'GDK_IS_MACOS_MONITOR (self)'`

- **Severity:** cosmetic (console noise only).
- **Where:** GTK4 itself (Homebrew `gtk4 4.22.4`, quartz backend), *not*
  Nautilus source. Fires once per window creation when the window default
  size is set before the surface is attached to a monitor.
- **Impact:** none — the window opens, sizes, and positions correctly. It is
  a `CRITICAL` only because GTK uses `g_return_val_if_fail`. This is the one
  expected line on every clean launch.
- **Action:** not fixable from Nautilus without patching GTK. Flag for a
  GTK-macOS upstream report.

## 2. Early-SIGTERM teardown segfault (exit 139) — NOT REPRODUCED

- **Severity:** unresolved but non-reproducing; left as a watch item.
- **History:** the packaging worker saw a single exit-139 (SIGSEGV) at
  ~7 s during teardown, once, and could not reproduce it.
- **Integration repro attempt (this pass):** launched
  `build/src/nautilus --new-window /tmp/int-qa/images` and sent `SIGTERM`
  after a delay, then `wait`ed on the exit code. Two sweeps:
  - **Coarse:** 10 runs, delays 5–8 s (the reported window). All 10 exited
    **143** (128 + SIGTERM) — clean signal teardown, no segfault.
  - **Fine:** 12 runs, delays 0.3 → 7.9 s spanning the whole startup curve.
    All 12 exited **143**. No 139/134/138/133.
  - No new crash report appeared in `~/Library/Logs/DiagnosticReports`
    (latest is the pre-integration `nautilus-2026-07-10-010350.ips`, an
    unrelated startup `g_settings` SIGTRAP from an earlier session, see #3).
- **Assessment:** 22/22 SIGTERM runs terminated cleanly. Nautilus installs
  no custom `SIGTERM`/`SIGINT` handler (`rg 'g_unix_signal_add'` in `src/`
  is empty), so `SIGTERM` is the default disposition — the process dies
  immediately without running GApplication shutdown/destructors. That is
  why an early TERM cannot hit a teardown-ordering bug: the destructors
  never run. The original exit-139 was most plausibly a `--quit`/window-close
  teardown path (which *does* run destructors) racing a still-in-flight
  async operation (a thumbnail QL completion or a directory-monitor
  cancellable), not a signal path. It remains unreproduced and is not on
  the critical path.
- **Action:** watch item. If it resurfaces, capture the `.ips` and inspect
  the faulting thread for a callback into a disposed object (likely a
  `GCancellable`/`GTask` completion after its owner was finalized — cf. the
  Phase-2 `nautilus-properties.c` `icon_cancellable` fix pattern). The W3
  thumbnailer notes its requests are "not cancellable mid-flight"
  (`docs/phase3-w3-thumbnails.md`), which is the most likely suspect for a
  quit-during-thumbnailing race.

## 3. Startup `g_settings` SIGTRAP when schemas are not on the GSettings path

- **Severity:** environmental, not a code regression.
- **What:** running `build/src/nautilus` **directly** (not through
  `run-nautilus.sh`) aborts in `nautilus_global_preferences_init` →
  `g_settings_new` → `g_log_abort` (captured in
  `nautilus-2026-07-10-010350.ips`). This is the classic "schema not found"
  instant-abort: the compiled `org.gnome.nautilus` schema is only found when
  `GSETTINGS_SCHEMA_DIR` / `XDG_DATA_DIRS` point at the install prefix.
- **Action:** none — always launch via `run-nautilus.sh` (dev) or the bundle
  launcher (which sets the env). Documented here so the stray `.ips` is not
  mistaken for issue #2.

## 4. Native traffic-light click wedged the main thread (GTK #7964) — FIXED (worked around)

- **Severity:** critical (was): app left "running with no window, cannot
  close or reopen" after clicking a native window button.
- **What:** libadwaita 1.9 force-enables native macOS window controls
  (`GtkWindowControls:use-native-controls`) on every header bar. On
  macOS 26.5 GDK's hit-test for those AppKit buttons
  (`over_native_window_buttons`, `gdkmacosdisplay-translate.c`) fails to
  claim the mouse-down, so AppKit runs `NSButtonCell
  -trackMouse:inRect:ofView:untilMouseUp:` — a modal loop whose matching
  mouse-up GTK's quartz event source has already stolen into its own queue.
  The loop never returns: main thread wedges inside AppKit, GLib main loop
  frozen. A close-button hit tears the window down first, leaving the
  wedged zombie process owning the `org.gnome.Nautilus` LaunchServices
  registration, which blocks every subsequent launch of
  `/Applications/Nautilus.app`. Upstream GTK issue #7964; the upstream fix
  (!9354) is already in Homebrew GTK 4.22.4 and does **not** cure it on
  macOS 26.5.
- **Fix:** `nautilus-application.c` (`macos_setup_native_window_controls`,
  applied from `window_added` for every toplevel): recursively force
  `use-native-controls = FALSE` on all `GtkWindowControls`, re-applied on
  `map` and on `AdwOverlaySplitView` sidebar changes (libadwaita recreates
  the controls there). GTK then draws its own CSS window buttons, which
  never enter AppKit's tracking loop. NSWindow's real traffic lights are
  `setHidden:YES` (verified via lldb: all three `standardWindowButton`s
  hidden; AX still reports a 16×16 close element because the AX attribute
  reflects the style mask, not visibility).
- **Note:** if a stuck instance from an old build is present, kill it
  (`pkill -x nautilus`) before launching the fixed bundle — LaunchServices
  refuses a second instance while the zombie holds the bundle ID.
- **Revisit:** when GTK ships a working #7964 fix for macOS 26, the
  override can be dropped to restore the native look.

## 5. Stateful native-menu items show no checkmark

- **Severity:** cosmetic (from W1's notes, unchanged by integration).
- Show Hidden Files and the sort radio items work but display no checkmark in
  the native NSMenu — GTK's quartz menu tracker cannot observe `view.*`/
  `win.*` action *state*. Upstreamable GTK fix. The items still function.

## 6. Startup SIGSEGV: Back/Forward during initial location load — FIXED (2026-07-16)

- **Severity:** was critical — this is the "Nautilus quit unexpectedly"
  crash-reporter dialog the user saw intermittently.
- **Crash signature** (4 `.ips` hits: 2026-07-09 23:35, 07-10 02:54,
  07-16 11:37 and 11:44 — the last two on the installed
  `/Applications/Nautilus.app`):
  `EXC_BAD_ACCESS (SIGSEGV) KERN_INVALID_ADDRESS at 0x38`, faulting frame
  `nautilus_files_view_is_searching + 12` ←
  `nautilus_window_slot_back_or_forward` ← `g_simple_action_activate`
  (`slot.back`) ← key-event dispatch. Every hit is **0.4–2.4 s after
  process launch** (`procLaunch` vs `captureTime` in the .ips).
- **Root cause (upstream Nautilus bug, not port code; two parts):**
  1. The slot's `back`/`forward`/`back-n`/`forward-n` `GSimpleAction`s are
     created **enabled** (GSimpleAction default) and are first synced with
     real history only when `update_back_forward_actions()` runs after the
     initial location finishes loading. During the first ~0.5–2 s of a
     window's life `slot.back` is activatable despite empty history.
  2. `nautilus_window_slot_back_or_forward()` starts with
     `nautilus_files_view_is_searching (self->content_view)`, and
     `content_view` is NULL until `got_file_info_for_view_selection_callback`
     creates the first view — exactly the same startup window.
     `is_searching` dereferences `self->directory` at struct offset 0x38,
     matching the fault address. Any Back activation in that window
     (Alt+Left, a "Back" media key, key events trailing a launcher hotkey)
     segfaults the main thread.
- **Fix** (`src/nautilus-window-slot.c`):
  - `nautilus_window_slot_init`: call `update_back_forward_actions()`
    right after the action entries are added, so Back/Forward start
    **disabled** until there is real history.
  - `nautilus_window_slot_back_or_forward`: NULL-guard `content_view`
    before the `is_searching` check (defense for the
    `restore_navigation_state` path — restore-closed-tab /
    back-in-new-tab re-enable the actions while the new slot's view is
    still NULL).
- **Repro before/after** (lldb, deterministic, no GUI interaction needed):
  break on `create_and_bind_new_content_view` (the instant before the
  first view exists), then evaluate
  `nautilus_window_slot_back_or_forward(slot, TRUE, 0)`.
  Unfixed `build/src/nautilus`: `slot.back` enabled = 1 and the call dies
  with `EXC_BAD_ACCESS address=0x38` (exact user crash). Fixed binary:
  `slot.back` enabled = 0 and the call returns cleanly.
- **Upstreamable:** yes — both halves apply to GNOME nautilus unmodified.
