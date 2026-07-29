# Lesson teaching engine. Student text is a knowledge check only.
# Implements: FR-050 through FR-054, FR-100 through FR-113.
#
# The lesson board redraws on each focus change:
# completed steps stay visible but muted; the current step is highlighted.

GS_LESSON_MODE="${GS_MODE_LEARN}"
GS_LESSON_NAME=""
GS_LESSON_ID=""
GS_LESSON_STEP=0
GS_LESSON_TOTAL=0
GS_LESSON_DONE=""
GS_LESSON_CURRENT=""
GS_LESSON_BOARD=1

lesson_begin() {
    local name="$1"
    local total="${2:-0}"
    local id="${3:-}"
    GS_LESSON_NAME="${name}"
    GS_LESSON_ID="${id}"
    GS_LESSON_STEP=0
    GS_LESSON_TOTAL="${total}"
    GS_LESSON_DONE=""
    GS_LESSON_CURRENT=""
    if [ "${GS_TERM_IS_TTY}" = "1" ] && [ "${GS_TERM_PLAIN}" != "1" ]; then
        GS_LESSON_BOARD=1
    else
        GS_LESSON_BOARD=0
    fi
    lesson_draw_board
    if [ "${GS_LESSON_MODE}" = "${GS_MODE_ASSISTED}" ]; then
        ui_muted "Assisted mode: confirm each command."
    else
        ui_muted "Learn mode: type each command."
    fi
}

# Clear the screen for a lesson board frame when interactive.
lesson_clear_board() {
    if [ "${GS_LESSON_BOARD}" != "1" ]; then
        printf '\n'
        return 0
    fi
    printf '\033[H\033[2J' 2>/dev/null || clear 2>/dev/null || printf '\n----------\n'
}

# Draw completed steps (muted) and the current step (highlighted).
lesson_draw_board() {
    local line
    local n

    lesson_clear_board
    ui_title "Lesson: ${GS_LESSON_NAME}"
    ui_blank

    if [ -n "${GS_LESSON_DONE}" ]; then
        while IFS= read -r line; do
            [ -n "${line}" ] || continue
            printf '%s  [ok] %s%s\n' "${GS_UI_MUTED}" "${line}" "${GS_UI_RESET}"
        done <<EOF
${GS_LESSON_DONE}
EOF
    fi

    if [ -n "${GS_LESSON_CURRENT}" ]; then
        printf '%s%s  [NOW] %s%s\n' "${GS_UI_BOLD}" "${GS_UI_ACCENT}" "${GS_LESSON_CURRENT}" "${GS_UI_RESET}"
    fi

    if [ "${GS_LESSON_TOTAL}" -gt 0 ] 2>/dev/null && [ "${GS_LESSON_STEP}" -lt "${GS_LESSON_TOTAL}" ] 2>/dev/null; then
        n=$((GS_LESSON_TOTAL - GS_LESSON_STEP))
        if [ "${n}" -gt 0 ] 2>/dev/null; then
            printf '%s  .... %s more%s\n' "${GS_UI_MUTED}" "${n}" "${GS_UI_RESET}"
        fi
    fi

    ui_blank
    if [ "${GS_TERM_UNICODE}" = "1" ] && [ "${GS_TERM_ASCII}" != "1" ] && [ "${GS_TERM_PLAIN}" != "1" ]; then
        printf '%s────────────────────────────────────────%s\n' "${GS_UI_MUTED}" "${GS_UI_RESET}"
    else
        printf '%s----------------------------------------%s\n' "${GS_UI_MUTED}" "${GS_UI_RESET}"
    fi
    ui_blank
}

# Move focus to a new current item. Previous current becomes [ok].
# If the title is unchanged, redraw only. Do not mark a new completed step.
lesson_focus() {
    local title="$1"
    if [ -n "${GS_LESSON_CURRENT}" ] && [ "${title}" = "${GS_LESSON_CURRENT}" ]; then
        lesson_draw_board
        return 0
    fi
    if [ -n "${GS_LESSON_CURRENT}" ]; then
        # Folder picking is one continuous flow. Do not pause when leaving it.
        if [ "${GS_LESSON_CURRENT}" != "Choose project folder" ]; then
            lesson_pause_continue
        fi
        if [ -n "${GS_LESSON_DONE}" ]; then
            GS_LESSON_DONE="${GS_LESSON_DONE}
${GS_LESSON_CURRENT}"
        else
            GS_LESSON_DONE="${GS_LESSON_CURRENT}"
        fi
    fi
    GS_LESSON_CURRENT="${title}"
    lesson_draw_board
}

lesson_step_begin() {
    local title="$1"
    local label
    GS_LESSON_STEP=$((GS_LESSON_STEP + 1))
    if [ "${GS_LESSON_TOTAL}" -gt 0 ] 2>/dev/null; then
        label="${GS_LESSON_STEP}/${GS_LESSON_TOTAL}  ${title}"
    else
        label="${title}"
    fi
    lesson_focus "${label}"
}

# Teach an exact command. On success, call the runner function name in $2.
# Optional $5: name of an alternate matcher function (typed, expected) -> status.
lesson_teach_exact_command() {
    local expected="$1"
    local runner="$2"
    local why="${3:-This command is part of the lesson.}"
    local result_text="${4:-}"
    local alt_match="${5:-}"
    local typed
    local normalized
    local expected_norm
    local matched

    ui_info "${why}"
    if [ -n "${result_text}" ]; then
        ui_muted "Result: ${result_text}"
    fi
    ui_command "${expected}"

    expected_norm="$(input_normalize_command "${expected}")"

    if [ "${GS_LESSON_MODE}" = "${GS_MODE_ASSISTED}" ]; then
        if ! input_confirm "Run it?"; then
            ui_stopped "Stopped before the command ran."
            ui_next "Start the lesson again when you are ready."
            return 1
        fi
    else
        while true; do
            input_read_line "> " || return 1
            typed="$(input_trim "${GS_INPUT_LAST}")"
            case "${typed}" in
                \?)
                    lesson_draw_board
                    ui_info "${why}"
                    ui_command "${expected}"
                    continue
                    ;;
                q|Q)
                    ui_stopped "Stopped before the command ran."
                    ui_next "Start the lesson again when you are ready."
                    return 1
                    ;;
            esac
            if safety_is_forbidden_command "${typed}"; then
                safety_stop \
                    "That command is not allowed in this tool." \
                    "The command can discard work or rewrite shared history." \
                    "Type the teaching command shown above." \
                    "${GS_CODE_SAFE_STOP}"
                continue
            fi
            normalized="$(input_normalize_command "${typed}")"
            matched=0
            if [ "${normalized}" = "${expected_norm}" ]; then
                matched=1
            elif [ -n "${alt_match}" ] && "${alt_match}" "${normalized}" "${expected_norm}"; then
                matched=1
            fi
            if [ "${matched}" = "1" ]; then
                break
            fi
            ui_warning "Not a match. Type this:"
            ui_command "${expected}"
            ui_muted "Tip: ? help, q stop. Code: ${GS_CODE_LESSON_CMD}"
        done
    fi

    if ! "${runner}"; then
        ui_fail_detail \
            "The operation did not complete." \
            "${expected}" \
            "The command exit status was ${GS_GIT_LAST_STATUS:-unknown}." \
            "Read the message above. Fix the issue. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        return 1
    fi
    ui_success "Done."
    return 0
}

# Wait so the student can read the screen before the board redraws.
# A buffered Enter from before this prompt is enough (do not drain first).
lesson_pause_continue() {
    ui_blank
    input_read_line "Press Enter to continue... " || true
}

lesson_teach_command_with_data() {
    local expected_display="$1"
    local runner="$2"
    local why="$3"
    local result_text="$4"
    lesson_teach_exact_command "${expected_display}" "${runner}" "${why}" "${result_text}"
}

lesson_confirm_change() {
    local description="$1"
    ui_review "${description}"
    input_confirm "Continue?"
}

lesson_show_result() {
    ui_muted "$*"
}

lesson_verify_state() {
    git_state_inspect
    ui_muted "Branch: ${GS_STATE_BRANCH:-none} | Clean: ${GS_STATE_IS_CLEAN} | State: ${GS_STATE_CLASS}"
}

lesson_stop_safe() {
    local title="$1"
    local reason="$2"
    local next_action="$3"
    local code="${4:-$GS_CODE_SAFE_STOP}"
    local operation="${GS_LESSON_NAME}"
    if [ -n "${GS_LESSON_ID}" ]; then
        operation="${GS_LESSON_NAME} (${GS_LESSON_ID})"
    fi
    ui_fail_detail "${title}" "${operation}" "${reason}" "${next_action}" "${code}"
    return 1
}

lesson_complete() {
    if [ -n "${GS_LESSON_CURRENT}" ]; then
        lesson_pause_continue
        if [ -n "${GS_LESSON_DONE}" ]; then
            GS_LESSON_DONE="${GS_LESSON_DONE}
${GS_LESSON_CURRENT}"
        else
            GS_LESSON_DONE="${GS_LESSON_CURRENT}"
        fi
        GS_LESSON_CURRENT=""
    fi
    GS_LESSON_STEP="${GS_LESSON_TOTAL}"
    lesson_draw_board
    ui_complete "Finished: ${GS_LESSON_NAME}"
    : "${GS_LESSON_ID}"
    ui_next "Return to the main menu, or choose Diagnose."
}

lesson_network_available() {
    return 0
}

# Explain when a remote step needs network access (not a product pitch).
lesson_explain_offline() {
    local step_name="$1"
    ui_warning "Needs network: ${step_name}"
    ui_next "Check your connection, then run this lesson again."
    ui_muted "Code: ${GS_CODE_NET_OFFLINE}"
}

# Build a student-friendly cd path. Prefer ~/ when the folder is under HOME.
lesson_cd_display_path() {
    local dir="$1"
    local home="${HOME:-}"
    if [ -n "${home}" ]; then
        case "${dir}" in
            "${home}")
                printf '~\n'
                return 0
                ;;
            "${home}"/*)
                # Literal tilde for display. Do not expand as $HOME.
                # shellcheck disable=SC2088
                printf '~/%s\n' "${dir#"${home}"/}"
                return 0
                ;;
        esac
    fi
    printf '%s\n' "${dir}"
}

# Expand a path that may start with ~. Print the expanded path.
lesson_expand_user_path() {
    local path="$1"
    local home="${HOME:-}"
    local prefix
    local rest

    # Do not write ${path#~/}. Bash expands ~/ in that pattern.
    # Literal '~/' is intentional display/input syntax (SC2088).
    # shellcheck disable=SC2088
    prefix='~/'
    # shellcheck disable=SC2088
    case "${path}" in
        '~')
            printf '%s\n' "${home}"
            ;;
        '~/'*)
            rest="${path#"${prefix}"}"
            printf '%s/%s\n' "${home}" "${rest}"
            ;;
        *)
            printf '%s\n' "${path}"
            ;;
    esac
}

# Strip a leading cd and optional -- from a command. Print the path argument.
lesson_cd_extract_path() {
    local cmd="$1"
    local path
    path="${cmd#cd}"
    path="$(input_trim "${path}")"
    case "${path}" in
        --\ *)
            path="${path#-- }"
            path="$(input_trim "${path}")"
            ;;
        --)
            path=""
            ;;
    esac
    path="${path#\'}"
    path="${path%\'}"
    path="${path#\"}"
    path="${path%\"}"
    printf '%s\n' "${path}"
}

# Return 0 when typed cd reaches the same folder as the expected cd command.
lesson_match_cd_command() {
    local typed="$1"
    local expected="$2"
    local typed_path
    local expected_path
    local typed_res
    local expected_res

    case "${typed}" in
        cd|cd\ *) ;;
        *) return 1 ;;
    esac
    case "${expected}" in
        cd|cd\ *) ;;
        *) return 1 ;;
    esac

    typed_path="$(lesson_cd_extract_path "${typed}")"
    expected_path="$(lesson_cd_extract_path "${expected}")"
    typed_path="$(lesson_expand_user_path "${typed_path}")"
    expected_path="$(lesson_expand_user_path "${expected_path}")"

    if [ -z "${typed_path}" ] || [ -z "${expected_path}" ]; then
        return 1
    fi
    if [ "${typed_path}" = "${expected_path}" ]; then
        return 0
    fi
    if [ ! -d "${typed_path}" ] || [ ! -d "${expected_path}" ]; then
        return 1
    fi
    typed_res="$(cd -- "${typed_path}" && pwd)" || return 1
    expected_res="$(cd -- "${expected_path}" && pwd)" || return 1
    if [ "${typed_res}" = "${expected_res}" ]; then
        return 0
    fi
    return 1
}

# Build a student-friendly commit command for display and typing.
lesson_format_commit_command() {
    local msg="$1"
    case "${msg}" in
        *\"*)
            printf 'git commit -m %s\n' "$(printf '%q' "${msg}")"
            ;;
        *)
            printf 'git commit -m "%s"\n' "${msg}"
            ;;
    esac
}

# Extract the commit message text from a git commit -m command.
lesson_commit_message_from_command() {
    local cmd="$1"
    local rest
    case "${cmd}" in
        git\ commit\ -m\ *|git\ commit\ -m)
            ;;
        *)
            return 1
            ;;
    esac
    rest="${cmd#git commit -m}"
    rest="$(input_trim "${rest}")"
    case "${rest}" in
        \"*\")
            rest="${rest#\"}"
            rest="${rest%\"}"
            ;;
        \'*\')
            rest="${rest#\'}"
            rest="${rest%\'}"
            ;;
        *)
            # Unescape forms such as First\ commit from printf %q.
            rest="$(printf '%s' "${rest}" | sed 's/\\ / /g')"
            ;;
    esac
    printf '%s\n' "${rest}"
    return 0
}

# Return 0 when typed and expected commit commands carry the same message.
lesson_match_commit_command() {
    local typed="$1"
    local expected="$2"
    local typed_msg
    local expected_msg

    typed_msg="$(lesson_commit_message_from_command "${typed}")" || return 1
    expected_msg="$(lesson_commit_message_from_command "${expected}")" || return 1
    if [ "${typed_msg}" = "${expected_msg}" ]; then
        return 0
    fi
    return 1
}
