# Sole Git execution layer. Never eval student text.
# Implements: FR-105 through FR-108, FR-280 through FR-282, FR-300 through FR-309.

GS_GIT_LAST_STATUS=0
GS_GIT_LAST_STDOUT=""

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
