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
if [[ "$out" == *"dry run"* ]]; then pass "dry run says so"
else fail "dry run says so" "$out"; fi
if [[ -d "$root/app-a/node_modules" ]]; then pass "dry run deletes nothing"
else fail "dry run deletes nothing" "app-a/node_modules is gone"; fi
check "dry run counts top-level matches" "count line" \
  "$(grep -cE '^  +[0-9.]+[BKMGT]?i?B?  ' <<<"$out" || true)" "2"

# --- prune: nested node_modules not listed separately ----------------------
if [[ "$out" != *"some-pkg"* ]]; then pass "nested node_modules pruned from output"
else fail "nested node_modules pruned from output" "$out"; fi
rm -rf "$root"

# --- delete with --yes -----------------------------------------------------
root="$(fixture)"
"$SCRIPT" --delete --yes "$root" >/dev/null 2>&1
if [[ ! -d "$root/app-a/node_modules" ]]; then pass "--delete removes node_modules"
else fail "--delete removes node_modules" "still present"; fi
if [[ ! -d "$root/app-b/nested/deep/node_modules" ]]; then pass "--delete recurses into subdirs"
else fail "--delete recurses into subdirs" "still present"; fi
if [[ -f "$root/app-c/src/keep.js" ]]; then pass "--delete leaves other files alone"
else fail "--delete leaves other files alone" "keep.js was removed"; fi
rm -rf "$root"

# --- delete without a tty and without --yes must refuse --------------------
root="$(fixture)"
"$SCRIPT" --delete "$root" </dev/null >/dev/null 2>&1
rc=$?
check "--delete without tty or --yes exits 1" "exit code" "$rc" "1"
if [[ -d "$root/app-a/node_modules" ]]; then pass "refused delete changed nothing"
else fail "refused delete changed nothing" "directory was removed anyway"; fi
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
if [[ "$out" == *"app-a/node_modules"* && "$out" != *"deep/node_modules"* ]]; then
  pass "--max-depth limits the walk"
else fail "--max-depth limits the walk" "$out"; fi
rm -rf "$root"

# --- empty tree ------------------------------------------------------------
root="$(mktemp -d)"; mkdir -p "$root/plain"
out="$("$SCRIPT" "$root" 2>&1)"; rc=$?
if [[ "$out" == *"no node_modules"* && $rc -eq 0 ]]; then pass "empty tree exits 0 cleanly"
else fail "empty tree exits 0 cleanly" "$out"; fi
rm -rf "$root"

# --- paths with spaces -----------------------------------------------------
root="$(mktemp -d)"; mkdir -p "$root/my project/node_modules"; echo x > "$root/my project/node_modules/a.js"
"$SCRIPT" --delete --yes "$root" >/dev/null 2>&1
if [[ ! -d "$root/my project/node_modules" ]]; then pass "handles paths with spaces"
else fail "handles paths with spaces" "still present"; fi
rm -rf "$root"

# --- misc ------------------------------------------------------------------
"$SCRIPT" --version >/dev/null 2>&1; check "--version exits 0" "exit code" "$?" "0"
"$SCRIPT" --help    >/dev/null 2>&1; check "--help exits 0"    "exit code" "$?" "0"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
