# test/lib.sh — shared helpers for test/*-test.sh
#
# Sourced, not executed. Every test file starts with:
#
#     source "$(dirname "$0")/lib.sh"
#
# Two ways to assert:
#
#   * from bash, with pass/fail/assert directly
#   * from Node, with run_node_test, for pure logic living in a .js module
#
# The Node path is the interesting one. QML has no test runner and needs a
# compositor to run at all, so logic that lives in .qml is effectively
# untestable. Logic that lives in a plain .js module next to it is not:
# QML imports it with `import "foo.js" as Foo` and ignores the trailing
# `module.exports` guard, while Node loads the same file as CommonJS. That
# dual citizenship is what makes the model layer testable with no
# compositor, no display, and no Quickshell.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

TESTS_RUN=0
TESTS_FAILED=0

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  ok   %s\n' "$1"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL %s\n' "$1"
}

assert() {
    # assert <condition-exit-status> <message>
    if [[ $1 -eq 0 ]]; then pass "$2"; else fail "$2"; fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        # A skip is a pass. A machine without node should not fail the suite
        # it cannot run; it should say so and move on.
        printf '  skip %s (%s not installed)\n' "${2:-tests}" "$1"
        exit 0
    fi
}

# run_node_test <<'JS' ... JS
#
# Prepends a prelude giving the heredoc the same vocabulary as the bash
# side, then reports the child's tally back into ours. Node's exit status
# is the pass/fail signal; its stdout is printed as-is.
run_node_test() {
    require_command node "node tests"

    local script prelude output status
    prelude=$(cat <<'PRELUDE'
const path = require("path");
const root = process.env.ROOT;
let __run = 0, __failed = 0;

function pass(msg)  { __run++; console.log("  ok   " + msg); }
function fail(msg)  { __run++; __failed++; console.log("  FAIL " + msg); }
function assert(cond, msg) { cond ? pass(msg) : fail(msg); }
function assertEqual(actual, expected, msg) {
  if (actual === expected) return pass(msg);
  fail(msg + "\n         expected: " + JSON.stringify(expected)
           + "\n         actual:   " + JSON.stringify(actual));
}
function assertDeepEqual(actual, expected, msg) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a === e) return pass(msg);
  fail(msg + "\n         expected: " + e + "\n         actual:   " + a);
}
// Import a repo-relative module, e.g. requireFromRoot("polkit/polkitModel.js")
function requireFromRoot(rel) { return require(path.join(root, rel)); }

process.on("exit", () => {
  if (__failed > 0) process.exitCode = 1;
});
PRELUDE
)
    script=$(cat)
    output=$(printf '%s\n%s\n' "$prelude" "$script" | node - 2>&1)
    status=$?
    printf '%s\n' "$output"

    # Fold the child's counts into ours so the summary is accurate.
    local child_run child_failed
    child_run=$(grep -cE '^  (ok|FAIL) ' <<<"$output" || true)
    child_failed=$(grep -cE '^  FAIL ' <<<"$output" || true)
    TESTS_RUN=$((TESTS_RUN + child_run))
    TESTS_FAILED=$((TESTS_FAILED + child_failed))

    # A non-zero exit with no FAIL lines means node itself blew up (syntax
    # error, missing module) — surface that rather than reporting success.
    if [[ $status -ne 0 && $child_failed -eq 0 ]]; then
        fail "node exited $status without reporting a failure (see output above)"
    fi
}

finish() {
    printf '\n  %d passed, %d failed (%d total)\n' \
        $((TESTS_RUN - TESTS_FAILED)) "$TESTS_FAILED" "$TESTS_RUN"
    [[ $TESTS_FAILED -eq 0 ]]
}
