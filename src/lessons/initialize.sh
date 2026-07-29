# Implements: FR-160 through FR-184.
# Teach a student how to publish an existing directory as a new repository.

GS_LESSON_INIT_COMMIT_MSG=""
GS_LESSON_INIT_REMOTE_URL=""

lesson_initialize_set_identity() {
    local name
    local email
    local scope

    # Quiet preflight. Speak only when author data is missing.
    git_state_inspect

    name=""
    email=""
    if git_cmd_config_get "user.name"; then
        name="${GS_GIT_LAST_STDOUT}"
    fi
    if git_cmd_config_get "user.email"; then
        email="${GS_GIT_LAST_STDOUT}"
    fi

    if [ -n "${name}" ] && [ -n "${email}" ]; then
        return 0
    fi

    ui_warning "Git needs your name and email before a commit."
    if [ -z "${name}" ]; then
        input_text "Your Git author name: " || return 1
        name="$(input_trim "${GS_INPUT_LAST}")"
    fi
    if [ -z "${email}" ]; then
        input_text "Your Git author email: " || return 1
        email="$(input_trim "${GS_INPUT_LAST}")"
    fi

    scope="local"
    ui_muted "Local config affects only this project."
    if input_confirm "Save in this project's Git config?"; then
        scope="local"
    else
        ui_warning "Global config changes your default identity on this machine."
        if ! input_confirm "Save in global Git config instead?"; then
            lesson_stop_safe \
                "Git identity is required before a commit." \
                "No author name or email is configured." \
                "Set user.name and user.email. Run this lesson again." \
                "${GS_CODE_GIT_IDENTITY}"
            return 1
        fi
        scope="global"
    fi

    if [ "${scope}" = "local" ] && [ "${GS_STATE_IS_REPO}" != "1" ]; then
        GS_LESSON_PENDING_NAME="${name}"
        GS_LESSON_PENDING_EMAIL="${email}"
        GS_LESSON_PENDING_SCOPE="local"
        ui_muted "Author will be saved after git init."
        return 0
    fi

    git_cmd_config_set "user.name" "${name}" "${scope}" || return 1
    git_cmd_config_set "user.email" "${email}" "${scope}" || return 1
    ui_success "Git author saved."
    return 0
}

GS_LESSON_PENDING_NAME=""
GS_LESSON_PENDING_EMAIL=""
GS_LESSON_PENDING_SCOPE=""

lesson_initialize_apply_pending_identity() {
    if [ -n "${GS_LESSON_PENDING_NAME}" ]; then
        git_cmd_config_set "user.name" "${GS_LESSON_PENDING_NAME}" "local" || return 1
        git_cmd_config_set "user.email" "${GS_LESSON_PENDING_EMAIL}" "local" || return 1
        GS_LESSON_PENDING_NAME=""
        GS_LESSON_PENDING_EMAIL=""
        ui_success "Local Git author configuration was saved"
    fi
    return 0
}

lesson_initialize_run_pwd() {
    pwd
}

lesson_initialize_run_ls() {
    if command -v ls >/dev/null 2>&1; then
        ls
    else
        printf '%s\n' *
    fi
}

lesson_initialize_run_init() {
    git_cmd_init
}

lesson_initialize_run_branch_main() {
    git_cmd_branch_rename_main
}

lesson_initialize_run_status() {
    git_cmd_status
}

lesson_initialize_run_add() {
    git_cmd_add_all
}

lesson_initialize_run_commit() {
    git_cmd_commit_message "${GS_LESSON_INIT_COMMIT_MSG}"
}

lesson_initialize_run_remote_add() {
    git_cmd_remote_add "origin" "${GS_LESSON_INIT_REMOTE_URL}"
}

lesson_initialize_run_remote_v() {
    git_cmd_remote_verbose
}

lesson_initialize_run_push() {
    local branch
    branch="${GS_STATE_BRANCH:-main}"
    git_cmd_push_upstream "origin" "${branch}"
}

lesson_initialize_repository() {
    local list_cmd
    local commit_display

    lesson_begin "Publish a directory as a new repository" 11

    GS_LESSON_PENDING_NAME=""
    GS_LESSON_PENDING_EMAIL=""
    if ! lesson_initialize_set_identity; then
        return 1
    fi

    if ! picker_run; then
        return 1
    fi

    lesson_step_begin "Confirm the working directory"
    if ! lesson_teach_exact_command \
        "pwd" \
        lesson_initialize_run_pwd \
        "pwd prints the folder you are in." \
        "You see the full path."
    then
        return 1
    fi

    lesson_step_begin "List files"
    list_cmd="ls"
    if ! command -v ls >/dev/null 2>&1; then
        list_cmd="printf '%s\n' *"
    fi
    if ! lesson_teach_exact_command \
        "${list_cmd}" \
        lesson_initialize_run_ls \
        "List files before Git tracks them." \
        "You see names in this folder."
    then
        return 1
    fi

    lesson_step_begin "Review before staging"
    safety_review_directory "$(pwd)" || true
    if ! safety_ensure_gitignore_review "$(pwd)"; then
        return 1
    fi

    git_state_inspect
    if [ "${GS_STATE_IS_REPO}" = "1" ]; then
        lesson_stop_safe \
            "This directory is already a Git repository." \
            "A .git directory or parent repository was detected." \
            "Use the commit and push lesson, or select a different directory." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    if git_state_is_nested "$(pwd)"; then
        ui_warning "This directory may be inside another Git repository"
        if ! input_confirm "Continue anyway?"; then
            return 1
        fi
    fi

    lesson_step_begin "Initialize the repository"
    if ! lesson_teach_exact_command \
        "git init" \
        lesson_initialize_run_init \
        "git init starts a new local repository here." \
        "Git creates a .git folder."
    then
        return 1
    fi
    git_state_inspect
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        lesson_stop_safe \
            "Repository initialization failed." \
            "Git did not report a working tree after git init." \
            "Check directory permissions. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    lesson_initialize_apply_pending_identity || return 1

    lesson_step_begin "Name the branch main"
    if ! lesson_teach_exact_command \
        "git branch -M main" \
        lesson_initialize_run_branch_main \
        "Classroom remotes often use the branch name main." \
        "The branch is named main."
    then
        return 1
    fi

    lesson_step_begin "Check status"
    if ! lesson_teach_exact_command \
        "git status" \
        lesson_initialize_run_status \
        "git status shows what Git sees right now." \
        "You see untracked or staged files."
    then
        return 1
    fi

    lesson_step_begin "Stage files"
    if ! lesson_teach_exact_command \
        "git add ." \
        lesson_initialize_run_add \
        "git add . stages files for the next commit (respects .gitignore)." \
        "Files are ready to commit."
    then
        return 1
    fi
    git_state_inspect
    ui_muted "Staged paths: ${GS_STATE_DIRTY_COUNT}"

    lesson_step_begin "Create the first commit"
    while true; do
        input_text "Commit message: " || return 1
        GS_LESSON_INIT_COMMIT_MSG="$(input_trim "${GS_INPUT_LAST}")"
        if [ "${#GS_LESSON_INIT_COMMIT_MSG}" -gt "${GS_LIMIT_COMMIT_MSG}" ]; then
            ui_warning "Use ${GS_LIMIT_COMMIT_MSG} characters or fewer."
            continue
        fi
        break
    done
    commit_display="$(lesson_format_commit_command "${GS_LESSON_INIT_COMMIT_MSG}")"
    if ! lesson_teach_exact_command \
        "${commit_display}" \
        lesson_initialize_run_commit \
        "A commit saves a snapshot of the staged files." \
        "Git stores the commit." \
        lesson_match_commit_command
    then
        return 1
    fi
    git_state_inspect
    if [ "${GS_STATE_HAS_COMMIT}" != "1" ]; then
        lesson_stop_safe \
            "The commit was not created." \
            "HEAD does not identify a commit." \
            "Check the commit message and staged files. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi
    ui_success "Local commit is complete."

    lesson_step_begin "Add the origin remote"
    ui_info "Next you connect this folder to a remote repository on a hosting service."
    ui_info "The remote URL is the HTTPS address of that empty repository."
    ui_muted "Many services host Git. GitHub is one common example."
    ui_muted "On GitHub: New repository → create it empty (skip README if this folder already has files)."
    ui_muted "Then open the repo → Code → HTTPS → copy the URL."
    ui_muted "Example: https://github.com/ACCOUNT/PROJECT.git"
    while true; do
        input_text "Paste the HTTPS remote URL: " || return 1
        GS_LESSON_INIT_REMOTE_URL="$(input_trim "${GS_INPUT_LAST}")"
        if git_validate_https_url "${GS_LESSON_INIT_REMOTE_URL}"; then
            break
        fi
        ui_warning "Enter an HTTPS Git URL without embedded credentials"
        ui_info "Example: https://github.com/ACCOUNT/PROJECT.git"
    done

    git_state_inspect
    if [ "${GS_STATE_HAS_ORIGIN}" = "1" ]; then
        lesson_stop_safe \
            "An origin remote already exists." \
            "Replacing a remote is not allowed in this lesson." \
            "Use diagnosis to inspect remotes. Ask an instructor for help." \
            "${GS_CODE_SAFE_STOP}"
        return 1
    fi

    if ! lesson_teach_exact_command \
        "git remote add origin $(printf '%q' "${GS_LESSON_INIT_REMOTE_URL}")" \
        lesson_initialize_run_remote_add \
        "A remote named origin points to your hosting service repository." \
        "Git stores the remote URL under the name origin"
    then
        return 1
    fi

    lesson_step_begin "Verify remotes"
    if ! lesson_teach_exact_command \
        "git remote -v" \
        lesson_initialize_run_remote_v \
        "git remote -v lists remote names and sanitized fetch and push URLs." \
        "You see origin configured for fetch and push"
    then
        return 1
    fi

    lesson_step_begin "Push the branch and set upstream"
    ui_info "Push needs a network connection and authentication through your Git credential helper"
    ui_info "GitStart does not request a password or token"
    if ! lesson_teach_exact_command \
        "git push -u origin ${GS_STATE_BRANCH:-main}" \
        lesson_initialize_run_push \
        "The first push publishes your branch and sets upstream tracking." \
        "The remote branch exists and your local branch tracks it"
    then
        lesson_explain_offline "git push"
        ui_info "Your local commit remains safe"
        return 1
    fi

    git_state_inspect
    lesson_verify_state
    lesson_complete
    return 0
}
