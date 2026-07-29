#!/usr/bin/env bash
# Unit tests: remote URL sanitization (FR-300 through FR-309).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core

out="$(git_sanitize_remote_url "https://user:secret@github.com/org/repo.git")"
assert_eq "https://github.com/org/repo.git" "${out}" "strip HTTPS userinfo"

out="$(git_sanitize_remote_url "origin  https://token@example.com/a.git (fetch)")"
assert_contains "${out}" "https://example.com/a.git" "sanitize remote -v line"
case "${out}" in
    *token@*)
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf 'FAIL: token must be removed from sanitized output\n'
        ;;
    *)
        TESTS_RUN=$((TESTS_RUN + 1))
        ;;
esac

assert_ok "valid HTTPS URL passes validation" git_validate_https_url "https://github.com/org/repo.git"
assert_fail "embedded credentials rejected" git_validate_https_url "https://user:pass@github.com/org/repo.git"
assert_fail "SSH URL rejected in MVP" git_validate_https_url "git@github.com:org/repo.git"

test_summary
