#!/usr/bin/env bash
# git-setup.sh — Shows or updates global Git user name and email.
#
# Shows current git config user.name and user.email.
# If arguments are passed, updates the corresponding global Git config values first.
#
# Dependencies:
#   git - https://git-scm.com/downloads
#         Linux: sudo apt install git  /  brew install git (macOS)
#
# Usage:
#   ./git-setup.sh [user_name] [user_email]
#
# Parameters:
#   user_name  : Optional. Git user name.
#   user_email : Optional. Git user email.
#
# Examples:
#   ./git-setup.sh
#   ./git-setup.sh "User Name" user@example.com

set -u

git_user_name="${1-}"
git_user_email="${2-}"

if [[ -n "$git_user_name" ]]; then
  git config --global user.name "$git_user_name"
fi

if [[ -n "$git_user_email" ]]; then
  git config --global user.email "$git_user_email"
fi

if [[ -z "$git_user_name" ]]; then
  git_user_name="$(git config --global --get user.name 2>/dev/null || true)"
fi

if [[ -z "$git_user_email" ]]; then
  git_user_email="$(git config --global --get user.email 2>/dev/null || true)"
fi

if [[ -z "$git_user_name" ]]; then
  echo "ERROR: git user.name is not set."
  echo
  echo 'Usage:'
  echo '  ./git-setup.sh "User Name" user@example.com'
  echo
  echo 'Or configure it manually:'
  echo '  git config --global user.name "User Name"'
  exit 1
fi

if [[ -z "$git_user_email" ]]; then
  echo "ERROR: git user.email is not set."
  echo
  echo 'Usage:'
  echo '  ./git-setup.sh "User Name" user@example.com'
  echo
  echo 'Or configure it manually:'
  echo '  git config --global user.email user@example.com'
  exit 1
fi

echo
echo "********************************************************************************"
echo "* Git user settings:"
echo "*   user.name  = $git_user_name"
echo "*   user.email = $git_user_email"
echo "********************************************************************************"
