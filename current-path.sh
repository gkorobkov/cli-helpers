#!/usr/bin/env bash

# current-path.sh — Checks, lists, adds, or removes the current directory in PATH.
#
# Inspects and modifies the persistent PATH in the shell profile (~/.bashrc etc.).
# Always prints the current working directory first for clarity.
# add/delete take effect in the current session only when the script is sourced.
#
# Dependencies:
#   bash 3.2+ - standard on Linux and macOS (no install needed)
#
# Usage:
#   ./current-path.sh [list|add|delete]
#
# Modes:
#   (none)  : Print YES/NO — whether the current directory is in PATH.
#   list    : Print all PATH entries from the current shell session.
#   add     : Add the current directory to the shell profile if missing.
#   delete  : Remove the current directory from the shell profile if present.
#
# Functions:
#   detect_profile_file()      : Detects the shell profile file (bashrc, zshrc, profile).
#   contains_current_path()    : Checks if current dir is in PATH.
#   list_current_path()        : Prints each PATH entry.
#   remove_current_from_path() : Returns PATH string with current dir removed.
#   is_sourced()               : Detects if script is sourced or run as subprocess.
#
# Note: Use "source ./current-path.sh add" to apply changes to the current session.
#
# Examples:
#   ./current-path.sh
#   ./current-path.sh list
#   ./current-path.sh add
#   source ./current-path.sh delete

set -u

target_path="$(pwd -P)"
mode="${1-}"

printf 'Current path:\n'
printf '  %s\n' "$target_path"

detect_profile_file() {
  local shell_name
  shell_name="${SHELL##*/}"

  case "$shell_name" in
    bash)
      if [[ -f "${HOME}/.bashrc" || ! -f "${HOME}/.profile" ]]; then
        printf '%s\n' "${HOME}/.bashrc"
      else
        printf '%s\n' "${HOME}/.profile"
      fi
      ;;
    zsh)
      printf '%s\n' "${HOME}/.zshrc"
      ;;
    *)
      printf '%s\n' "${HOME}/.profile"
      ;;
  esac
}

contains_current_path() {
  local entry

  IFS=':' read -r -a path_entries <<< "${PATH}"
  for entry in "${path_entries[@]}"; do
    if [[ "$entry" == "$target_path" ]]; then
      return 0
    fi
  done

  return 1
}

list_current_path() {
  local entry

  IFS=':' read -r -a path_entries <<< "${PATH}"
  for entry in "${path_entries[@]}"; do
    printf '%s\n' "$entry"
  done
}

remove_current_from_path() {
  local entry
  local new_entries=()
  local joined_path

  IFS=':' read -r -a path_entries <<< "${PATH}"
  for entry in "${path_entries[@]}"; do
    if [[ "$entry" != "$target_path" && -n "$entry" ]]; then
      new_entries+=("$entry")
    fi
  done

  joined_path=$(IFS=:; printf '%s' "${new_entries[*]}")
  printf '%s\n' "$joined_path"
}

is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

finish() {
  local exit_code="${1:-0}"

  if is_sourced; then
    return "$exit_code"
  fi

  exit "$exit_code"
}

usage() {
  printf 'Usage:\n'
  printf '  ./current-path.sh\n'
  printf '  ./current-path.sh list\n'
  printf '  ./current-path.sh add\n'
  printf '  ./current-path.sh delete\n'
}

profile_file="$(detect_profile_file)"
export_line="export PATH=\"${target_path}:\$PATH\""

if [[ -z "$mode" ]]; then
  mode="check"
fi

case "$mode" in
  check)
    if contains_current_path; then
      printf 'YES\n'
      finish 0
    fi

    printf 'NO\n'
    finish 1
    ;;
  list)
    printf 'PATH entries from the current shell environment variable PATH:\n'
    list_current_path
    finish 0
    ;;
  add)
    touch "$profile_file"

    if ! grep -Fqx "$export_line" "$profile_file"; then
      printf '\n%s\n' "$export_line" >> "$profile_file"
    fi

    if is_sourced && ! contains_current_path; then
      export PATH="${target_path}:${PATH}"
    fi

    printf 'Ensured current directory is present in PATH:\n'
    printf '  %s\n' "$target_path"

    if is_sourced; then
      printf 'Updated %s and the current shell session.\n' "$profile_file"
    else
      printf 'Updated %s. Open a new shell or run `source %s` to refresh PATH.\n' "$profile_file" "$profile_file"
    fi

    finish 0
    ;;
  delete)
    removed_from_profile=0
    removed_from_session=0

    if [[ -f "$profile_file" ]]; then
      if grep -Fqx "$export_line" "$profile_file"; then
        removed_from_profile=1
        tmp_file="$(mktemp)"
        grep -Fvx "$export_line" "$profile_file" > "$tmp_file" || true
        mv "$tmp_file" "$profile_file"
      fi
    fi

    if is_sourced && contains_current_path; then
      export PATH="$(remove_current_from_path)"
      removed_from_session=1
    fi

    if (( removed_from_profile == 0 && removed_from_session == 0 )); then
      printf 'Current directory was not found in PATH:\n'
      printf '  %s\n' "$target_path"
      finish 1
    fi

    printf 'Removed current directory from PATH where it was found:\n'
    printf '  %s\n' "$target_path"

    if is_sourced; then
      printf 'Updated %s and the current shell session.\n' "$profile_file"
    else
      printf 'Updated %s. Open a new shell to refresh PATH.\n' "$profile_file"
    fi

    finish 0
    ;;
  *)
    usage
    finish 2
    ;;
esac
