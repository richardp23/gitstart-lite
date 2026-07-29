#!/usr/bin/env bash
# Shared test helpers for GitStart Lite.

set -u
set -o pipefail

# Keep test mode local to this shell. Do not export it.
# Exported GS_TEST_MODE blocks main() in child CLI process tests.
GS_TEST_MODE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TESTS_RUN=0
TESTS_FAILED=0

source_module() {
    # shellcheck disable=SC1090
    . "${ROOT}/src/$1"
}

source_core() {
    source_module 00_header.sh
    source_module 10_constants.sh
    source_module 20_terminal.sh
    source_module 30_text.sh
    source_module 40_input.sh
    source_module 60_fuzzy.sh
    source_module 70_git_exec.sh
    source_module 80_git_state.sh
    source_module 90_safety.sh
}

source_lesson_engine() {
    source_core
    source_module 100_lesson_engine.sh
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-assert_eq}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${expected}" = "${actual}" ]; then
        return 0
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s\n' "${msg}"
    printf '  expected: %q\n' "${expected}"
    printf '  actual:   %q\n' "${actual}"
    return 1
}

assert_ok() {
    local msg="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if "$@"; then
        return 0
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s (expected success)\n' "${msg}"
    return 1
}

assert_fail() {
    local msg="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! "$@"; then
        return 0
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s (expected failure)\n' "${msg}"
    return 1
}

assert_gt() {
    local a="$1"
    local b="$2"
    local msg="${3:-assert_gt}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${a}" -gt "${b}" ] 2>/dev/null; then
        return 0
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s (%s > %s)\n' "${msg}" "${a}" "${b}"
    return 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-assert_contains}"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "${haystack}" in
        *"${needle}"*)
            return 0
            ;;
    esac
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s\n' "${msg}"
    printf '  missing: %q\n' "${needle}"
    return 1
}

test_summary() {
    printf 'Tests run: %s  Failed: %s\n' "${TESTS_RUN}" "${TESTS_FAILED}"
    if [ "${TESTS_FAILED}" -gt 0 ]; then
        return 1
    fi
    return 0
}
