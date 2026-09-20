#!/usr/bin/env bash
#
# Self-contained tests. No framework needed: ./test/run-tests.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/clean-node-modules"
PASS=0
FAIL=0

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$(( PASS + 1 )); }
fail() { printf '  \033[31mFAIL\033[0m %s\n     %s\n' "$1" "${2:-}"; FAIL=$(( FAIL + 1 )); }

check() { # check <name> <condition-description> <actual> <expected>
  if [[ "$3" == "$4" ]]; then pass "$1"; else fail "$1" "$2: got '$3', want '$4'"; fi
}

# Build a throwaway project tree.
fixture() {
  local root; root="$(mktemp -d)"
  mkdir -p "$root/app-a/node_modules/some-pkg/node_modules" \
           "$root/app-b/nested/deep/node_modules" \
           "$root/app-c/src"
  echo x > "$root/app-a/node_modules/some-pkg/index.js"
  echo x > "$root/app-b/nested/deep/node_modules/thing.js"
  echo x > "$root/app-c/src/keep.js"
  printf '%s' "$root"
}

echo "clean-node-modules tests"
echo

# --- dry run ---------------------------------------------------------------
root="$(fixture)"
out="$("$SCRIPT" "$root" 2>&1)"
[[ "$out" == *"dry run"* ]] && pass "dry run says so" || fail "dry run says so" "$out"
[[ -d "$root/app-a/node_modules" ]] && pass "dry run deletes nothing" \
  || fail "dry run deletes nothing" "app-a/node_modules is gone"
check "dry run counts top-level matches" "count line" \
  "$(grep -cE '^  +[0-9.]+[BKMGT]?i?B?  ' <<<"$out" || true)" "2"

# --- prune: nested node_modules not listed separately ----------------------
[[ "$out" != *"some-pkg"* ]] && pass "nested node_modules pruned from output" \
  || fail "nested node_modules pruned from output" "$out"
rm -rf "$root"

# --- delete with --yes -----------------------------------------------------
root="$(fixture)"
"$SCRIPT" --delete --yes "$root" >/dev/null 2>&1
[[ ! -d "$root/app-a/node_modules" ]] && pass "--delete removes node_modules" \
  || fail "--delete removes node_modules" "still present"
[[ ! -d "$root/app-b/nested/deep/node_modules" ]] && pass "--delete recurses into subdirs" \
  || fail "--delete recurses into subdirs" "still present"
[[ -f "$root/app-c/src/keep.js" ]] && pass "--delete leaves other files alone" \
  || fail "--delete leaves other files alone" "keep.js was removed"
rm -rf "$root"

# --- delete without a tty and without --yes must refuse --------------------
root="$(fixture)"
"$SCRIPT" --delete "$root" </dev/null >/dev/null 2>&1
rc=$?
check "--delete without tty or --yes exits 1" "exit code" "$rc" "1"
[[ -d "$root/app-a/node_modules" ]] && pass "refused delete changed nothing" \
  || fail "refused delete changed nothing" "directory was removed anyway"
rm -rf "$root"

# --- safety guards ---------------------------------------------------------
"$SCRIPT" "$HOME" >/dev/null 2>&1; check "refuses \$HOME" "exit code" "$?" "1"
"$SCRIPT" / >/dev/null 2>&1;       check "refuses /"      "exit code" "$?" "1"
"$SCRIPT" /nonexistent-xyz >/dev/null 2>&1; check "rejects missing dir" "exit code" "$?" "1"
"$SCRIPT" --older-than abc . >/dev/null 2>&1; check "rejects non-numeric --older-than" "exit code" "$?" "1"
"$SCRIPT" --frobnicate >/dev/null 2>&1; check "rejects unknown option" "exit code" "$?" "1"

# --- max depth -------------------------------------------------------------
root="$(fixture)"
out="$("$SCRIPT" --max-depth 2 "$root" 2>&1)"
[[ "$out" == *"app-a/node_modules"* && "$out" != *"deep/node_modules"* ]] \
  && pass "--max-depth limits the walk" || fail "--max-depth limits the walk" "$out"
rm -rf "$root"

# --- empty tree ------------------------------------------------------------
root="$(mktemp -d)"; mkdir -p "$root/plain"
out="$("$SCRIPT" "$root" 2>&1)"; rc=$?
[[ "$out" == *"no node_modules"* && $rc -eq 0 ]] && pass "empty tree exits 0 cleanly" \
  || fail "empty tree exits 0 cleanly" "$out"
rm -rf "$root"

# --- paths with spaces -----------------------------------------------------
root="$(mktemp -d)"; mkdir -p "$root/my project/node_modules"; echo x > "$root/my project/node_modules/a.js"
"$SCRIPT" --delete --yes "$root" >/dev/null 2>&1
[[ ! -d "$root/my project/node_modules" ]] && pass "handles paths with spaces" \
  || fail "handles paths with spaces" "still present"
rm -rf "$root"

# --- misc ------------------------------------------------------------------
"$SCRIPT" --version >/dev/null 2>&1; check "--version exits 0" "exit code" "$?" "0"
"$SCRIPT" --help    >/dev/null 2>&1; check "--help exits 0"    "exit code" "$?" "0"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
