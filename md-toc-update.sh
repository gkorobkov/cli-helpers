#!/usr/bin/env bash
# =============================================================
# md-toc-update.sh — Creates or updates TOC in Markdown files.
#
# Pure bash — no Python or PowerShell required.
# Finds a TOC marker heading and replaces the block below it
# (up to the next heading) with auto-generated anchor links.
# If no TOC marker heading is found, inserts "# Table of contents" at the top.
# Recognized markers: Оглавление, Оглавлние, TOC, Table of contents, Contents.
#
# Without file arguments: scans for *.md files, shows TOC status per file,
# and prints ready-to-run example commands — nothing is written.
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
#   log()             : Outputs an indented log line to stdout.
#   usage()           : Prints usage.
#   parse_args()      : Parses CLI arguments.
#   slugify()         : Generates a GitHub-style anchor slug from heading text.
#   clean_heading()   : Strips trailing closing hashes and whitespace.
#   is_toc_marker()   : Returns 0 if text matches a known TOC marker.
#   show_md_list()    : Shows MD files with TOC status and example commands.
#   process_file()    : Orchestrates read -> generate -> write for one file.
#
# Usage:
#   ./md-toc-update.sh [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--hN]
#
# Parameters:
#   FILE              : Optional. One or more Markdown files (positional).
#   --files FILE ...  : Optional. Alternative explicit file list.
#   --dry-run         : Optional. Show changes without writing.
#   --hN              : Optional. Limit entries to H1-HN (e.g. --h2, --h3).
#
# Examples:
#   ./md-toc-update.sh                        List MD files and show example commands
#   ./md-toc-update.sh README.md              Update TOC in a single file
#   ./md-toc-update.sh README.md --dry-run    Preview without writing
#   ./md-toc-update.sh README.md --h3         H1-H3 headings only
#   ./md-toc-update.sh a.md b.md --dry-run    Preview multiple files
# =============================================================

set -u

# ── Configuration ─────────────────────────────────────────────────────────

TOC_BULLET="-"
TOC_INDENT="  "
TOC_MARKERS=("оглавление" "оглавлние" "toc" "table of contents" "contents")
AUTO_INSERT_HEADING="# Table of contents"

DRY_RUN=0
TOC_MAX=6
FILES=()
EXPLICIT_FILES=0  # set to 1 when files are given explicitly

readonly FENCE_RE='^[[:space:]]*(```|~~~)'
readonly HEADING_RE='^(#{1,6})[[:space:]](.*)'

# ── Helpers ───────────────────────────────────────────────────────────────

log() {
    echo "  $*"
}

usage() {
    echo "Usage: md-toc-update.sh [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--hN]"
    echo "  --hN    Limit TOC depth to H1-HN. Examples: --h2, --h3, --h4"
    echo ""
    echo "Without file arguments: scans current directory and shows example commands."
    echo ""
    echo "Examples:"
    echo "  ./md-toc-update.sh                        List MD files and show example commands"
    echo "  ./md-toc-update.sh README.md              Update TOC in a single file"
    echo "  ./md-toc-update.sh README.md --dry-run    Preview without writing"
    echo "  ./md-toc-update.sh README.md --h3         H1-H3 headings only"
}

# ── Argument parsing ──────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage; exit 0 ;;
            --dry-run)
                DRY_RUN=1 ;;
            --h[1-6])
                TOC_MAX="${1:3:1}" ;;
            --files)
                : ;;  # remaining positional args still collected as files
            --*)
                echo "Error: Unknown option: $1" >&2; usage >&2; exit 2 ;;
            *)
                FILES+=("$1")
                EXPLICIT_FILES=1 ;;
        esac
        shift
    done
}

# ── Text helpers ──────────────────────────────────────────────────────────

slugify() {
    local text="${1,,}"
    text=$(printf '%s' "$text" | sed 's/[^[:alnum:][:space:]-]//g')
    text=$(printf '%s' "$text" | sed 's/[[:space:]-][[:space:]-]*/-/g; s/^-//; s/-$//')
    printf '%s' "${text:-section}"
}

clean_heading() {
    local text="$1"
    text=$(printf '%s' "$text" | sed 's/[[:space:]][[:space:]]*#*[[:space:]]*$//')
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

# ── List mode ─────────────────────────────────────────────────────────────

show_md_list() {
    local -a targets=("$@")
    local -a actionable=()

    echo "Found ${#targets[@]} markdown file(s) in current directory:"
    echo ""

    local path toc_start i in_fence txt
    for path in "${targets[@]}"; do
        local -a lines=()
        mapfile -t lines < "$path"
        local n=${#lines[@]}
        in_fence=0
        toc_start=-1
        local has_headings=0

        for (( i = 0; i < n; i++ )); do
            if [[ "${lines[$i]}" =~ $FENCE_RE ]]; then
                in_fence=$(( 1 - in_fence )); continue
            fi
            [[ $in_fence -eq 1 ]] && continue
            [[ "${lines[$i]}" =~ $HEADING_RE ]] || continue
            txt=$(clean_heading "${BASH_REMATCH[2]}")
            [[ -z "$txt" ]] && continue
            has_headings=1
            if [[ $toc_start -eq -1 ]] && is_toc_marker "$txt"; then
                toc_start=$i
                break
            fi
        done

        if [[ $toc_start -ge 0 ]]; then
            local marker_line="${lines[$toc_start]}"
            echo "  $path"
            echo "    has TOC marker: $marker_line"
            actionable+=("$path")
        elif [[ $has_headings -eq 1 ]]; then
            echo "  $path"
            echo "    no TOC marker — '$AUTO_INSERT_HEADING' will be added at top"
            actionable+=("$path")
        else
            echo "  $path"
            echo "    no headings — skipped"
        fi
    done

    if [[ ${#actionable[@]} -eq 0 ]]; then
        echo ""
        echo "No files to update."
        return
    fi

    echo ""
    echo "To update TOC run:"
    for path in "${actionable[@]}"; do
        echo "  ./md-toc-update.sh $path"
    done

    if [[ ${#actionable[@]} -gt 1 ]]; then
        echo ""
        echo "To update all at once:"
        echo "  ./md-toc-update.sh ${actionable[*]}"
    fi
}

# ── File processing ───────────────────────────────────────────────────────

# Returns: 0 = up-to-date / skipped, 1 = changed, 2 = error
process_file() {
    local path="$1"

    if [[ ! -f "$path" ]]; then
        echo "Error: file not found: $path" >&2; return 2
    fi

    log "Reading file..."
    local -a lines=()
    mapfile -t lines < "$path"
    local n=${#lines[@]}
    log "File has $n lines"

    # ── Find TOC marker heading ───────────────────────────────────────────
    log "Searching for TOC marker heading..."
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
            if is_toc_marker "$txt"; then toc_start=$i; fi
        else
            toc_end=$i; break
        fi
    done

    # ── No TOC marker: collect all headings and insert at top ─────────────
    if [[ $toc_start -eq -1 ]]; then
        log "No TOC marker found"
        local -a hlvl=() htxt=()
        in_fence=0

        for (( i = 0; i < n; i++ )); do
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

        if [[ ${#hlvl[@]} -eq 0 ]]; then
            log "No headings found — skipping"
            echo "$path: no headings"
            return 0
        fi

        log "No headings found for TOC — inserting '$AUTO_INSERT_HEADING' at top"
        log "Found ${#hlvl[@]} heading(s), generating TOC entries (H1-H${TOC_MAX})..."

        # Build TOC lines
        local -a toc_lines=()
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

        log "Generated ${#toc_lines[@]} TOC entry/entries"

        # Assemble: insert heading + TOC before original content
        local -a out=()
        out+=("$AUTO_INSERT_HEADING")
        out+=("")
        [[ ${#toc_lines[@]} -gt 0 ]] && out+=("${toc_lines[@]}")
        out+=("")
        out+=("${lines[@]}")

        local label
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "$path: would insert TOC"; label="preview"
        else
            log "Writing file..."
            printf '%s\n' "${out[@]}" > "$path"
            echo "$path: toc inserted"; label="output"
        fi

        echo ""
        echo "  --- TOC $label ---"
        echo "  $AUTO_INSERT_HEADING"
        echo ""
        if [[ ${#toc_lines[@]} -gt 0 ]]; then
            for tl in "${toc_lines[@]}"; do echo "  $tl"; done
        else
            echo "  $TOC_BULLET (empty)"
        fi
        return 1
    fi

    # ── TOC marker found: update existing block ───────────────────────────
    log "TOC marker found at line $(( toc_start + 1 )): '${lines[$toc_start]}'"
    log "TOC block ends at line $(( toc_end + 1 ))"

    # Collect headings after the TOC block
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

    log "Found ${#hlvl[@]} heading(s) after TOC block, generating entries (H1-H${TOC_MAX})..."

    # Build TOC lines
    local -a toc_lines=()

    if [[ ${#hlvl[@]} -gt 0 ]]; then
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

    log "Generated ${#toc_lines[@]} TOC entry/entries"

    # Assemble new content
    local -a out=()
    for (( i = 0; i <= toc_start; i++ )); do out+=("${lines[$i]}"); done
    out+=("")
    [[ ${#toc_lines[@]} -gt 0 ]] && out+=("${toc_lines[@]}")
    out+=("")
    for (( i = toc_end; i < n; i++ )); do out+=("${lines[$i]}"); done

    local old_text; old_text=$(printf '%s\n' "${lines[@]}")
    local new_text; new_text=$(printf '%s\n' "${out[@]}")

    if [[ "$new_text" == "$old_text" ]]; then
        log "Content unchanged"
        echo "$path: up to date"; return 0
    fi

    local label
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "$path: would update"; label="preview"
    else
        log "Writing file..."
        printf '%s\n' "${out[@]}" > "$path"
        echo "$path: updated"; label="output"
    fi

    echo ""
    echo "  --- TOC $label ---"
    echo "  ${lines[$toc_start]}"
    echo ""
    if [[ ${#toc_lines[@]} -gt 0 ]]; then
        for tl in "${toc_lines[@]}"; do echo "  $tl"; done
    else
        echo "  $TOC_BULLET (empty)"
    fi
    return 1
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

# No explicit files: list mode — show status and example commands, do not write
if [[ $EXPLICIT_FILES -eq 0 ]]; then
    show_md_list "${FILES[@]}"
    exit 0
fi

changed=0
for f in "${FILES[@]}"; do
    echo ""
    echo "${f}:"
    process_file "$f"
    case $? in
        1) changed=$(( changed + 1 )) ;;
        2) exit 2 ;;
    esac
done

echo ""
echo "Done. changed=$changed, total=${#FILES[@]}"
