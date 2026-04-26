@echo off
:: git-stash-list.cmd — Shows all Git stashes with additional stash details.
::
:: Runs git stash list and then git stash show for each stash entry.
:: Use it when the default stash list output is too compact.
::
:: Dependencies:
::   git - https://git-scm.com/downloads
::         Windows: winget install Git.Git
::
:: Usage:
::   git-stash-list.cmd
::
:: Examples:
::   git-stash-list.cmd

echo Git Stash List
echo ==============
echo.

:: Get the list of stashes
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
:: pause
