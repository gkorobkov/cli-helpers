@echo off
REM git-branch-name.cmd — Prints the current Git branch name.
REM Runs: git rev-parse --abbrev-ref HEAD
REM Useful inside other scripts or in a terminal pipeline.
REM Dependencies:
REM   git - https://git-scm.com/downloads
REM         Windows: winget install Git.Git
REM Usage:
REM   git-branch-name.cmd
REM Examples:
REM   git-branch-name.cmd
git rev-parse --abbrev-ref HEAD
