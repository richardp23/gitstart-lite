# Read-only Git state inspection and classification.
# Implements: FR-120 through FR-130, SRS §11.

GS_STATE_IS_REPO=0
GS_STATE_ROOT=""
GS_STATE_BRANCH=""
GS_STATE_HAS_COMMIT=0
GS_STATE_IS_CLEAN=1
GS_STATE_REMOTE_COUNT=0
GS_STATE_HAS_ORIGIN=0
GS_STATE_HAS_UPSTREAM_REMOTE=0
GS_STATE_UPSTREAM=""
GS_STATE_AHEAD=0
GS_STATE_BEHIND=0
GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
GS_STATE_RELATION="UNKNOWN"
GS_STATE_DIRTY_COUNT=0

# Reset all state variables before inspection.
git_state_reset() {
    GS_STATE_IS_REPO=0
    GS_STATE_ROOT=""
    GS_STATE_BRANCH=""
    GS_STATE_HAS_COMMIT=0
    GS_STATE_IS_CLEAN=1
    GS_STATE_REMOTE_COUNT=0
    GS_STATE_HAS_ORIGIN=0
    GS_STATE_HAS_UPSTREAM_REMOTE=0
    GS_STATE_UPSTREAM=""
    GS_STATE_AHEAD=0
    GS_STATE_BEHIND=0
    GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
    GS_STATE_RELATION="UNKNOWN"
    GS_STATE_DIRTY_COUNT=0
}

# Inspect the current directory. Store results in GS_STATE_* variables.
git_state_inspect() {
    local out
    local remotes
    local counts
    local ahead
    local behind
    local porcelain

    git_state_reset

    if ! git_is_available; then
        GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
        return 1
    fi

    if ! git_capture rev-parse --is-inside-work-tree; then
        GS_STATE_CLASS="NOT_A_REPOSITORY"
        return 0
    fi
    if [ "${GS_GIT_LAST_STDOUT}" != "true" ]; then
        GS_STATE_CLASS="NOT_A_REPOSITORY"
        return 0
    fi

    GS_STATE_IS_REPO=1

    if git_capture rev-parse --show-toplevel; then
        GS_STATE_ROOT="${GS_GIT_LAST_STDOUT}"
    fi

    # Prefer branch --show-current. Fall back to rev-parse.
    if git_capture branch --show-current; then
        GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
    elif git_capture rev-parse --abbrev-ref HEAD; then
        if [ "${GS_GIT_LAST_STDOUT}" != "HEAD" ]; then
            GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
        fi
    fi

    if git_capture rev-parse --verify HEAD; then
        GS_STATE_HAS_COMMIT=1
    else
        GS_STATE_HAS_COMMIT=0
        GS_STATE_CLASS="REPOSITORY_NO_COMMIT"
    fi

    if git_capture status --porcelain=v1; then
        porcelain="${GS_GIT_LAST_STDOUT}"
        if [ -n "${porcelain}" ]; then
            GS_STATE_IS_CLEAN=0
            GS_STATE_DIRTY_COUNT="$(printf '%s\n' "${porcelain}" | grep -c '.' || true)"
        else
            GS_STATE_IS_CLEAN=1
            GS_STATE_DIRTY_COUNT=0
        fi
    fi

    remotes=""
    if git_capture remote; then
        remotes="${GS_GIT_LAST_STDOUT}"
    fi
    if [ -n "${remotes}" ]; then
        GS_STATE_REMOTE_COUNT="$(printf '%s\n' "${remotes}" | grep -c '.' || true)"
        printf '%s\n' "${remotes}" | grep -qx 'origin' && GS_STATE_HAS_ORIGIN=1 || true
        printf '%s\n' "${remotes}" | grep -qx 'upstream' && GS_STATE_HAS_UPSTREAM_REMOTE=1 || true
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "1" ] && [ "${GS_STATE_REMOTE_COUNT}" = "0" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_REMOTE"
    fi

    GS_STATE_UPSTREAM=""
    if [ "${GS_STATE_HAS_COMMIT}" = "1" ]; then
        if git_capture rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'; then
            GS_STATE_UPSTREAM="${GS_GIT_LAST_STDOUT}"
        fi
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "1" ] && [ "${GS_STATE_REMOTE_COUNT}" -gt 0 ] && [ -z "${GS_STATE_UPSTREAM}" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_UPSTREAM"
        GS_STATE_RELATION="UNTRACKED"
    fi

    GS_STATE_AHEAD=0
    GS_STATE_BEHIND=0
    if [ -n "${GS_STATE_UPSTREAM}" ]; then
        if git_capture rev-list --left-right --count 'HEAD...@{upstream}'; then
            counts="${GS_GIT_LAST_STDOUT}"
            ahead="$(printf '%s' "${counts}" | awk '{print $1}')"
            behind="$(printf '%s' "${counts}" | awk '{print $2}')"
            GS_STATE_AHEAD="${ahead:-0}"
            GS_STATE_BEHIND="${behind:-0}"
            if [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null && [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="DIVERGED"
                GS_STATE_CLASS="BRANCH_DIVERGED"
            elif [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="AHEAD"
                GS_STATE_CLASS="BRANCH_AHEAD"
            elif [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="BEHIND"
                GS_STATE_CLASS="BRANCH_BEHIND"
            else
                GS_STATE_RELATION="EQUAL"
                GS_STATE_CLASS="BRANCH_EQUAL"
            fi
        else
            GS_STATE_RELATION="UNKNOWN"
        fi
    fi

    if [ "${GS_STATE_IS_CLEAN}" = "0" ]; then
        # Changed worktree is a primary class when not already a hard stop class.
        case "${GS_STATE_CLASS}" in
            BRANCH_DIVERGED|UNKNOWN_OR_UNSAFE) ;;
            *)
                GS_STATE_CLASS="WORKTREE_CHANGED"
                ;;
        esac
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "0" ] && [ "${GS_STATE_IS_REPO}" = "1" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_COMMIT"
    fi

    return 0
}

# Print a short human-readable summary of the current state.
git_state_summary() {
    ui_info "Repository root: ${GS_STATE_ROOT:-none}"
    ui_info "Current branch: ${GS_STATE_BRANCH:-none}"
    if [ "${GS_STATE_IS_CLEAN}" = "1" ]; then
        ui_info "Working tree: clean"
    else
        ui_info "Working tree: changed (${GS_STATE_DIRTY_COUNT} entries)"
    fi
    ui_info "Remotes: ${GS_STATE_REMOTE_COUNT}"
    ui_info "Upstream: ${GS_STATE_UPSTREAM:-none}"
    ui_info "Relation: ${GS_STATE_RELATION}"
    ui_info "State class: ${GS_STATE_CLASS}"
}

# Return 0 when a nested repository risk exists (selected dir inside parent repo root).
git_state_is_nested() {
    local selected="$1"
    local root
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        return 1
    fi
    root="${GS_STATE_ROOT}"
    if [ -z "${root}" ]; then
        return 1
    fi
    # Compare resolved paths as strings. Nested when selected is under root but not root.
    case "${selected}" in
        "${root}")
            return 1
            ;;
        "${root}"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
