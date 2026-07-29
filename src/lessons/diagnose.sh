# Implements: FR-260 through FR-264.
# Collect local Git state for diagnosis without file contents or credentials.

lesson_diagnose_os_family() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin) printf 'macOS\n' ;;
        Linux) printf 'Linux\n' ;;
        MINGW*|MSYS*|CYGWIN*) printf 'Windows-GitBash\n' ;;
        *) printf 'unknown\n' ;;
    esac
}

lesson_diagnose() {
    local report
    local remote_line
    local sanitized

    lesson_begin "Diagnose a Git problem" 1 "${GS_LESSON_DIAGNOSE}"

    if ! picker_run; then
        # Diagnosis can still run in the current directory.
        ui_info "Using the current directory for diagnosis"
    fi

    git_state_inspect

    report=""
    report="${report}GitStart diagnosis report\n"
    report="${report}=========================\n"
    report="${report}Application: ${GS_APP_NAME} ${GS_APP_VERSION}\n"
    report="${report}OS family: $(lesson_diagnose_os_family)\n"
    report="${report}Bash: ${BASH_VERSION:-unknown}\n"
    if git_is_available; then
        report="${report}Git: $(git --version 2>/dev/null || echo unknown)\n"
    else
        report="${report}Git: not available\n"
    fi
    report="${report}Repository root: ${GS_STATE_ROOT:-none}\n"
    report="${report}Current branch: ${GS_STATE_BRANCH:-none}\n"
    report="${report}Has commit: ${GS_STATE_HAS_COMMIT}\n"
    report="${report}Working tree clean: ${GS_STATE_IS_CLEAN}\n"
    report="${report}Dirty entries: ${GS_STATE_DIRTY_COUNT}\n"
    report="${report}Remote count: ${GS_STATE_REMOTE_COUNT}\n"
    report="${report}Upstream: ${GS_STATE_UPSTREAM:-none}\n"
    report="${report}Ahead: ${GS_STATE_AHEAD}\n"
    report="${report}Behind: ${GS_STATE_BEHIND}\n"
    report="${report}Relation: ${GS_STATE_RELATION}\n"
    report="${report}State class: ${GS_STATE_CLASS}\n"
    report="${report}Last Git status: ${GS_GIT_LAST_STATUS:-n/a}\n"
    report="${report}Remotes (sanitized):\n"

    if git_capture remote -v; then
        if [ -n "${GS_GIT_LAST_STDOUT}" ]; then
            while IFS= read -r remote_line; do
                [ -n "${remote_line}" ] || continue
                sanitized="$(git_sanitize_remote_url "${remote_line}")"
                report="${report}  ${sanitized}\n"
            done <<EOF
${GS_GIT_LAST_STDOUT}
EOF
        else
            report="${report}  none\n"
        fi
    else
        report="${report}  unavailable\n"
    fi

    ui_blank
    ui_title "Diagnosis report"
    printf '%b\n' "${report}"
    ui_blank
    ui_info "This report does not include file contents"
    ui_info "Remote URLs are sanitized"
    ui_info "GitStart does not send this report automatically"
    ui_next "Copy the report text if you need instructor help"
    lesson_complete
    return 0
}
