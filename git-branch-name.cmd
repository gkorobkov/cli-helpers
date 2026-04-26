@echo off
:: git-branch-name.cmd — Prints the current Git branch name.
::
:: Runs: git rev-parse --abbrev-ref HEAD
:: Useful inside other scripts or in a terminal pipeline.
::
:: Dependencies:
::   git - https://git-scm.com/downloads
::         Windows: winget install Git.Git
::
:: Usage:
::   git-branch-name.cmd
::
:: Examples:
::   git-branch-name.cmd
git rev-parse --abbrev-ref HEAD
