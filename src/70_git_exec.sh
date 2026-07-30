# Sole Git execution layer. Never eval student text.
# Implements: FR-105 through FR-108, FR-280 through FR-282, FR-300 through FR-309.

GS_GIT_LAST_STATUS=0
GS_GIT_LAST_STDOUT=""
GS_GIT_REMOTE_ERROR_CLASS=""

# Return 0 when git is available.
git_is_available() {
    command -v git >/dev/null 2>&1
}

# Run a read-only Git command. Arguments are passed separately.
# Usage: git_run_readonly [git args...]
git_run_readonly() {
    GS_GIT_LAST_STATUS=0
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    git "$@"
    GS_GIT_LAST_STATUS=$?
    return "${GS_GIT_LAST_STATUS}"
}

# Capture stdout from a read-only Git command into GS_GIT_LAST_STDOUT.
git_capture() {
    local out
    local status
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    out="$(git "$@" 2>/dev/null)"
    status=$?
    GS_GIT_LAST_STATUS="${status}"
    GS_GIT_LAST_STDOUT="${out}"
    return "${status}"
}

# Capture stdout and status. Same as git_capture. Kept for API clarity.
git_capture_status() {
    git_capture "$@"
}

# Run a state-changing Git command with separate arguments.
# Lessons must confirm before calling this function.
# Filter common Windows CRLF notices so students see real errors first.
git_run_change() {
    local combined
    local filtered
    local crlf_count
    GS_GIT_LAST_STATUS=0
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    combined="$(git "$@" 2>&1)"
    GS_GIT_LAST_STATUS=$?
    GS_GIT_LAST_STDOUT="${combined}"
    crlf_count=0
    filtered=""
    if [ -n "${combined}" ]; then
        while IFS= read -r line; do
            case "${line}" in
                *"LF will be replaced by CRLF"*)
                    crlf_count=$((crlf_count + 1))
                    ;;
                *)
                    if [ -n "${filtered}" ]; then
                        filtered="${filtered}
${line}"
                    else
                        filtered="${line}"
                    fi
                    ;;
            esac
        done <<EOF
${combined}
EOF
    fi
    if [ -n "${filtered}" ]; then
        printf '%s\n' "${filtered}"
    fi
    if [ "${crlf_count}" -gt 0 ] 2>/dev/null; then
        ui_muted "Git noted ${crlf_count} line-ending messages. This is common on Windows."
    fi
    return "${GS_GIT_LAST_STATUS}"
}

# Remove credentials from a remote URL for display. Print sanitized URL.
git_sanitize_remote_url() {
    local url="$1"
    # Remove userinfo before @ in URL forms.
    printf '%s\n' "${url}" | sed -E 's#(https?://)[^/@[:space:]]+@#\1#; s#(git://)[^/@[:space:]]+@#\1#; s#:[^/@[:space:]]+@#:@#'
}

# Validate an HTTPS Git remote URL. Return 0 when acceptable for MVP.
git_validate_https_url() {
    local url="$1"
    case "${url}" in
        *[[:cntrl:]]*)
            return 1
            ;;
        https://*@*|http://*@*)
            # Embedded userinfo is rejected in MVP.
            return 1
            ;;
        https://*.git|https://*)
            case "${url}" in
                https://*/*)
                    return 0
                    ;;
            esac
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Predefined safe Git operations used after command validation.

git_cmd_init() {
    git_run_change init
}

git_cmd_branch_rename_main() {
    git_run_change branch -M main
}

git_cmd_status() {
    git_run_readonly status
}

git_cmd_status_porcelain() {
    git_capture status --porcelain=v1
}

git_cmd_add_all() {
    git_run_change add -A
}

git_cmd_commit_message() {
    local message="$1"
    git_run_change commit -m "${message}"
}

git_cmd_remote_add() {
    local name="$1"
    local url="$2"
    git_run_change remote add "${name}" "${url}"
}

git_cmd_remote_verbose() {
    git_run_readonly remote -v
}

git_cmd_push_upstream() {
    local remote="$1"
    local branch="$2"
    git_run_change push -u "${remote}" "${branch}"
}

git_cmd_push() {
    local remote="$1"
    local branch="$2"
    git_run_change push "${remote}" "${branch}"
}

git_cmd_fetch() {
    local remote="${1:-}"
    if [ -n "${remote}" ]; then
        git_run_change fetch "${remote}"
    else
        git_run_change fetch
    fi
}

git_cmd_pull_ff_only() {
    git_run_change pull --ff-only
}

git_cmd_merge_ff_only() {
    local ref="$1"
    git_run_change merge --ff-only "${ref}"
}

git_cmd_config_get() {
    local key="$1"
    local scope="${2:-}"
    if [ "${scope}" = "local" ]; then
        git_capture config --local --get "${key}"
    elif [ "${scope}" = "global" ]; then
        git_capture config --global --get "${key}"
    else
        git_capture config --get "${key}"
    fi
}

git_cmd_config_set() {
    local key="$1"
    local value="$2"
    local scope="${3:-local}"
    if [ "${scope}" = "global" ]; then
        git_run_change config --global "${key}" "${value}"
    else
        git_run_change config --local "${key}" "${value}"
    fi
}

git_cmd_check_ref_format() {
    local branch="$1"
    git_run_readonly check-ref-format --branch "${branch}"
}

# Classify a failed remote Git operation. Print one category name.
# Categories: NETWORK TLS AUTHENTICATION PERMISSION REMOTE_NOT_FOUND
# NON_FAST_FORWARD DIVERGED UNKNOWN
# Uses exit status, message text, and optional relation hint. Does not guess.
# Usage: git_classify_remote_error STATUS MESSAGE [RELATION]
git_classify_remote_error() {
    local status="${1:-1}"
    local message="${2:-}"
    local relation="${3:-}"
    local lower

    lower="$(printf '%s' "${message}" | tr '[:upper:]' '[:lower:]')"

    # Strong relation evidence from prior state inspection.
    if [ "${relation}" = "DIVERGED" ]; then
        printf 'DIVERGED\n'
        return 0
    fi

    case "${lower}" in
        *"have diverged"*|*"diverged"*"merge"*|*"need to be merged"*)
            printf 'DIVERGED\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"non-fast-forward"*|*"fetch first"*|*"updates were rejected"*)
            printf 'NON_FAST_FORWARD\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"repository not found"*|*"repo not found"*)
            printf 'REMOTE_NOT_FOUND\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"write access"*|*"not allowed to push"*|*"protected branch"*|*"permission to"*"denied to push"*)
            printf 'PERMISSION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"authentication failed"*|*"invalid credentials"*|*"could not read username"*|*"terminal prompts disabled"*|*"http basic: access denied"*|*"401 unauthorized"*|*"auth failed"*)
            printf 'AUTHENTICATION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"permission denied (publickey)"*|*"permission denied"*|*"403 forbidden"*|*"access denied"*)
            printf 'AUTHENTICATION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"ssl certificate"*|*"tls"*|*"schannel"*|*"revocation"*|*"certificate verify failed"*|*"ssl error"*|*"curl: (35)"*|*"curl: (60)"*)
            printf 'TLS\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"could not resolve host"*|*"name or service not known"*|*"nodename nor servname"*|*"temporary failure in name resolution"*|*"network is unreachable"*|*"no route to host"*|*"connection timed out"*|*"could not connect"*|*"connection refused"*|*"failed to connect"*)
            printf 'NETWORK\n'
            return 0
            ;;
    esac

    # Weak evidence: stay UNKNOWN (FR-287).
    : "${status}"
    printf 'UNKNOWN\n'
    return 0
}

# Explain a classified remote failure. Uses GS_GIT_LAST_* and optional relation.
# Usage: git_explain_remote_failure OPERATION [RELATION]
git_explain_remote_failure() {
    local operation="$1"
    local relation="${2:-${GS_STATE_RELATION:-}}"
    local reason
    local next
    local code

    GS_GIT_REMOTE_ERROR_CLASS="$(git_classify_remote_error "${GS_GIT_LAST_STATUS:-1}" "${GS_GIT_LAST_STDOUT:-}" "${relation}")"

    case "${GS_GIT_REMOTE_ERROR_CLASS}" in
        NETWORK)
            reason="The remote host was not reachable."
            next="Check your network connection. Run this lesson again."
            code="${GS_CODE_NET_OFFLINE}"
            ;;
        TLS)
            reason="A TLS or certificate check failed while contacting the remote."
            next="Check the system clock and certificate store. See troubleshooting docs. Run this lesson again."
            code="${GS_CODE_NET_TLS}"
            ;;
        AUTHENTICATION)
            reason="The remote rejected authentication."
            next="Sign in with your Git credential helper. GitStart does not request a password or token."
            code="${GS_CODE_AUTH_REQUIRED}"
            ;;
        PERMISSION)
            reason="Your account does not have permission for this remote action."
            next="Confirm the repository URL and your access rights. Ask an instructor if needed."
            code="${GS_CODE_AUTH_PERMISSION}"
            ;;
        REMOTE_NOT_FOUND)
            reason="The remote repository was not found."
            next="Confirm the HTTPS remote URL. Create the empty remote if it is missing."
            code="${GS_CODE_GIT_REMOTE_NOT_FOUND}"
            ;;
        NON_FAST_FORWARD)
            reason="The remote has commits that your branch does not have."
            next="Use the update lesson or diagnose. Do not force-push."
            code="${GS_CODE_GIT_NON_FF}"
            ;;
        DIVERGED)
            reason="The local and remote branches have diverged."
            next="Use diagnosis. Ask an instructor before you merge. Do not force-push."
            code="${GS_CODE_SAFE_DIVERGED}"
            ;;
        *)
            GS_GIT_REMOTE_ERROR_CLASS="UNKNOWN"
            reason="The remote command failed for an unclear reason."
            next="Read the Git message above. Use Diagnose, then ask an instructor if needed."
            code="${GS_CODE_GIT_STATE}"
            ;;
    esac

    ui_fail_detail \
        "Remote step failed: ${operation}" \
        "${operation}" \
        "${reason}" \
        "${next}" \
        "${code}"
    ui_muted "Class: ${GS_GIT_REMOTE_ERROR_CLASS}"
}
