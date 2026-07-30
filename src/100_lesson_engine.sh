# Lesson teaching engine. Student text is a knowledge check only.
# Implements: FR-050 through FR-054, FR-100 through FR-118.
#
# The lesson board redraws on each focus change (D-011).
# Mandatory pause applies when leaving a finished conceptual stage (D-013).

GS_LESSON_MODE="${GS_MODE_LEARN}"
GS_LESSON_NAME=""
GS_LESSON_ID=""
GS_LESSON_STEP=0
GS_LESSON_TOTAL=0
GS_LESSON_DONE=""
GS_LESSON_CURRENT=""
GS_LESSON_BOARD=1
GS_LESSON_STAGE_TITLES=()
GS_LESSON_STAGE_COUNT=0
GS_LESSON_STAGE_INDEX=0
GS_LESSON_STAGE_DONE=""
GS_LESSON_SUBSTEP=""
GS_LESSON_USE_STAGES=0

# Optional structured teaching fields for the current command (FR-114).
GS_TEACH_GOAL=""
GS_TEACH_CONCEPT=""
GS_TEACH_LOOK_FOR=""
GS_TEACH_HELP_FN=""
GS_TEACH_RESULT=""

# Session paths (FR-116, D-019). Set once at startup. Immutable after that.
GS_SESSION_START_DIR=""

lesson_session_record_start_dir() {
    local dir
    if ! dir="$(pwd -P 2>/dev/null)"; then
        dir="$(pwd)"
    fi
    GS_SESSION_START_DIR="${dir}"
}

lesson_current_dir_resolved() {
    pwd -P 2>/dev/null || pwd
}

lesson_path_resolve() {
    local path="$1"
    if [ ! -d "${path}" ]; then
        return 1
    fi
    (cd -- "${path}" && pwd -P 2>/dev/null) || (cd -- "${path}" && pwd)
}

lesson_paths_equal() {
    local a="$1"
    local b="$2"
    local ra
    local rb
    ra="$(lesson_path_resolve "${a}")" || return 1
    rb="$(lesson_path_resolve "${b}")" || return 1
    [ "${ra}" = "${rb}" ]
}

lesson_teach_reset_fields() {
    GS_TEACH_GOAL=""
    GS_TEACH_CONCEPT=""
    GS_TEACH_LOOK_FOR=""
    GS_TEACH_HELP_FN=""
    GS_TEACH_RESULT=""
}

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
    GS_LESSON_STAGE_TITLES=()
    GS_LESSON_STAGE_COUNT=0
    GS_LESSON_STAGE_INDEX=0
    GS_LESSON_STAGE_DONE=""
    GS_LESSON_SUBSTEP=""
    GS_LESSON_USE_STAGES=0
    lesson_teach_reset_fields
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

# Begin a lesson with conceptual stages (FR-115). Remaining args are stage titles.
lesson_begin_stages() {
    local name="$1"
    local id="$2"
    shift 2
    local title
    local count=0

    GS_LESSON_NAME="${name}"
    GS_LESSON_ID="${id}"
    GS_LESSON_STEP=0
    GS_LESSON_TOTAL=0
    GS_LESSON_DONE=""
    GS_LESSON_CURRENT=""
    GS_LESSON_STAGE_TITLES=()
    GS_LESSON_STAGE_COUNT=0
    GS_LESSON_STAGE_INDEX=0
    GS_LESSON_STAGE_DONE=""
    GS_LESSON_SUBSTEP=""
    GS_LESSON_USE_STAGES=1
    lesson_teach_reset_fields

    for title in "$@"; do
        GS_LESSON_STAGE_TITLES[count]="${title}"
        count=$((count + 1))
    done
    GS_LESSON_STAGE_COUNT="${count}"
    GS_LESSON_TOTAL="${count}"

    if [ "${GS_TERM_IS_TTY}" = "1" ] && [ "${GS_TERM_PLAIN}" != "1" ]; then
        GS_LESSON_BOARD=1
    else
        GS_LESSON_BOARD=0
    fi
    lesson_draw_board
    if [ "${GS_LESSON_MODE}" = "${GS_MODE_ASSISTED}" ]; then
        ui_muted "Assisted mode: confirm each command. Type ? or choose help for detail."
    else
        ui_muted "Learn mode: type each command. Type ? for detailed help."
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

# Draw conceptual stage board or legacy step board.
lesson_draw_board() {
    local line
    local n
    local i
    local title
    local remaining

    lesson_clear_board
    ui_title "Lesson: ${GS_LESSON_NAME}"
    ui_blank

    if [ "${GS_LESSON_USE_STAGES}" = "1" ]; then
        if [ -n "${GS_LESSON_STAGE_DONE}" ]; then
            while IFS= read -r line; do
                [ -n "${line}" ] || continue
                printf '%s  [ok] %s%s\n' "${GS_UI_MUTED}" "${line}" "${GS_UI_RESET}"
            done <<EOF
${GS_LESSON_STAGE_DONE}
EOF
        fi

        if [ "${GS_LESSON_STAGE_INDEX}" -gt 0 ] 2>/dev/null && [ "${GS_LESSON_STAGE_INDEX}" -le "${GS_LESSON_STAGE_COUNT}" ] 2>/dev/null; then
            i=$((GS_LESSON_STAGE_INDEX - 1))
            title="${GS_LESSON_STAGE_TITLES[i]}"
            printf '%s%s  [NOW] %s%s\n' "${GS_UI_BOLD}" "${GS_UI_ACCENT}" "${title}" "${GS_UI_RESET}"
            if [ -n "${GS_LESSON_SUBSTEP}" ]; then
                printf '%s        > %s%s\n' "${GS_UI_MUTED}" "${GS_LESSON_SUBSTEP}" "${GS_UI_RESET}"
            fi
        fi

        remaining=0
        i="${GS_LESSON_STAGE_INDEX}"
        while [ "${i}" -lt "${GS_LESSON_STAGE_COUNT}" ] 2>/dev/null; do
            remaining=$((remaining + 1))
            i=$((i + 1))
        done
        if [ "${remaining}" -gt 0 ] 2>/dev/null; then
            i="${GS_LESSON_STAGE_INDEX}"
            while [ "${i}" -lt "${GS_LESSON_STAGE_COUNT}" ] 2>/dev/null; do
                title="${GS_LESSON_STAGE_TITLES[i]}"
                printf '%s  .... %s%s\n' "${GS_UI_MUTED}" "${title}" "${GS_UI_RESET}"
                i=$((i + 1))
                # Keep the board short on narrow terminals.
                if [ "${GS_TERM_WIDTH}" -lt "${GS_LIMIT_NARROW_COLS}" ] 2>/dev/null; then
                    n=$((GS_LESSON_STAGE_COUNT - i))
                    if [ "${n}" -gt 0 ] 2>/dev/null; then
                        printf '%s  .... %s more%s\n' "${GS_UI_MUTED}" "${n}" "${GS_UI_RESET}"
                    fi
                    break
                fi
            done
        fi
    else
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

# Enter a conceptual stage. Pause when leaving a previous finished stage.
lesson_stage_begin() {
    local title="$1"
    local prev_title
    local i

    if [ "${GS_LESSON_USE_STAGES}" != "1" ]; then
        lesson_step_begin "${title}"
        return 0
    fi

    if [ "${GS_LESSON_STAGE_INDEX}" -gt 0 ] 2>/dev/null; then
        i=$((GS_LESSON_STAGE_INDEX - 1))
        prev_title="${GS_LESSON_STAGE_TITLES[i]}"
        if [ "${prev_title}" != "${title}" ]; then
            lesson_pause_continue
            if [ -n "${GS_LESSON_STAGE_DONE}" ]; then
                GS_LESSON_STAGE_DONE="${GS_LESSON_STAGE_DONE}
${prev_title}"
            else
                GS_LESSON_STAGE_DONE="${prev_title}"
            fi
        fi
    fi

    i=0
    while [ "${i}" -lt "${GS_LESSON_STAGE_COUNT}" ]; do
        if [ "${GS_LESSON_STAGE_TITLES[i]}" = "${title}" ]; then
            GS_LESSON_STAGE_INDEX=$((i + 1))
            GS_LESSON_STEP="${GS_LESSON_STAGE_INDEX}"
            GS_LESSON_SUBSTEP=""
            GS_LESSON_CURRENT="${title}"
            lesson_draw_board
            return 0
        fi
        i=$((i + 1))
    done

    # Unknown title: treat as linear step fallback.
    GS_LESSON_SUBSTEP=""
    lesson_focus "${title}"
}

# Set the current substep inside a conceptual stage. No mandatory pause.
lesson_substep_begin() {
    local title="$1"
    GS_LESSON_SUBSTEP="${title}"
    lesson_draw_board
}

# Print structured teaching labels (FR-114). Markers work without color.
lesson_show_teach_sections() {
    local expected="$1"

    if [ -n "${GS_TEACH_GOAL}" ]; then
        ui_print "GOAL"
        ui_muted "${GS_TEACH_GOAL}"
        ui_blank
    fi
    if [ -n "${GS_TEACH_CONCEPT}" ]; then
        ui_print "CONCEPT"
        ui_muted "${GS_TEACH_CONCEPT}"
        ui_blank
    fi
    ui_print "TYPE"
    ui_command "${expected}"
    ui_blank
    if [ -n "${GS_TEACH_LOOK_FOR}" ]; then
        ui_print "LOOK FOR"
        ui_muted "${GS_TEACH_LOOK_FOR}"
        ui_blank
    elif [ -n "${GS_TEACH_RESULT}" ]; then
        ui_print "LOOK FOR"
        ui_muted "${GS_TEACH_RESULT}"
        ui_blank
    fi
}

# Show detailed help without completing or running the command (FR-110).
lesson_show_detailed_help() {
    local expected="$1"
    local why="$2"
    local result_text="$3"

    lesson_clear_board
    ui_title "Detailed help"
    ui_blank
    if [ -n "${GS_TEACH_HELP_FN}" ]; then
        "${GS_TEACH_HELP_FN}" "${expected}" || true
    else
        ui_print "GOAL"
        ui_muted "${GS_TEACH_GOAL:-${why}}"
        ui_blank
        ui_print "CONCEPT"
        ui_muted "${GS_TEACH_CONCEPT:-${why}}"
        ui_blank
        ui_print "COMMAND"
        ui_command "${expected}"
        ui_blank
        ui_print "AFTER"
        ui_muted "${GS_TEACH_LOOK_FOR:-${result_text:-Read the command output.}}"
        ui_blank
        ui_print "COMMON MISTAKES"
        ui_muted "Do not change the command spelling."
        ui_muted "Do not add extra options unless the lesson shows them."
    fi
    ui_blank
    lesson_pause_continue
}

# Redisplay the normal command screen after help or a mismatch.
lesson_redisplay_command() {
    local expected="$1"
    local why="$2"
    local result_text="$3"

    lesson_draw_board
    if [ -n "${GS_TEACH_GOAL}" ] || [ -n "${GS_TEACH_CONCEPT}" ]; then
        lesson_show_teach_sections "${expected}"
    else
        ui_info "Why: ${why}"
        if [ -n "${result_text}" ]; then
            ui_muted "What happens: ${result_text}"
        fi
        ui_print "Type this command:"
        ui_command "${expected}"
    fi
    if [ "${GS_LESSON_MODE}" = "${GS_MODE_ASSISTED}" ]; then
        ui_muted "Tip: h = detailed help. n = stop."
    else
        ui_muted "Tip: ? detailed help, q stop."
    fi
}

# Teach an exact command. On success, call the runner function name in $2.
# Optional $5: name of an alternate matcher function (typed, expected) -> status.
# Optional structured fields: set GS_TEACH_* before calling.
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
    local assist_choice

    if [ -z "${GS_TEACH_RESULT}" ] && [ -n "${result_text}" ]; then
        GS_TEACH_RESULT="${result_text}"
    fi

    lesson_redisplay_command "${expected}" "${why}" "${result_text}"

    expected_norm="$(input_normalize_command "${expected}")"

    if [ "${GS_LESSON_MODE}" = "${GS_MODE_ASSISTED}" ]; then
        while true; do
            ui_print "1) Run the command"
            ui_print "2) Show detailed help"
            ui_print "3) Stop"
            input_choice 3 "Select a number: " || return 1
            assist_choice="${GS_INPUT_LAST}"
            case "${assist_choice}" in
                1)
                    break
                    ;;
                2)
                    lesson_show_detailed_help "${expected}" "${why}" "${result_text}"
                    lesson_redisplay_command "${expected}" "${why}" "${result_text}"
                    ;;
                3)
                    ui_stopped "Stopped before the command ran."
                    ui_next "Start the lesson again when you are ready."
                    lesson_teach_reset_fields
                    return 1
                    ;;
            esac
        done
    else
        while true; do
            input_read_line "> " || return 1
            typed="$(input_trim "${GS_INPUT_LAST}")"
            case "${typed}" in
                \?)
                    lesson_show_detailed_help "${expected}" "${why}" "${result_text}"
                    lesson_redisplay_command "${expected}" "${why}" "${result_text}"
                    continue
                    ;;
                q|Q)
                    ui_stopped "Stopped before the command ran."
                    ui_next "Start the lesson again when you are ready."
                    lesson_teach_reset_fields
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
            ui_muted "Tip: ? detailed help, q stop. Code: ${GS_CODE_LESSON_CMD}"
        done
    fi

    if ! "${runner}"; then
        ui_fail_detail \
            "The operation did not complete." \
            "${expected}" \
            "The command exit status was ${GS_GIT_LAST_STATUS:-unknown}." \
            "Read the message above. Fix the issue. Run the lesson again." \
            "${GS_CODE_GIT_STATE}"
        lesson_teach_reset_fields
        return 1
    fi
    ui_success "Done."
    lesson_teach_reset_fields
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

# Explain child-shell directory behavior when the selected folder differs
# from the immutable session start directory (FR-118, D-019).
lesson_explain_child_shell_if_needed() {
    local cd_cmd
    local selected="${GS_PICKER_SELECTED:-}"

    if [ -z "${selected}" ] || [ -z "${GS_SESSION_START_DIR}" ]; then
        return 0
    fi
    if lesson_paths_equal "${selected}" "${GS_SESSION_START_DIR}"; then
        return 0
    fi
    ui_blank
    ui_info "GitStart used this project folder during the lesson:"
    ui_print "${selected}"
    ui_info "When GitStart closes, your normal terminal returns to the folder where you started it."
    if cd_cmd="$(lesson_format_cd_command "${selected}")"; then
        ui_info "To open this project again, use:"
        ui_command "${cd_cmd}"
    fi
}

lesson_complete() {
    local i
    if [ "${GS_LESSON_USE_STAGES}" = "1" ]; then
        if [ "${GS_LESSON_STAGE_INDEX}" -gt 0 ] 2>/dev/null; then
            lesson_pause_continue
            i=$((GS_LESSON_STAGE_INDEX - 1))
            if [ -n "${GS_LESSON_STAGE_DONE}" ]; then
                GS_LESSON_STAGE_DONE="${GS_LESSON_STAGE_DONE}
${GS_LESSON_STAGE_TITLES[i]}"
            else
                GS_LESSON_STAGE_DONE="${GS_LESSON_STAGE_TITLES[i]}"
            fi
            GS_LESSON_STAGE_INDEX=0
            GS_LESSON_SUBSTEP=""
            GS_LESSON_CURRENT=""
        fi
        GS_LESSON_STEP="${GS_LESSON_STAGE_COUNT}"
    else
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
    fi
    lesson_draw_board
    ui_complete "Finished: ${GS_LESSON_NAME}"
    lesson_explain_child_shell_if_needed
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

# Explain a failed remote Git step using the conservative classifier (FR-287).
lesson_explain_remote_failure() {
    local step_name="$1"
    git_explain_remote_failure "${step_name}" "${GS_STATE_RELATION:-}"
}

# Build a student-friendly path for display. Prefer ~/ when under HOME.
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

# Format a cd command that works when copied into Bash (FR-089, D-019).
# Return 0 and print the command. Return 1 when the path is unsupported.
lesson_format_cd_command() {
    local dir="$1"
    local home="${HOME:-}"
    local home_res=""
    local relative
    local resolved

    case "${dir}" in
        *[[:cntrl:]]*)
            return 1
            ;;
        "")
            return 1
            ;;
    esac

    if [ -d "${dir}" ]; then
        resolved="$(lesson_path_resolve "${dir}")" || resolved="${dir}"
    else
        resolved="${dir}"
    fi

    case "${resolved}" in
        *[[:cntrl:]]*)
            return 1
            ;;
    esac

    if [ -n "${home}" ] && [ -d "${home}" ]; then
        home_res="$(lesson_path_resolve "${home}")" || home_res="${home}"
    elif [ -n "${home}" ]; then
        home_res="${home}"
    fi

    if [ -n "${home_res}" ]; then
        if [ "${resolved}" = "${home_res}" ]; then
            printf 'cd -- ~\n'
            return 0
        fi
        case "${resolved}" in
            "${home_res}"/*)
                relative="${resolved#"${home_res}"/}"
                # Keep ~/ unquoted. Escape only the remainder (Bash 3.2).
                # shellcheck disable=SC2088
                printf 'cd -- ~/%q\n' "${relative}"
                return 0
                ;;
        esac
    fi

    printf 'cd -- %q\n' "${resolved}"
    return 0
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

# Exact normalized match only for cd (FR-104, FR-105). No weak path resolution.
lesson_match_cd_command() {
    local typed="$1"
    local expected="$2"
    if [ "${typed}" = "${expected}" ]; then
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

# Show staged paths from porcelain status (FR-171). Prefer names over a count.
lesson_show_staged_paths() {
    local line
    local first
    local path
    local count=0

    if ! git_cmd_status_porcelain; then
        ui_warning "Could not read staged file names."
        return 1
    fi
    ui_info "Look for: Changes to be committed."
    ui_info "Staged paths:"
    while IFS= read -r line; do
        [ -n "${line}" ] || continue
        first="$(printf '%s' "${line}" | cut -c1)"
        case "${first}" in
            ' '|'?'|'')
                continue
                ;;
        esac
        path="${line#??}"
        path="$(input_trim "${path}")"
        case "${path}" in
            *' -> '*)
                path="${path##* -> }"
                ;;
        esac
        ui_print "  ${path}"
        count=$((count + 1))
    done <<EOF
${GS_GIT_LAST_STDOUT}
EOF
    if [ "${count}" = "0" ]; then
        ui_muted "No staged paths were reported."
    fi
    return 0
}
