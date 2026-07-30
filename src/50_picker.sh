# Built-in interactive directory picker with numbered fallback.
# Implements: FR-060 through FR-088.
#
# UX notes:
# - Redraw clears the screen in interactive mode so the list does not stack.
# - Labels use "." and ".." so the actions match common shell navigation.
# - Enter is the only primary action: choose ".", go up, or open a child folder.
# - Preview describes the highlighted row. It does not change the current folder.
# - Directory records use Bash 3.2 indexed arrays (path, label, kind, search).

GS_PICKER_DIR=""
GS_PICKER_SELECTED=""
GS_PICKER_SHOW_HIDDEN=0
GS_PICKER_FILTER=""
GS_PICKER_INDEX=0
GS_PICKER_COUNT=0
GS_PICKER_PATHS=()
GS_PICKER_LABELS=()
GS_PICKER_KINDS=()
# Parallel search values for each row (filter and tests).
# shellcheck disable=SC2034
GS_PICKER_SEARCH=()

# Preview cache for the highlighted directory.
GS_PICKER_PREVIEW_PATH=""
GS_PICKER_PREVIEW_TEXT=""
GS_PICKER_PREVIEW_FORCE=0
GS_PICKER_SHOW_PREVIEW_NARROW=0

# Clear picker lists.
picker_clear_lists() {
    GS_PICKER_PATHS=()
    GS_PICKER_LABELS=()
    GS_PICKER_KINDS=()
    GS_PICKER_SEARCH=()
    GS_PICKER_COUNT=0
}

# Invalidate cached preview text.
picker_preview_invalidate() {
    GS_PICKER_PREVIEW_PATH=""
    GS_PICKER_PREVIEW_TEXT=""
}

# Append one row: path, label, kind (select|parent|dir), search value.
picker_append() {
    local path="$1"
    local label="$2"
    local kind="$3"
    local search="${4:-$2}"
    GS_PICKER_PATHS[GS_PICKER_COUNT]="${path}"
    GS_PICKER_LABELS[GS_PICKER_COUNT]="${label}"
    GS_PICKER_KINDS[GS_PICKER_COUNT]="${kind}"
    # shellcheck disable=SC2034
    GS_PICKER_SEARCH[GS_PICKER_COUNT]="${search}"
    GS_PICKER_COUNT=$((GS_PICKER_COUNT + 1))
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
# Sort complete records. Do not sort labels and then re-search paths.
picker_enumerate() {
    local path
    local name
    local parent
    local tmp_paths=()
    local tmp_names=()
    local tmp_count=0
    local sorted
    local line
    local idx
    local i

    picker_clear_lists
    picker_append "${GS_PICKER_DIR}" ".  (use this folder)" "select" "."
    if ! parent="$(cd -- "${GS_PICKER_DIR}/.." && pwd 2>/dev/null)"; then
        parent="$(dirname -- "${GS_PICKER_DIR}")"
    fi
    picker_append "${parent}" ".. (go up one folder)" "parent" ".."

    for path in "${GS_PICKER_DIR}"/*; do
        [ -e "${path}" ] || continue
        [ -d "${path}" ] || continue
        name="${path##*/}"
        tmp_paths[tmp_count]="${path}"
        tmp_names[tmp_count]="${name}"
        tmp_count=$((tmp_count + 1))
    done

    if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
        for path in "${GS_PICKER_DIR}"/.[!.]* "${GS_PICKER_DIR}"/..?*; do
            [ -e "${path}" ] || continue
            [ -d "${path}" ] || continue
            name="${path##*/}"
            case "${name}" in
                .|..) continue ;;
            esac
            tmp_paths[tmp_count]="${path}"
            tmp_names[tmp_count]="${name}"
            tmp_count=$((tmp_count + 1))
        done
    fi

    if [ "${tmp_count}" -gt 0 ]; then
        sorted=""
        i=0
        while [ "${i}" -lt "${tmp_count}" ]; do
            # Sort key: name, then original index for stable path lookup.
            if [ -z "${sorted}" ]; then
                sorted="${tmp_names[i]}"$'\t'"${i}"
            else
                sorted="${sorted}"$'\n'"${tmp_names[i]}"$'\t'"${i}"
            fi
            i=$((i + 1))
        done
        if command -v sort >/dev/null 2>&1; then
            sorted="$(printf '%s\n' "${sorted}" | LC_ALL=C sort -f -t "$(printf '\t')" -k1,1)"
        fi
        while IFS="$(printf '\t')" read -r name idx; do
            [ -n "${idx}" ] || continue
            path="${tmp_paths[idx]}"
            name="${tmp_names[idx]}"
            if [ -n "${GS_PICKER_FILTER}" ]; then
                if ! fuzzy_match "${GS_PICKER_FILTER}" "${name}"; then
                    continue
                fi
            fi
            picker_append "${path}" "${name}/" "dir" "${name}"
        done <<EOF
${sorted}
EOF
    fi

    if [ "${GS_PICKER_INDEX}" -ge "${GS_PICKER_COUNT}" ]; then
        GS_PICKER_INDEX=0
    fi
}

# Build compact preview text for one directory into GS_PICKER_PREVIEW_TEXT.
# Does not print. Skips work when the highlight path is unchanged.
picker_preview_build() {
    local dir="$1"
    local limit="${2:-$GS_LIMIT_PREVIEW_ENTRIES}"
    local count=0
    local path
    local name
    local bits=""
    local lines=""
    local line

    if [ "${GS_PICKER_PREVIEW_FORCE}" != "1" ] && [ "${dir}" = "${GS_PICKER_PREVIEW_PATH}" ] && [ -n "${GS_PICKER_PREVIEW_TEXT}" ]; then
        return 0
    fi
    GS_PICKER_PREVIEW_FORCE=0

    if [ -d "${dir}/.git" ]; then
        bits="[GIT]"
    fi
    safety_scan_secrets "${dir}"
    safety_scan_generated "${dir}"
    if [ -n "${GS_SAFE_SECRET_HITS}" ]; then
        if [ -n "${bits}" ]; then
            bits="${bits} [SECRET?]"
        else
            bits="[SECRET?]"
        fi
    fi
    if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
        if [ -n "${bits}" ]; then
            bits="${bits} [GENERATED]"
        else
            bits="[GENERATED]"
        fi
    fi
    safety_is_dangerous_directory "${dir}" || true
    if [ "${GS_SAFE_DANGEROUS}" = "1" ]; then
        if [ -n "${bits}" ]; then
            bits="${bits} [WIDE]"
        else
            bits="[WIDE]"
        fi
    fi

    lines="${dir##*/}"
    if [ -n "${bits}" ]; then
        lines="${lines}  ${bits}"
    fi

    for path in "${dir}"/*; do
        [ -e "${path}" ] || continue
        name="${path##*/}"
        if [ -d "${path}" ]; then
            line="  ${name}/"
        else
            line="  ${name}"
        fi
        lines="${lines}
${line}"
        count=$((count + 1))
        if [ "${count}" -ge "${limit}" ]; then
            lines="${lines}
  ..."
            break
        fi
    done
    if [ "${count}" -eq 0 ]; then
        lines="${lines}
  (empty)"
    fi

    GS_PICKER_PREVIEW_PATH="${dir}"
    GS_PICKER_PREVIEW_TEXT="${lines}"
}

# Print cached preview using adaptive layout.
picker_preview_render() {
    local kind="$1"
    local path="$2"
    local width="${GS_TERM_WIDTH:-80}"
    local line
    local shown=0

    if [ "${kind}" != "dir" ]; then
        return 0
    fi
    if [ ! -d "${path}" ]; then
        return 0
    fi

    if [ "${width}" -lt "${GS_LIMIT_NARROW_COLS}" ] 2>/dev/null; then
        if [ "${GS_PICKER_SHOW_PREVIEW_NARROW}" != "1" ]; then
            ui_muted "p: preview"
            return 0
        fi
    fi

    picker_preview_build "${path}"

    ui_blank
    if [ "${width}" -ge "${GS_LIMIT_WIDE_COLS}" ] 2>/dev/null; then
        ui_muted "Preview:"
        while IFS= read -r line; do
            ui_muted "${line}"
            shown=$((shown + 1))
            if [ "${shown}" -ge $((GS_LIMIT_PREVIEW_ENTRIES + 2)) ]; then
                break
            fi
        done <<EOF
${GS_PICKER_PREVIEW_TEXT}
EOF
    else
        # Medium: one-line summary (first line of cache).
        line="$(printf '%s\n' "${GS_PICKER_PREVIEW_TEXT}" | head -n 1)"
        ui_muted "Preview: ${line}"
    fi
}

# Short preview API for confirmation screens (prints directly).
picker_preview() {
    local dir="$1"
    GS_PICKER_PREVIEW_FORCE=1
    picker_preview_build "${dir}"
    while IFS= read -r line; do
        [ -n "${line}" ] || continue
        ui_muted "${line}"
    done <<EOF
${GS_PICKER_PREVIEW_TEXT}
EOF
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
    local hint

    picker_clear_frame

    printf '%s\n' "${GS_PICKER_DIR}"
    if [ -n "${GS_PICKER_FILTER}" ]; then
        ui_muted "filter: ${GS_PICKER_FILTER}"
    fi
    ui_blank

    while [ "${i}" -lt "${GS_PICKER_COUNT}" ]; do
        label="${GS_PICKER_LABELS[i]}"
        if [ "${i}" -eq "${GS_PICKER_INDEX}" ]; then
            printf '%s> %s%s\n' "${GS_UI_ACCENT}${GS_UI_BOLD}" "${label}" "${GS_UI_RESET}"
        else
            printf '  %s\n' "${label}"
        fi
        i=$((i + 1))
    done

    kind="${GS_PICKER_KINDS[GS_PICKER_INDEX]}"
    path="${GS_PICKER_PATHS[GS_PICKER_INDEX]}"
    case "${kind}" in
        select) hint="Enter: use this folder" ;;
        parent) hint="Enter: go up" ;;
        dir) hint="Enter: open folder" ;;
        *) hint="Enter: continue" ;;
    esac
    ui_blank
    if [ "${GS_TERM_WIDTH}" -ge "${GS_LIMIT_WIDE_COLS}" ] 2>/dev/null; then
        ui_muted "${hint}   arrows  /=search  .=hidden  m=path  p=preview  ?=help  q=quit"
    elif [ "${GS_TERM_WIDTH}" -lt "${GS_LIMIT_NARROW_COLS}" ] 2>/dev/null; then
        ui_muted "${hint}  p=preview"
    else
        ui_muted "${hint}   ?=help  p=preview  q=quit"
    fi
    picker_preview_render "${kind}" "${path}"
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
    picker_preview_invalidate
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
            label="${GS_PICKER_LABELS[i]}"
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
                picker_preview_invalidate
                continue
                ;;
            h|H)
                if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
                    GS_PICKER_SHOW_HIDDEN=0
                else
                    GS_PICKER_SHOW_HIDDEN=1
                fi
                picker_preview_invalidate
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
        path="${GS_PICKER_PATHS[GS_PICKER_INDEX]}"
        label="${GS_PICKER_LABELS[GS_PICKER_INDEX]}"
        kind="${GS_PICKER_KINDS[GS_PICKER_INDEX]}"
        case "${kind}" in
            select)
                GS_PICKER_SELECTED="${GS_PICKER_DIR}"
                return 0
                ;;
            parent)
                GS_PICKER_DIR="$(cd -- "${GS_PICKER_DIR}/.." && pwd)"
                GS_PICKER_INDEX=0
                picker_preview_invalidate
                continue
                ;;
            dir)
                if [ -d "${path}" ]; then
                    GS_PICKER_DIR="$(cd -- "${path}" && pwd)"
                    GS_PICKER_INDEX=0
                    GS_PICKER_FILTER=""
                    picker_preview_invalidate
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
                picker_preview_invalidate
                ;;
            enter)
                path="${GS_PICKER_PATHS[GS_PICKER_INDEX]}"
                label="${GS_PICKER_LABELS[GS_PICKER_INDEX]}"
                kind="${GS_PICKER_KINDS[GS_PICKER_INDEX]}"
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
                        picker_preview_invalidate
                        ;;
                    dir)
                        if [ -d "${path}" ]; then
                            GS_PICKER_DIR="$(cd -- "${path}" && pwd)"
                            GS_PICKER_INDEX=0
                            GS_PICKER_FILTER=""
                            picker_preview_invalidate
                        fi
                        ;;
                esac
                ;;
            /)
                picker_drain_tty
                input_text "Search: " 1 || true
                GS_PICKER_FILTER="$(input_trim "${GS_INPUT_LAST}")"
                GS_PICKER_INDEX=0
                picker_preview_invalidate
                ;;
            .)
                if [ "${GS_PICKER_SHOW_HIDDEN}" = "1" ]; then
                    GS_PICKER_SHOW_HIDDEN=0
                else
                    GS_PICKER_SHOW_HIDDEN=1
                fi
                GS_PICKER_INDEX=0
                picker_preview_invalidate
                ;;
            p|P)
                if [ "${GS_TERM_WIDTH}" -lt "${GS_LIMIT_NARROW_COLS}" ] 2>/dev/null; then
                    if [ "${GS_PICKER_SHOW_PREVIEW_NARROW}" = "1" ]; then
                        GS_PICKER_SHOW_PREVIEW_NARROW=0
                    else
                        GS_PICKER_SHOW_PREVIEW_NARROW=1
                        GS_PICKER_PREVIEW_FORCE=1
                    fi
                else
                    GS_PICKER_PREVIEW_FORCE=1
                fi
                ;;
            m|M)
                picker_manual_path || true
                ;;
            \?|h|H)
                input_drain_tty
                ui_blank
                ui_help "Up/Down: move. Enter: act. Left: go up."
                ui_help "/ search | . hidden | m path | p preview | q cancel"
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
        ui_warning "Note: ${warn_bits} found."
        ui_muted "Next you will learn about .gitignore, a file that tells Git what to skip."
    fi
    safety_is_dangerous_directory "${dir}" || true
    if [ "${GS_SAFE_DANGEROUS}" = "1" ]; then
        ui_warning "${GS_SAFE_DANGEROUS_REASON}"
        ui_muted "Code: ${GS_CODE_PATH_DANGEROUS}"
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
    GS_PICKER_SHOW_PREVIEW_NARROW=0
    picker_preview_invalidate

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
