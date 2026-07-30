#!/usr/bin/env bash
# Bootstrap cleanup, exit status, and Windows TLS order (FR-004–FR-009, D-005).

set -u
set -o pipefail

. "$(dirname "$0")/../lib/common.sh"

TMP=""
cleanup() {
    if [ -n "${TMP}" ] && [ -d "${TMP}" ]; then
        rm -rf "${TMP}"
    fi
}
trap cleanup EXIT

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t gitstart-boot-test)"
SITE="${TMP}/site"
BIN="${TMP}/bin"
LOG="${TMP}/curl_attempts.log"
FAKE_APP_DIR="${TMP}/fake_apps"
mkdir -p "${SITE}/releases/v9.9.9" "${BIN}" "${FAKE_APP_DIR}"

# Minimal app that exits with a known status and records that it ran.
printf '%s\n' '#!/usr/bin/env bash' 'printf "app-ran\n"' 'exit 42' >"${SITE}/releases/v9.9.9/gitstart.sh"
chmod +x "${SITE}/releases/v9.9.9/gitstart.sh"
(
    cd "${SITE}/releases/v9.9.9" || exit 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum gitstart.sh >gitstart.sh.sha256
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 gitstart.sh >gitstart.sh.sha256
    else
        printf 'SKIP: no sha256 tool\n'
        exit 0
    fi
)
printf 'v9.9.9\n' >"${SITE}/stable.txt"

# Stub curl: map URLs under file:// or http://localhost-style to SITE files.
# Logs each attempt as: MODE|ARGS
cat >"${BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -u
log="${GITSTART_TEST_CURL_LOG:-/dev/null}"
mode="normal"
args_join=""
url=""
dest=""
out_stdout=0
i=1
while [ "${i}" -le "$#" ]; do
    eval "arg=\${${i}}"
    case "${arg}" in
        --ssl-no-revoke) mode="ssl-no-revoke" ;;
        -o)
            i=$((i + 1))
            eval "dest=\${${i}}"
            args_join="${args_join} -o"
            ;;
        -fsSL|-f|-s|-S|-L) ;;
        http*|file*)
            url="${arg}"
            ;;
        *)
            args_join="${args_join} ${arg}"
            ;;
    esac
    i=$((i + 1))
done
printf '%s|%s\n' "${mode}" "${url}" >>"${log}"

# Map .../path to SITE root file.
rel="${url#*://}"
rel="${rel#*/}"
# Accept FILE_BASE/path or any host/path ending with known suffixes.
case "${url}" in
    */stable.txt) src="${GITSTART_TEST_SITE}/stable.txt" ;;
    */gitstart.sh.sha256) src="${GITSTART_TEST_SITE}/releases/v9.9.9/gitstart.sh.sha256" ;;
    */gitstart.sh) src="${GITSTART_TEST_SITE}/releases/v9.9.9/gitstart.sh" ;;
    *)
        exit 22
        ;;
esac

# Optional failure injection for TLS order tests.
if [ "${GITSTART_TEST_CURL_FAIL_NORMAL:-0}" = "1" ] && [ "${mode}" = "normal" ]; then
    exit 35
fi
if [ "${GITSTART_TEST_CURL_FAIL_ALL:-0}" = "1" ]; then
    exit 35
fi

if [ -z "${dest}" ]; then
    cat "${src}"
    exit 0
fi
cp "${src}" "${dest}"
exit 0
EOF
chmod +x "${BIN}/curl"

# Stub wget and powershell so Windows path prefers curl stubs.
cat >"${BIN}/wget" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${BIN}/wget"

export PATH="${BIN}:${PATH}"
export GITSTART_TEST_SITE="${SITE}"
export GITSTART_TEST_CURL_LOG="${LOG}"
export GITSTART_BASE_URL="http://gitstart.test"
# Force non-Windows path for cleanup/status tests (uname may be MINGW on this host).
# The bootstrap uses boot_is_windows_shell; override uname in PATH for stable tests.
cat >"${BIN}/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Linux\n'
EOF
chmod +x "${BIN}/uname"

# --- Cleanup and exit status (FR-005, FR-008, FR-009, D-005) ---
: >"${LOG}"
OUT="$(bash "${ROOT}/site/run" 2>&1)"
STATUS=$?
assert_eq "42" "${STATUS}" "bootstrap preserves application exit status"
assert_contains "${OUT}" "app-ran" "bootstrap runs downloaded application"

# Temp dirs named gitstart* under /tmp or TMPDIR should not remain from this run.
# Capture GS_TMP by scanning log is hard; verify no leftover under our controlled mktemp.
# Replace mktemp to use a known directory.
cat >"${BIN}/mktemp" <<EOF
#!/usr/bin/env bash
d="${TMP}/boot_tmp_\$\$"
mkdir -p "\$d"
printf '%s\n' "\$d"
EOF
chmod +x "${BIN}/mktemp"

: >"${LOG}"
bash "${ROOT}/site/run" >/dev/null 2>&1 || true
leftover=0
for d in "${TMP}"/boot_tmp_*; do
    if [ -d "${d}" ]; then
        leftover=1
    fi
done
assert_eq "0" "${leftover}" "bootstrap removes temporary download directory"

# Failure exit status also cleans up.
printf '%s\n' '#!/usr/bin/env bash' 'exit 7' >"${SITE}/releases/v9.9.9/gitstart.sh"
chmod +x "${SITE}/releases/v9.9.9/gitstart.sh"
(
    cd "${SITE}/releases/v9.9.9" || exit 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum gitstart.sh >gitstart.sh.sha256
    else
        shasum -a 256 gitstart.sh >gitstart.sh.sha256
    fi
)
: >"${LOG}"
bash "${ROOT}/site/run" >/dev/null 2>&1
STATUS=$?
assert_eq "7" "${STATUS}" "bootstrap preserves failing application exit status"
leftover=0
for d in "${TMP}"/boot_tmp_*; do
    if [ -d "${d}" ]; then
        leftover=1
    fi
done
assert_eq "0" "${leftover}" "bootstrap removes temp dir after application failure"

# --- TLS fallback order (Windows path) ---
# Restore a successful app for download order checks via function-level harness.
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${SITE}/releases/v9.9.9/gitstart.sh"
(
    cd "${SITE}/releases/v9.9.9" || exit 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum gitstart.sh >gitstart.sh.sha256
    else
        shasum -a 256 gitstart.sh >gitstart.sh.sha256
    fi
)

# Extract and source bootstrap helpers without running main body or traps.
HELPERS="${TMP}/boot_helpers.sh"
awk '
    /^cleanup[(]/ { exit }
    { print }
' "${ROOT}/site/run" >"${HELPERS}"
# shellcheck disable=SC1090
. "${HELPERS}"

# Force Windows shell detection.
boot_is_windows_shell() { return 0; }

: >"${LOG}"
export GITSTART_TEST_CURL_FAIL_NORMAL=1
WARN_OUT="$(boot_download "${GITSTART_BASE_URL}/releases/v9.9.9/gitstart.sh" "${TMP}/dl.sh" 2>&1 >/dev/null)"
assert_ok "ssl-no-revoke fallback succeeds after normal TLS fail" test -s "${TMP}/dl.sh"
assert_contains "${WARN_OUT}" "ssl-no-revoke" "ssl-no-revoke warning goes to stderr"
# First attempts must be normal before ssl-no-revoke.
first_mode="$(head -n 1 "${LOG}" | cut -d'|' -f1)"
assert_eq "normal" "${first_mode}" "first Windows download attempt is normal TLS"
if grep -q '^ssl-no-revoke|' "${LOG}"; then
    assert_ok "ssl-no-revoke used after normal failure" true
else
    assert_ok "ssl-no-revoke used after normal failure" false
fi

# stable.txt capture must not include warning text on stdout.
: >"${LOG}"
export GITSTART_TEST_CURL_FAIL_NORMAL=1
captured="$(boot_download "${GITSTART_BASE_URL}/stable.txt" "-" 2>/dev/null)"
case "${captured}" in
    *WARNING*|*ssl-no-revoke*)
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        printf 'FAIL: warning leaked into stdout capture\n'
        ;;
    *)
        assert_contains "${captured}" "v9.9.9" "stable.txt stdout capture stays clean"
        ;;
esac

# Normal success must not use ssl-no-revoke first.
: >"${LOG}"
export GITSTART_TEST_CURL_FAIL_NORMAL=0
rm -f "${TMP}/dl2.sh"
boot_download "${GITSTART_BASE_URL}/releases/v9.9.9/gitstart.sh" "${TMP}/dl2.sh" 2>/dev/null
assert_ok "normal TLS download succeeds" test -s "${TMP}/dl2.sh"
if grep -q '^ssl-no-revoke|' "${LOG}"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    printf 'FAIL: ssl-no-revoke used when normal TLS succeeded\n'
else
    assert_ok "ssl-no-revoke not used on normal success" true
fi

test_summary
