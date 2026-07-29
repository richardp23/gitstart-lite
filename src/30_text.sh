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
    ui_muted "Version ${GS_APP_VERSION}"
    ui_muted "Learn Git with real commands."
    ui_blank
}

ui_show_help_text() {
    cat <<EOF
${GS_APP_NAME} ${GS_APP_VERSION}

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
