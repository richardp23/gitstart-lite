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
        ui_muted "File contents were not read. Prefer .gitignore before git add."
    fi

    if [ -n "${GS_SAFE_GENERATED_HITS}" ]; then
        has_issue=1
        names="$(printf '%s\n' "${GS_SAFE_GENERATED_HITS}" | tr '\n' ',' | sed 's/,$//;s/,/, /g')"
        ui_warning "Generated folders: ${names}"
        ui_muted "Prefer .gitignore before git add."
    fi

    return "${has_issue}"
}

# Ensure a .gitignore exists or is reviewed when warnings exist.
safety_ensure_gitignore_review() {
    local dir="$1"
    if [ ! -f "${dir}/.gitignore" ]; then
        ui_warning "No .gitignore yet."
        if input_confirm "Create a basic .gitignore?"; then
            safety_write_basic_gitignore "${dir}"
            ui_success "Created .gitignore."
        else
            ui_next "Add .gitignore before you stage private or generated files."
        fi
    else
        ui_muted ".gitignore found."
        if ! input_confirm "Continue?"; then
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
