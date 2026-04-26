@echo off
:: git-run-allfolders.cmd — Runs a Git command across all matching subfolders.
::
:: Recursively scans directories for a marker folder (default: .git) and runs
:: a command in each matching location. Use "update" as a shortcut for git-update.cmd.
:: Without arguments, prints git status -s -b -v for every repository found.
::
:: Dependencies:
::   git            - https://git-scm.com/downloads
::                    Windows: winget install Git.Git
::   git-update.cmd - sibling script, only needed when run_command is "update"
::
:: Usage:
::   git-run-allfolders.cmd [run_command] [search_path] [search_folder]
::
:: Parameters:
::   run_command   : Optional. Command template. Use %%path_to_git_folder%% as placeholder.
::                   Shortcut: "update" expands to git-update.cmd %%path_to_git_folder%%
::                   Default:  git -C %%path_to_git_folder%% status -s -b -v
::   search_path   : Optional. Root folder to scan. Defaults to current directory.
::   search_folder : Optional. Marker folder to detect. Defaults to .git.
::
:: Functions:
::   search_folders : Recursively walks directories looking for search_folder.
::
:: Examples:
::   git-run-allfolders.cmd
::   git-run-allfolders.cmd update C:\work
::   git-run-allfolders.cmd "git -C %%path_to_git_folder%% pull" C:\work .git


setlocal EnableDelayedExpansion

set "run_command=%~1"
if "%run_command%"=="update" set "run_command=git-update.cmd %%path_to_git_folder%% "
if "%run_command%"==""       set "run_command=git -C %%path_to_git_folder%% status -s -b -v"

echo.
echo *************************************************************

echo * run_command: !run_command!

set "search_path=%~2"
if "%search_path%"=="" set "search_path=%cd%"
echo * search_path: !search_path!

set "search_folder=%~3"
if "%search_folder%"=="" set "search_folder=.git"
echo * search_folder: !search_folder!
echo *************************************************************


echo.

call :search_folders "%search_path%"

echo.
echo Search completed.
:: pause
exit /b

:search_folders
set "current_path=%~1"
:: echo Searching !current_path!\!search_folder!

if exist "!current_path!\!search_folder!" (
    echo.
    set "path_to_git_folder="!current_path!""
    echo *************************************************************
    echo * Found "%search_folder%" folder in: !path_to_git_folder!
    echo *************************************************************
    echo Running:
    echo %run_command%
    call %run_command%
) else (
    rem echo Searching "%search_folder%" folder in: !current_path!
    for /d %%d in ("!current_path!\*") do (
        rem echo Searching "%search_folder%" folder in: "%%d"
        call :search_folders "%%d"
    )
)

exit /b
