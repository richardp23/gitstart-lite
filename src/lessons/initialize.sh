# Implements: FR-160 through FR-184, FR-087–FR-089, FR-114–FR-118, FR-130, FR-171, FR-181.
# Teach a student how to publish an existing directory as a new repository.
# Conditional cd teaching: D-019.

GS_LESSON_INIT_COMMIT_MSG=""
GS_LESSON_INIT_REMOTE_URL=""

# Check and set Git author identity in the current repository.
# Call after git init so local config applies to the selected project.
lesson_initialize_set_identity() {
    local name
    local email
    local scope

    name=""
    email=""
    # Effective identity in this repository (local, then global).
    if git_cmd_config_get "user.name"; then
        name="${GS_GIT_LAST_STDOUT}"
    fi
    if git_cmd_config_get "user.email"; then
        email="${GS_GIT_LAST_STDOUT}"
    fi

    if [ -n "${name}" ] && [ -n "${email}" ]; then
        ui_muted "Git author: ${name} <${email}>"
        return 0
    fi

    ui_warning "Git needs your name and email before a commit."
    ui_info "The name and email become commit metadata."
    ui_info "They are not necessarily your hosting-service login credentials."
    ui_info "GitStart does not use this identity to sign in."
    ui_muted "Use your real class name and school email unless your instructor says otherwise."
    if [ -z "${name}" ]; then
        input_text "Your Git author name: " || return 1
        name="$(input_trim "${GS_INPUT_LAST}")"
    fi
    if [ -z "${email}" ]; then
        input_text "Your Git author email: " || return 1
        email="$(input_trim "${GS_INPUT_LAST}")"
    fi

    scope="local"
    ui_info "Where should Git store this author info?"
    ui_muted "Local config: only this repository. Recommended for class work."
    ui_muted "Global config: other repositories on this computer also use it."
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

    git_cmd_config_set "user.name" "${name}" "${scope}" || return 1
    git_cmd_config_set "user.email" "${email}" "${scope}" || return 1
    ui_success "Git author saved (${scope})."
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

lesson_initialize_help_pwd() {
    ui_print "GOAL"
    ui_muted "Confirm that GitStart is using your project folder."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "pwd means print working directory."
    ui_muted "The working directory is the folder that terminal commands use."
    ui_blank
    ui_print "BEFORE"
    ui_muted "You selected a project folder."
    ui_blank
    ui_print "AFTER"
    ui_muted "The printed path must match the selected project folder."
    ui_muted "Later Git commands act on this folder."
    ui_blank
    ui_print "COMMON MISTAKES"
    ui_muted "If the path does not match, stop and select the folder again."
}

lesson_initialize_help_ls() {
    ui_print "GOAL"
    ui_muted "Check that this folder holds the project files you expect."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "ls means list."
    ui_muted "It shows visible names in the working directory."
    ui_muted "Basic ls does not normally show hidden files such as .git."
    ui_blank
    ui_print "BEFORE"
    ui_muted "You verified the working directory with pwd."
    ui_blank
    ui_print "AFTER"
    ui_muted "You should see your project files."
    ui_muted "Stop if the folder contains unrelated personal files."
    ui_blank
    ui_print "COMMON MISTAKES"
    ui_muted "Do not continue if this is the wrong folder."
}

lesson_initialize_help_init() {
    ui_print "GOAL"
    ui_muted "Create a local Git repository in this folder."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "git init creates a hidden .git directory."
    ui_muted "It does not upload files."
    ui_muted "It does not move or replace project files."
    ui_blank
    ui_print "AFTER"
    ui_muted "This folder becomes a Git working tree."
}

lesson_initialize_help_branch() {
    ui_print "GOAL"
    ui_muted "Name the current branch main for common classroom remotes."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "git branch works with branch names."
    ui_muted "-M renames the current branch."
    ui_muted "main is the new name."
    ui_muted "The command does not create a second project copy."
}

lesson_initialize_help_status() {
    ui_print "GOAL"
    ui_muted "Ask Git what it sees in this repository."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "Look for the current branch name."
    ui_muted "Look for untracked files, modified files, or staged files."
    ui_muted "A clean working tree means no pending changes."
}

lesson_initialize_help_add() {
    ui_print "GOAL"
    ui_muted "Stage project files for the first commit."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "git add stages changes."
    ui_muted "The dot means the current directory."
    ui_muted "Staging does not create a commit."
    ui_muted "Staging does not upload files."
    ui_muted ".gitignore can prevent matching paths from being staged."
}

lesson_initialize_help_commit() {
    ui_print "GOAL"
    ui_muted "Save a local snapshot of the staged changes."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "A commit is a local saved snapshot."
    ui_muted "Only staged changes enter the commit."
    ui_muted "-m provides the message."
    ui_muted "A commit does not push automatically."
    ui_muted "The message should describe the change."
}

lesson_initialize_help_remote() {
    ui_print "GOAL"
    ui_muted "Save a connection to your remote repository as origin."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "The local repository is on your computer."
    ui_muted "The remote repository is on a hosting service."
    ui_muted "A remote is a saved connection."
    ui_muted "origin is a local nickname."
    ui_muted "Adding origin does not upload anything."
}

lesson_initialize_help_push() {
    ui_print "GOAL"
    ui_muted "Publish your local commits and set upstream tracking."
    ui_blank
    ui_print "CONCEPT"
    ui_muted "push sends commits."
    ui_muted "-u saves the upstream connection."
    ui_muted "origin is the remote nickname."
    ui_muted "main is the branch name."
    ui_muted "Later git push commands can usually be shorter."
    ui_blank
    ui_print "AUTH"
    ui_muted "GitStart does not request a password or token."
    ui_muted "Use your credential helper or hosting-service sign-in flow."
}

# Stop when the remote already has history (FR-181, FR-182).
lesson_initialize_preflight_remote() {
    local class

    ui_info "Checking whether the remote already has Git history."
    ui_muted "This uses a read-only network check. It does not change your files."

    if ! git_cmd_ls_remote_heads_tags "${GS_LESSON_INIT_REMOTE_URL}"; then
        class="$(git_classify_ls_remote_result)"
        case "${class}" in
            EMPTY|HAS_REFS)
                class="UNKNOWN"
                ;;
        esac
        GS_GIT_REMOTE_ERROR_CLASS="${class}"
        git_explain_remote_failure "git ls-remote"
        return 1
    fi

    class="$(git_classify_ls_remote_result)"
    case "${class}" in
        EMPTY)
            ui_success "The remote is empty. First publish can continue."
            return 0
            ;;
        HAS_REFS)
            lesson_stop_safe \
                "The remote already contains Git history." \
                "The first-publish lesson expects an empty remote. Pushing now can cause a non-fast-forward conflict." \
                "Use an empty repository, or ask an instructor for help. Do not force-push." \
                "${GS_CODE_SAFE_STOP}"
            return 1
            ;;
        *)
            GS_GIT_REMOTE_ERROR_CLASS="${class}"
            git_explain_remote_failure "git ls-remote"
            return 1
            ;;
    esac
}

lesson_initialize_repository() {
    local list_cmd
    local commit_display
    local here

    lesson_begin_stages \
        "Publish a directory as a new repository" \
        "${GS_LESSON_INIT}" \
        "Choose and verify the project" \
        "Protect project files" \
        "Create the local repository" \
        "Create the first commit" \
        "Connect and publish" \
        "Verify completion"

    lesson_stage_begin "Choose and verify the project"
    if ! picker_run; then
        return 1
    fi

    lesson_substep_begin "Verify the project folder"
    GS_TEACH_GOAL="Confirm that GitStart is using your project folder."
    GS_TEACH_CONCEPT="The working directory is the folder that terminal commands use. pwd means print working directory."
    GS_TEACH_LOOK_FOR="The output must match the folder that you selected."
    GS_TEACH_HELP_FN="lesson_initialize_help_pwd"
    if ! lesson_teach_exact_command \
        "pwd" \
        lesson_initialize_run_pwd \
        "Confirm you are in the project folder before any Git command." \
        "The printed path matches the selected project folder."
    then
        return 1
    fi
    here="$(lesson_current_dir_resolved)"
    if [ "${here}" != "$(lesson_path_resolve "${GS_PICKER_SELECTED}")" ]; then
        lesson_stop_safe \
            "The working directory does not match the selected folder." \
            "pwd reported a different path." \
            "Select the project folder again." \
            "${GS_CODE_PATH_INVALID}"
        return 1
    fi

    lesson_substep_begin "List project files"
    list_cmd="ls"
    if ! command -v ls >/dev/null 2>&1; then
        list_cmd="printf '%s\n' *"
    fi
    GS_TEACH_GOAL="Check that this folder holds the expected project files."
    GS_TEACH_CONCEPT="ls means list. It shows visible names in the working directory. Hidden files are not normally shown."
    GS_TEACH_LOOK_FOR="You should see your project files. Stop if the folder has unrelated personal files."
    GS_TEACH_HELP_FN="lesson_initialize_help_ls"
    if ! lesson_teach_exact_command \
        "${list_cmd}" \
        lesson_initialize_run_ls \
        "Look at the files before Git starts tracking them." \
        "You see visible names in this folder."
    then
        return 1
    fi

    lesson_stage_begin "Protect project files"
    lesson_substep_begin "Review ignored and secret paths"
    ui_info "Before git add, decide what Git should ignore."
    ui_muted "A .gitignore file lists names that Git should skip."
    safety_review_directory "$(pwd)" || true
    if ! safety_ensure_gitignore_review "$(pwd)"; then
        return 1
    fi

    if git_state_check_is_repo; then
        lesson_stop_safe \
            "This directory is already a Git repository." \
            "A .git directory or parent repository was detected." \
            "Use the commit and push lesson, or select a different directory." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    git_state_inspect
    if git_state_is_nested "$(pwd)"; then
        ui_warning "This directory may be inside another Git repository"
        ui_info "A nested repository can confuse later Git commands."
        if ! input_confirm "Continue anyway?"; then
            return 1
        fi
    fi

    lesson_stage_begin "Create the local repository"
    lesson_substep_begin "Initialize the repository"
    GS_TEACH_GOAL="Create a local Git repository in this folder."
    GS_TEACH_CONCEPT="git init creates a hidden .git directory. It does not upload files. It does not move or replace project files."
    GS_TEACH_LOOK_FOR="Git reports that it initialized an empty repository."
    GS_TEACH_HELP_FN="lesson_initialize_help_init"
    if ! lesson_teach_exact_command \
        "git init" \
        lesson_initialize_run_init \
        "Start a new local repository in this folder." \
        "Git creates a hidden .git folder that stores history."
    then
        return 1
    fi
    if ! git_state_check_is_repo; then
        lesson_stop_safe \
            "Repository initialization failed." \
            "Git did not report a working tree after git init." \
            "Check directory permissions. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    lesson_substep_begin "Set Git author identity"
    if ! lesson_initialize_set_identity; then
        return 1
    fi

    lesson_substep_begin "Name the branch main"
    GS_TEACH_GOAL="Rename the current branch to main."
    GS_TEACH_CONCEPT="git branch works with branch names. -M renames the current branch. main is the new name. The command does not create a second project copy."
    GS_TEACH_LOOK_FOR="The current branch is named main."
    GS_TEACH_HELP_FN="lesson_initialize_help_branch"
    if ! lesson_teach_exact_command \
        "git branch -M main" \
        lesson_initialize_run_branch_main \
        "Rename the current branch to main so it matches common classroom remotes." \
        "The current branch is named main."
    then
        return 1
    fi

    lesson_stage_begin "Create the first commit"
    lesson_substep_begin "Check status before staging"
    GS_TEACH_GOAL="Ask Git what it sees before you stage files."
    GS_TEACH_CONCEPT="Look for untracked files and the current branch name."
    GS_TEACH_LOOK_FOR="You see untracked project files on branch main."
    GS_TEACH_HELP_FN="lesson_initialize_help_status"
    if ! lesson_teach_exact_command \
        "git status" \
        lesson_initialize_run_status \
        "Ask Git what it sees before you stage files." \
        "You see untracked files and the current branch."
    then
        return 1
    fi

    lesson_substep_begin "Stage files"
    GS_TEACH_GOAL="Prepare project files for the first commit."
    GS_TEACH_CONCEPT="git add stages changes. The dot means the current directory. Staging does not create a commit. Staging does not upload files."
    GS_TEACH_LOOK_FOR="Selected files are staged. Names in .gitignore stay out."
    GS_TEACH_HELP_FN="lesson_initialize_help_add"
    if ! lesson_teach_exact_command \
        "git add ." \
        lesson_initialize_run_add \
        "Prepare project files for the first commit. Skip names listed in .gitignore." \
        "Selected files are staged and ready to commit."
    then
        return 1
    fi

    lesson_substep_begin "Verify staged files"
    GS_TEACH_GOAL="Confirm which paths are staged for the commit."
    GS_TEACH_CONCEPT="git status shows staged paths under Changes to be committed."
    GS_TEACH_LOOK_FOR="Look for Changes to be committed and the staged file names."
    GS_TEACH_HELP_FN="lesson_initialize_help_status"
    if ! lesson_teach_exact_command \
        "git status" \
        lesson_initialize_run_status \
        "Confirm the staged paths before you create the commit." \
        "You see Changes to be committed and the staged file names."
    then
        return 1
    fi
    lesson_show_staged_paths

    lesson_substep_begin "Create the first commit"
    ui_info "A commit is a local saved snapshot. Write a short message that describes the change."
    ui_muted "Keep the first line short. ${GS_LIMIT_COMMIT_MSG} characters or fewer."
    while true; do
        input_text "Commit message: " || return 1
        GS_LESSON_INIT_COMMIT_MSG="$(input_trim "${GS_INPUT_LAST}")"
        if [ "${#GS_LESSON_INIT_COMMIT_MSG}" -gt "${GS_LIMIT_COMMIT_MSG}" ]; then
            ui_warning "Use ${GS_LIMIT_COMMIT_MSG} characters or fewer."
            continue
        fi
        if [ -z "${GS_LESSON_INIT_COMMIT_MSG}" ]; then
            ui_warning "The commit message cannot be empty."
            continue
        fi
        break
    done
    commit_display="$(lesson_format_commit_command "${GS_LESSON_INIT_COMMIT_MSG}")"
    GS_TEACH_GOAL="Save a snapshot of the staged files into Git history."
    GS_TEACH_CONCEPT="A commit is a local saved snapshot. Only staged changes enter the commit. -m provides the message. A commit does not push automatically."
    GS_TEACH_LOOK_FOR="Git stores the commit on the current branch."
    GS_TEACH_HELP_FN="lesson_initialize_help_commit"
    if ! lesson_teach_exact_command \
        "${commit_display}" \
        lesson_initialize_run_commit \
        "Save a snapshot of the staged files into Git history." \
        "Git stores the commit on the current branch." \
        lesson_match_commit_command
    then
        return 1
    fi
    if ! git_state_check_has_commit; then
        lesson_stop_safe \
            "The commit was not created." \
            "HEAD does not identify a commit." \
            "Check the commit message and staged files. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi
    ui_success "Local commit is complete."

    lesson_stage_begin "Connect and publish"
    lesson_substep_begin "Add the origin remote"
    ui_info "A remote is a named link to a repository on a hosting service."
    ui_info "origin is the usual nickname for your own remote repository."
    ui_info "Adding origin does not upload anything."
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

    if git_state_check_has_remote "origin"; then
        lesson_stop_safe \
            "An origin remote already exists." \
            "Replacing a remote is not allowed in this lesson." \
            "Use diagnosis to inspect remotes. Ask an instructor for help." \
            "${GS_CODE_SAFE_STOP}"
        return 1
    fi

    GS_TEACH_GOAL="Save the hosting service URL under the name origin."
    GS_TEACH_CONCEPT="The local repository is on your computer. The remote is on a hosting service. origin is a local nickname. Adding origin does not upload anything."
    GS_TEACH_LOOK_FOR="Git stores the remote URL under the name origin."
    GS_TEACH_HELP_FN="lesson_initialize_help_remote"
    if ! lesson_teach_exact_command \
        "git remote add origin $(printf '%q' "${GS_LESSON_INIT_REMOTE_URL}")" \
        lesson_initialize_run_remote_add \
        "Save the hosting service URL under the name origin." \
        "Git stores the remote URL under the name origin."
    then
        return 1
    fi
    if ! git_state_check_has_remote "origin"; then
        lesson_stop_safe \
            "The origin remote was not saved." \
            "Git did not report an origin remote after the add step." \
            "Check the remote URL. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi

    lesson_substep_begin "Verify remotes"
    GS_TEACH_GOAL="Check that origin points to the URL you expect."
    GS_TEACH_CONCEPT="git remote -v lists saved remote connections."
    GS_TEACH_LOOK_FOR="You see origin configured for fetch and push."
    GS_TEACH_HELP_FN="lesson_initialize_help_remote"
    if ! lesson_teach_exact_command \
        "git remote -v" \
        lesson_initialize_run_remote_v \
        "Check that origin points to the URL you expect." \
        "You see origin configured for fetch and push."
    then
        return 1
    fi

    lesson_substep_begin "Confirm the remote is empty"
    if ! lesson_initialize_preflight_remote; then
        return 1
    fi

    lesson_substep_begin "Push the branch and set upstream"
    ui_info "Push sends your local commits to the remote."
    ui_info "The first push also sets upstream tracking so later git push knows where to go."
    ui_info "Push needs a network connection and authentication through your Git credential helper."
    ui_info "GitStart does not request a password or token."
    GS_TEACH_GOAL="Publish your branch to origin and remember that remote as upstream."
    GS_TEACH_CONCEPT="push sends commits. -u saves the upstream connection. origin is the remote nickname. Later git push commands can usually be shorter."
    GS_TEACH_LOOK_FOR="The remote branch exists and your local branch tracks it."
    GS_TEACH_HELP_FN="lesson_initialize_help_push"
    if ! lesson_teach_exact_command \
        "git push -u origin ${GS_STATE_BRANCH:-main}" \
        lesson_initialize_run_push \
        "Publish your branch to origin and remember that remote as upstream." \
        "The remote branch exists and your local branch tracks it."
    then
        lesson_explain_remote_failure "git push"
        return 1
    fi

    lesson_stage_begin "Verify completion"
    lesson_substep_begin "Confirm local and remote state"
    git_state_inspect_tracking
    lesson_verify_state
    lesson_complete
    return 0
}
