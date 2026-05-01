@echo off
REM git-stash-list.cmd — Shows all Git stashes with additional stash details.
REM Runs git stash list and then git stash show for each stash entry.
REM Use it when the default stash list output is too compact.
REM Dependencies:
REM   git - https://git-scm.com/downloads
REM         Windows: winget install Git.Git
REM Usage:
REM   git-stash-list.cmd
REM Examples:
REM   git-stash-list.cmd

echo Git Stash List
echo ==============
echo.

REM Get the list of stashes
git stash list
for /f "tokens=1 delims=:" %%i in ('git stash list') do (
    echo === %%i ===
    git stash show  %%i 
    echo.
    rem TODO: add simplified output for the stash
    echo.
)

echo.
echo Stash listing completed.
REM pause
