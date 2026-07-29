# Implements: FR-240 through FR-248.
# Teach origin versus upstream for a fork workflow.

GS_LESSON_FORK_UPSTREAM_URL=""
GS_LESSON_FORK_BRANCH=""

lesson_fork_run_remote_v() {
    git_cmd_remote_verbose
}

lesson_fork_run_add_upstream() {
    git_cmd_remote_add "upstream" "${GS_LESSON_FORK_UPSTREAM_URL}"
}

lesson_fork_run_fetch_upstream() {
    git_cmd_fetch "upstream"
}

lesson_fork_run_ff() {
    git_cmd_merge_ff_only "upstream/${GS_LESSON_FORK_BRANCH}"
}

lesson_fork_run_push_origin() {
    git_cmd_push "origin" "${GS_STATE_BRANCH}"
}

lesson_sync_fork() {
    lesson_begin "Synchronize a fork" 6

    if ! picker_run; then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        lesson_stop_safe \
            "This directory is not a Git repository." \
            "No working tree was detected." \
            "Select your fork clone and try again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if [ -n "${GS_STATE_ROOT}" ]; then
        cd -- "${GS_STATE_ROOT}" || return 1
        git_state_inspect
    fi

    lesson_step_begin "Explain origin and upstream"
    ui_info "origin is your fork on the hosting service"
    ui_info "upstream is the original repository that you forked"
    ui_info "You fetch from upstream. You push to origin"

    if ! lesson_teach_exact_command \
        "git remote -v" \
        lesson_fork_run_remote_v \
        "List remotes to see which URLs are configured." \
        "You see remote names and sanitized URLs"
    then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_HAS_ORIGIN}" != "1" ]; then
        lesson_stop_safe \
            "No origin remote is configured." \
            "A fork workflow needs origin for your fork." \
            "Add origin first. Then run this lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if [ "${GS_STATE_HAS_UPSTREAM_REMOTE}" != "1" ]; then
        lesson_step_begin "Add the upstream remote"
        while true; do
            input_text "Enter the original repository HTTPS URL: " || return 1
            GS_LESSON_FORK_UPSTREAM_URL="$(input_trim "${GS_INPUT_LAST}")"
            if git_validate_https_url "${GS_LESSON_FORK_UPSTREAM_URL}"; then
                break
            fi
            ui_warning "Enter an HTTPS Git URL without embedded credentials"
        done
        if ! lesson_teach_exact_command \
            "git remote add upstream $(printf '%q' "${GS_LESSON_FORK_UPSTREAM_URL}")" \
            lesson_fork_run_add_upstream \
            "upstream points to the original project repository." \
            "Git stores the upstream remote URL"
        then
            return 1
        fi
    else
        ui_success "An upstream remote already exists"
    fi

    if [ "${GS_STATE_IS_CLEAN}" = "0" ]; then
        lesson_stop_safe \
            "The working tree has local changes." \
            "A fast-forward update needs a clean working tree." \
            "Commit or review your changes. Then run this lesson again." \
            "${GS_CODE_SAFE_STOP}"
        return 1
    fi

    lesson_step_begin "Fetch from upstream"
    if ! lesson_teach_exact_command \
        "git fetch upstream" \
        lesson_fork_run_fetch_upstream \
        "Fetch downloads commits from the original repository." \
        "upstream remote-tracking branches are updated"
    then
        lesson_explain_offline "git fetch upstream"
        return 1
    fi

    lesson_step_begin "Confirm the default branch"
    GS_LESSON_FORK_BRANCH="${GS_STATE_BRANCH:-main}"
    ui_info "Current local branch: ${GS_STATE_BRANCH:-unknown}"
    input_text "Upstream branch to merge (default ${GS_LESSON_FORK_BRANCH}): " 1 || return 1
    if [ -n "$(input_trim "${GS_INPUT_LAST}")" ]; then
        GS_LESSON_FORK_BRANCH="$(input_trim "${GS_INPUT_LAST}")"
    fi
    if ! git_cmd_check_ref_format "${GS_LESSON_FORK_BRANCH}"; then
        lesson_stop_safe \
            "The branch name is not valid." \
            "Git rejected the branch name format." \
            "Enter a valid branch name and try again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    lesson_step_begin "Fast-forward the local branch from upstream"
    if ! lesson_teach_exact_command \
        "git merge --ff-only upstream/${GS_LESSON_FORK_BRANCH}" \
        lesson_fork_run_ff \
        "A fast-forward-only merge keeps history linear when possible." \
        "Your local branch includes upstream commits"
    then
        lesson_stop_safe \
            "The local branch and upstream branch diverged or the merge failed." \
            "A fast-forward-only update was not possible." \
            "Stop here. Ask an instructor before any conflict work." \
            "${GS_CODE_SAFE_DIVERGED}"
        return 1
    fi

    lesson_step_begin "Push the updated branch to origin"
    if ! lesson_teach_exact_command \
        "git push origin ${GS_STATE_BRANCH}" \
        lesson_fork_run_push_origin \
        "Push updates your fork after a successful upstream sync." \
        "origin has the updated branch"
    then
        lesson_explain_offline "git push"
        ui_info "Your local fast-forward update is preserved"
        return 1
    fi

    git_state_inspect
    lesson_verify_state
    lesson_complete
    return 0
}
