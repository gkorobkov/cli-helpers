#!/usr/bin/env bash

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
