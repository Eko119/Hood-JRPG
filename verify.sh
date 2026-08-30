#!/usr/bin/env bash
# verify.sh — the single command that decides whether the project is green.
#
# CLAUDE.md Rule 0: Claude's output is never evidence that something works.
# This script is the evidence. If it exits 0, the machine-checkable half of the
# current milestone gate passes. If it exits non-zero, nothing else matters.
#
# Deliberately NOT a CI config. CI is this script plus a YAML wrapper, and that
# wrapper is a ten-minute job whenever it's wanted. The discipline that matters
# is that one command verifies everything, locally, before any commit.

set -uo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  for c in ./bin/godot godot godot4; do
    command -v "$c" >/dev/null 2>&1 && GODOT="$c" && break
    [[ -x "$c" ]] && GODOT="$c" && break
  done
fi
if [[ -z "$GODOT" ]]; then
  echo "FAIL: no Godot binary. Set GODOT=/path/to/godot or place it at ./bin/godot"
  exit 1
fi

PINNED="4.7"
FAILURES=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILURES=$((FAILURES+1)); }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

mkdir -p reports

step "1. Engine version pin (DEC-011)"
VERSION="$("$GODOT" --headless --version 2>/dev/null | tail -1)"
echo "     found: $VERSION"
if [[ "$VERSION" == $PINNED* ]]; then pass "engine matches pinned $PINNED"
else fail "engine is $VERSION, project pins $PINNED"; fi

step "2. Project boots headless with no errors"
BOOT="$("$GODOT" --headless --path . --quit-after 2 2>&1)"
echo "$BOOT" | sed 's/^/     /' | grep -v '^     $' | head -8
if echo "$BOOT" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load|ERROR:"; then
  fail "boot produced errors"
else pass "clean boot"; fi

step "3. RNG lint — enforces DEC-004"
# Documented policy is not enforcement. This is enforcement.
HITS="$(grep -rnE '(^|[^_a-zA-Z.])(randi|randf|randi_range|randf_range)\(' \
        systems/combat/ 2>/dev/null || true)"
if [[ -n "$HITS" ]]; then
  echo "$HITS" | sed 's/^/     /'
  fail "global RNG used in the combat domain layer"
else pass "no global RNG under systems/combat/"; fi

step "4. Content validator"
VAL="$("$GODOT" --headless --path . --script res://tools/validate_content.gd 2>&1)"
echo "$VAL" | grep -E '^\[validator\]|ERROR|WARN' | sed 's/^/     /'
if echo "$VAL" | grep -q "0 error(s)"; then pass "content valid"
else fail "content validation errors"; fi

step "5. Test suite (GUT, headless)"
# GUT registers its class_names (GutTest et al.) only after an import pass.
# Without this, gut_cmdln.gd aborts with "Some GUT class_names have not been
# imported" — found by running it, which is the point of Rule 0.
"$GODOT" --headless --import --path . >/dev/null 2>&1
TESTS="$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
         -gdir=res://tests -ginclude_subdirs -gexit 2>&1)"
echo "$TESTS" | grep -E 'Scripts|^Tests|Passing Tests|Asserts' | sed 's/^/     /'
# GUT reports "All tests passed!" even when a whole test FILE failed to parse and
# was silently skipped. Found the hard way: an 18-test file vanished from the run
# while the suite still reported green. Any script-load failure now fails the gate.
LOADFAIL="$(echo "$TESTS" | grep -cE 'Parse Error|Failed to load script|SCRIPT ERROR' || true)"
if [[ "$LOADFAIL" -gt 0 ]]; then
  echo "$TESTS" | grep -E 'Parse Error|Failed to load script' | head -5 | sed 's/^/     /'
  fail "$LOADFAIL script load/parse error(s) — tests were silently skipped"
fi
# Robust against column-width changes as the suite grows. The original
# fixed-width lookbehind silently returned empty once counts hit two digits,
# reporting failure on a fully passing suite.
RAN="$(echo "$TESTS" | grep -oP '^Tests\s+\K[0-9]+' | head -1)"
PASSED="$(echo "$TESTS" | grep -oP '^Passing Tests\s+\K[0-9]+' | head -1)"
if [[ "${RAN:-0}" -gt 0 && "${RAN:-0}" == "${PASSED:-x}" ]]; then
  pass "all tests passed ($RAN/$RAN)"
else fail "tests: ${PASSED:-?}/${RAN:-?} passed"; fi

step "RESULT"
if [[ $FAILURES -eq 0 ]]; then
  printf '  \033[32mM0 machine-checkable gate: PASS\033[0m\n\n'; exit 0
else
  printf '  \033[31m%d check(s) failed\033[0m\n\n' "$FAILURES"; exit 1
fi
