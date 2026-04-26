#!/usr/bin/env bash
# =============================================================
# update-md-toc.sh — Creates or updates TOC in Markdown files.
#
# Pure bash — no Python or PowerShell required.
# Finds a TOC marker heading and replaces the block below it
# (up to the next heading) with auto-generated anchor links.
# Recognized markers: Оглавление, Оглавлние, TOC, Table of contents, Contents.
#
# Android / Termux: works out of the box, no extra packages needed.
# Note: for correct Unicode slugs (Russian headings) set LANG=C.UTF-8
#       in Termux: echo 'export LANG=C.UTF-8' >> ~/.bashrc
#
# Dependencies:
#   bash 4.0+ - pre-installed in Termux (no extra install needed)
#   sed       - pre-installed in Termux
#
# Functions:
#   parse_args()      : Parses CLI arguments.
#   slugify()         : Generates a GitHub-style anchor slug from heading text.
#   clean_heading()   : Strips trailing closing hashes and whitespace.
#   is_toc_marker()   : Returns 0 if text matches a known TOC marker.
#   process_file()    : Orchestrates read → generate → write for one file.
#
# Usage:
#   ./update-md-toc.sh [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--toc-depth hN]
#
# Parameters:
#   FILE              : Optional. One or more Markdown files (positional).
#   --files FILE ...  : Optional. Alternative explicit file list.
#   --dry-run         : Optional. Show changes without writing.
#   --toc-depth hN    : Optional. Limit entries to H1-HN (e.g. h2, h3).
#
# Examples:
#   ./update-md-toc.sh                        Process all *.md in current dir
#   ./update-md-toc.sh README.md              Process a single file
#   ./update-md-toc.sh README.md --dry-run    Preview without writing
#   ./update-md-toc.sh README.md --toc-depth h3   H1-H3 headings only
#   ./update-md-toc.sh a.md b.md --dry-run    Preview multiple files
# =============================================================

set -u

# ── Configuration ─────────────────────────────────────────────────────────

TOC_BULLET="-"
TOC_INDENT="  "
TOC_MARKERS=("оглавление" "оглавлние" "toc" "table of contents" "contents")

DRY_RUN=0
TOC_MAX=6
FILES=()

readonly FENCE_RE='^[[:space:]]*(```|~~~)'
readonly HEADING_RE='^(#{1,6})[[:space:]](.*)'

# ── Argument parsing ──────────────────────────────────────────────────────

usage() {
    echo "Usage: update-md-toc.sh [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--toc-depth hN]"
    echo ""
    echo "Examples:"
    echo "  ./update-md-toc.sh                        Process all *.md in current dir"
    echo "  ./update-md-toc.sh README.md              Process a single file"
    echo "  ./update-md-toc.sh README.md --dry-run    Preview without writing"
    echo "  ./update-md-toc.sh README.md --toc-depth h3  H1-H3 headings only"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage; exit 0 ;;
            --dry-run)
                DRY_RUN=1 ;;
            --toc-depth)
                shift
                if [[ ! "${1:-}" =~ ^[hH]([1-6])$ ]]; then
                    echo "Error: --toc-depth must be hN where N is 1..6 (e.g. h2)" >&2; exit 2
                fi
                TOC_MAX="${BASH_REMATCH[1]}" ;;
            --files)
                : ;;  # positional args after this are still collected as files
            --*)
                echo "Error: Unknown option: $1" >&2; usage >&2; exit 2 ;;
            *)
                FILES+=("$1") ;;
        esac
        shift
    done
}

# ── Text helpers ──────────────────────────────────────────────────────────

slugify() {
    local text="${1,,}"  # lowercase (bash 4+ handles Unicode with UTF-8 locale)
    # Remove chars that are not alphanumeric, space, or hyphen
    text=$(printf '%s' "$text" | sed 's/[^[:alnum:][:space:]-]//g')
    # Collapse consecutive spaces/hyphens into one hyphen, trim edges
    text=$(printf '%s' "$text" | sed 's/[[:space:]-][[:space:]-]*/-/g; s/^-//; s/-$//')
    printf '%s' "${text:-section}"
}

clean_heading() {
    local text="$1"
    # Strip trailing closing hashes (e.g. "Heading ##")
    text=$(printf '%s' "$text" | sed 's/[[:space:]][[:space:]]*#*[[:space:]]*$//')
    # Trim leading/trailing whitespace
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    printf '%s' "$text"
}

is_toc_marker() {
    local text="${1,,}"
    local m
    for m in "${TOC_MARKERS[@]}"; do
        [[ "$text" == "$m" ]] && return 0
    done
    return 1
}

# ── File processing ───────────────────────────────────────────────────────

# Returns: 0 = up-to-date or marker not found, 1 = changed, 2 = error
process_file() {
    local path="$1"

    if [[ ! -f "$path" ]]; then
        echo "Error: file not found: $path" >&2; return 2
    fi

    mapfile -t lines < "$path"
    local n=${#lines[@]}

    # ── Find TOC marker heading and the end of its block ──────────────────
    local in_fence=0 toc_start=-1 toc_end=$n i

    for (( i = 0; i < n; i++ )); do
        if [[ "${lines[$i]}" =~ $FENCE_RE ]]; then
            in_fence=$(( 1 - in_fence )); continue
        fi
        [[ $in_fence -eq 1 ]] && continue
        [[ "${lines[$i]}" =~ $HEADING_RE ]] || continue

        local txt; txt=$(clean_heading "${BASH_REMATCH[2]}")
        [[ -z "$txt" ]] && continue

        if [[ $toc_start -eq -1 ]]; then
            is_toc_marker "$txt" && toc_start=$i
        else
            toc_end=$i; break
        fi
    done

    if [[ $toc_start -eq -1 ]]; then
        echo "$path: marker not found"; return 0
    fi

    # ── Collect headings after the TOC block ──────────────────────────────
    local -a hlvl=() htxt=()
    in_fence=0

    for (( i = toc_end; i < n; i++ )); do
        if [[ "${lines[$i]}" =~ $FENCE_RE ]]; then
            in_fence=$(( 1 - in_fence )); continue
        fi
        [[ $in_fence -eq 1 ]] && continue
        [[ "${lines[$i]}" =~ $HEADING_RE ]] || continue

        local lvl=${#BASH_REMATCH[1]}
        local txt; txt=$(clean_heading "${BASH_REMATCH[2]}")
        [[ -z "$txt" ]] && continue
        [[ $lvl -gt $TOC_MAX ]] && continue
        hlvl+=("$lvl"); htxt+=("$txt")
    done

    # ── Build TOC lines ───────────────────────────────────────────────────
    local -a toc_lines=()

    if [[ ${#hlvl[@]} -gt 0 ]]; then
        # Find minimum heading level to use as indent baseline
        local base_lvl=${hlvl[0]} j
        for (( j = 0; j < ${#hlvl[@]}; j++ )); do
            [[ ${hlvl[$j]} -lt $base_lvl ]] && base_lvl=${hlvl[$j]}
        done

        declare -A slug_cnt=()
        for (( j = 0; j < ${#hlvl[@]}; j++ )); do
            local base_slug; base_slug=$(slugify "${htxt[$j]}")
            local cnt=${slug_cnt[$base_slug]:-0}
            slug_cnt[$base_slug]=$(( cnt + 1 ))
            local slug
            [[ $cnt -eq 0 ]] && slug="$base_slug" || slug="${base_slug}-$(( cnt + 1 ))"
            local pad="" k
            for (( k = 0; k < hlvl[$j] - base_lvl; k++ )); do pad+="$TOC_INDENT"; done
            toc_lines+=("${pad}${TOC_BULLET} [${htxt[$j]}](#${slug})")
        done
    fi

    # ── Assemble new content ──────────────────────────────────────────────
    local -a out=()
    for (( i = 0; i <= toc_start; i++ )); do out+=("${lines[$i]}"); done
    out+=("")
    [[ ${#toc_lines[@]} -gt 0 ]] && out+=("${toc_lines[@]}")
    out+=("")
    for (( i = toc_end; i < n; i++ )); do out+=("${lines[$i]}"); done

    # Compare (command substitution strips trailing newlines — fine for diff check)
    local old_text; old_text=$(printf '%s\n' "${lines[@]}")
    local new_text; new_text=$(printf '%s\n' "${out[@]}")

    if [[ "$new_text" == "$old_text" ]]; then
        echo "$path: up to date"; return 0
    fi

    # ── Write or preview ──────────────────────────────────────────────────
    local label
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "$path: would update"; label="preview"
    else
        printf '%s\n' "${out[@]}" > "$path"
        echo "$path: updated"; label="output"
    fi

    echo "--- TOC $label for $path ---"
    echo "${lines[$toc_start]}"
    echo ""
    if [[ ${#toc_lines[@]} -gt 0 ]]; then
        printf '%s\n' "${toc_lines[@]}"
    else
        echo "${TOC_BULLET} (empty)"
    fi
    echo ""
    return 1  # signals: file was changed
}

# ── Main ──────────────────────────────────────────────────────────────────

parse_args "$@"

# Validate explicitly specified files before processing
for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: file not found: $f" >&2; exit 2
    fi
done

# Auto-discover *.md if no files specified
if [[ ${#FILES[@]} -eq 0 ]]; then
    shopt -s nullglob
    FILES=(*.md)
    shopt -u nullglob
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No markdown files found."; exit 1
fi

changed=0
for f in "${FILES[@]}"; do
    process_file "$f"
    case $? in
        1) changed=$(( changed + 1 )) ;;
        2) exit 2 ;;
    esac
done

echo "Done. changed=$changed, total=${#FILES[@]}"
