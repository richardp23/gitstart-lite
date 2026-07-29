# Built-in interactive directory picker with numbered fallback.
# Implements: FR-060 through FR-088.
#
# UX notes:
# - Redraw clears the screen in interactive mode so the list does not stack.
# - Labels use "." and ".." so the actions match common shell navigation.
# - Enter is the only primary action: choose ".", go up, or open a child folder.
# - Preview describes the highlighted row. It does not change the current folder.

GS_PICKER_DIR=""
GS_PICKER_SELECTED=""
GS_PICKER_SHOW_HIDDEN=0
GS_PICKER_FILTER=""
GS_PICKER_INDEX=0
GS_PICKER_COUNT=0
GS_PICKER_PATHS=""
GS_PICKER_LABELS=""
GS_PICKER_KINDS=""

# Clear picker lists.
picker_clear_lists() {
    GS_PICKER_PATHS=""
    GS_PICKER_LABELS=""
    GS_PICKER_KINDS=""
    GS_PICKER_COUNT=0
}

# Append one row: path, label, kind (select|parent|dir).
picker_append() {
    local path="$1"
    local label="$2"
    local kind="$3"
    if [ "${GS_PICKER_COUNT}" -eq 0 ]; then
        GS_PICKER_PATHS="${path}"
        GS_PICKER_LABELS="${label}"
        GS_PICKER_KINDS="${kind}"
    else
        GS_PICKER_PATHS="${GS_PICKER_PATHS}
${path}"
        GS_PICKER_LABELS="${GS_PICKER_LABELS}
${label}"
        GS_PICKER_KINDS="${GS_PICKER_KINDS}
${kind}"
    fi
    GS_PICKER_COUNT=$((GS_PICKER_COUNT + 1))
}

# Get list item by 0-based index from a newline-separated string.
picker_nth() {
    local list="$1"
    local idx="$2"
    local i=0
    local line
    # Avoid a pipeline subshell so the selected line is returned reliably.
    while IFS= read -r line; do
        if [ "${i}" -eq "${idx}" ]; then
            printf '%s\n' "${line}"
            return 0
        fi
        i=$((i + 1))
    done <<EOF
${list}
EOF
    return 1
}

# Clear the screen for one picker frame. Lesson text above is replaced during navigation.
picker_clear_frame() {
    if [ -n "${GS_LESSON_NAME}" ] && [ "${GS_LESSON_BOARD}" = "1" ]; then
        lesson_draw_board
        return 0
    fi
    if [ "${GS_TERM_PLAIN}" = "1" ] || [ "${GS_TERM_IS_TTY}" != "1" ]; then
        printf '\n----------\n'
        return 0
    fi
    printf '\033[H\033[2J' 2>/dev/null || clear 2>/dev/null || printf '\n----------\n'
}

# Enumerate immediate child directories of GS_PICKER_DIR.
picker_enumerate() {
    local path
    local name
    local show
    local tmp_labels
    local tmp_paths
    local parent

    picker_clear_lists
    picker_append "${GS_PICKER_DIR}" ".  (use this folder)" "select"
    parent="$(cd -- "${GS_PICKER_DIR}/.." && pwd 2>/dev/null || dirname -- "${GS_PICKER_DIR}")"
    picker_append "${parent}" ".. (go up one folder)" "parent"

    tmp_labels=""
    tmp_paths=""

    for path in "${GS_PICKER_DIR}"/*; do
        [ -e "${path}" ] || continue
        [ -d "${path}" ] || continue
        name="${path##*/}"
        if [ -z "${tmp_paths}" ]; then
            tmp_paths="${path}"
            tmp_labels="${name}"
        else
            tmp_paths="${tmp_paths}
${path}"
            tmp_labels="${tmp_labels}
${name}"
        fi
    done

    if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
        for path in "${GS_PICKER_DIR}"/.[!.]* "${GS_PICKER_DIR}"/..?*; do
            [ -e "${path}" ] || continue
            [ -d "${path}" ] || continue
            name="${path##*/}"
            case "${name}" in
                .|..) continue ;;
            esac
            if [ -z "${tmp_paths}" ]; then
                tmp_paths="${path}"
                tmp_labels="${name}"
            else
                tmp_paths="${tmp_paths}
${path}"
                tmp_labels="${tmp_labels}
${name}"
            fi
        done
    fi

    if [ -n "${tmp_labels}" ]; then
        if command -v sort >/dev/null 2>&1; then
            while IFS= read -r name; do
                [ -n "${name}" ] || continue
                show=1
                if [ -n "${GS_PICKER_FILTER}" ]; then
                    if ! fuzzy_match "${GS_PICKER_FILTER}" "${name}"; then
                        show=0
                    fi
                fi
                if [ "${show}" = "1" ]; then
                    path=""
                    while IFS= read -r p; do
                        if [ "${p##*/}" = "${name}" ]; then
                            path="${p}"
                            break
                        fi
                    done <<EOF
${tmp_paths}
EOF
                    if [ -n "${path}" ]; then
                        picker_append "${path}" "${name}/" "dir"
                    fi
                fi
            done <<EOF
$(printf '%s\n' "${tmp_labels}" | LC_ALL=C sort -f)
EOF
        else
            while IFS= read -r path; do
                [ -n "${path}" ] || continue
                name="${path##*/}"
                show=1
                if [ -n "${GS_PICKER_FILTER}" ]; then
                    if ! fuzzy_match "${GS_PICKER_FILTER}" "${name}"; then
                        show=0
                    fi
                fi
                if [ "${show}" = "1" ]; then
                    picker_append "${path}" "${name}/" "dir"
                fi
            done <<EOF
${tmp_paths}
EOF
        fi
    fi

    if [ "${GS_PICKER_INDEX}" -ge "${GS_PICKER_COUNT}" ]; then
        GS_PICKER_INDEX=0
    fi
}

# Short preview for one directory. Limit entries for readable frames.
picker_preview() {
    local dir="$1"
    local limit="${2:-8}"
    local count=0
    local path
    local name

    ui_muted "Folder: ${dir}"
    if [ -d "${dir}/.git" ]; then
        ui_info "[GIT] This folder is a Git repository."
    fi

    safety_scan_secrets "${dir}"
    safety_scan_generated "${dir}"
    if [ -n "${GS_SAFE_SECRET_HITS}" ]; then
        ui_warning "[SECRET?] Likely secret file names are present."
    fi
    if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
        ui_warning "[GENERATED] Generated directories are present."
    fi
    if safety_is_dangerous_directory "${dir}"; then
        ui_warning "[WIDE] ${GS_SAFE_DANGEROUS_REASON}"
    fi

    ui_muted "Contents:"
    for path in "${dir}"/*; do
        [ -e "${path}" ] || continue
        name="${path##*/}"
        if [ -d "${path}" ]; then
            ui_muted "  ${name}/"
        else
            ui_muted "  ${name}"
        fi
        count=$((count + 1))
        if [ "${count}" -ge "${limit}" ]; then
            ui_muted "  ..."
            break
        fi
    done
    if [ "${count}" -eq 0 ]; then
        ui_muted "  (no visible entries)"
    fi
}

# Discard unread terminal bytes. Prefer shared input_drain_tty.
picker_drain_tty() {
    input_drain_tty
}

# Render one quiet picker frame.
picker_render() {
    local i=0
    local label
    local kind
    local path
    local marker
    local hint

    picker_clear_frame

    printf '%s\n' "${GS_PICKER_DIR}"
    if [ -n "${GS_PICKER_FILTER}" ]; then
        ui_muted "filter: ${GS_PICKER_FILTER}"
    fi
    ui_blank

    while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
        label="$(picker_nth "${GS_PICKER_LABELS}" "${i}")"
        if [ "${i}" -eq "${GS_PICKER_INDEX}" ]; then
            printf '%s> %s%s\n' "${GS_UI_ACCENT}${GS_UI_BOLD}" "${label}" "${GS_UI_RESET}"
        else
            printf '  %s\n' "${label}"
        fi
        i=$((i + 1))
    done

    kind="$(picker_nth "${GS_PICKER_KINDS}" "${GS_PICKER_INDEX}")"
    path="$(picker_nth "${GS_PICKER_PATHS}" "${GS_PICKER_INDEX}")"
    case "${kind}" in
        select) hint="Enter: use this folder" ;;
        parent) hint="Enter: go up" ;;
        dir) hint="Enter: open folder" ;;
        *) hint="Enter: continue" ;;
    esac
    ui_blank
    ui_muted "${hint}   ?=help  q=quit"
}

# Manual path entry.
picker_manual_path() {
    local path
    input_drain_tty
    input_text "Folder path: " || return 1
    path="$(input_trim "${GS_INPUT_LAST}")"
    if [ ! -d "${path}" ]; then
        ui_warning "That path is not a folder."
        input_read_line "Press Enter... " || true
        return 1
    fi
    path="$(cd -- "${path}" && pwd)"
    GS_PICKER_DIR="${path}"
    GS_PICKER_INDEX=0
    GS_PICKER_FILTER=""
    return 0
}

# Numbered menu fallback when single-key input is not available.
picker_numbered() {
    local choice
    local path
    local label
    local kind
    local i

    while true; do
        picker_enumerate
        ui_blank
        ui_title "Choose a project folder"
        ui_info "You are here: ${GS_PICKER_DIR}"
        ui_muted "Type a number. Then press Enter."
        ui_blank
        i=0
        while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
            label="$(picker_nth "${GS_PICKER_LABELS}" "${i}")"
            printf '  %s) %s\n' "$((i + 1))" "${label}"
            i=$((i + 1))
        done
        ui_blank
        ui_help "Letters: s=search | h=hidden | m=type path | q=cancel"
        input_read_line "Choice: " || return 1
        choice="$(input_trim "${GS_INPUT_LAST}")"
        case "${choice}" in
            q|Q)
                return 1
                ;;
            s|S)
                input_text "Search text: " 1 || true
                GS_PICKER_FILTER="$(input_trim "${GS_INPUT_LAST}")"
                continue
                ;;
            h|H)
                if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
                    GS_PICKER_SHOW_HIDDEN=0
                else
                    GS_PICKER_SHOW_HIDDEN=1
                fi
                continue
                ;;
            m|M)
                picker_manual_path || true
                continue
                ;;
        esac
        case "${choice}" in
            ''|*[!0-9]*)
                ui_info "Type a list number or a command letter."
                continue
                ;;
        esac
        if [ "${choice}" -lt 1 ] || [ "${choice}" -gt "${GS_PICKER_COUNT}" ]; then
            ui_info "Type a number from 1 to ${GS_PICKER_COUNT}."
            continue
        fi
        GS_PICKER_INDEX=$((choice - 1))
        path="$(picker_nth "${GS_PICKER_PATHS}" "${GS_PICKER_INDEX}")"
        label="$(picker_nth "${GS_PICKER_LABELS}" "${GS_PICKER_INDEX}")"
        kind="$(picker_nth "${GS_PICKER_KINDS}" "${GS_PICKER_INDEX}")"
        case "${kind}" in
            select)
                GS_PICKER_SELECTED="${GS_PICKER_DIR}"
                return 0
                ;;
            parent)
                GS_PICKER_DIR="$(cd -- "${GS_PICKER_DIR}/.." && pwd)"
                GS_PICKER_INDEX=0
                continue
                ;;
            dir)
                if [ -d "${path}" ]; then
                    GS_PICKER_DIR="$(cd -- "${path}" && pwd)"
                    GS_PICKER_INDEX=0
                    GS_PICKER_FILTER=""
                fi
                continue
                ;;
        esac
    done
}

# Interactive arrow-key picker.
picker_interactive() {
    local key
    local path
    local label
    local kind

    while true; do
        picker_enumerate
        picker_render
        if ! input_read_key; then
            picker_drain_tty
            return 1
        fi
        key="${GS_INPUT_LAST}"
        case "${key}" in
            up)
                if [ "${GS_PICKER_INDEX}" -gt 0 ]; then
                    GS_PICKER_INDEX=$((GS_PICKER_INDEX - 1))
                fi
                ;;
            down)
                if [ "${GS_PICKER_INDEX}" -lt $((GS_PICKER_COUNT - 1)) ]; then
                    GS_PICKER_INDEX=$((GS_PICKER_INDEX + 1))
                fi
                ;;
            left|backspace)
                GS_PICKER_DIR="$(cd -- "${GS_PICKER_DIR}/.." && pwd)"
                GS_PICKER_INDEX=0
                GS_PICKER_FILTER=""
                ;;
            enter)
                path="$(picker_nth "${GS_PICKER_PATHS}" "${GS_PICKER_INDEX}")"
                label="$(picker_nth "${GS_PICKER_LABELS}" "${GS_PICKER_INDEX}")"
                kind="$(picker_nth "${GS_PICKER_KINDS}" "${GS_PICKER_INDEX}")"
                case "${kind}" in
                    select)
                        GS_PICKER_SELECTED="${GS_PICKER_DIR}"
                        picker_drain_tty
                        return 0
                        ;;
                    parent)
                        GS_PICKER_DIR="$(cd -- "${GS_PICKER_DIR}/.." && pwd)"
                        GS_PICKER_INDEX=0
                        GS_PICKER_FILTER=""
                        ;;
                    dir)
                        if [ -d "${path}" ]; then
                            GS_PICKER_DIR="$(cd -- "${path}" && pwd)"
                            GS_PICKER_INDEX=0
                            GS_PICKER_FILTER=""
                        fi
                        ;;
                esac
                ;;
            /)
                picker_drain_tty
                input_text "Search: " 1 || true
                GS_PICKER_FILTER="$(input_trim "${GS_INPUT_LAST}")"
                GS_PICKER_INDEX=0
                ;;
            .)
                if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
                    GS_PICKER_SHOW_HIDDEN=0
                else
                    GS_PICKER_SHOW_HIDDEN=1
                fi
                GS_PICKER_INDEX=0
                ;;
            m|M)
                picker_manual_path || true
                ;;
            \?|h|H)
                input_drain_tty
                ui_blank
                ui_help "Up/Down: move. Enter: act. Left: go up."
                ui_help "/ search | . hidden | m path | q cancel"
                input_read_line "Press Enter... " || true
                ;;
            q|Q|esc)
                input_drain_tty
                return 1
                ;;
        esac
    done
}

# Confirm selection, warn briefly, teach cd.
picker_confirm_and_teach_cd() {
    local dir="$1"
    local cd_cmd
    local cd_path
    local warn_bits=""

    input_drain_tty
    if [ -n "${GS_LESSON_NAME}" ]; then
        # Same lesson-board step as the picker. New screen, same [NOW] label.
        lesson_focus "Choose project folder"
    else
        ui_step "Confirm folder"
    fi
    ui_print "${dir}"

    safety_scan_secrets "${dir}"
    safety_scan_generated "${dir}"
    if [ -n "${GS_SAFE_SECRET_HITS}" ]; then
        warn_bits="secret-looking names"
    fi
    if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
        if [ -n "${warn_bits}" ]; then
            warn_bits="${warn_bits}; generated folders"
        else
            warn_bits="generated folders"
        fi
    fi
    if [ -n "${warn_bits}" ]; then
        ui_warning "Note: ${warn_bits} found. You will review .gitignore next."
    fi
    if safety_is_dangerous_directory "${dir}"; then
        ui_warning "${GS_SAFE_DANGEROUS_REASON}"
        if ! input_confirm "Use this folder anyway?"; then
            return 1
        fi
    fi

    if ! input_confirm "Use this folder?"; then
        return 1
    fi

    # Teach the home-relative form students usually type.
    cd_path="$(lesson_cd_display_path "${dir}")"
    case "${cd_path}" in
        -*)
            cd_cmd="cd -- $(printf '%q' "${cd_path}")"
            ;;
        *)
            cd_cmd="cd ${cd_path}"
            ;;
    esac

    if [ -n "${GS_LESSON_NAME}" ]; then
        lesson_focus "Open the folder"
    else
        ui_step "Open the folder"
    fi
    if ! lesson_teach_exact_command \
        "${cd_cmd}" \
        picker_noop_cd \
        "cd moves your shell into the project folder." \
        "This folder becomes your working directory." \
        lesson_match_cd_command
    then
        return 1
    fi
    if ! cd -- "${dir}"; then
        ui_fail_detail \
            "Could not open the directory." \
            "cd" \
            "The directory is not accessible." \
            "Select a different directory." \
            "${GS_CODE_PATH_INVALID}"
        return 1
    fi
    ui_success "Using: $(pwd)"
    GS_PICKER_SELECTED="$(pwd)"
    return 0
}

picker_noop_cd() {
    return 0
}

# Main picker entry. Sets GS_PICKER_SELECTED on success.
picker_run() {
    GS_PICKER_DIR="$(pwd)"
    GS_PICKER_SELECTED=""
    GS_PICKER_SHOW_HIDDEN=0
    GS_PICKER_FILTER=""
    GS_PICKER_INDEX=0

    if [ -n "${GS_LESSON_NAME}" ]; then
        lesson_focus "Choose project folder"
    else
        ui_step "Choose project folder"
    fi
    ui_muted "Up/Down move. Enter acts. Highlight '.  (use this folder)' to choose."

    if [ "${GS_TERM_SINGLE_KEY}" = "1" ]; then
        if ! picker_interactive; then
            ui_stopped "Cancelled."
            input_drain_tty
            return 1
        fi
    else
        if ! picker_numbered; then
            ui_stopped "Cancelled."
            return 1
        fi
    fi

    input_drain_tty
    picker_confirm_and_teach_cd "${GS_PICKER_SELECTED}"
}
