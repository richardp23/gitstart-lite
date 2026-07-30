#!/usr/bin/env bash
# Run all GitStart Lite tests.

set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}" || exit 1

if [ ! -f "dist/gitstart.sh" ]; then
    printf 'Building dist/gitstart.sh first...\n'
    bash build.sh || exit 1
fi

TOTAL_FAILED=0
TESTS=(
    tests/unit/test_fuzzy.sh
    tests/unit/test_url_sanitize.sh
    tests/unit/test_forbidden.sh
    tests/unit/test_cli.sh
    tests/unit/test_commit_match.sh
    tests/unit/test_input_drain.sh
    tests/unit/test_bootstrap.sh
    tests/unit/test_git_remote_error.sh
    tests/unit/test_picker.sh
    tests/integration/test_git_state.sh
    tests/integration/test_git_state_helpers.sh
    tests/integration/test_identity.sh
    tests/integration/test_no_eval.sh
)

for t in "${TESTS[@]}"; do
    printf '\n== %s ==\n' "${t}"
    if bash "${t}"; then
        printf 'PASS: %s\n' "${t}"
    else
        printf 'FAIL: %s\n' "${t}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

printf '\n'
if [ "${TOTAL_FAILED}" -gt 0 ]; then
    printf '%s test file(s) failed.\n' "${TOTAL_FAILED}"
    exit 1
fi
printf 'All automated tests passed.\n'
printf 'Note: this suite does not test interactive TTY input.\n'
printf 'Run manual checks in tests/manual/README.md on Git Bash or macOS Terminal.\n'
exit 0
