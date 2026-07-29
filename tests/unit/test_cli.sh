#!/usr/bin/env bash
# Unit tests: CLI --version, --help, and --plain (FR-050 through FR-055).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"

APP="${ROOT}/dist/gitstart.sh"
EXPECTED_VERSION="$(sed -n 's/^GS_APP_VERSION="\(.*\)"/\1/p' "${ROOT}/src/10_constants.sh")"

# Clear any inherited test-mode flag so main() runs in the child process.
out="$(env -u GS_TEST_MODE bash "${APP}" --version 2>&1)"
assert_contains "${out}" "GitStart Lite" "--version shows app name"
assert_contains "${out}" "${EXPECTED_VERSION}" "--version shows version"

out="$(env -u GS_TEST_MODE bash "${APP}" --help 2>&1)"
assert_contains "${out}" "Usage:" "--help shows usage"
assert_contains "${out}" "--plain" "--help lists --plain"

out="$(env -u GS_TEST_MODE bash "${APP}" --not-a-flag 2>&1 || true)"
assert_contains "${out}" "[ERROR]" "unknown option uses error marker"

test_summary
