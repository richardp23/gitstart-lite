#!/usr/bin/env bash
# Conditional cd uses current cwd, not session start alone (FR-087, D-019).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_lesson_engine
source_module 50_picker.sh

TMP=""
cleanup() {
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-cd-cond)"
DIR_A="${TMP}/A"
DIR_B="${TMP}/B"
mkdir -p "${DIR_A}" "${DIR_B}"
DIR_A="$(lesson_path_resolve "${DIR_A}")"
DIR_B="$(lesson_path_resolve "${DIR_B}")"

# Stub interactive confirms and teaching so the test stays noninteractive.
input_confirm() { return 0; }
lesson_teach_exact_command() {
    local expected="$1"
    local runner="$2"
    GS_TEST_LAST_CD_CMD="${expected}"
    GS_TEST_CD_TAUGHT=1
    "${runner}"
}
lesson_focus() { :; }
lesson_substep_begin() { :; }
ui_step() { :; }
ui_print() { :; }
ui_info() { :; }
ui_success() { :; }
ui_warning() { :; }
ui_muted() { :; }
ui_fail_detail() { return 1; }
safety_scan_secrets() { GS_SAFE_SECRET_HITS=""; }
safety_scan_generated() { GS_SAFE_GENERATED_HITS=""; }
safety_is_dangerous_directory() { GS_SAFE_DANGEROUS=0; return 0; }
input_drain_tty() { :; }

# 1) Session starts in A.
cd -- "${DIR_A}" || exit 1
lesson_session_record_start_dir
assert_eq "${DIR_A}" "${GS_SESSION_START_DIR}" "session start records A"
assert_eq "${DIR_A}" "$(lesson_current_dir_resolved)" "current dir is A"

# 2) Application changes to B (as after an earlier lesson/picker).
cd -- "${DIR_B}" || exit 1
assert_eq "${DIR_B}" "$(lesson_current_dir_resolved)" "current dir is B"
assert_eq "${DIR_A}" "${GS_SESSION_START_DIR}" "session start stays A"

# 3) Later picker selects A while current is B -> must teach and run cd.
GS_TEST_CD_TAUGHT=0
GS_TEST_LAST_CD_CMD=""
GS_PICKER_SELECTED="${DIR_A}"
assert_ok "select A from B teaches and runs cd" \
    picker_confirm_and_teach_cd "${DIR_A}"
assert_eq "1" "${GS_TEST_CD_TAUGHT}" "cd was taught when returning to A"
assert_eq "${DIR_A}" "$(lesson_current_dir_resolved)" "cwd is A after cd"
assert_eq "${DIR_A}" "${GS_PICKER_SELECTED}" "selected resolved to A"
assert_contains "${GS_TEST_LAST_CD_CMD}" "cd --" "taught a cd command"

# 4) Session still A; move to B again; select B -> skip cd.
cd -- "${DIR_B}" || exit 1
GS_TEST_CD_TAUGHT=0
GS_TEST_LAST_CD_CMD=""
GS_PICKER_SELECTED="${DIR_B}"
assert_ok "select B while in B skips cd" \
    picker_confirm_and_teach_cd "${DIR_B}"
assert_eq "0" "${GS_TEST_CD_TAUGHT}" "cd was not taught when already in B"
assert_eq "${DIR_B}" "$(lesson_current_dir_resolved)" "cwd remains B"
assert_eq "${DIR_B}" "${GS_PICKER_SELECTED}" "selected resolved to B"
assert_eq "${DIR_A}" "${GS_SESSION_START_DIR}" "session start still immutable A"

# Restore UI printers for completion-note checks.
ui_info() { printf '%s\n' "$*"; }
ui_print() { printf '%s\n' "$*"; }
ui_command() { printf '%s\n' "$*"; }
ui_blank() { printf '\n'; }

# Completion note: selected B differs from start A.
OUT="$(lesson_explain_child_shell_if_needed 2>&1)"
assert_contains "${OUT}" "When GitStart closes" "child-shell note when selected is B and start is A"

# Completion note: selected A equals start A.
GS_PICKER_SELECTED="${DIR_A}"
OUT="$(lesson_explain_child_shell_if_needed 2>&1)"
case "${OUT}" in
    *'When GitStart closes'*)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: child-shell note shown when selected equals session start\n'
        ;;
    *)
        assert_ok "no child-shell note when selected equals session start" true
        ;;
esac

test_summary
