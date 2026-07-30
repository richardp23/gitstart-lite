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

score="$(fuzzy_score "XYZ" "project")"
assert_eq "0" "${score}" "case-insensitive no match stays zero"

score="$(fuzzy_score "PRO" "project")"
assert_gt "${score}" "7990" "case-insensitive prefix"

score="$(fuzzy_score "" "project")"
assert_eq "1" "${score}" "empty query scores positive"

score="$(fuzzy_score "a" "a")"
assert_eq "10000" "${score}" "single-char exact"

score_early="$(fuzzy_score "ab" "abxxxxx")"
score_late="$(fuzzy_score "ab" "xxxxxab")"
assert_gt "${score_early}" "${score_late}" "earlier substring ranks higher"

assert_ok "fuzzy_match accepts prefix" fuzzy_match "git" "gitstart"
assert_fail "fuzzy_match rejects unrelated" fuzzy_match "abc" "gitstart"
assert_ok "fuzzy_match case-insensitive" fuzzy_match "GIT" "gitstart"

test_summary
