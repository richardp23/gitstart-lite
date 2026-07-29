# Local fuzzy matcher for visible directory labels.
# Implements: FR-068 through FR-070.

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
            # Prefer earlier substring match.
            first_pos=0
            i=0
            while [ "${i}" -le "$((c_len - q_len))" ]; do
                if [ "$(printf '%s' "${c_lower}" | cut -c $((i + 1))-$((i + q_len)))" = "${q_lower}" ]; then
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
        ch="$(printf '%s' "${q_lower}" | cut -c $((i + 1)))"
        while [ "${j}" -lt "${c_len}" ]; do
            if [ "$(printf '%s' "${c_lower}" | cut -c $((j + 1)))" = "${ch}" ]; then
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
