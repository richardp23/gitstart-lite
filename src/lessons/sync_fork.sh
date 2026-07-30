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
    lesson_begin "Synchronize a fork" 6 "${GS_LESSON_FORK}"

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
    ui_info "A fork is your copy of someone else's project on a hosting service."
    ui_info "origin is your fork. You push to origin."
    ui_info "upstream is the original project. You fetch from upstream."
    ui_muted "This lesson updates your local branch from upstream, then pushes to your fork."

    if ! lesson_teach_exact_command \
        "git remote -v" \
        lesson_fork_run_remote_v \
        "List remotes so you can see which URLs are configured." \
        "You see remote names and sanitized URLs."
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
        ui_info "You need the HTTPS URL of the original repository you forked."
        ui_muted "Example: https://github.com/ORIGINAL_OWNER/PROJECT.git"
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
            "Save the original project URL under the name upstream." \
            "Git stores the upstream remote URL."
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
    ui_info "Fetch downloads commits from the original project without changing your files."
    if ! lesson_teach_exact_command \
        "git fetch upstream" \
        lesson_fork_run_fetch_upstream \
        "Download new commits from the original repository." \
        "upstream remote-tracking branches are updated."
    then
        lesson_explain_remote_failure "git fetch upstream"
        return 1
    fi

    lesson_step_begin "Confirm the default branch"
    GS_LESSON_FORK_BRANCH="${GS_STATE_BRANCH:-main}"
    ui_info "Choose which upstream branch to fast-forward into your local branch."
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
    ui_info "Fast-forward means: move your branch forward when history is a straight line."
    ui_muted "GitStart uses --ff-only so it stops instead of creating a merge conflict."
    if ! lesson_teach_exact_command \
        "git merge --ff-only upstream/${GS_LESSON_FORK_BRANCH}" \
        lesson_fork_run_ff \
        "Update your local branch from upstream only when no divergence exists." \
        "Your local branch includes upstream commits."
    then
        lesson_stop_safe \
            "The local branch and upstream branch diverged or the merge failed." \
            "A fast-forward-only update was not possible." \
            "Stop here. Ask an instructor before any conflict work." \
            "${GS_CODE_SAFE_DIVERGED}"
        return 1
    fi

    lesson_step_begin "Push the updated branch to origin"
    ui_info "Now publish the updated local branch to your fork on origin."
    if ! lesson_teach_exact_command \
        "git push origin ${GS_STATE_BRANCH}" \
        lesson_fork_run_push_origin \
        "Update your fork after a successful upstream sync." \
        "origin has the updated branch."
    then
        lesson_explain_remote_failure "git push"
        return 1
    fi

    git_state_inspect
    lesson_verify_state
    lesson_complete
    return 0
}
