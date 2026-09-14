#!/usr/bin/env bash
# Exercise the signed candidate's post-update helper through Foundation's
# Process/NSTask launch path. This is the candidate-helper release gate; it is
# intentionally not a substitute for the separate previous-release-to-candidate
# download/DMG/update test required by AGENTS.md.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
candidate_app="${1:-$repo_root/dist/Shenzhen Files.app}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d "$candidate_app" ]] || fail "candidate app not found: $candidate_app"
candidate_app="$(cd "$(dirname "$candidate_app")" && pwd)/$(basename "$candidate_app")"
info_plist="$candidate_app/Contents/Info.plist"
helper_rel="Contents/MacOS/nautilus"
icon_rel="Contents/Resources/AppIcon.icns"
[[ -x "$candidate_app/$helper_rel" ]] || fail "candidate helper is missing"
[[ -f "$candidate_app/$icon_rel" ]] || fail "candidate icon is missing"
codesign --verify --deep --strict "$candidate_app"

tag="$(/usr/libexec/PlistBuddy -c 'Print :SZFReleaseTag' "$info_plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
[[ -n "$tag" && -n "$build" ]] || fail "candidate release identity is incomplete"

test_root="$(mktemp -d "${TMPDIR%/}/szf-updater-e2e.XXXXXX")"
case "$test_root" in
  "${TMPDIR%/}"/szf-updater-e2e.*) ;;
  *) fail "refusing unsafe test directory: $test_root" ;;
esac
cleanup() {
  case "$test_root" in
    "${TMPDIR%/}"/szf-updater-e2e.*) rm -rf "$test_root" ;;
  esac
}
trap cleanup EXIT

target_parent="$test_root/installed"
stage_parent="$test_root/.shenzhen-files-update-e2e"
target_app="$target_parent/Shenzhen Files.app"
staged_app="$stage_parent/Shenzhen Files.app"
ready_path="$stage_parent/.helper-ready"
helper_log="$test_root/helper.log"
mkdir -p "$target_parent" "$stage_parent" "$test_root/home"
ditto "$candidate_app" "$target_app"
ditto "$candidate_app" "$staged_app"

expected_executable_sha="$(shasum -a 256 "$staged_app/$helper_rel" | awk '{print $1}')"
expected_icon_sha="$(shasum -a 256 "$staged_app/$icon_rel" | awk '{print $1}')"

set +e
CFFIXED_USER_HOME="$test_root/home" xcrun swift \
  "$script_dir/updater-helper-process-test.swift" \
  "$target_app/$helper_rel" "$staged_app" "$target_app" "$tag" \
  "$ready_path" "$helper_log"
runner_status=$?
set -e
if [[ $runner_status -ne 0 ]]; then
  sed -n '1,160p' "$helper_log" >&2 || true
  fail "Foundation updater-helper test failed"
fi

[[ -d "$target_app" ]] || fail "updated target bundle is missing"
[[ -d "$target_app.old" ]] || fail "move-aside old bundle is missing"
[[ ! -e "$staged_app" ]] || fail "staged bundle was not consumed"
actual_tag="$(/usr/libexec/PlistBuddy -c 'Print :SZFReleaseTag' "$target_app/Contents/Info.plist")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$target_app/Contents/Info.plist")"
actual_executable_sha="$(shasum -a 256 "$target_app/$helper_rel" | awk '{print $1}')"
actual_icon_sha="$(shasum -a 256 "$target_app/$icon_rel" | awk '{print $1}')"
[[ "$actual_tag" == "$tag" ]] || fail "release tag changed during update: $actual_tag"
[[ "$actual_build" == "$build" ]] || fail "bundle version changed during update: $actual_build"
[[ "$actual_executable_sha" == "$expected_executable_sha" ]] \
  || fail "final executable does not match the staged payload"
[[ "$actual_icon_sha" == "$expected_icon_sha" ]] \
  || fail "final icon does not match the staged payload"

printf 'PASS: Foundation helper readiness, atomic swap, exact-path relaunch, tag %s, build %s, executable hash, and icon hash.\n' \
  "$tag" "$build"
