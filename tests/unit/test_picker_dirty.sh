#!/usr/bin/env bash
# Picker dirty-flag refresh behavior (NFR-060–NFR-061). No TTY required.

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"
source_core
source_module 50_picker.sh

TMP=""
cleanup() {
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-picker-dirty)"
ROOT_DIR="${TMP}/root"
mkdir -p "${ROOT_DIR}/Alpha" "${ROOT_DIR}/beta"

GS_PICKER_DIR="${ROOT_DIR}"
GS_PICKER_SHOW_HIDDEN=0
GS_PICKER_FILTER=""
GS_PICKER_INDEX=0
GS_PICKER_RECORDS_DIRTY=1

# First ensure builds records.
picker_records_ensure
assert_eq "0" "${GS_PICKER_RECORDS_DIRTY}" "ensure clears dirty flag"
count1="${GS_PICKER_COUNT}"
assert_gt "${count1}" "2" "enumerate lists children"

# Snapshot labels.
label0="${GS_PICKER_LABELS[0]}"
# Up/Down simulation must not rebuild: clear arrays would be wrong; instead
# poison the dirty flag off and confirm ensure is a no-op.
GS_PICKER_PATHS[0]="POISON"
picker_records_ensure
assert_eq "POISON" "${GS_PICKER_PATHS[0]}" "Up/Down path does not re-enumerate"

# Opening a child marks dirty and refreshes.
GS_PICKER_DIR="${ROOT_DIR}/Alpha"
GS_PICKER_INDEX=0
picker_records_mark_dirty
assert_eq "1" "${GS_PICKER_RECORDS_DIRTY}" "navigation marks dirty"
picker_records_ensure
assert_eq "0" "${GS_PICKER_RECORDS_DIRTY}" "ensure after navigation clears dirty"
assert_eq "select" "${GS_PICKER_KINDS[0]}" "refreshed records start with select"

# Filter change marks dirty.
GS_PICKER_DIR="${ROOT_DIR}"
GS_PICKER_FILTER="alp"
picker_records_mark_dirty
picker_records_ensure
assert_eq "Alpha/" "${GS_PICKER_LABELS[2]}" "filter refresh lists Alpha"
: "${label0}"

test_summary
