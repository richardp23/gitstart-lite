#!/usr/bin/env bash
# GitStart Lite — local Git teaching tool
# Copyright (c) 2026 GitStart contributors
# SPDX-License-Identifier: MIT
#
# This file is generated from source modules. Do not edit the release by hand.

set -u
set -o pipefail

# --- 10_constants.sh ---
# Application constants. Do not put mutable state in this module.

GS_APP_NAME="GitStart Lite"
GS_APP_VERSION="0.4.0"
GS_APP_ID="gitstart-lite"

# Teaching limits
GS_LIMIT_COMMIT_MSG=72
GS_LIMIT_PREVIEW_ENTRIES=6
GS_LIMIT_NARROW_COLS=70
GS_LIMIT_WIDE_COLS=100

# Lesson identifiers
GS_LESSON_INIT="initialize"
GS_LESSON_COMMIT_PUSH="commit_push"
GS_LESSON_UPDATE="update_clone"
GS_LESSON_FORK="sync_fork"
GS_LESSON_DIAGNOSE="diagnose"

# Diagnostic code groups (stable IDs)
# Bootstrap codes are emitted by site/run; keep them in this catalog.
# shellcheck disable=SC2034
GS_CODE_BOOT_CHECKSUM="GS-BOOT-001"
# shellcheck disable=SC2034
GS_CODE_BOOT_DOWNLOAD="GS-BOOT-002"
GS_CODE_TERM_INPUT="GS-TERM-001"
GS_CODE_PATH_INVALID="GS-PATH-001"
GS_CODE_PATH_DANGEROUS="GS-PATH-002"
GS_CODE_GIT_MISSING="GS-GIT-001"
GS_CODE_GIT_STATE="GS-GIT-002"
GS_CODE_GIT_IDENTITY="GS-GIT-003"
GS_CODE_NET_OFFLINE="GS-NET-001"
GS_CODE_NET_TLS="GS-NET-002"
GS_CODE_AUTH_REQUIRED="GS-AUTH-001"
GS_CODE_AUTH_PERMISSION="GS-AUTH-002"
GS_CODE_GIT_REMOTE_NOT_FOUND="GS-GIT-004"
GS_CODE_GIT_NON_FF="GS-GIT-005"
GS_CODE_SAFE_STOP="GS-SAFE-001"
GS_CODE_SAFE_SECRET="GS-SAFE-002"
GS_CODE_SAFE_DIVERGED="GS-SAFE-003"
# Reserved when histories cannot merge safely (MVP stops before auto-merge).
# shellcheck disable=SC2034
GS_CODE_SAFE_UNRELATED="GS-SAFE-004"
GS_CODE_LESSON_CMD="GS-LESSON-001"
GS_CODE_INTERNAL="GS-INTERNAL-001"

# Mode values
GS_MODE_LEARN="learn"
GS_MODE_ASSISTED="assisted"

# --- 20_terminal.sh ---
# Terminal capability detection, color control, and cleanup traps.
# Implements: FR-020 through FR-031, FR-040 through FR-048, NFR-100, NFR-101.

GS_TERM_IS_TTY=0
GS_TERM_WIDTH=80
GS_TERM_COLOR=0
GS_TERM_UNICODE=1
GS_TERM_ANIMATION=1
GS_TERM_PLAIN=0
GS_TERM_ASCII=0
GS_TERM_SINGLE_KEY=0
GS_TERM_STTY_SAVED=""
GS_TERM_CLEANED=0

# Restore terminal echo and cursor. Safe to call more than one time.
terminal_cleanup() {
    if [ "${GS_TERM_CLEANED}" = "1" ]; then
        # Still force cooked mode: a prior restore may have failed on Git Bash.
        stty echo icanon 2>/dev/null || stty sane 2>/dev/null || true
        printf '\033[?25h' >/dev/tty 2>/dev/null || printf '\033[?25h' 2>/dev/null || true
        return 0
    fi
    GS_TERM_CLEANED=1
    if [ -n "${GS_TERM_STTY_SAVED}" ]; then
        stty "${GS_TERM_STTY_SAVED}" 2>/dev/null || true
    fi
    stty echo icanon 2>/dev/null || stty sane 2>/dev/null || true
    printf '\033[?25h' >/dev/tty 2>/dev/null || printf '\033[?25h' 2>/dev/null || true
}

# Install cleanup for normal exit and common signals.
terminal_install_traps() {
    trap 'terminal_cleanup' EXIT
    trap 'terminal_cleanup; exit 130' INT
    trap 'terminal_cleanup; exit 143' TERM
    trap 'terminal_cleanup; exit 129' HUP
}

# Detect whether standard output is a terminal.
terminal_is_tty() {
    if [ -t 1 ]; then
        return 0
    fi
    return 1
}

# Read terminal width. Prefer tput. Fall back to COLUMNS or 80.
terminal_get_width() {
    local width
    width=""
    if command -v tput >/dev/null 2>&1; then
        width="$(tput cols 2>/dev/null || true)"
    fi
    if [ -z "${width}" ] || [ "${width}" -lt 20 ] 2>/dev/null; then
        width="${COLUMNS:-80}"
    fi
    if [ -z "${width}" ] || [ "${width}" -lt 20 ] 2>/dev/null; then
        width=80
    fi
    printf '%s\n' "${width}"
}

# Return 0 when color output is allowed.
terminal_supports_color() {
    if [ "${GS_TERM_PLAIN}" = "1" ]; then
        return 1
    fi
    if [ "${GS_TERM_COLOR}" != "1" ]; then
        return 1
    fi
    if [ -n "${NO_COLOR:-}" ]; then
        return 1
    fi
    if [ "${GS_TERM_IS_TTY}" != "1" ]; then
        return 1
    fi
    case "${TERM:-}" in
        dumb|"")
            return 1
            ;;
    esac
    return 0
}

# Return 0 when single-key raw input is available.
terminal_supports_single_key() {
    if [ "${GS_TERM_IS_TTY}" != "1" ]; then
        return 1
    fi
    if [ "${GS_TERM_PLAIN}" = "1" ]; then
        return 1
    fi
    if ! command -v stty >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

terminal_hide_cursor() {
    if [ "${GS_TERM_IS_TTY}" = "1" ] && [ "${GS_TERM_PLAIN}" != "1" ]; then
        printf '\033[?25l'
    fi
}

terminal_show_cursor() {
    printf '\033[?25h'
}

terminal_clear_line() {
    if [ "${GS_TERM_PLAIN}" = "1" ]; then
        printf '\n'
        return 0
    fi
    printf '\r\033[K'
}

# Initialize terminal state from environment and flags already set in GS_TERM_*.
terminal_init() {
    GS_TERM_CLEANED=0
    if terminal_is_tty; then
        GS_TERM_IS_TTY=1
    else
        GS_TERM_IS_TTY=0
    fi

    GS_TERM_WIDTH="$(terminal_get_width)"

    if [ -n "${NO_COLOR:-}" ]; then
        GS_TERM_COLOR=0
    elif [ "${GS_TERM_PLAIN}" = "1" ]; then
        GS_TERM_COLOR=0
    elif [ "${GS_TERM_IS_TTY}" = "1" ]; then
        case "${TERM:-}" in
            dumb|"")
                GS_TERM_COLOR=0
                ;;
            *)
                if [ "${GS_TERM_COLOR}" != "0" ]; then
                    GS_TERM_COLOR=1
                fi
                ;;
        esac
    else
        GS_TERM_COLOR=0
    fi

    if [ "${GS_TERM_ASCII}" = "1" ] || [ "${GS_TERM_PLAIN}" = "1" ]; then
        GS_TERM_UNICODE=0
    fi

    if [ "${GS_TERM_PLAIN}" = "1" ] || [ "${TERM:-}" = "dumb" ] || [ "${GS_TERM_IS_TTY}" != "1" ]; then
        GS_TERM_ANIMATION=0
    fi

    if terminal_supports_single_key; then
        GS_TERM_SINGLE_KEY=1
        GS_TERM_STTY_SAVED="$(stty -g 2>/dev/null || true)"
    else
        GS_TERM_SINGLE_KEY=0
    fi

    terminal_install_traps
}

# --- 30_text.sh ---
# User-interface text helpers and startup artwork.
# Implements: FR-040 through FR-046, NFR-001 through NFR-006, NFR-020 through NFR-025.

GS_UI_RESET=""
GS_UI_BOLD=""
GS_UI_ACCENT=""
GS_UI_SUCCESS=""
GS_UI_WARNING=""
GS_UI_ERROR=""
GS_UI_INFO=""
GS_UI_MUTED=""

# Load style codes when color is enabled.
ui_init_styles() {
    if terminal_supports_color; then
        GS_UI_RESET="$(printf '\033[0m')"
        GS_UI_BOLD="$(printf '\033[1m')"
        GS_UI_ACCENT="$(printf '\033[38;5;39m')"
        GS_UI_SUCCESS="$(printf '\033[38;5;40m')"
        GS_UI_WARNING="$(printf '\033[38;5;214m')"
        GS_UI_ERROR="$(printf '\033[38;5;196m')"
        GS_UI_INFO="$(printf '\033[38;5;45m')"
        GS_UI_MUTED="$(printf '\033[38;5;245m')"
    else
        GS_UI_RESET=""
        GS_UI_BOLD=""
        GS_UI_ACCENT=""
        GS_UI_SUCCESS=""
        GS_UI_WARNING=""
        GS_UI_ERROR=""
        GS_UI_INFO=""
        GS_UI_MUTED=""
    fi
}

ui_print() {
    printf '%s\n' "$*"
}

ui_blank() {
    printf '\n'
}

ui_title() {
    printf '%s%s%s\n' "${GS_UI_BOLD}${GS_UI_ACCENT}" "$*" "${GS_UI_RESET}"
}

ui_info() {
    printf '%s[INFO]%s %s\n' "${GS_UI_INFO}" "${GS_UI_RESET}" "$*"
}

ui_success() {
    printf '%s[SUCCESS]%s %s\n' "${GS_UI_SUCCESS}" "${GS_UI_RESET}" "$*"
}

ui_warning() {
    printf '%s[WARNING]%s %s\n' "${GS_UI_WARNING}" "${GS_UI_RESET}" "$*"
}

ui_error() {
    printf '%s[ERROR]%s %s\n' "${GS_UI_ERROR}" "${GS_UI_RESET}" "$*" >&2
}

ui_stopped() {
    printf '%s[STOPPED]%s %s\n' "${GS_UI_ERROR}" "${GS_UI_RESET}" "$*"
}

ui_next() {
    printf '%s[NEXT]%s %s\n' "${GS_UI_ACCENT}" "${GS_UI_RESET}" "$*"
}

# Mark the active lesson step so it stands out from scrollback.
ui_step() {
    local width
    local rule
    width="${GS_TERM_WIDTH:-40}"
    if [ "${width}" -gt 48 ] 2>/dev/null; then
        width=48
    fi
    if [ "${width}" -lt 20 ] 2>/dev/null; then
        width=20
    fi
    if [ "${GS_TERM_UNICODE:-1}" = "1" ] && [ "${GS_TERM_ASCII:-0}" != "1" ] && [ "${GS_TERM_PLAIN:-0}" != "1" ]; then
        rule="$(printf '%*s' "${width}" '' | sed 's/ /─/g')"
    else
        rule="$(printf '%*s' "${width}" '' | sed 's/ /=/g')"
    fi
    ui_blank
    printf '%s%s%s\n' "${GS_UI_MUTED}" "${rule}" "${GS_UI_RESET}"
    printf '%s%s[NOW]%s %s%s%s\n' "${GS_UI_BOLD}" "${GS_UI_ACCENT}" "${GS_UI_RESET}" "${GS_UI_BOLD}" "$*" "${GS_UI_RESET}"
    printf '%s%s%s\n' "${GS_UI_MUTED}" "${rule}" "${GS_UI_RESET}"
}

ui_complete() {
    printf '%s[COMPLETE]%s %s\n' "${GS_UI_SUCCESS}" "${GS_UI_RESET}" "$*"
}

ui_review() {
    printf '%s[REVIEW]%s %s\n' "${GS_UI_WARNING}" "${GS_UI_RESET}" "$*"
}

ui_muted() {
    printf '%s%s%s\n' "${GS_UI_MUTED}" "$*" "${GS_UI_RESET}"
}

ui_command() {
    printf '%s  %s%s\n' "${GS_UI_BOLD}" "$*" "${GS_UI_RESET}"
}

ui_help() {
    printf '%s[HELP]%s %s\n' "${GS_UI_INFO}" "${GS_UI_RESET}" "$*"
}

# Show a structured stop message with a diagnostic code.
# Usage: ui_fail_detail "title" "operation" "reason" "next_action" "code"
ui_fail_detail() {
    local title="$1"
    local operation="$2"
    local reason="$3"
    local next_action="$4"
    local code="$5"
    ui_stopped "${title}"
    ui_print "Operation: ${operation}"
    ui_print "Reason: ${reason}"
    ui_print "Your local work is safe."
    ui_next "${next_action}"
    ui_muted "Code: ${code}"
}

# Show ASCII or Unicode startup art. Skip in plain mode on a narrow terminal.
ui_show_banner() {
    if [ "${GS_TERM_ANIMATION}" != "1" ]; then
        ui_title "${GS_APP_NAME} ${GS_APP_VERSION}"
        ui_muted "id: ${GS_APP_ID}"
        return 0
    fi
    if [ "${GS_TERM_PLAIN}" = "1" ] && [ "${GS_TERM_WIDTH}" -lt 50 ] 2>/dev/null; then
        ui_title "${GS_APP_NAME} ${GS_APP_VERSION}"
        return 0
    fi
    if [ "${GS_TERM_UNICODE}" = "1" ]; then
        printf '%s\n' "${GS_UI_ACCENT}"
        cat <<'EOF'
   ____ _ _   ____  _             _
  / ___(_) |_| ___| |_ __ _ _ __| |_
 | |  _| | __|___ \ __/ _` | '__| __|
 | |_| | | |_ ___) | || (_| | |  | |_
  \____|_|\__|____/ \__\__,_|_|   \__|
EOF
        printf '%s\n' "${GS_UI_RESET}"
    else
        cat <<'EOF'
  GitStart Lite
  ------------
EOF
    fi
    ui_muted "Version ${GS_APP_VERSION} (${GS_APP_ID})"
    ui_muted "Learn Git with real commands."
    ui_blank
}

ui_show_help_text() {
    cat <<EOF
${GS_APP_NAME} ${GS_APP_VERSION} (${GS_APP_ID})

Usage:
  bash gitstart.sh [options]

Options:
  --learn          Use Learn mode (default). Type each teaching command.
  --assisted       Use Assisted mode. Confirm each teaching command.
  --no-color       Disable color output.
  --plain          Use plain text without color art and animation.
  --ascii          Use ASCII art instead of Unicode art.
  --no-animation   Disable optional animation.
  --version        Show the version and exit.
  --help           Show this help text and exit.

Learn mode is the default mode.
EOF
}

# --- 40_input.sh ---
# Input helpers. Student text is data only. Never execute it as code.
# Implements: FR-064 through FR-066, FR-075, FR-103, FR-111.

GS_INPUT_LAST=""

# Discard unread terminal bytes (arrow leftovers after raw key reads).
# Git Bash: read -t 0 may "succeed" with an empty result forever — bound the loop.
# Never use a blocking read here: that eats the next real key and can leave
# the terminal in raw mode if interrupted.
input_drain_tty() {
    local junk
    local n=0
    local max=64
    if [ "${GS_TERM_SINGLE_KEY:-0}" != "1" ]; then
        return 0
    fi
    stty -echo -icanon time 0 min 0 2>/dev/null || return 0
    while [ "${n}" -lt "${max}" ]; do
        if ! IFS= read -r -n 1 -t 0 junk 2>/dev/null; then
            break
        fi
        # Byte was discarded; silence unused-variable lint.
        : "${junk}"
        n=$((n + 1))
    done
    input_restore_tty
}

# Restore cooked terminal settings. Safe after raw or drain modes.
input_restore_tty() {
    if [ -n "${GS_TERM_STTY_SAVED:-}" ]; then
        stty "${GS_TERM_STTY_SAVED}" 2>/dev/null || true
    fi
    # Reinforce on Git Bash when saved settings fail to apply.
    stty echo icanon 2>/dev/null || true
}

# Read one full line into GS_INPUT_LAST. Return 1 on EOF.
# Does not drain first: a buffered Enter may answer "Press Enter to continue".
input_read_line() {
    local prompt="${1:-}"
    GS_INPUT_LAST=""
    if [ -n "${prompt}" ]; then
        printf '%s' "${prompt}" >/dev/tty 2>/dev/null || printf '%s' "${prompt}"
    fi
    if ! IFS= read -r GS_INPUT_LAST </dev/tty 2>/dev/null; then
        if ! IFS= read -r GS_INPUT_LAST; then
            ui_muted "Code: ${GS_CODE_TERM_INPUT}"
            return 1
        fi
    fi
    return 0
}

# Read one key when raw mode is available. Sets GS_INPUT_LAST to a token:
# up, down, left, right, enter, backspace, esc, or a single character.
# Bash 3.2 (macOS /bin/bash) rejects fractional read -t values such as 0.1.
# Escape-sequence tails use stty VTIME (tenths of a second) instead.
input_read_key() {
    local key
    local rest
    GS_INPUT_LAST=""
    if [ "${GS_TERM_SINGLE_KEY}" != "1" ]; then
        return 1
    fi
    stty -echo -icanon time 0 min 1 2>/dev/null || return 1
    IFS= read -r -n 1 key </dev/tty || {
        input_restore_tty
        return 1
    }
    if [ "${key}" = $'\033' ]; then
        # Wait up to 0.1s for CSI bytes. Do not use fractional read timeouts.
        stty -echo -icanon time 1 min 0 2>/dev/null || true
        IFS= read -r -n 1 rest </dev/tty || rest=""
        if [ "${rest}" = "[" ]; then
            IFS= read -r -n 1 rest </dev/tty || rest=""
            case "${rest}" in
                A) GS_INPUT_LAST="up" ;;
                B) GS_INPUT_LAST="down" ;;
                C) GS_INPUT_LAST="right" ;;
                D) GS_INPUT_LAST="left" ;;
                *) GS_INPUT_LAST="esc" ;;
            esac
        else
            GS_INPUT_LAST="esc"
        fi
    elif [ "${key}" = "" ] || [ "${key}" = $'\n' ] || [ "${key}" = $'\r' ]; then
        GS_INPUT_LAST="enter"
    elif [ "${key}" = $'\x7f' ] || [ "${key}" = $'\b' ]; then
        GS_INPUT_LAST="backspace"
    else
        GS_INPUT_LAST="${key}"
    fi
    input_restore_tty
    return 0
}

# Ask for yes or no. Return 0 for yes, 1 for no.
input_confirm() {
    local prompt="${1:-Continue?}"
    local answer
    while true; do
        input_read_line "${prompt} [y/n]: " || return 1
        answer="$(printf '%s' "${GS_INPUT_LAST}" | tr '[:upper:]' '[:lower:]')"
        case "${answer}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) ui_info "Type y or n." ;;
        esac
    done
}

# Ask for a numbered choice from 1 to max. Store result in GS_INPUT_LAST.
input_choice() {
    local max="$1"
    local prompt="${2:-Select a number: }"
    local n
    while true; do
        input_read_line "${prompt}" || return 1
        n="${GS_INPUT_LAST}"
        case "${n}" in
            ''|*[!0-9]*)
                ui_info "Type a number from 1 to ${max}."
                continue
                ;;
        esac
        if [ "${n}" -ge 1 ] 2>/dev/null && [ "${n}" -le "${max}" ] 2>/dev/null; then
            GS_INPUT_LAST="${n}"
            return 0
        fi
        ui_info "Type a number from 1 to ${max}."
    done
}

# Ask for non-empty text data. Store in GS_INPUT_LAST.
input_text() {
    local prompt="${1:-Enter text: }"
    local allow_empty="${2:-0}"
    while true; do
        input_read_line "${prompt}" || return 1
        if [ "${allow_empty}" = "1" ]; then
            return 0
        fi
        case "${GS_INPUT_LAST}" in
            *[![:space:]]*) return 0 ;;
            *) ui_info "Enter a value that is not empty." ;;
        esac
    done
}

# Trim leading and trailing spaces. Print result on stdout.
input_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "${s}"
}

# Normalize a teaching command for comparison. Print result on stdout.
# Remove leading and trailing spaces. Collapse repeated spaces outside quotes
# is not fully parsed; MVP uses simple trim and space collapse for unquoted text.
input_normalize_command() {
    local s
    s="$(input_trim "$1")"
    # Collapse repeated spaces for simple unquoted commands.
    while printf '%s' "${s}" | grep -q '  '; do
        s="$(printf '%s' "${s}" | sed 's/  / /g')"
    done
    printf '%s' "${s}"
}

# --- 60_fuzzy.sh ---
# Local fuzzy matcher for visible directory labels.
# Implements: FR-068 through FR-070.
#
# Lowercase once per call. Use Bash substring expansion in character loops.
# Do not call cut/tr/sed inside per-character loops.

# Score a candidate label against a query. Higher is better. Print score.
# Score bands: exact 10000, prefix 8000+, substring 5000+, ordered chars 1000+.
fuzzy_score() {
    local query="$1"
    local candidate="$2"
    local q_lower
    local c_lower
    local q_len
    local c_len
    local i
    local j
    local ch
    local gaps
    local first_pos
    local last_pos
    local slice

    # One lowercase pass each (external tr once, not per character).
    q_lower="$(printf '%s' "${query}" | tr '[:upper:]' '[:lower:]')"
    c_lower="$(printf '%s' "${candidate}" | tr '[:upper:]' '[:lower:]')"
    q_len="${#q_lower}"
    c_len="${#c_lower}"

    if [ "${q_len}" -eq 0 ]; then
        printf '1\n'
        return 0
    fi

    if [ "${c_lower}" = "${q_lower}" ]; then
        printf '10000\n'
        return 0
    fi

    case "${c_lower}" in
        "${q_lower}"*)
            printf '%s\n' "$((8000 + 100 - c_len))"
            return 0
            ;;
    esac

    case "${c_lower}" in
        *"${q_lower}"*)
            # Prefer earlier substring match. Bash slice avoids cut.
            first_pos=0
            i=0
            while [ "${i}" -le "$((c_len - q_len))" ]; do
                slice="${c_lower:${i}:${q_len}}"
                if [ "${slice}" = "${q_lower}" ]; then
                    first_pos="${i}"
                    break
                fi
                i=$((i + 1))
            done
            printf '%s\n' "$((5000 + 100 - first_pos - c_len / 10))"
            return 0
            ;;
    esac

    # Ordered character match.
    i=0
    j=0
    gaps=0
    first_pos=-1
    last_pos=-1
    while [ "${i}" -lt "${q_len}" ] && [ "${j}" -lt "${c_len}" ]; do
        ch="${q_lower:${i}:1}"
        while [ "${j}" -lt "${c_len}" ]; do
            if [ "${c_lower:${j}:1}" = "${ch}" ]; then
                if [ "${first_pos}" -lt 0 ]; then
                    first_pos="${j}"
                fi
                if [ "${last_pos}" -ge 0 ]; then
                    gaps=$((gaps + j - last_pos - 1))
                fi
                last_pos="${j}"
                j=$((j + 1))
                i=$((i + 1))
                break
            fi
            j=$((j + 1))
        done
    done

    if [ "${i}" -eq "${q_len}" ]; then
        printf '%s\n' "$((1000 + 100 - gaps - first_pos - c_len / 10))"
        return 0
    fi

    printf '0\n'
    return 0
}

# Return 0 when the candidate matches the query with a positive score.
fuzzy_match() {
    local score
    score="$(fuzzy_score "$1" "$2")"
    if [ "${score}" -gt 0 ] 2>/dev/null; then
        return 0
    fi
    return 1
}

# --- 50_picker.sh ---
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

# --- 70_git_exec.sh ---
# Sole Git execution layer. Never eval student text.
# Implements: FR-105 through FR-108, FR-280 through FR-282, FR-300 through FR-309.

GS_GIT_LAST_STATUS=0
GS_GIT_LAST_STDOUT=""
GS_GIT_REMOTE_ERROR_CLASS=""

# Return 0 when git is available.
git_is_available() {
    command -v git >/dev/null 2>&1
}

# Run a read-only Git command. Arguments are passed separately.
# Usage: git_run_readonly [git args...]
git_run_readonly() {
    GS_GIT_LAST_STATUS=0
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    git "$@"
    GS_GIT_LAST_STATUS=$?
    return "${GS_GIT_LAST_STATUS}"
}

# Capture stdout from a read-only Git command into GS_GIT_LAST_STDOUT.
git_capture() {
    local out
    local status
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    out="$(git "$@" 2>/dev/null)"
    status=$?
    GS_GIT_LAST_STATUS="${status}"
    GS_GIT_LAST_STDOUT="${out}"
    return "${status}"
}

# Capture stdout and status. Same as git_capture. Kept for API clarity.
git_capture_status() {
    git_capture "$@"
}

# Run a state-changing Git command with separate arguments.
# Lessons must confirm before calling this function.
# Filter common Windows CRLF notices so students see real errors first.
git_run_change() {
    local combined
    local filtered
    local crlf_count
    GS_GIT_LAST_STATUS=0
    GS_GIT_LAST_STDOUT=""
    if ! git_is_available; then
        GS_GIT_LAST_STATUS=127
        return 127
    fi
    combined="$(git "$@" 2>&1)"
    GS_GIT_LAST_STATUS=$?
    GS_GIT_LAST_STDOUT="${combined}"
    crlf_count=0
    filtered=""
    if [ -n "${combined}" ]; then
        while IFS= read -r line; do
            case "${line}" in
                *"LF will be replaced by CRLF"*)
                    crlf_count=$((crlf_count + 1))
                    ;;
                *)
                    if [ -n "${filtered}" ]; then
                        filtered="${filtered}
${line}"
                    else
                        filtered="${line}"
                    fi
                    ;;
            esac
        done <<EOF
${combined}
EOF
    fi
    if [ -n "${filtered}" ]; then
        printf '%s\n' "${filtered}"
    fi
    if [ "${crlf_count}" -gt 0 ] 2>/dev/null; then
        ui_muted "Git noted ${crlf_count} line-ending messages. This is common on Windows."
    fi
    return "${GS_GIT_LAST_STATUS}"
}

# Remove credentials from a remote URL for display. Print sanitized URL.
git_sanitize_remote_url() {
    local url="$1"
    # Remove userinfo before @ in URL forms.
    printf '%s\n' "${url}" | sed -E 's#(https?://)[^/@[:space:]]+@#\1#; s#(git://)[^/@[:space:]]+@#\1#; s#:[^/@[:space:]]+@#:@#'
}

# Validate an HTTPS Git remote URL. Return 0 when acceptable for MVP.
git_validate_https_url() {
    local url="$1"
    case "${url}" in
        *[[:cntrl:]]*)
            return 1
            ;;
        https://*@*|http://*@*)
            # Embedded userinfo is rejected in MVP.
            return 1
            ;;
        https://*.git|https://*)
            case "${url}" in
                https://*/*)
                    return 0
                    ;;
            esac
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Predefined safe Git operations used after command validation.

git_cmd_init() {
    git_run_change init
}

git_cmd_branch_rename_main() {
    git_run_change branch -M main
}

git_cmd_status() {
    git_run_readonly status
}

git_cmd_status_porcelain() {
    git_capture status --porcelain=v1
}

git_cmd_add_all() {
    git_run_change add -A
}

git_cmd_commit_message() {
    local message="$1"
    git_run_change commit -m "${message}"
}

git_cmd_remote_add() {
    local name="$1"
    local url="$2"
    git_run_change remote add "${name}" "${url}"
}

git_cmd_remote_verbose() {
    git_run_readonly remote -v
}

git_cmd_push_upstream() {
    local remote="$1"
    local branch="$2"
    git_run_change push -u "${remote}" "${branch}"
}

git_cmd_push() {
    local remote="$1"
    local branch="$2"
    git_run_change push "${remote}" "${branch}"
}

git_cmd_fetch() {
    local remote="${1:-}"
    if [ -n "${remote}" ]; then
        git_run_change fetch "${remote}"
    else
        git_run_change fetch
    fi
}

git_cmd_pull_ff_only() {
    git_run_change pull --ff-only
}

git_cmd_merge_ff_only() {
    local ref="$1"
    git_run_change merge --ff-only "${ref}"
}

git_cmd_config_get() {
    local key="$1"
    local scope="${2:-}"
    if [ "${scope}" = "local" ]; then
        git_capture config --local --get "${key}"
    elif [ "${scope}" = "global" ]; then
        git_capture config --global --get "${key}"
    else
        git_capture config --get "${key}"
    fi
}

git_cmd_config_set() {
    local key="$1"
    local value="$2"
    local scope="${3:-local}"
    if [ "${scope}" = "global" ]; then
        git_run_change config --global "${key}" "${value}"
    else
        git_run_change config --local "${key}" "${value}"
    fi
}

git_cmd_check_ref_format() {
    local branch="$1"
    git_run_readonly check-ref-format --branch "${branch}"
}

# Classify a failed remote Git operation. Print one category name.
# Categories: NETWORK TLS AUTHENTICATION PERMISSION REMOTE_NOT_FOUND
# NON_FAST_FORWARD DIVERGED UNKNOWN
# Uses exit status, message text, and optional relation hint. Does not guess.
# Usage: git_classify_remote_error STATUS MESSAGE [RELATION]
git_classify_remote_error() {
    local status="${1:-1}"
    local message="${2:-}"
    local relation="${3:-}"
    local lower

    lower="$(printf '%s' "${message}" | tr '[:upper:]' '[:lower:]')"

    # Strong relation evidence from prior state inspection.
    if [ "${relation}" = "DIVERGED" ]; then
        printf 'DIVERGED\n'
        return 0
    fi

    case "${lower}" in
        *"have diverged"*|*"diverged"*"merge"*|*"need to be merged"*)
            printf 'DIVERGED\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"non-fast-forward"*|*"fetch first"*|*"updates were rejected"*)
            printf 'NON_FAST_FORWARD\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"repository not found"*|*"repo not found"*)
            printf 'REMOTE_NOT_FOUND\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"write access"*|*"not allowed to push"*|*"protected branch"*|*"permission to"*"denied to push"*)
            printf 'PERMISSION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"authentication failed"*|*"invalid credentials"*|*"could not read username"*|*"terminal prompts disabled"*|*"http basic: access denied"*|*"401 unauthorized"*|*"auth failed"*)
            printf 'AUTHENTICATION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"permission denied (publickey)"*|*"permission denied"*|*"403 forbidden"*|*"access denied"*)
            printf 'AUTHENTICATION\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"ssl certificate"*|*"tls"*|*"schannel"*|*"revocation"*|*"certificate verify failed"*|*"ssl error"*|*"curl: (35)"*|*"curl: (60)"*)
            printf 'TLS\n'
            return 0
            ;;
    esac

    case "${lower}" in
        *"could not resolve host"*|*"name or service not known"*|*"nodename nor servname"*|*"temporary failure in name resolution"*|*"network is unreachable"*|*"no route to host"*|*"connection timed out"*|*"could not connect"*|*"connection refused"*|*"failed to connect"*)
            printf 'NETWORK\n'
            return 0
            ;;
    esac

    # Weak evidence: stay UNKNOWN (FR-287).
    : "${status}"
    printf 'UNKNOWN\n'
    return 0
}

# Explain a classified remote failure. Uses GS_GIT_LAST_* and optional relation.
# Usage: git_explain_remote_failure OPERATION [RELATION]
git_explain_remote_failure() {
    local operation="$1"
    local relation="${2:-${GS_STATE_RELATION:-}}"
    local reason
    local next
    local code

    GS_GIT_REMOTE_ERROR_CLASS="$(git_classify_remote_error "${GS_GIT_LAST_STATUS:-1}" "${GS_GIT_LAST_STDOUT:-}" "${relation}")"

    case "${GS_GIT_REMOTE_ERROR_CLASS}" in
        NETWORK)
            reason="The remote host was not reachable."
            next="Check your network connection. Run this lesson again."
            code="${GS_CODE_NET_OFFLINE}"
            ;;
        TLS)
            reason="A TLS or certificate check failed while contacting the remote."
            next="Check the system clock and certificate store. See troubleshooting docs. Run this lesson again."
            code="${GS_CODE_NET_TLS}"
            ;;
        AUTHENTICATION)
            reason="The remote rejected authentication."
            next="Sign in with your Git credential helper. GitStart does not request a password or token."
            code="${GS_CODE_AUTH_REQUIRED}"
            ;;
        PERMISSION)
            reason="Your account does not have permission for this remote action."
            next="Confirm the repository URL and your access rights. Ask an instructor if needed."
            code="${GS_CODE_AUTH_PERMISSION}"
            ;;
        REMOTE_NOT_FOUND)
            reason="The remote repository was not found."
            next="Confirm the HTTPS remote URL. Create the empty remote if it is missing."
            code="${GS_CODE_GIT_REMOTE_NOT_FOUND}"
            ;;
        NON_FAST_FORWARD)
            reason="The remote has commits that your branch does not have."
            next="Use the update lesson or diagnose. Do not force-push."
            code="${GS_CODE_GIT_NON_FF}"
            ;;
        DIVERGED)
            reason="The local and remote branches have diverged."
            next="Use diagnosis. Ask an instructor before you merge. Do not force-push."
            code="${GS_CODE_SAFE_DIVERGED}"
            ;;
        *)
            GS_GIT_REMOTE_ERROR_CLASS="UNKNOWN"
            reason="The remote command failed for an unclear reason."
            next="Read the Git message above. Use Diagnose, then ask an instructor if needed."
            code="${GS_CODE_GIT_STATE}"
            ;;
    esac

    ui_fail_detail \
        "Remote step failed: ${operation}" \
        "${operation}" \
        "${reason}" \
        "${next}" \
        "${code}"
    ui_muted "Class: ${GS_GIT_REMOTE_ERROR_CLASS}"
}

# --- 80_git_state.sh ---
# Read-only Git state inspection and classification.
# Implements: FR-120 through FR-130, SRS §11.

GS_STATE_IS_REPO=0
GS_STATE_ROOT=""
GS_STATE_BRANCH=""
GS_STATE_HAS_COMMIT=0
GS_STATE_IS_CLEAN=1
GS_STATE_REMOTE_COUNT=0
GS_STATE_HAS_ORIGIN=0
GS_STATE_HAS_UPSTREAM_REMOTE=0
GS_STATE_UPSTREAM=""
GS_STATE_AHEAD=0
GS_STATE_BEHIND=0
GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
GS_STATE_RELATION="UNKNOWN"
GS_STATE_DIRTY_COUNT=0

# Reset all state variables before inspection.
git_state_reset() {
    GS_STATE_IS_REPO=0
    GS_STATE_ROOT=""
    GS_STATE_BRANCH=""
    GS_STATE_HAS_COMMIT=0
    GS_STATE_IS_CLEAN=1
    GS_STATE_REMOTE_COUNT=0
    GS_STATE_HAS_ORIGIN=0
    GS_STATE_HAS_UPSTREAM_REMOTE=0
    GS_STATE_UPSTREAM=""
    GS_STATE_AHEAD=0
    GS_STATE_BEHIND=0
    GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
    GS_STATE_RELATION="UNKNOWN"
    GS_STATE_DIRTY_COUNT=0
}

# Inspect the current directory. Store results in GS_STATE_* variables.
git_state_inspect() {
    local out
    local remotes
    local counts
    local ahead
    local behind
    local porcelain

    git_state_reset

    if ! git_is_available; then
        GS_STATE_CLASS="UNKNOWN_OR_UNSAFE"
        return 1
    fi

    if ! git_capture rev-parse --is-inside-work-tree; then
        GS_STATE_CLASS="NOT_A_REPOSITORY"
        return 0
    fi
    if [ "${GS_GIT_LAST_STDOUT}" != "true" ]; then
        GS_STATE_CLASS="NOT_A_REPOSITORY"
        return 0
    fi

    GS_STATE_IS_REPO=1

    if git_capture rev-parse --show-toplevel; then
        GS_STATE_ROOT="${GS_GIT_LAST_STDOUT}"
    fi

    # Prefer branch --show-current. Fall back to rev-parse.
    if git_capture branch --show-current; then
        GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
    elif git_capture rev-parse --abbrev-ref HEAD; then
        if [ "${GS_GIT_LAST_STDOUT}" != "HEAD" ]; then
            GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
        fi
    fi

    if git_capture rev-parse --verify HEAD; then
        GS_STATE_HAS_COMMIT=1
    else
        GS_STATE_HAS_COMMIT=0
        GS_STATE_CLASS="REPOSITORY_NO_COMMIT"
    fi

    if git_capture status --porcelain=v1; then
        porcelain="${GS_GIT_LAST_STDOUT}"
        if [ -n "${porcelain}" ]; then
            GS_STATE_IS_CLEAN=0
            GS_STATE_DIRTY_COUNT="$(printf '%s\n' "${porcelain}" | grep -c '.' || true)"
        else
            GS_STATE_IS_CLEAN=1
            GS_STATE_DIRTY_COUNT=0
        fi
    fi

    remotes=""
    if git_capture remote; then
        remotes="${GS_GIT_LAST_STDOUT}"
    fi
    if [ -n "${remotes}" ]; then
        GS_STATE_REMOTE_COUNT="$(printf '%s\n' "${remotes}" | grep -c '.' || true)"
        if printf '%s\n' "${remotes}" | grep -qx 'origin'; then
            GS_STATE_HAS_ORIGIN=1
        fi
        if printf '%s\n' "${remotes}" | grep -qx 'upstream'; then
            GS_STATE_HAS_UPSTREAM_REMOTE=1
        fi
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "1" ] && [ "${GS_STATE_REMOTE_COUNT}" = "0" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_REMOTE"
    fi

    GS_STATE_UPSTREAM=""
    if [ "${GS_STATE_HAS_COMMIT}" = "1" ]; then
        if git_capture rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'; then
            GS_STATE_UPSTREAM="${GS_GIT_LAST_STDOUT}"
        fi
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "1" ] && [ "${GS_STATE_REMOTE_COUNT}" -gt 0 ] && [ -z "${GS_STATE_UPSTREAM}" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_UPSTREAM"
        GS_STATE_RELATION="UNTRACKED"
    fi

    GS_STATE_AHEAD=0
    GS_STATE_BEHIND=0
    if [ -n "${GS_STATE_UPSTREAM}" ]; then
        if git_capture rev-list --left-right --count 'HEAD...@{upstream}'; then
            counts="${GS_GIT_LAST_STDOUT}"
            ahead="$(printf '%s' "${counts}" | awk '{print $1}')"
            behind="$(printf '%s' "${counts}" | awk '{print $2}')"
            GS_STATE_AHEAD="${ahead:-0}"
            GS_STATE_BEHIND="${behind:-0}"
            if [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null && [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="DIVERGED"
                GS_STATE_CLASS="BRANCH_DIVERGED"
            elif [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="AHEAD"
                GS_STATE_CLASS="BRANCH_AHEAD"
            elif [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
                GS_STATE_RELATION="BEHIND"
                GS_STATE_CLASS="BRANCH_BEHIND"
            else
                GS_STATE_RELATION="EQUAL"
                GS_STATE_CLASS="BRANCH_EQUAL"
            fi
        else
            GS_STATE_RELATION="UNKNOWN"
        fi
    fi

    if [ "${GS_STATE_IS_CLEAN}" = "0" ]; then
        # Changed worktree is a primary class when not already a hard stop class.
        case "${GS_STATE_CLASS}" in
            BRANCH_DIVERGED|UNKNOWN_OR_UNSAFE) ;;
            *)
                GS_STATE_CLASS="WORKTREE_CHANGED"
                ;;
        esac
    fi

    if [ "${GS_STATE_HAS_COMMIT}" = "0" ] && [ "${GS_STATE_IS_REPO}" = "1" ]; then
        GS_STATE_CLASS="REPOSITORY_NO_COMMIT"
    fi

    return 0
}

# Print a short human-readable summary of the current state.
git_state_summary() {
    ui_info "Repository root: ${GS_STATE_ROOT:-none}"
    ui_info "Current branch: ${GS_STATE_BRANCH:-none}"
    if [ "${GS_STATE_IS_CLEAN}" = "1" ]; then
        ui_info "Working tree: clean"
    else
        ui_info "Working tree: changed (${GS_STATE_DIRTY_COUNT} entries)"
    fi
    ui_info "Remotes: ${GS_STATE_REMOTE_COUNT}"
    ui_info "Upstream: ${GS_STATE_UPSTREAM:-none}"
    ui_info "Relation: ${GS_STATE_RELATION}"
    ui_info "State class: ${GS_STATE_CLASS}"
}

# Return 0 when a nested repository risk exists (selected dir inside parent repo root).
git_state_is_nested() {
    local selected="$1"
    local root
    if [ "${GS_STATE_IS_REPO}" != "1" ]; then
        return 1
    fi
    root="${GS_STATE_ROOT}"
    if [ -z "${root}" ]; then
        return 1
    fi
    # Compare resolved paths as strings. Nested when selected is under root but not root.
    case "${selected}" in
        "${root}")
            return 1
            ;;
        "${root}"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Targeted checks for lesson steps. Prefer these over a full inspect when enough.

# Return 0 when the current directory is inside a Git working tree.
git_state_check_is_repo() {
    if ! git_capture rev-parse --is-inside-work-tree; then
        return 1
    fi
    if [ "${GS_GIT_LAST_STDOUT}" = "true" ]; then
        return 0
    fi
    return 1
}

# Return 0 when HEAD identifies a commit.
git_state_check_has_commit() {
    git_capture rev-parse --verify HEAD
}

# Return 0 when a named remote exists.
git_state_check_has_remote() {
    local name="$1"
    git_capture remote get-url "${name}"
}

# Refresh upstream tracking and ahead/behind only. Keep other GS_STATE_* values.
git_state_inspect_tracking() {
    local counts
    local ahead
    local behind

    GS_STATE_UPSTREAM=""
    GS_STATE_AHEAD=0
    GS_STATE_BEHIND=0
    GS_STATE_RELATION="UNKNOWN"

    if ! git_state_check_is_repo; then
        GS_STATE_IS_REPO=0
        return 1
    fi
    GS_STATE_IS_REPO=1

    if git_capture branch --show-current; then
        GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
    elif git_capture rev-parse --abbrev-ref HEAD; then
        if [ "${GS_GIT_LAST_STDOUT}" != "HEAD" ]; then
            GS_STATE_BRANCH="${GS_GIT_LAST_STDOUT}"
        fi
    fi

    if git_capture rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'; then
        GS_STATE_UPSTREAM="${GS_GIT_LAST_STDOUT}"
    else
        GS_STATE_RELATION="UNTRACKED"
        return 0
    fi

    if git_capture rev-list --left-right --count 'HEAD...@{upstream}'; then
        counts="${GS_GIT_LAST_STDOUT}"
        ahead="$(printf '%s' "${counts}" | awk '{print $1}')"
        behind="$(printf '%s' "${counts}" | awk '{print $2}')"
        GS_STATE_AHEAD="${ahead:-0}"
        GS_STATE_BEHIND="${behind:-0}"
        if [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null && [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
            GS_STATE_RELATION="DIVERGED"
        elif [ "${GS_STATE_AHEAD}" -gt 0 ] 2>/dev/null; then
            GS_STATE_RELATION="AHEAD"
        elif [ "${GS_STATE_BEHIND}" -gt 0 ] 2>/dev/null; then
            GS_STATE_RELATION="BEHIND"
        else
            GS_STATE_RELATION="EQUAL"
        fi
    fi
    return 0
}

# --- 90_safety.sh ---
# Safety checks for directories, secrets, generated files, and forbidden operations.
# Implements: FR-083 through FR-085, FR-140 through FR-144, FR-300 through FR-310.

GS_SAFE_SECRET_HITS=""
GS_SAFE_GENERATED_HITS=""
GS_SAFE_DANGEROUS=0
GS_SAFE_DANGEROUS_REASON=""

# Return 0 when the path looks like a broad or dangerous location.
safety_is_dangerous_directory() {
    local path="$1"
    local home
    home="${HOME:-}"
    GS_SAFE_DANGEROUS=0
    GS_SAFE_DANGEROUS_REASON=""

    case "${path}" in
        /|//)
            GS_SAFE_DANGEROUS=1
            GS_SAFE_DANGEROUS_REASON="This path is the file-system root."
            return 0
            ;;
    esac

    # Windows drive roots in Git Bash forms.
    case "${path}" in
        /[a-zA-Z]|/[a-zA-Z]/|[a-zA-Z]:/|[a-zA-Z]:\\)
            GS_SAFE_DANGEROUS=1
            GS_SAFE_DANGEROUS_REASON="This path is a drive root."
            return 0
            ;;
    esac

    if [ -n "${home}" ] && [ "${path}" = "${home}" ]; then
        GS_SAFE_DANGEROUS=1
        GS_SAFE_DANGEROUS_REASON="This path is your home directory."
        return 0
    fi

    if [ -n "${home}" ]; then
        case "${path}" in
            "${home}/Desktop"|"${home}/Documents"|"${home}/Downloads")
                GS_SAFE_DANGEROUS=1
                GS_SAFE_DANGEROUS_REASON="This path is a top-level user folder, not a single project folder."
                return 0
                ;;
        esac
    fi

    return 1
}

# Scan first-level names for likely secret files. Do not read file contents.
safety_scan_secrets() {
    local dir="$1"
    local name
    local path
    GS_SAFE_SECRET_HITS=""

    for path in "${dir}"/* "${dir}"/.[!.]* "${dir}"/..?*; do
        [ -e "${path}" ] || continue
        name="${path##*/}"
        case "${name}" in
            .env|.env.*|*.pem|*.key|id_rsa|id_dsa|id_ecdsa|id_ed25519|credentials.json|service-account*.json|*secret*|*.p12|*.pfx|.npmrc|.pypirc)
                if [ -n "${GS_SAFE_SECRET_HITS}" ]; then
                    GS_SAFE_SECRET_HITS="${GS_SAFE_SECRET_HITS}
${name}"
                else
                    GS_SAFE_SECRET_HITS="${name}"
                fi
                ;;
        esac
    done
}

# Scan first-level names for common generated directories.
safety_scan_generated() {
    local dir="$1"
    local name
    local path
    GS_SAFE_GENERATED_HITS=""

    for path in "${dir}"/* "${dir}"/.[!.]*; do
        [ -e "${path}" ] || continue
        [ -d "${path}" ] || continue
        name="${path##*/}"
        case "${name}" in
            node_modules|.venv|venv|__pycache__|dist|build|.next|target|.tox|.pytest_cache|vendor)
                if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
                    GS_SAFE_GENERATED_HITS="${GS_SAFE_GENERATED_HITS}
${name}"
                else
                    GS_SAFE_GENERATED_HITS="${name}"
                fi
                ;;
        esac
    done
}

# Explain .gitignore in plain language before any decision (NFR-004, FR-143).
safety_explain_gitignore() {
    ui_info "What is a .gitignore file?"
    ui_print "A .gitignore file tells Git which files to leave alone."
    ui_print "Git will not stage those files when you run git add ."
    ui_blank
    ui_muted "Use it for secrets, such as .env or password files."
    ui_muted "Use it for generated folders, such as node_modules or build."
    ui_muted "Your project source files still get tracked as normal."
    ui_blank
    ui_print "Without .gitignore, a secret or large generated folder can enter a commit."
    ui_print "Then it can be pushed to the remote. That is hard to undo safely."
}

# Show secret and generated warnings for a directory. Return 1 when hits exist.
safety_review_directory() {
    local dir="$1"
    local has_issue=0
    local names

    safety_scan_secrets "${dir}"
    safety_scan_generated "${dir}"

    if [ -n "${GS_SAFE_SECRET_HITS}" ]; then
        has_issue=1
        names="$(printf '%s\n' "${GS_SAFE_SECRET_HITS}" | tr '\n' ',' | sed 's/,$//;s/,/, /g')"
        ui_warning "Secret-looking names: ${names}"
        ui_muted "File contents were not read."
        ui_muted "A .gitignore file can keep these names out of git add ."
        ui_muted "Code: ${GS_CODE_SAFE_SECRET}"
    fi

    if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
        has_issue=1
        names="$(printf '%s\n' "${GS_SAFE_GENERATED_HITS}" | tr '\n' ',' | sed 's/,$//;s/,/, /g')"
        ui_warning "Generated folders: ${names}"
        ui_muted "These folders are usually built by tools. Do not commit them."
        ui_muted "A .gitignore file can keep them out of git add ."
    fi

    return "${has_issue}"
}

# Teach .gitignore, then create or confirm before staging (FR-143, NFR-004).
safety_ensure_gitignore_review() {
    local dir="$1"

    safety_explain_gitignore
    ui_blank

    if [ ! -f "${dir}/.gitignore" ]; then
        ui_warning "This folder has no .gitignore file yet."
        ui_print "GitStart can create a basic starter file for secrets and generated folders."
        ui_muted "You can edit the file later for your project."
        if input_confirm "Create a basic .gitignore now?"; then
            safety_write_basic_gitignore "${dir}"
            ui_success "Created .gitignore in this folder."
            ui_muted "It lists common secret names and generated folders."
            ui_muted "Open the file in your editor if you want to add more names."
        else
            ui_warning "Continuing without .gitignore."
            ui_next "Create one before git add . if this folder has secrets or generated files."
            if ! input_confirm "Continue without .gitignore?"; then
                return 1
            fi
        fi
    else
        ui_success "A .gitignore file is already in this folder."
        ui_muted "Git will skip names listed in that file when you stage files."
        if ! input_confirm "Continue with this .gitignore?"; then
            ui_next "Edit .gitignore in your editor. Then run this lesson again."
            return 1
        fi
    fi
    return 0
}

# Write a basic .gitignore. Do not overwrite an existing file.
safety_write_basic_gitignore() {
    local dir="$1"
    if [ -f "${dir}/.gitignore" ]; then
        return 0
    fi
    cat >"${dir}/.gitignore" <<'EOF'
# Secrets
.env
.env.*
*.pem
*.key
credentials.json

# Generated
node_modules/
.venv/
venv/
__pycache__/
dist/
build/
.next/
target/
EOF
}

# Return 1 when a command string looks like a forbidden destructive operation.
safety_is_forbidden_command() {
    local cmd
    cmd="$(input_normalize_command "$1")"
    case "${cmd}" in
        *"push --force"*|*"push -f"*|*"reset --hard"*|*"clean -fd"*|*"clean -f"*|"git restore ."|"git checkout -- ."|*"branch -D"*)
            return 0
            ;;
    esac
    return 1
}

# Stop with a standard safety message.
safety_stop() {
    local title="$1"
    local reason="$2"
    local next_action="$3"
    local code="${4:-$GS_CODE_SAFE_STOP}"
    ui_fail_detail "${title}" "Safety check" "${reason}" "${next_action}" "${code}"
    return 1
}

# --- 100_lesson_engine.sh ---
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

    ui_info "Why: ${why}"
    if [ -n "${result_text}" ]; then
        ui_muted "What happens: ${result_text}"
    fi
    ui_print "Type this command:"
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
                    ui_info "Why: ${why}"
                    if [ -n "${result_text}" ]; then
                        ui_muted "What happens: ${result_text}"
                    fi
                    ui_print "Type this command:"
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

# Explain a failed remote Git step using the conservative classifier (FR-287).
lesson_explain_remote_failure() {
    local step_name="$1"
    git_explain_remote_failure "${step_name}" "${GS_STATE_RELATION:-}"
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

# --- lessons/initialize.sh ---
# Implements: FR-160 through FR-184, FR-130, FR-164–FR-166.
# Teach a student how to publish an existing directory as a new repository.

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
    ui_info "Why: every commit records an author. Remotes and classmates use this to see who saved the change."
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
    ui_muted "Local config: only this project. Recommended for class work."
    ui_muted "Global config: every Git project on this computer."
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

lesson_initialize_repository() {
    local list_cmd
    local commit_display

    lesson_begin "Publish a directory as a new repository" 12 "${GS_LESSON_INIT}"

    if ! picker_run; then
        return 1
    fi

    lesson_step_begin "Confirm the working directory"
    if ! lesson_teach_exact_command \
        "pwd" \
        lesson_initialize_run_pwd \
        "Confirm you are in the project folder before any Git command." \
        "You see the full path of the current folder."
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
        "Look at the files before Git starts tracking them." \
        "You see names in this folder."
    then
        return 1
    fi

    lesson_step_begin "Protect secrets before Git tracks files"
    ui_info "Before git add, decide what Git should ignore."
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

    lesson_step_begin "Initialize the repository"
    ui_info "A repository is a folder that Git can track over time."
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

    lesson_step_begin "Set Git author identity"
    if ! lesson_initialize_set_identity; then
        return 1
    fi

    lesson_step_begin "Name the branch main"
    ui_info "A branch is a named line of work. Classroom remotes usually start with main."
    if ! lesson_teach_exact_command \
        "git branch -M main" \
        lesson_initialize_run_branch_main \
        "Rename the current branch to main so it matches common classroom remotes." \
        "The current branch is named main."
    then
        return 1
    fi

    lesson_step_begin "Check status"
    if ! lesson_teach_exact_command \
        "git status" \
        lesson_initialize_run_status \
        "Ask Git what it sees before you stage files." \
        "You see untracked files and the current branch."
    then
        return 1
    fi

    lesson_step_begin "Stage files"
    ui_info "Staging means: choose which changes go into the next commit."
    ui_muted "git add . stages the files in this folder. Names listed in .gitignore stay out."
    if ! lesson_teach_exact_command \
        "git add ." \
        lesson_initialize_run_add \
        "Prepare project files for the first commit. Skip names listed in .gitignore." \
        "Selected files are staged and ready to commit."
    then
        return 1
    fi
    git_state_inspect
    ui_muted "Staged paths: ${GS_STATE_DIRTY_COUNT}"

    lesson_step_begin "Create the first commit"
    ui_info "A commit is a saved snapshot. Write a short message that describes the change."
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

    lesson_step_begin "Add the origin remote"
    ui_info "A remote is a named link to a repository on a hosting service."
    ui_info "origin is the usual name for your own remote repository."
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

    if git_state_check_has_remote "origin"; then
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

    lesson_step_begin "Verify remotes"
    if ! lesson_teach_exact_command \
        "git remote -v" \
        lesson_initialize_run_remote_v \
        "Check that origin points to the URL you expect." \
        "You see origin configured for fetch and push."
    then
        return 1
    fi

    lesson_step_begin "Push the branch and set upstream"
    ui_info "Push sends your local commits to the remote."
    ui_info "The first push also sets upstream tracking so later git push knows where to go."
    ui_info "Push needs a network connection and authentication through your Git credential helper."
    ui_info "GitStart does not request a password or token."
    if ! lesson_teach_exact_command \
        "git push -u origin ${GS_STATE_BRANCH:-main}" \
        lesson_initialize_run_push \
        "Publish your branch to origin and remember that remote as upstream." \
        "The remote branch exists and your local branch tracks it."
    then
        lesson_explain_remote_failure "git push"
        return 1
    fi

    git_state_inspect_tracking
    lesson_verify_state
    lesson_complete
    return 0
}

# --- lessons/commit_push.sh ---
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

# --- lessons/update_clone.sh ---
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

# --- lessons/sync_fork.sh ---
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

# --- lessons/diagnose.sh ---
# Implements: FR-260 through FR-264.
# Collect local Git state for diagnosis without file contents or credentials.

lesson_diagnose_os_family() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin) printf 'macOS\n' ;;
        Linux) printf 'Linux\n' ;;
        MINGW*|MSYS*|CYGWIN*) printf 'Windows-GitBash\n' ;;
        *) printf 'unknown\n' ;;
    esac
}

lesson_diagnose() {
    local report
    local remote_line
    local sanitized

    lesson_begin "Diagnose a Git problem" 1 "${GS_LESSON_DIAGNOSE}"

    ui_info "Diagnosis collects safe local facts about this repository."
    ui_muted "It does not read secret file contents. It does not send data automatically."

    if ! picker_run; then
        # Diagnosis can still run in the current directory.
        ui_info "Using the current directory for diagnosis"
    fi

    lesson_step_begin "Collect local Git facts"
    ui_info "GitStart inspects branch, remotes, and ahead or behind counts."
    git_state_inspect

    report=""
    report="${report}GitStart diagnosis report\n"
    report="${report}=========================\n"
    report="${report}Application: ${GS_APP_NAME} ${GS_APP_VERSION}\n"
    report="${report}OS family: $(lesson_diagnose_os_family)\n"
    report="${report}Bash: ${BASH_VERSION:-unknown}\n"
    if git_is_available; then
        report="${report}Git: $(git --version 2>/dev/null || echo unknown)\n"
    else
        report="${report}Git: not available\n"
    fi
    report="${report}Repository root: ${GS_STATE_ROOT:-none}\n"
    report="${report}Current branch: ${GS_STATE_BRANCH:-none}\n"
    report="${report}Has commit: ${GS_STATE_HAS_COMMIT}\n"
    report="${report}Working tree clean: ${GS_STATE_IS_CLEAN}\n"
    report="${report}Dirty entries: ${GS_STATE_DIRTY_COUNT}\n"
    report="${report}Remote count: ${GS_STATE_REMOTE_COUNT}\n"
    report="${report}Upstream: ${GS_STATE_UPSTREAM:-none}\n"
    report="${report}Ahead: ${GS_STATE_AHEAD}\n"
    report="${report}Behind: ${GS_STATE_BEHIND}\n"
    report="${report}Relation: ${GS_STATE_RELATION}\n"
    report="${report}State class: ${GS_STATE_CLASS}\n"
    report="${report}Last Git status: ${GS_GIT_LAST_STATUS:-n/a}\n"
    report="${report}Remotes (sanitized):\n"

    if git_capture remote -v; then
        if [ -n "${GS_GIT_LAST_STDOUT}" ]; then
            while IFS= read -r remote_line; do
                [ -n "${remote_line}" ] || continue
                sanitized="$(git_sanitize_remote_url "${remote_line}")"
                report="${report}  ${sanitized}\n"
            done <<EOF
${GS_GIT_LAST_STDOUT}
EOF
        else
            report="${report}  none\n"
        fi
    else
        report="${report}  unavailable\n"
    fi

    ui_blank
    ui_title "Diagnosis report"
    printf '%b\n' "${report}"
    ui_blank
    ui_info "This report does not include file contents"
    ui_info "Remote URLs are sanitized"
    ui_info "GitStart does not send this report automatically"
    ui_next "Copy the report text if you need instructor help"
    lesson_complete
    return 0
}

# --- 999_main.sh ---
# Main entry: argument parsing, capability checks, and menu routing.
# Implements: FR-050 through FR-055, CLI options from SRS §10.1.

GS_APP_MODE="${GS_MODE_LEARN}"

# Show Git installation guidance when git is missing.
main_require_git() {
    if git_is_available; then
        return 0
    fi
    ui_fail_detail \
        "Git is not available." \
        "Startup check" \
        "The git command was not found in PATH." \
        "Install Git. On Windows install Git for Windows. On macOS install Xcode Command Line Tools or Git. Then run GitStart again." \
        "${GS_CODE_GIT_MISSING}"
    return 1
}

# Reject ancient Bash versions below 3.2.
main_check_bash() {
    local major
    local minor
    major="${BASH_VERSINFO[0]:-0}"
    minor="${BASH_VERSINFO[1]:-0}"
    if [ "${major}" -lt 3 ] 2>/dev/null; then
        printf '%s\n' "[ERROR] Bash 3.2 or later is required."
        printf '%s\n' "This Bash version is too old."
        return 1
    fi
    if [ "${major}" -eq 3 ] && [ "${minor}" -lt 2 ] 2>/dev/null; then
        printf '%s\n' "[ERROR] Bash 3.2 or later is required."
        return 1
    fi
    return 0
}

main_parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --learn)
                GS_APP_MODE="${GS_MODE_LEARN}"
                shift
                ;;
            --assisted)
                GS_APP_MODE="${GS_MODE_ASSISTED}"
                shift
                ;;
            --no-color)
                GS_TERM_COLOR=0
                shift
                ;;
            --plain)
                GS_TERM_PLAIN=1
                GS_TERM_COLOR=0
                GS_TERM_ANIMATION=0
                shift
                ;;
            --ascii)
                GS_TERM_ASCII=1
                GS_TERM_UNICODE=0
                shift
                ;;
            --no-animation)
                GS_TERM_ANIMATION=0
                shift
                ;;
            --version)
                printf '%s %s (%s)\n' "${GS_APP_NAME}" "${GS_APP_VERSION}" "${GS_APP_ID}"
                exit 0
                ;;
            --help|-h)
                ui_show_help_text
                exit 0
                ;;
            *)
                printf '%s\n' "[ERROR] Unknown option: $1"
                printf '%s\n' "Run with --help to see available options."
                exit 2
                ;;
        esac
    done
    GS_LESSON_MODE="${GS_APP_MODE}"
}

main_menu() {
    local choice
    while true; do
        ui_blank
        ui_title "Main menu"
        ui_print "1) Publish an existing directory as a new repository"
        ui_muted "    New folder: start Git, make the first commit, and push it."
        ui_print "2) Save and push changes in an existing repository"
        ui_muted "    You edited files: commit them and send them to the remote."
        ui_print "3) Update an existing clone"
        ui_muted "    The remote moved ahead: bring those commits into your local copy."
        ui_print "4) Synchronize a fork"
        ui_muted "    Fork workflow: fetch from the original repo, then push to your fork."
        ui_print "5) Diagnose a Git problem"
        ui_muted "    Inspect the repository and get a safe next action."
        ui_print "6) Quit"
        ui_blank
        input_choice 6 "Select a number: " || return 1
        choice="${GS_INPUT_LAST}"
        case "${choice}" in
            1) lesson_initialize_repository || true ;;
            2) lesson_commit_push || true ;;
            3) lesson_update_clone || true ;;
            4) lesson_sync_fork || true ;;
            5) lesson_diagnose || true ;;
            6)
                ui_info "Goodbye."
                return 0
                ;;
            *)
                ui_fail_detail \
                    "Unexpected menu choice." \
                    "Main menu" \
                    "The choice was not recognized." \
                    "Select a listed number." \
                    "${GS_CODE_INTERNAL}"
                ;;
        esac
    done
}

main() {
    if ! main_check_bash; then
        exit 1
    fi

    # Defaults before arg parse.
    GS_TERM_COLOR=1
    GS_TERM_PLAIN=0
    GS_TERM_ASCII=0
    GS_TERM_ANIMATION=1

    main_parse_args "$@"
    terminal_init
    ui_init_styles
    ui_show_banner

    if ! main_require_git; then
        exit 1
    fi

    ui_info "Mode: ${GS_LESSON_MODE}"
    main_menu
    terminal_cleanup
}

# Start when executed as a script. Support being sourced in tests.
if [ "${GS_TEST_MODE:-0}" != "1" ]; then
    main "$@"
fi
