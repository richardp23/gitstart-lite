#!/usr/bin/env bash
# cd command formatting and safe execution (FR-087–FR-089, FR-104–FR-105, D-019).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_lesson_engine

TMP=""
cleanup() {
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-cd)"
export HOME="${TMP}/home"
mkdir -p "${HOME}/Documents/weather-app"
mkdir -p "${HOME}/Documents/Final Project"
mkdir -p "${HOME}/Projects/\$demo"
mkdir -p "${HOME}/Documents/O'Brien"
mkdir -p "${HOME}/Documents/say \"hi\""
mkdir -p "${HOME}/Documents/a(b)"
mkdir -p "${HOME}/Documents/a&b"
mkdir -p "${HOME}/Documents/a[b]"
mkdir -p "${HOME}/Documents/--leading"
mkdir -p "${TMP}/outside/Final Project"
mkdir -p "${TMP}/Volumes/Class/Student Work"

# Fake Git Bash / macOS-style absolute paths outside HOME.
mkdir -p "${TMP}/c/School/Final Project"
OUTSIDE="${TMP}/outside/Final Project"
MAC_STYLE="${TMP}/Volumes/Class/Student Work"
DRIVE_STYLE="${TMP}/c/School/Final Project"

cmd=""
got=""

cmd="$(lesson_format_cd_command "${HOME}")"
assert_eq "cd -- ~" "${cmd}" "home directory formats as cd -- ~"

cmd="$(lesson_format_cd_command "${HOME}/Documents/weather-app")"
assert_eq "cd -- ~/Documents/weather-app" "${cmd}" "home child keeps unquoted tilde"

cmd="$(lesson_format_cd_command "${HOME}/Documents/Final Project")"
case "${cmd}" in
    'cd -- ~/Documents/Final\ Project') ;;
    *)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: spaces under home: %q\n' "${cmd}"
        ;;
esac
assert_ok "tilde not incorrectly quoted with spaces" \
    bash -c 'case "$1" in *\"~/*|*\~\") exit 1;; esac' _ "${cmd}"

cmd="$(lesson_format_cd_command "${HOME}/Projects/\$demo")"
assert_contains "${cmd}" 'cd -- ~/' "dollar path keeps tilde prefix"
assert_contains "${cmd}" 'demo' "dollar path includes demo name"

cmd="$(lesson_format_cd_command "${OUTSIDE}")"
case "${cmd}" in
    cd\ --\ /*)
        assert_ok "outside HOME uses absolute path" true
        ;;
    *)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: outside path not absolute: %q\n' "${cmd}"
        ;;
esac
case "${cmd}" in
    *'~'*)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: outside path should not use tilde: %q\n' "${cmd}"
        ;;
    *)
        assert_ok "outside path has no tilde" true
        ;;
esac

# Reject control characters.
assert_fail "control character path rejected" \
    lesson_format_cd_command "$(printf 'bad\tpath')"

# Generated command must work in a child Bash process (FR-089).
run_generated_cd() {
    local target="$1"
    local generated
    local result
    generated="$(lesson_format_cd_command "${target}")" || return 1
    result="$(bash -c "${generated}; pwd -P" )" || return 1
    expected="$(lesson_path_resolve "${target}")" || return 1
    [ "${result}" = "${expected}" ]
}

assert_ok "generated cd home works" run_generated_cd "${HOME}"
assert_ok "generated cd weather-app works" run_generated_cd "${HOME}/Documents/weather-app"
assert_ok "generated cd spaces works" run_generated_cd "${HOME}/Documents/Final Project"
assert_ok "generated cd dollar works" run_generated_cd "${HOME}/Projects/\$demo"
assert_ok "generated cd apostrophe works" run_generated_cd "${HOME}/Documents/O'Brien"
assert_ok "generated cd double-quote works" run_generated_cd "${HOME}/Documents/say \"hi\""
assert_ok "generated cd paren works" run_generated_cd "${HOME}/Documents/a(b)"
assert_ok "generated cd ampersand works" run_generated_cd "${HOME}/Documents/a&b"
assert_ok "generated cd brackets works" run_generated_cd "${HOME}/Documents/a[b]"
assert_ok "generated cd leading hyphen works" run_generated_cd "${HOME}/Documents/--leading"
assert_ok "generated cd outside spaces works" run_generated_cd "${OUTSIDE}"
assert_ok "generated cd mac-style path works" run_generated_cd "${MAC_STYLE}"
assert_ok "generated cd drive-style path works" run_generated_cd "${DRIVE_STYLE}"

# Exact match only for typed cd.
assert_ok "exact cd match accepted" \
    lesson_match_cd_command "cd -- ~/Documents/weather-app" "cd -- ~/Documents/weather-app"
assert_fail "unquoted spaces not accepted by weak matcher" \
    lesson_match_cd_command "cd -- ~/Documents/Final Project" "cd -- ~/Documents/Final\\ Project"

# Session path helpers.
GS_SESSION_START_DIR="$(lesson_path_resolve "${HOME}")"
assert_ok "same start and selected" lesson_paths_equal "${HOME}" "${GS_SESSION_START_DIR}"
assert_fail "different selected folder" lesson_paths_equal "${HOME}" "${HOME}/Documents/weather-app"
cd -- "${HOME}" || exit 1
assert_eq "${GS_SESSION_START_DIR}" "$(lesson_current_dir_resolved)" "current helper matches home"

test_summary
