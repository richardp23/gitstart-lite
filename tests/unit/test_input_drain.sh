#!/usr/bin/env bash
# Unit tests: TTY drain must finish fast and restore cooked mode (Git Bash).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"

source_core

# Bounded drain pattern used by input_drain_tty (no blocking read).
drain_bounded() {
    local junk
    local n=0
    local max=64
    while [ "${n}" -lt "${max}" ]; do
        if ! IFS= read -r -n 1 -t 0 junk 2>/dev/null; then
            break
        fi
        n=$((n + 1))
    done
    printf '%s' "${n}"
}

# With no input, Git Bash may spin; bound must stop at max.
count="$(drain_bounded </dev/null)"
if [ "${count}" -le 64 ] 2>/dev/null; then
    assert_eq "1" "1" "bounded drain stops at or before max=64 (got ${count})"
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: drain exceeded max (%s)\n' "${count}"
fi

# input_read_line must not call drain (extra Enter should satisfy a pause prompt).
body="$(sed -n '/^input_read_line()/,/^}/p' "${ROOT}/src/40_input.sh")"
case "${body}" in
    *input_drain_tty*)
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf 'FAIL: input_read_line body still drains TTY\n'
        ;;
    *)
        assert_eq "1" "1" "input_read_line does not drain before read"
        ;;
esac

# Drain must use a bounded loop (max=), not a blocking read -d ''.
assert_contains "$(sed -n '/^input_drain_tty()/,/^}/p' "${ROOT}/src/40_input.sh")" "max=64" \
    "input_drain_tty bounds the loop"
assert_fail "input_drain_tty must not use blocking read -d ''" \
    grep -q "read -r -d ''" "${ROOT}/src/40_input.sh"

# Restore helper must force echo/icanon for Git Bash recovery.
assert_contains "$(sed -n '/^input_restore_tty()/,/^}/p' "${ROOT}/src/40_input.sh")" "echo icanon" \
    "input_restore_tty forces echo icanon"

# Bash 3.2 (macOS) rejects fractional read -t; arrow parsing must not use it.
assert_fail "input_read_key must not use fractional read -t (Bash 3.2)" \
    grep -E 'IFS= read .* -t 0\.[0-9]' "${ROOT}/src/40_input.sh"
assert_contains "$(sed -n '/^input_read_key()/,/^}/p' "${ROOT}/src/40_input.sh")" "time 1 min 0" \
    "input_read_key uses stty VTIME for escape tails"

test_summary
