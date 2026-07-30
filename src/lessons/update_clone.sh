# Implements: FR-220 through FR-227.
# Teach a fast-forward-only update of an existing clone.

lesson_update_run_fetch() {
    git_cmd_fetch
}

lesson_update_run_ff() {
    git_cmd_pull_ff_only
}

lesson_update_clone() {
    lesson_begin "Update an existing clone" 4 "${GS_LESSON_UPDATE}"

    if ! picker_run; then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        lesson_stop_safe \
            "This directory is not a Git repository." \
            "No working tree was detected." \
            "Select a clone directory and try again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if [ -n "${GS_STATE_ROOT}" ] && [ "$(pwd)" != "${GS_STATE_ROOT}" ]; then
        cd -- "${GS_STATE_ROOT}" || return 1
        git_state_inspect
    fi

    lesson_step_begin "Require a clean working tree"
    ui_info "A clean working tree means you have no unsaved local edits."
    ui_muted "Update is safer when Git can move your branch forward without mixing in local edits."
    git_state_summary
    if [ "${GS_STATE_IS_CLEAN}" = "0" ]; then
        ui_warning "The working tree has local changes"
        ui_print "Safe choices:"
        ui_print "  1) Commit the changes first"
        ui_print "  2) Stop and review the changes"
        ui_print "  3) Stash is not available in this version"
        input_choice 2 "Select 1 or 2: " || return 1
        case "${GS_INPUT_LAST}" in
            1)
                ui_next "Run the commit and push lesson. Then return to update"
                return 1
                ;;
            2)
                ui_next "Review your changes. Keep your work. Run update when the tree is clean"
                return 1
                ;;
        esac
    fi

    if [ -z "${GS_STATE_UPSTREAM}" ]; then
        lesson_stop_safe \
            "No upstream tracking branch is set." \
            "A fast-forward update needs an upstream branch." \
            "Set upstream with a push -u lesson, or ask an instructor." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    lesson_step_begin "Fetch remote updates"
    ui_info "Fetch downloads new commits from the remote without changing your files."
    if ! lesson_teach_exact_command \
        "git fetch" \
        lesson_update_run_fetch \
        "Download remote commits so you can compare your branch with the remote." \
        "Remote tracking branches are updated."
    then
        lesson_explain_remote_failure "git fetch"
        return 1
    fi

    git_state_inspect
    ui_info "Local branch relation to upstream: ${GS_STATE_RELATION}"
    ui_info "Ahead: ${GS_STATE_AHEAD}  Behind: ${GS_STATE_BEHIND}"
    ui_muted "Ahead means you have local commits not on the remote."
    ui_muted "Behind means the remote has commits you do not have yet."

    case "${GS_STATE_RELATION}" in
        EQUAL)
            ui_success "The branch is already up to date"
            lesson_complete
            return 0
            ;;
        AHEAD)
            ui_info "The local branch has commits that are not on the remote"
            ui_next "Use the commit and push lesson if you need to publish them"
            lesson_complete
            return 0
            ;;
        DIVERGED)
            lesson_stop_safe \
                "A fast-forward update is not possible." \
                "Local and remote histories diverged." \
                "Stop here. Ask an instructor before any merge work." \
                "${GS_CODE_SAFE_DIVERGED}"
            return 1
            ;;
        BEHIND)
            ;;
        *)
            lesson_stop_safe \
                "The branch relation is unknown." \
                "Git could not classify ahead and behind counts." \
                "Use diagnosis. Ask an instructor if needed." \
                "${GS_CODE_GIT_STATE}"
            return 1
            ;;
    esac

    lesson_step_begin "Apply a fast-forward-only update"
    ui_info "Fast-forward means: move your branch pointer forward to match the remote."
    ui_muted "GitStart uses --ff-only so it will stop instead of creating a merge conflict."
    if ! lesson_teach_exact_command \
        "git pull --ff-only" \
        lesson_update_run_ff \
        "Update your local branch only when the remote is a straight continuation of your history." \
        "Your local branch matches the upstream branch."
    then
        lesson_explain_remote_failure "git pull --ff-only"
        return 1
    fi

    git_state_inspect
    ui_success "Update complete"
    if git_capture log --oneline -n 5; then
        ui_info "Recent commits:"
        ui_print "${GS_GIT_LAST_STDOUT}"
    fi
    lesson_verify_state
    lesson_complete
    return 0
}
