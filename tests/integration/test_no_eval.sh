#!/usr/bin/env bash
# Integration tests: student text is not executed as shell code (FR-103, FR-111).
#
# This file uses a stubbed input_read_line. It does not open /dev/tty.
# It does not test stty, arrow keys, or interactive terminal input.
# See tests/manual/README.md for real TTY checks.

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"

# Load modules first. Override input and UI after load so stubs stay active.
source_lesson_engine

TEST_INPUT_QUEUE=""
TEST_INPUT_INDEX=1
TEST_RUNNER_CALLS=0

input_read_line() {
    local idx="${TEST_INPUT_INDEX}"
    TEST_INPUT_INDEX=$((TEST_INPUT_INDEX + 1))
    GS_INPUT_LAST="$(printf '%s\n' "${TEST_INPUT_QUEUE}" | sed -n "${idx}p")"
    if [ -z "${GS_INPUT_LAST}" ]; then
        return 1
    fi
    return 0
}

ui_info() { :; }
ui_print() { :; }
ui_command() { :; }
ui_help() { :; }
ui_warning() { :; }
ui_next() { :; }
ui_muted() { :; }
ui_stopped() { :; }
ui_success() { :; }
ui_fail_detail() { :; }

test_lesson_runner() {
    TEST_RUNNER_CALLS=$((TEST_RUNNER_CALLS + 1))
    return 0
}

# Forbidden command must not reach the runner.
TEST_INPUT_QUEUE="git push --force
git status"
TEST_INPUT_INDEX=1
TEST_RUNNER_CALLS=0
GS_LESSON_MODE="${GS_MODE_LEARN}"

if lesson_teach_exact_command \
    "git status" \
    test_lesson_runner \
    "Show status." \
    "Status is shown."
then
    assert_eq "1" "${TEST_RUNNER_CALLS}" "runner called once after forbidden input is rejected"
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: lesson should succeed after retry\n'
fi

# Wrong command must not call runner.
TEST_INPUT_QUEUE="git statuz
git status"
TEST_INPUT_INDEX=1
TEST_RUNNER_CALLS=0

if lesson_teach_exact_command \
    "git status" \
    test_lesson_runner \
    "Show status." \
    "Status is shown."
then
    assert_eq "1" "${TEST_RUNNER_CALLS}" "runner called once after typo correction"
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: lesson should accept corrected command\n'
fi

if grep -q 'eval' "${ROOT}/src/100_lesson_engine.sh" 2>/dev/null; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: lesson engine must not use eval\n'
else
    TESTS_RUN=$((TESTS_RUN + 1))
fi

test_summary
