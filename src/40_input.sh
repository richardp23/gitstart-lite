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
