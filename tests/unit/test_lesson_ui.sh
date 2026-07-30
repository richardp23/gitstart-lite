#!/usr/bin/env bash
# Lesson board stages, help callback, staged paths (FR-110, FR-114–FR-115, FR-171).

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

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-lesson-ui)"
REPO="${TMP}/repo"
mkdir -p "${REPO}"
cd "${REPO}" || exit 1
git init >/dev/null 2>&1
git config user.name "Test"
git config user.email "test@example.com"
printf 'one\n' >a.txt
printf 'two\n' >b.txt
git add a.txt b.txt

# Staged path names (FR-171).
OUT="$(lesson_show_staged_paths 2>&1)"
assert_contains "${OUT}" "a.txt" "staged paths show a.txt"
assert_contains "${OUT}" "b.txt" "staged paths show b.txt"

# Conceptual stages board.
GS_TERM_IS_TTY=0
GS_TERM_PLAIN=1
lesson_begin_stages "Demo" "demo" "Stage A" "Stage B" "Stage C"
assert_eq "1" "${GS_LESSON_USE_STAGES}" "stages mode enabled"
assert_eq "3" "${GS_LESSON_STAGE_COUNT}" "three stages registered"
lesson_stage_begin "Stage A"
assert_eq "1" "${GS_LESSON_STAGE_INDEX}" "first stage index"
lesson_substep_begin "Substep 1"
assert_eq "Substep 1" "${GS_LESSON_SUBSTEP}" "substep label set"
BOARD="$(lesson_draw_board 2>&1)"
assert_contains "${BOARD}" "[NOW]" "board shows current marker"
assert_contains "${BOARD}" "Stage A" "board shows current stage"
assert_contains "${BOARD}" "Substep 1" "board shows substep"
assert_contains "${BOARD}" "Stage B" "board lists remaining stage"

# Detailed help callback returns without completing.
test_help_fn() {
    ui_print "HELP_OK"
}
GS_TEACH_HELP_FN="test_help_fn"
# Stub pause so help does not wait on stdin.
lesson_pause_continue() { return 0; }
OUT="$(lesson_show_detailed_help "pwd" "why" "result" 2>&1)"
assert_contains "${OUT}" "HELP_OK" "help callback output shown"
assert_eq "1" "${GS_LESSON_STAGE_INDEX}" "help does not advance stage"
assert_eq "Substep 1" "${GS_LESSON_SUBSTEP}" "help preserves substep"

# Structured sections use labels.
GS_TEACH_GOAL="Goal text"
GS_TEACH_CONCEPT="Concept text"
GS_TEACH_LOOK_FOR="Look text"
OUT="$(lesson_show_teach_sections "pwd" 2>&1)"
assert_contains "${OUT}" "GOAL" "GOAL label present"
assert_contains "${OUT}" "CONCEPT" "CONCEPT label present"
assert_contains "${OUT}" "TYPE" "TYPE label present"
assert_contains "${OUT}" "LOOK FOR" "LOOK FOR label present"
assert_contains "${OUT}" "pwd" "command shown under TYPE"

# Child-shell note only when selected differs from session start.
GS_SESSION_START_DIR="$(lesson_path_resolve "${REPO}")"
GS_PICKER_SELECTED="${GS_SESSION_START_DIR}"
OUT="$(lesson_explain_child_shell_if_needed 2>&1)"
case "${OUT}" in
    *'When GitStart closes'*)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: child-shell note shown when selected equals session start\n'
        ;;
    *)
        assert_ok "no child-shell note when selected equals start" true
        ;;
esac
OTHER="${TMP}/other"
mkdir -p "${OTHER}"
GS_PICKER_SELECTED="$(lesson_path_resolve "${OTHER}")"
OUT="$(lesson_explain_child_shell_if_needed 2>&1)"
assert_contains "${OUT}" "When GitStart closes" "child-shell note when selected differs from start"
assert_contains "${OUT}" "cd --" "return cd command shown"

test_summary
