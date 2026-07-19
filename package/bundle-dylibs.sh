#!/usr/bin/env bash
#
# bundle-dylibs.sh — make dist/Nautilus.app self-contained (PLAN.md §5 Phase 5
# task 2) and ad-hoc sign it (task 4).
#
# 1. BFS over `otool -L` starting from Contents/MacOS/nautilus plus every
#    already-bundled Mach-O (Frameworks dylibs, gdk-pixbuf loaders, GIO
#    modules); resolves @loader_path/@rpath references against the referrer.
# 2. Copies the transitive closure into Contents/Frameworks.
# 3. Rewrites every Mach-O: `install_name_tool -id` to
#    @executable_path/../Frameworks/<name>, `-change` for every non-system
#    dependency, and strips absolute (/opt/homebrew, $HOME) LC_RPATH entries.
# 4. Re-signs every modified Mach-O ad-hoc (`codesign --force -s -`) —
#    REQUIRED on arm64: install_name_tool invalidates the signature and an
#    unsigned/invalid arm64 binary is SIGKILL'd by the kernel.
# 5. Signs the bundle nested-first, then the app itself.
#
# Release signing (NOT required for local builds) — same pattern as
# shenzhen-pdf portable/build-mac-release.sh:
#   * Set MAC_SIGN_IDENTITY='Developer ID Application: …' in the environment
#     to sign with hardened runtime + timestamp instead of ad-hoc.
#   * Then notarize + staple the DMG produced by make-dmg.sh:
#       xcrun notarytool submit dist/Nautilus-mac-arm64.dmg \
#         --keychain-profile "$NOTARY_PROFILE" --wait
#       xcrun stapler staple dist/Nautilus-mac-arm64.dmg
#       xcrun stapler validate dist/Nautilus-mac-arm64.dmg
#       spctl -a -t open --context context:primary-signature dist/Nautilus-mac-arm64.dmg
#   See package/README.md for the one-time credential setup.
#
# Usage: ./package/bundle-dylibs.sh [app-path]   (default: <repo>/dist/Shenzhen Files.app)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
APP="${1:-$repo_root/dist/Shenzhen Files.app}"

[[ -d "$APP" ]] || { echo "error: app bundle not found: $APP (run make-app.sh first)" >&2; exit 1; }

python3 - "$APP" <<'PYEOF'
import os, subprocess, sys, glob, shutil, collections

app = os.path.abspath(sys.argv[1])
BREW = os.environ.get("HOMEBREW_PREFIX", "/opt/homebrew")
frameworks = os.path.join(app, "Contents", "Frameworks")
macos = os.path.join(app, "Contents", "MacOS")
res = os.path.join(app, "Contents", "Resources")
os.makedirs(frameworks, exist_ok=True)

FW_REF = "@executable_path/../Frameworks/"

def run(*cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)}\n{p.stderr}")
    return p.stdout

def is_macho(path):
    if os.path.islink(path) or not os.path.isfile(path):
        return False
    with open(path, "rb") as f:
        magic = f.read(4)
    return magic in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe")

def lc_deps(path):
    """(install-name-or-None, [dependency install names])"""
    out = run("otool", "-L", path)
    lines = [l.strip().split(" (")[0] for l in out.splitlines()[1:] if l.strip()]
    # For dylibs the first entry is LC_ID_DYLIB; detect via otool -D.
    ident = run("otool", "-D", path).splitlines()
    ident = ident[1].strip() if len(ident) > 1 and ident[1].strip() else None
    deps = lines[1:] if ident and lines and lines[0] == ident else lines
    return ident, deps

def lc_rpaths(path):
    out = run("otool", "-l", path).splitlines()
    rp = []
    for i, l in enumerate(out):
        if "LC_RPATH" in l:
            for j in range(i, min(i + 4, len(out))):
                if " path " in out[j]:
                    rp.append(out[j].split(" path ")[1].split(" (offset")[0])
    return rp

def is_system(dep):
    return dep.startswith(("/usr/lib/", "/System/"))

def resolve(dep, referrer):
    """Resolve a dependency install name to a real on-disk source file."""
    rdir = os.path.dirname(os.path.realpath(referrer))
    if dep.startswith("@loader_path/"):
        return os.path.realpath(os.path.join(rdir, dep[len("@loader_path/"):]))
    if dep.startswith("@executable_path/"):
        return None  # already bundle-relative
    if dep.startswith("@rpath/"):
        rest = dep[len("@rpath/"):]
        for rp in lc_rpaths(referrer):
            if rp.startswith("@loader_path/"):
                cand = os.path.join(rdir, rp[len("@loader_path/"):], rest)
            elif rp.startswith("@executable_path/"):
                continue
            else:
                cand = os.path.join(rp, rest)
            cand = os.path.realpath(cand)
            if os.path.exists(cand):
                return cand
        # Modules copied into the bundle by make-app.sh lose their original
        # @loader_path anchors (e.g. the SVG loader's librsvg). Fall back to
        # Homebrew's linked lib dir, where every formula's dylibs appear.
        cand = os.path.realpath(os.path.join(BREW, "lib", rest))
        if os.path.exists(cand):
            return cand
        return None
    return os.path.realpath(dep)

# --- roots: main binary + everything already shipped as a Mach-O ---------------
roots = [os.path.join(macos, "nautilus")]
for base in (frameworks, os.path.join(res, "lib")):
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            p = os.path.join(dirpath, f)
            if is_macho(p):
                roots.append(p)

# --- pass 1: compute closure, copy into Frameworks ------------------------------
# alias maps a dependency's install-name basename (often a version symlink like
# libicuuc.78.dylib) to the real copied file's basename (libicuuc.78.3.dylib);
# pass 2 must rewrite references through it or dyld will look for the symlink
# name, which doesn't exist inside Frameworks.
basename_src = {}          # Frameworks basename -> real source path
alias = {}                 # dep basename -> real basename
processed = set()
queue = collections.deque(os.path.realpath(r) for r in roots)
in_bundle_real = {os.path.realpath(r) for r in roots}

while queue:
    path = queue.popleft()
    if path in processed:
        continue
    processed.add(path)
    _ident, deps = lc_deps(path)
    for dep in deps:
        if is_system(dep) or dep.startswith("@executable_path/"):
            continue
        src = resolve(dep, path)
        if src is None:
            raise RuntimeError(f"unresolvable dependency {dep} of {path}")
        base = os.path.basename(src)
        dep_base = os.path.basename(dep)
        if alias.setdefault(dep_base, base) != base:
            raise RuntimeError(f"alias collision: {dep_base}: {alias[dep_base]} vs {base}")
        if src in in_bundle_real:
            continue  # e.g. libnautilus-extension already copied by make-app.sh
        prev = basename_src.get(base)
        if prev is None:
            basename_src[base] = src
        elif prev != src:
            raise RuntimeError(f"basename collision: {base}: {prev} vs {src}")
        if src not in processed:
            queue.append(src)

for base, src in sorted(basename_src.items()):
    dst = os.path.join(frameworks, base)
    if not os.path.exists(dst):
        shutil.copy2(src, dst)
        os.chmod(dst, 0o755)
print(f"copied {len(basename_src)} dylibs into Contents/Frameworks")

# --- pass 2: rewrite ids, references, rpaths in every bundled Mach-O -------------
def bundle_machos():
    out = [os.path.join(macos, "nautilus")]
    for base in (frameworks, os.path.join(res, "lib")):
        for dirpath, _dirs, files in os.walk(base):
            for f in files:
                p = os.path.join(dirpath, f)
                if is_macho(p):
                    out.append(p)
    return out

modified = []
for path in bundle_machos():
    args = []
    ident, deps = lc_deps(path)
    if ident:
        # id = the file's actual bundle-relative location (Frameworks for the
        # closure, Resources/lib/... for loaders and GIO modules).
        rel = os.path.relpath(path, os.path.join(app, "Contents", "MacOS"))
        new_id = "@executable_path/" + rel
        if ident != new_id:
            args += ["-id", new_id]
    for dep in deps:
        if is_system(dep) or dep.startswith("@executable_path/"):
            continue
        base = alias.get(os.path.basename(dep), os.path.basename(dep))
        args += ["-change", dep, FW_REF + base]
    for rp in lc_rpaths(path):
        if rp.startswith("/"):   # absolute rpaths (/opt/homebrew, $HOME builds)
            args += ["-delete_rpath", rp]
    if args:
        run("install_name_tool", *args, path)
        modified.append(path)

print(f"rewrote load commands in {len(modified)} Mach-Os")

# --- pass 3: audit — no absolute non-system load commands left, and every
# @executable_path/../Frameworks reference actually exists in the bundle.
bad = []
for path in bundle_machos():
    ident, deps = lc_deps(path)
    for dep in deps:
        if is_system(dep):
            continue
        if dep.startswith(FW_REF):
            if not os.path.exists(os.path.join(frameworks, dep[len(FW_REF):])):
                bad.append((path, f"missing target {dep}"))
        else:
            bad.append((path, dep))
    for rp in lc_rpaths(path):
        if rp.startswith("/"):
            bad.append((path, f"rpath {rp}"))
if bad:
    for p, d in bad:
        print(f"AUDIT FAIL: {p}: {d}", file=sys.stderr)
    sys.exit(1)
print("audit OK: all load commands are @executable_path or system")
PYEOF

# --- codesign: nested Mach-Os first, then the bundle ----------------------------
# DEFAULT = ad-hoc (`codesign --sign -`): the ONLY thing arm64 strictly needs
# after install_name_tool, and it NEVER prompts for a password. This script
# deliberately does not create, import, or trust any certificate and runs no
# `security` subcommand — a normal repackage is 100% password-free.
#
# A real signature is OPT-IN and release-only: set MAC_SIGN_IDENTITY (e.g.
# 'Developer ID Application: … (TEAMID)') to sign with hardened runtime +
# secure timestamp for notarization. That path may prompt once for keychain
# access — acceptable because it is explicit. See package/README.md.
#
# Tradeoff of ad-hoc: the CDHash changes every rebuild, so a Full Disk Access
# grant does not persist across rebuilds. Accepted — FDA is now manual and
# menu-only (Help ▸ "Grant Full Disk Access…"), never auto-prompted.
SIGN_ID="${MAC_SIGN_IDENTITY:--}"
SIGN_FLAGS=(--force --sign "$SIGN_ID")
if [[ "$SIGN_ID" != "-" ]]; then
  SIGN_FLAGS+=(--timestamp --options runtime)
  echo "==> signing with identity: $SIGN_ID (opt-in; may prompt for keychain access)"
else
  echo "==> signing ad-hoc (no password required)"
fi

while IFS= read -r -d '' f; do
  if [[ "$(head -c4 "$f" | xxd -p)" == "cffaedfe" || "$(head -c4 "$f" | xxd -p)" == "cafebabe" ]]; then
    codesign "${SIGN_FLAGS[@]}" "$f" 2>/dev/null
  fi
done < <(find "$APP/Contents/Frameworks" "$APP/Contents/Resources/lib" -type f -print0)

codesign "${SIGN_FLAGS[@]}" "$APP/Contents/MacOS/nautilus"
codesign "${SIGN_FLAGS[@]}" "$APP"

codesign --verify --strict "$APP"
echo "==> bundle signed + verified: $APP"
echo "    next: ./package/make-dmg.sh \"$APP\""
