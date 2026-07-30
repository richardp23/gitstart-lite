#!/usr/bin/env bash
# Unit/integration: picker records, sort, filter, preview cache (FR-060–FR-085).

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

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-picker)"
ROOT_DIR="${TMP}/root"
mkdir -p "${ROOT_DIR}/Alpha" "${ROOT_DIR}/beta" "${ROOT_DIR}/with space" "${ROOT_DIR}/.hidden"
mkdir -p "${ROOT_DIR}/many"
i=1
while [ "${i}" -le 30 ]; do
    mkdir -p "${ROOT_DIR}/many/d$(printf '%02d' "${i}")"
    i=$((i + 1))
done
mkdir -p "${ROOT_DIR}/Alpha/.git"
touch "${ROOT_DIR}/beta/.env"

# Empty directory
EMPTY="${TMP}/empty"
mkdir -p "${EMPTY}"
GS_PICKER_DIR="${EMPTY}"
GS_PICKER_SHOW_HIDDEN=0
GS_PICKER_FILTER=""
GS_PICKER_INDEX=0
picker_enumerate
assert_eq "2" "${GS_PICKER_COUNT}" "empty dir has select and parent only"
assert_eq "select" "${GS_PICKER_KINDS[0]}" "first row is current-directory select"
assert_eq "parent" "${GS_PICKER_KINDS[1]}" "second row is parent"

# Case-insensitive sort and spaces
GS_PICKER_DIR="${ROOT_DIR}"
picker_enumerate
# After . and .., expect Alpha, beta, many, with space (case-insensitive).
assert_eq "Alpha/" "${GS_PICKER_LABELS[2]}" "Alpha sorts before beta (case-insensitive)"
found_space=0
i=0
while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
    if [ "${GS_PICKER_LABELS[${i}]}" = "with space/" ]; then
        found_space=1
        assert_eq "dir" "${GS_PICKER_KINDS[${i}]}" "space name is a dir row"
        case "${GS_PICKER_PATHS[${i}]}" in
            *"with space") ;;
            *)
                TESTS_FAILED=$((TESTS_FAILED + 1))
                printf 'FAIL: path with spaces not preserved\n'
                ;;
        esac
    fi
    i=$((i + 1))
done
assert_eq "1" "${found_space}" "directory with spaces is listed"

# Hidden toggle
GS_PICKER_SHOW_HIDDEN=0
picker_enumerate
hidden_visible=0
i=0
while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
    case "${GS_PICKER_LABELS[${i}]}" in
        .hidden/) hidden_visible=1 ;;
    esac
    i=$((i + 1))
done
assert_eq "0" "${hidden_visible}" "hidden dirs omitted by default"
GS_PICKER_SHOW_HIDDEN=1
picker_enumerate
hidden_visible=0
i=0
while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
    case "${GS_PICKER_LABELS[${i}]}" in
        .hidden/) hidden_visible=1 ;;
    esac
    i=$((i + 1))
done
assert_eq "1" "${hidden_visible}" "hidden dirs listed when enabled"

# Filtered results
GS_PICKER_SHOW_HIDDEN=0
GS_PICKER_FILTER="alp"
picker_enumerate
assert_eq "3" "${GS_PICKER_COUNT}" "filter keeps select, parent, and Alpha"
assert_eq "Alpha/" "${GS_PICKER_LABELS[2]}" "filtered child is Alpha"

# Many directories
GS_PICKER_DIR="${ROOT_DIR}/many"
GS_PICKER_FILTER=""
picker_enumerate
assert_eq "32" "${GS_PICKER_COUNT}" "many directories: select+parent+30"

# Preview cache
GS_PICKER_DIR="${ROOT_DIR}"
GS_TERM_WIDTH=120
picker_preview_invalidate
picker_preview_build "${ROOT_DIR}/Alpha"
first="${GS_PICKER_PREVIEW_TEXT}"
assert_contains "${first}" "[GIT]" "preview notes Git repository"
picker_preview_build "${ROOT_DIR}/Alpha"
assert_eq "${first}" "${GS_PICKER_PREVIEW_TEXT}" "preview cache reused for same path"
picker_preview_build "${ROOT_DIR}/beta"
assert_contains "${GS_PICKER_PREVIEW_TEXT}" "[SECRET?]" "preview notes secret name"
# Invalidate on directory change signal
picker_preview_invalidate
assert_eq "" "${GS_PICKER_PREVIEW_PATH}" "preview cache cleared on invalidate"

# Parent and current selection kinds remain first
GS_PICKER_FILTER=""
picker_enumerate
assert_eq "select" "${GS_PICKER_KINDS[0]}" "current-directory selection preserved"
assert_eq "parent" "${GS_PICKER_KINDS[1]}" "parent selection preserved"

test_summary
