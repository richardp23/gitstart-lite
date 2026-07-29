#!/usr/bin/env bash
# Unit tests: forbidden command detection (FR-140 through FR-144).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core

assert_ok "detect push --force" safety_is_forbidden_command "git push --force origin main"
assert_ok "detect push -f" safety_is_forbidden_command "git push -f"
assert_ok "detect reset --hard" safety_is_forbidden_command "git reset --hard"
assert_ok "detect clean -fd" safety_is_forbidden_command "git clean -fd"
assert_ok "detect restore ." safety_is_forbidden_command "git restore ."
assert_ok "detect checkout -- ." safety_is_forbidden_command "git checkout -- ."
assert_ok "detect branch -D" safety_is_forbidden_command "git branch -D feature"

assert_fail "allow git status" safety_is_forbidden_command "git status"
assert_fail "allow git add" safety_is_forbidden_command "git add ."
assert_fail "allow git push" safety_is_forbidden_command "git push"

test_summary
