#!/usr/bin/env bash
# Build dist/gitstart.sh from source modules.
# Development tool. Students do not need this script.

set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/src"
DIST="${ROOT}/dist"
OUT="${DIST}/gitstart.sh"
SUM="${DIST}/gitstart.sh.sha256"

MODULES="
00_header.sh
10_constants.sh
20_terminal.sh
30_text.sh
40_input.sh
60_fuzzy.sh
50_picker.sh
70_git_exec.sh
80_git_state.sh
90_safety.sh
100_lesson_engine.sh
lessons/initialize.sh
lessons/commit_push.sh
lessons/update_clone.sh
lessons/sync_fork.sh
lessons/diagnose.sh
999_main.sh
"

printf 'Building %s\n' "${OUT}"
mkdir -p "${DIST}"
: >"${OUT}"

first=1
for mod in ${MODULES}; do
    path="${SRC}/${mod}"
    if [ ! -f "${path}" ]; then
        printf 'Missing source module: %s\n' "${path}" >&2
        exit 1
    fi
    if [ "${first}" = "1" ]; then
        cat "${path}" >>"${OUT}"
        first=0
    else
        printf '\n# --- %s ---\n' "${mod}" >>"${OUT}"
        # Drop shebang lines from later modules.
        sed '/^#!/d' "${path}" >>"${OUT}"
    fi
done

# Normalize to LF line endings when possible.
if command -v sed >/dev/null 2>&1; then
    tmp="${OUT}.tmp"
    sed 's/\r$//' "${OUT}" >"${tmp}" && mv "${tmp}" "${OUT}"
fi

chmod +x "${OUT}" 2>/dev/null || true

if ! bash -n "${OUT}"; then
    printf 'Syntax check failed.\n' >&2
    exit 1
fi
printf 'Syntax check passed.\n'

if command -v sha256sum >/dev/null 2>&1; then
    (cd "${DIST}" && sha256sum "gitstart.sh" >"gitstart.sh.sha256")
elif command -v shasum >/dev/null 2>&1; then
    (cd "${DIST}" && shasum -a 256 "gitstart.sh" >"gitstart.sh.sha256")
else
    printf 'Warning: no SHA-256 command found. Checksum file was not written.\n' >&2
fi

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash "${OUT}" || printf 'ShellCheck reported issues.\n' >&2
else
    printf 'ShellCheck not installed. Skipped.\n'
fi

printf 'Built %s\n' "${OUT}"
if [ -f "${SUM}" ]; then
    printf 'Checksum %s\n' "${SUM}"
fi
