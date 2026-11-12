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

# Longest a Godot script run may take before it is cut off and its step FAILs
# (GATE-1). Measured 2026-11-12 on the pinned build, five clean exports: the
# slowest healthy bounded run was the GUT suite at 1.48 s. 60 s is about 40x.
RUN_LIMIT_SECONDS=60

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

# bounded CMD... runs CMD with the caller's stdout and stderr, exactly as if it
# were run directly, and returns CMD's exit status. If CMD is still running
# after RUN_LIMIT_SECONDS it is killed and bounded returns CUT_OFF instead.
# Found by planting faults (GATE-1): a --script run whose dependency fails to
# compile, or a test that never returns, keeps Godot's SceneTree alive forever.
# Pure bash on purpose (read -t, SECONDS, kill, wait): no timeout or sleep
# command, so nothing beyond what this script already needs.
# How it waits: the inner group prints CMD's pid, then holds the pipe open
# until CMD exits. The watchdog reads the pid, then waits for end-of-input
# with read -t. End-of-input before the deadline means CMD finished. CMD gets
# the caller's stdout and stderr through fds 4 and 5; the inner group's own
# stderr is discarded so that bash's "Killed" job notice does not leak out.
CUT_OFF=124
bounded() {
  { { "$@" >&4 2>&5 4>&- 5>&- & printf '%s\n' "$!"; wait "$!"; } 2>/dev/null |
    _watchdog; } 4>&1 5>&2
}
_watchdog() {
  local pid line left deadline=$((SECONDS + RUN_LIMIT_SECONDS))
  IFS= read -r pid || return 0
  while left=$((deadline - SECONDS)); (( left > 0 )); do
    IFS= read -r -t "$left" line && continue
    (( SECONDS < deadline )) && return 0   # end of input: CMD exited
  done
  kill -KILL "$pid" 2>/dev/null
  return "$CUT_OFF"
}

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
"$GODOT" --headless --import --path . >/dev/null 2>&1
VAL="$(bounded "$GODOT" --headless --path . --script res://tools/validate_content.gd 2>&1)"
VAL_EXIT=$?
echo "$VAL" | grep -E '^\[validator\]|ERROR|WARN' | sed 's/^/     /'
if [[ $VAL_EXIT -eq $CUT_OFF ]]; then fail "validator run cut off after ${RUN_LIMIT_SECONDS}s — did not exit by itself"
elif [[ $VAL_EXIT -eq 0 ]] && echo "$VAL" | grep -q '^\[validator\] 0 error(s),'; then pass "content valid"
else fail "content validation errors"; fi

step "5. Test suite (GUT, headless)"
# GUT registers its class_names (GutTest et al.) only after an import pass.
# Without this, gut_cmdln.gd aborts with "Some GUT class_names have not been
# imported" — found by running it, which is the point of Rule 0.
"$GODOT" --headless --import --path . >/dev/null 2>&1
TESTS="$(bounded "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
         -gdir=res://tests -ginclude_subdirs -gexit 2>&1)"
TESTS_EXIT=$?
echo "$TESTS" | grep -E 'Scripts|^Tests|Passing Tests|Asserts' | sed 's/^/     /'
if [[ $TESTS_EXIT -eq $CUT_OFF ]]; then
  fail "test run cut off after ${RUN_LIMIT_SECONDS}s — did not exit by itself"
fi
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

step "6. Cross-process determinism (M2 requirement 10)"
# Unit tests prove reproducibility WITHIN one process, where pointer values and
# allocation order happen to be stable — exactly the condition that hid the
# DEC-020 StringName bug. This runs the same scenario in three FRESH processes.
# Each run's output is captured first so that its exit status can be read.
P1="$(bounded "$GODOT" --headless --path . --script res://tools/determinism_probe.gd 2>/dev/null)"; C1=$?
P2="$(bounded "$GODOT" --headless --path . --script res://tools/determinism_probe.gd 2>/dev/null)"; C2=$?
P3="$(bounded "$GODOT" --headless --path . --script res://tools/determinism_probe.gd 2>/dev/null)"; C3=$?
H1="$(printf '%s\n' "$P1" | grep -o 'DETERMINISM_HASH=.*')"
H2="$(printf '%s\n' "$P2" | grep -o 'DETERMINISM_HASH=.*')"
H3="$(printf '%s\n' "$P3" | grep -o 'DETERMINISM_HASH=.*')"
CUT=""
[[ $C1 -eq $CUT_OFF ]] && CUT="$CUT 1"
[[ $C2 -eq $CUT_OFF ]] && CUT="$CUT 2"
[[ $C3 -eq $CUT_OFF ]] && CUT="$CUT 3"
echo "     ${H1:-<no hash>}"
if [[ -n "$CUT" ]]; then
  fail "probe run(s)$CUT cut off after ${RUN_LIMIT_SECONDS}s — did not exit by itself"
elif [[ -n "$H1" && "$H1" == "$H2" && "$H2" == "$H3" ]]; then
  pass "identical state hash across 3 separate processes"
else
  echo "     run2: ${H2:-<none>}"; echo "     run3: ${H3:-<none>}"
  fail "state hash differs across processes — determinism broken"
fi

step "RESULT"
if [[ $FAILURES -eq 0 ]]; then
  printf '  \033[32mM0 machine-checkable gate: PASS\033[0m\n\n'; exit 0
else
  printf '  \033[31m%d check(s) failed\033[0m\n\n' "$FAILURES"; exit 1
fi
