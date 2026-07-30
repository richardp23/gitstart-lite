# Implements: FR-200 through FR-211.
# Teach commit and push in an existing repository.

GS_LESSON_CP_COMMIT_MSG=""

lesson_commit_push_run_status() {
    git_cmd_status
}

lesson_commit_push_run_add() {
    git_cmd_add_all
}

lesson_commit_push_run_commit() {
    git_cmd_commit_message "${GS_LESSON_CP_COMMIT_MSG}"
}

lesson_commit_push_run_fetch() {
    git_cmd_fetch
}

lesson_commit_push_run_push() {
    local remote="origin"
    local branch="${GS_STATE_BRANCH}"
    git_cmd_push "${remote}" "${branch}"
}

lesson_commit_push() {
    local commit_display

    lesson_begin "Save and push changes" 6 "${GS_LESSON_COMMIT_PUSH}"

    if ! picker_run; then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        lesson_stop_safe \
            "This directory is not a Git repository." \
            "No working tree was detected." \
            "Use the new repository lesson, or select a repository directory." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if [ -n "${GS_STATE_ROOT}" ] && [ "$(pwd)" != "${GS_STATE_ROOT}" ]; then
        ui_info "Repository root: ${GS_STATE_ROOT}"
        if input_confirm "Move to the repository root?"; then
            cd -- "${GS_STATE_ROOT}" || return 1
            git_state_inspect
        fi
    fi

    lesson_step_begin "Show the current branch and status"
    ui_info "First look at the current branch and whether files changed."
    ui_info "Current branch: ${GS_STATE_BRANCH:-unknown}"
    git_state_summary
    if ! lesson_teach_exact_command \
        "git status" \
        lesson_commit_push_run_status \
        "Ask Git whether this folder has changes to save." \
        "You see staged changes, unstaged changes, or a clean tree."
    then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_IS_CLEAN}" = "1" ] && [ "${GS_STATE_RELATION}" != "AHEAD" ]; then
        ui_success "The working tree is clean"
        if [ "${GS_STATE_RELATION}" = "EQUAL" ]; then
            ui_info "The branch matches its upstream. No push is required"
            lesson_complete
            return 0
        fi
    fi

    if [ "${GS_STATE_IS_CLEAN}" = "0" ]; then
        lesson_step_begin "Protect secrets before staging"
        ui_info "Before git add, decide what Git should ignore."
        safety_review_directory "$(pwd)" || true
        if ! safety_ensure_gitignore_review "$(pwd)"; then
            return 1
        fi

        lesson_step_begin "Stage changes"
        ui_info "Staging means: choose which changes go into the next commit."
        ui_muted "git add . stages the files in this folder. Names listed in .gitignore stay out."
        if ! lesson_teach_exact_command \
            "git add ." \
            lesson_commit_push_run_add \
            "Prepare your edited files for a commit. Skip names listed in .gitignore." \
            "Changed files are staged."
        then
            return 1
        fi

        lesson_step_begin "Commit changes"
        ui_info "A commit is a saved snapshot. Write a short message that describes the change."
        ui_muted "Keep the first line short. ${GS_LIMIT_COMMIT_MSG} characters or fewer."
        while true; do
            input_text "Enter a commit message: " || return 1
            GS_LESSON_CP_COMMIT_MSG="$(input_trim "${GS_INPUT_LAST}")"
            if [ "${#GS_LESSON_CP_COMMIT_MSG}" -gt "${GS_LIMIT_COMMIT_MSG}" ]; then
                ui_warning "Use ${GS_LIMIT_COMMIT_MSG} characters or fewer for the first line"
                continue
            fi
            if [ -z "${GS_LESSON_CP_COMMIT_MSG}" ]; then
                ui_warning "The commit message cannot be empty."
                continue
            fi
            break
        done
        commit_display="$(lesson_format_commit_command "${GS_LESSON_CP_COMMIT_MSG}")"
        if ! lesson_teach_exact_command \
            "${commit_display}" \
            lesson_commit_push_run_commit \
            "Save your staged changes into Git history." \
            "A new commit exists on the current branch." \
            lesson_match_commit_command
        then
            return 1
        fi
        git_state_inspect
    fi

    lesson_step_begin "Fetch remote information"
    ui_info "Fetch downloads remote updates without changing your local files."
    ui_muted "This helps you check if the remote moved ahead before you push."
    if [ "${GS_STATE_HAS_ORIGIN}" != "1" ]; then
        lesson_stop_safe \
            "No origin remote is configured." \
            "A push needs a remote named origin in this lesson." \
            "Add an origin remote first. Use the new repository lesson or diagnosis." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if ! lesson_teach_exact_command \
        "git fetch" \
        lesson_commit_push_run_fetch \
        "Update remote tracking data so you know if the remote has new commits." \
        "Remote branch information is current."
    then
        lesson_explain_remote_failure "git fetch"
        return 1
    fi

    git_state_inspect
    case "${GS_STATE_RELATION}" in
        DIVERGED)
            lesson_stop_safe \
                "Local and remote histories diverged." \
                "The branch is ahead and behind its upstream." \
                "Stop here. Ask an instructor before you merge or rebase." \
                "${GS_CODE_SAFE_DIVERGED}"
            return 1
            ;;
        BEHIND)
            ui_warning "The local branch is behind the remote branch"
            ui_info "Someone else pushed commits you do not have yet."
            ui_next "Use the update lesson to apply a fast-forward update first"
            return 1
            ;;
        AHEAD|EQUAL)
            ;;
        UNTRACKED)
            ui_warning "No upstream tracking branch is set"
            ui_info "Upstream tracking tells git push which remote branch to update."
            if input_confirm "Push and set upstream to origin/${GS_STATE_BRANCH}?"; then
                if ! lesson_teach_exact_command \
                    "git push -u origin ${GS_STATE_BRANCH}" \
                    lesson_commit_push_run_push_u \
                    "Publish your commits and remember origin as the upstream for this branch." \
                    "The remote branch tracks your local branch."
                then
                    lesson_explain_remote_failure "git push"
                    return 1
                fi
                git_state_inspect
                lesson_complete
                return 0
            fi
            return 1
            ;;
        *)
            ui_warning "The branch relation is unknown"
            ui_next "Use diagnosis. Ask an instructor if the state is unclear"
            return 1
            ;;
    esac

    if [ "${GS_STATE_RELATION}" = "EQUAL" ]; then
        ui_success "The branch already matches its upstream"
        lesson_complete
        return 0
    fi

    lesson_step_begin "Push local commits"
    ui_info "Push sends your local commits to the remote named origin."
    if ! lesson_teach_exact_command \
        "git push" \
        lesson_commit_push_run_push \
        "Send local commits that are ahead of the upstream branch." \
        "The remote branch includes your commits."
    then
        lesson_explain_remote_failure "git push"
        return 1
    fi

    git_state_inspect
    lesson_verify_state
    lesson_complete
    return 0
}

lesson_commit_push_run_push_u() {
    git_cmd_push_upstream "origin" "${GS_STATE_BRANCH}"
}
