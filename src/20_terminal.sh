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
