#!/usr/bin/env bash
# Targeted Git state helpers (FR-120–FR-128).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core

if ! git_is_available; then
    printf 'SKIP: git not available\n'
    exit 0
fi

TMP=""
cleanup() {
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-state-helpers)"
cd "${TMP}" || exit 1

assert_fail "non-repo check_is_repo fails" git_state_check_is_repo

git init -q
assert_ok "repo after init" git_state_check_is_repo
assert_fail "no commit yet" git_state_check_has_commit
assert_fail "no origin yet" git_state_check_has_remote origin

git config user.email "t@example.com"
git config user.name "T"
printf 'x\n' >f.txt
git add f.txt
git commit -qm "c"

assert_ok "commit exists" git_state_check_has_commit
assert_fail "still no origin" git_state_check_has_remote origin

git remote add origin "${TMP}/elsewhere.git"
assert_ok "origin exists" git_state_check_has_remote origin

# Tracking helper with no upstream
git_state_inspect_tracking
assert_eq "UNTRACKED" "${GS_STATE_RELATION}" "no upstream is UNTRACKED"

# Bare remote and push to set upstream
git init --bare "${TMP}/elsewhere.git" -q
git push -u origin HEAD >/dev/null 2>&1
git_state_inspect_tracking
assert_eq "EQUAL" "${GS_STATE_RELATION}" "tracking EQUAL after push -u"

# Full inspect still works for diagnosis
git_state_inspect
assert_eq "1" "${GS_STATE_IS_REPO}" "full inspect still reports repo"

test_summary
