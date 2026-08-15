#!/usr/bin/env bash
# locks.sh - Finds processes whose command lines reference a file or directory.
# Optionally terminates all matching processes or selected PIDs.
#
# Dependencies:
#   bash 4+
#   Linux /proc filesystem
#
# Usage:
#   ./locks.sh [path] [--kill] [--help]
#
# Examples:
#   ./locks.sh
#   ./locks.sh package.json
#   ./locks.sh /home/user/projects/my-app
#   ./locks.sh --kill
#   ./locks.sh /home/user/projects/my-app --kill
#
# Notes:
#   Without a path, the current working directory is checked.
#   Detection is based on process command lines containing the target path.
#   This is not a complete Linux file-descriptor or file-lock scan.

set -u

target_argument=""
kill_mode=0
show_help=0

show_help_text() {
    cat <<'EOF'

LOCKS - find processes referencing a file or directory

Usage:
  ./locks.sh
  ./locks.sh <path>
  ./locks.sh --kill
  ./locks.sh <path> --kill
  ./locks.sh --help

Parameters:
  <path>        File or directory to check.
                Defaults to the current working directory.

  --kill        Offer to terminate matching processes.

  --help        Show this help.

Kill selection:
  y             Terminate all listed processes.
  N or Enter    Cancel.
  20532         Terminate one listed PID.
  20532,23160   Terminate selected listed PIDs.

Examples:
  ./locks.sh
  ./locks.sh package.json
  ./locks.sh /home/user/projects/my-app
  ./locks.sh --kill
  ./locks.sh /home/user/projects/my-app --kill

Detection method:
  Process command lines from /proc/<PID>/cmdline are searched for
  the normalized target path.

Limitation:
  This is not a complete Linux file-descriptor or file-lock scan.
  A process can hold a file or directory descriptor even when the
  target path does not appear in its command line.

EOF
}

for argument in "$@"; do
    case "$argument" in
        --kill)
            kill_mode=1
            ;;

        --help)
            show_help=1
            ;;

        -*)
            printf 'ERROR: Unknown option: %s\n' "$argument" >&2
            printf 'Run "./locks.sh --help" for usage.\n' >&2
            exit 2
            ;;

        *)
            if [[ -n "$target_argument" ]]; then
                printf 'ERROR: More than one target path was specified.\n' >&2
                printf 'Run "./locks.sh --help" for usage.\n' >&2
                exit 2
            fi

            target_argument="$argument"
            ;;
    esac
done

if (( show_help )); then
    show_help_text
    exit 0
fi

if [[ -z "$target_argument" ]]; then
    target="$(pwd -P)"
else
    if [[ ! -e "$target_argument" ]]; then
        printf '\nERROR: Path does not exist:\n' >&2
        printf '  %s\n' "$target_argument" >&2
        exit 2
    fi

    if [[ -d "$target_argument" ]]; then
        target="$(
            cd -- "$target_argument" 2>/dev/null &&
            pwd -P
        )"
    else
        target_dir="${target_argument%/*}"
        target_name="${target_argument##*/}"

        if [[ "$target_dir" == "$target_argument" ]]; then
            target_dir="."
        fi

        target="$(
            cd -- "$target_dir" 2>/dev/null &&
            printf '%s/%s\n' "$(pwd -P)" "$target_name"
        )"
    fi
fi

if [[ -z "$target" ]]; then
    printf 'ERROR: Unable to resolve target path.\n' >&2
    exit 2
fi

printf '\n'
printf '============================================================\n'
printf ' LOCKS\n'
printf '============================================================\n'
printf ' Target path : %s\n' "$target"

if (( kill_mode )); then
    printf ' Kill mode   : enabled\n'
else
    printf ' Kill mode   : disabled\n'
fi

printf ' Method      : /proc command-line path match\n'
printf '============================================================\n'
printf '\n'

declare -a found_pids=()
declare -a found_ppids=()
declare -a found_names=()
declare -a found_parents=()
declare -a found_cmdlines=()

self_pid="$$"
parent_pid="$PPID"

for proc_dir in /proc/[0-9]*; do
    pid="${proc_dir##*/}"

    [[ "$pid" == "$self_pid" ]] && continue
    [[ "$pid" == "$parent_pid" ]] && continue

    [[ -r "$proc_dir/cmdline" ]] || continue

    cmdline=""
    while IFS= read -r -d '' argument; do
        if [[ -n "$cmdline" ]]; then
            cmdline+=" "
        fi

        cmdline+="$argument"
    done < "$proc_dir/cmdline"

    [[ -n "$cmdline" ]] || continue

    if [[ "$cmdline" != *"$target"* ]]; then
        continue
    fi

    ppid=""

    if [[ -r "$proc_dir/status" ]]; then
        while IFS=$'\t' read -r key value; do
            if [[ "$key" == "PPid:" ]]; then
                ppid="$value"
                break
            fi
        done < "$proc_dir/status"
    fi

    name=""

    if [[ -r "$proc_dir/comm" ]]; then
        IFS= read -r name < "$proc_dir/comm" || true
    fi

    parent_name=""

    if [[ -n "$ppid" && -r "/proc/$ppid/comm" ]]; then
        IFS= read -r parent_name < "/proc/$ppid/comm" || true
    fi

    found_pids+=("$pid")
    found_ppids+=("$ppid")
    found_names+=("$name")
    found_parents+=("$parent_name")
    found_cmdlines+=("$cmdline")
done

found_count="${#found_pids[@]}"

if (( found_count == 0 )); then
    printf 'No processes referencing this path were found.\n'
    printf '\n'
    printf 'NOTE:\n'
    printf 'A process may still hold a file or directory descriptor without\n'
    printf 'the target path appearing in its command line.\n'
    printf '\n'
    exit 0
fi

printf 'Found: %d process(es)\n' "$found_count"
printf '\n'

for ((i = 0; i < found_count; i++)); do
    printf '%s\n' '------------------------------------------------------------'
    printf 'PID         : %s\n' "${found_pids[$i]}"
    printf 'PPID        : %s\n' "${found_ppids[$i]}"
    printf 'Process     : %s\n' "${found_names[$i]}"
    printf 'Parent      : %s\n' "${found_parents[$i]}"
    printf 'CommandLine : %s\n' "${found_cmdlines[$i]}"
done

printf '%s\n' '------------------------------------------------------------'
printf '\n'

if (( ! kill_mode )); then
    printf 'To terminate matching processes, run:\n'
    printf '\n'
    printf '  ./locks.sh --kill\n'
    printf '\n'
    exit 0
fi

printf 'Terminate processes? [y/N/PID]\n'
printf '\n'
printf '  y           = terminate ALL listed processes\n'
printf '  N / Enter   = cancel\n'
printf '  %s       = terminate one PID\n' "${found_pids[0]}"

if (( found_count > 1 )); then
    printf '  %s,%s = terminate selected PIDs\n' \
        "${found_pids[0]}" "${found_pids[1]}"
fi

printf '\n'
printf 'Selection: '
IFS= read -r answer

case "$answer" in
    ""|n|N|no|NO|No)
        printf '\nNo processes terminated.\n'
        exit 0
        ;;

    y|Y|yes|YES|Yes)
        selected_pids=("${found_pids[@]}")
        ;;

    *)
        normalized_answer="${answer//;/,}"
        normalized_answer="${normalized_answer// /,}"

        IFS=',' read -r -a requested_pids <<< "$normalized_answer"

        selected_pids=()

        for requested_pid in "${requested_pids[@]}"; do
            [[ -n "$requested_pid" ]] || continue

            if [[ ! "$requested_pid" =~ ^[0-9]+$ ]]; then
                printf '\nERROR: Invalid PID: %s\n' "$requested_pid" >&2
                exit 3
            fi

            found=0

            for listed_pid in "${found_pids[@]}"; do
                if [[ "$listed_pid" == "$requested_pid" ]]; then
                    found=1
                    break
                fi
            done

            if (( ! found )); then
                printf '\nERROR: PID not in the found process list: %s\n' \
                    "$requested_pid" >&2
                exit 3
            fi

            already_selected=0

            for selected_pid in "${selected_pids[@]-}"; do
                if [[ "$selected_pid" == "$requested_pid" ]]; then
                    already_selected=1
                    break
                fi
            done

            if (( ! already_selected )); then
                selected_pids+=("$requested_pid")
            fi
        done
        ;;
esac

if (( ${#selected_pids[@]} == 0 )); then
    printf '\nNo processes selected.\n'
    exit 0
fi

printf '\n'

terminated_count=0
failed_count=0

for selected_pid in "${selected_pids[@]}"; do
    process_name=""

    for ((i = 0; i < found_count; i++)); do
        if [[ "${found_pids[$i]}" == "$selected_pid" ]]; then
            process_name="${found_names[$i]}"
            break
        fi
    done

    printf 'Terminating PID %s (%s)... ' \
        "$selected_pid" "$process_name"

    # kill is a shell builtin in bash, not an external executable.
    if kill "$selected_pid" 2>/dev/null; then
        sleep 0.3

        if [[ -d "/proc/$selected_pid" ]]; then
            printf 'FAILED\n'
            ((failed_count++))
        else
            printf 'OK\n'
            ((terminated_count++))
        fi
    else
        printf 'FAILED\n'
        ((failed_count++))
    fi
done

printf '\n'
printf '============================================================\n'
printf ' Terminated : %d\n' "$terminated_count"
printf ' Failed     : %d\n' "$failed_count"
printf '============================================================\n'
printf '\n'

if (( failed_count > 0 )); then
    exit 1
fi

exit 0