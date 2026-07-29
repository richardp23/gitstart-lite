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
                printf '%s %s\n' "${GS_APP_NAME}" "${GS_APP_VERSION}"
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
        ui_print "2) Save and push changes in an existing repository"
        ui_print "3) Update an existing clone"
        ui_print "4) Synchronize a fork"
        ui_print "5) Diagnose a Git problem"
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
