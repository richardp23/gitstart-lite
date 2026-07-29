#!/usr/bin/env bash
# Integration tests: git state inspection on temporary repositories (FR-120 through FR-130).

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

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-test)"
cd "${TMP}" || exit 1

git_state_inspect
assert_eq "0" "${GS_STATE_IS_REPO}" "non-repo directory"
assert_eq "NOT_A_REPOSITORY" "${GS_STATE_CLASS}" "non-repo class"

git init -q
git config user.email "test@example.com"
git config user.name "Test User"
echo "hello" >README.md
git add README.md
git commit -qm "Initial commit"

git_state_inspect
assert_eq "1" "${GS_STATE_IS_REPO}" "repo detected after init"
assert_eq "1" "${GS_STATE_HAS_COMMIT}" "commit detected"
assert_eq "1" "${GS_STATE_IS_CLEAN}" "clean tree after commit"

test_summary
