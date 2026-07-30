#!/usr/bin/env bash
# Identity sequence in selected repository (FR-130, FR-164–FR-166, D-008).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_lesson_engine
source_module lessons/initialize.sh

if ! git_is_available; then
    printf 'SKIP: git not available\n'
    exit 0
fi

TMP=""
REAL_HOME="${HOME:-}"
cleanup() {
    if [ -n "${REAL_HOME}" ]; then
        HOME="${REAL_HOME}"
        export HOME
    fi
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-ident)"
export HOME="${TMP}/home"
mkdir -p "${HOME}"
# Isolate global config; never touch the developer's real global config.
git config --global user.useConfigOnly true >/dev/null 2>&1 || true
git config --global --unset-all user.name >/dev/null 2>&1 || true
git config --global --unset-all user.email >/dev/null 2>&1 || true

LAUNCH="${TMP}/launch"
SELECTED="${TMP}/selected project"
mkdir -p "${LAUNCH}" "${SELECTED}"
cd "${LAUNCH}" || exit 1
git init -q
git config --local user.name "Launch Local"
git config --local user.email "launch@example.com"

# Local identity in launch directory must not satisfy selected repo.
cd "${SELECTED}" || exit 1
git init -q
name=""
email=""
if git_cmd_config_get "user.name"; then
    name="${GS_GIT_LAST_STDOUT}"
fi
if git_cmd_config_get "user.email"; then
    email="${GS_GIT_LAST_STDOUT}"
fi
assert_eq "" "${name}" "launch-dir local name does not apply in selected repo"
assert_eq "" "${email}" "launch-dir local email does not apply in selected repo"

# Global identity satisfies effective check in selected repo.
git config --global user.name "Global User"
git config --global user.email "global@example.com"
if git_cmd_config_get "user.name"; then
    name="${GS_GIT_LAST_STDOUT}"
fi
if git_cmd_config_get "user.email"; then
    email="${GS_GIT_LAST_STDOUT}"
fi
assert_eq "Global User" "${name}" "global identity is visible in selected repo"
assert_eq "global@example.com" "${email}" "global email is visible in selected repo"

# Clear global again for no-identity and local-create tests.
git config --global --unset-all user.name >/dev/null 2>&1 || true
git config --global --unset-all user.email >/dev/null 2>&1 || true

name=""
email=""
if git_cmd_config_get "user.name"; then
    name="${GS_GIT_LAST_STDOUT}"
fi
if git_cmd_config_get "user.email"; then
    email="${GS_GIT_LAST_STDOUT}"
fi
assert_eq "" "${name}" "no identity when global cleared"
assert_eq "" "${email}" "no email when global cleared"

# Create local identity in selected repository.
git_cmd_config_set "user.name" "Selected Local" "local" || exit 1
git_cmd_config_set "user.email" "selected@example.com" "local" || exit 1
assert_eq "Selected Local" "$(git config --local --get user.name)" "local name saved in selected repo"
assert_eq "selected@example.com" "$(git config --local --get user.email)" "local email saved in selected repo"

# Declined global configuration: lesson_initialize_set_identity with stubbed input.
rm -rf "${SELECTED}/.git"
git init -q
git config --global --unset-all user.name >/dev/null 2>&1 || true
git config --global --unset-all user.email >/dev/null 2>&1 || true

# Answers: name, email, decline local, decline global.
GS_TEST_ANSWERS=$'Test Student\ntest@example.com\nn\nn\n'
input_read_line() {
    local prompt="${1:-}"
    if [ -n "${GS_TEST_ANSWERS}" ]; then
        GS_INPUT_LAST="${GS_TEST_ANSWERS%%$'\n'*}"
        GS_TEST_ANSWERS="${GS_TEST_ANSWERS#*$'\n'}"
        return 0
    fi
    GS_INPUT_LAST=""
    return 1
}
input_confirm() {
    input_read_line "$1" || return 1
    case "${GS_INPUT_LAST}" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
input_text() {
    input_read_line "$1" || return 1
}

# Silence UI during identity call.
ui_warning() { :; }
ui_info() { :; }
ui_muted() { :; }
ui_success() { :; }
lesson_stop_safe() { return 1; }

if lesson_initialize_set_identity; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    printf 'FAIL: declined global should stop identity setup\n'
else
    assert_ok "declined global configuration stops safely" true
fi

# Global config must remain unset.
gname="$(git config --global --get user.name 2>/dev/null || true)"
assert_eq "" "${gname}" "declined path does not write global user.name"

test_summary
