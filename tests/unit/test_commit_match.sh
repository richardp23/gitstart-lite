#!/usr/bin/env bash
# Smoke test commit-message matching (FR-174).
set -u
GS_TEST_MODE=1
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1090
. "${ROOT}/tests/lib/common.sh"
source_lesson_engine

fail=0
fmt="$(lesson_format_commit_command "First commit")"
assert_eq 'git commit -m "First commit"' "${fmt}" "format uses double quotes" || fail=1

lesson_match_commit_command 'git commit -m "First commit"' 'git commit -m "First commit"' \
    || { echo "FAIL quoted vs quoted"; fail=1; }
lesson_match_commit_command 'git commit -m First\ commit' 'git commit -m "First commit"' \
    || { echo "FAIL escaped vs quoted"; fail=1; }
lesson_match_commit_command "git commit -m 'First commit'" 'git commit -m "First commit"' \
    || { echo "FAIL single vs quoted"; fail=1; }

if [ "${fail}" -ne 0 ]; then
    exit 1
fi
echo "commit match smoke: ok"
test_summary
