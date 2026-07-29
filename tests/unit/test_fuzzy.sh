#!/usr/bin/env bash
# Unit tests: fuzzy match scoring (FR-068 through FR-070).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core

score="$(fuzzy_score "proj" "proj")"
assert_eq "10000" "${score}" "exact match score"

score="$(fuzzy_score "pro" "project")"
assert_gt "${score}" "7990" "prefix match beats substring"

score="$(fuzzy_score "ect" "project")"
assert_gt "${score}" "0" "substring match is positive"

score="$(fuzzy_score "pjt" "project")"
assert_gt "${score}" "0" "ordered character match is positive"

score="$(fuzzy_score "xyz" "project")"
assert_eq "0" "${score}" "no match score is zero"

assert_ok "fuzzy_match accepts prefix" fuzzy_match "git" "gitstart"
assert_fail "fuzzy_match rejects unrelated" fuzzy_match "abc" "gitstart"

test_summary
