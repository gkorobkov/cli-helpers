@ECHO OFF
REM git-update.cmd — Pulls the latest changes for a Git branch and optionally builds.
REM Updates a repository: optionally fetches, optionally checks out a branch,
REM pulls from origin, and prints git status. Branch defaults to the current
REM branch detected by git-branch-name.cmd if not specified.
REM Dependencies:
REM   git              - https://git-scm.com/downloads
REM                      Windows: winget install Git.Git
REM   git-branch-name.cmd - sibling script, must be in the same folder or PATH
REM Usage:
REM   git-update.cmd [sub_path] [branch_name]
REM Parameters:
REM   sub_path    : Optional. Repository folder. Defaults to current directory.
REM   branch_name : Optional. Branch to pull. Defaults to the current branch.
REM Environment variables:
REM   fetch_origin=true       : Run git fetch origin before pull.
REM   checkout_branch=true    : Run git checkout before pull.
REM   auto_stash=true         : Enable auto-stash behavior.
REM   build-after-update=true : Run a local build script after update.
REM   exitonfinish=true       : Exit the shell when done.
REM Examples:
REM   git-update.cmd
REM   git-update.cmd C:\work\my-repo main
REM   set fetch_origin=true && git-update.cmd

setlocal EnableExtensions

set "sub_path=%~1"
if not defined sub_path set "sub_path=%CD%"
if not exist "%sub_path%\" goto noFolder

pushd "%sub_path%" || (
  echo ERROR: Failed to enter repository folder: "%sub_path%"
  endlocal & exit /b 1
)

set "branch_name=%~2"
if not defined branch_name (
  rem >&2 echo [ Running: call "%~dp0git-branch-name.cmd" ]
  for /f "usebackq delims=" %%a in (`call "%~dp0git-branch-name.cmd"`) do set "branch_name=%%a"
)

if not defined branch_name (
  echo ERROR: Could not determine the current Git branch.
  goto failed
)

echo.
echo ********************************************************************************
echo * Running git UPDATE. Branch: '%branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title Running git UPDATE. Branch: '%branch_name%'. Folder: '%sub_path%'

if /I "%auto_stash%"=="true" (
  echo Auto-stash was requested, but the stash operation is not implemented.
)

if /I "%fetch_origin%"=="true" (
  echo [ Running: git fetch origin "%branch_name%" ]
  git fetch origin "%branch_name%"
  if errorlevel 1 goto failed
)

if /I "%checkout_branch%"=="true" (
  echo [ Running: git checkout "%branch_name%" ]
  git checkout "%branch_name%"
  if errorlevel 1 goto failed
)

echo [ Running: git pull origin "%branch_name%" ]
git pull origin "%branch_name%"
if errorlevel 1 goto failed

echo [ Running: git status -s -b -v ]
git status -s -b -v
if errorlevel 1 goto failed

if /I "%build-after-update%"=="true" (
  echo %sub_path% %branch_name% BUILDING
  title %sub_path% %branch_name% BUILDING
  if exist command1.cmd (
    echo [ Running: call command1.cmd ]
    call command1.cmd
    if errorlevel 1 goto failed
  ) else if exist command2.cmd (
    echo [ Running: call command2.cmd ]
    call command2.cmd
    if errorlevel 1 goto failed
  ) else (
    echo NO BUILD COMMAND FOUND FOR %sub_path% %branch_name%
  )
)

echo.
echo ********************************************************************************
echo * UPDATE FINISHED. Branch: '%branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title UPDATE FINISHED. Branch: '%branch_name%'. Folder: '%sub_path%'
popd
endlocal & exit /b 0

:failed
set "update_exit_code=%errorlevel%"
if "%update_exit_code%"=="0" set "update_exit_code=1"
echo ERROR: Git update failed for branch "%branch_name%" in "%sub_path%".
popd
endlocal & exit /b %update_exit_code%

:noFolder
echo ERROR: "%sub_path%" path not found.
  echo This command updates a Git branch to the latest state.
  echo [Optional] The first parameter is the subfolder path where the branch is being updated. If the parameter is missing, the current folder is used.
  echo [Optional] The second parameter is the branch name. If the parameter is missing, the current local branch is used.

echo Usage:
echo   git-update.cmd
echo   git-update.cmd subfolder_name
echo   git-update.cmd subfolder_name branch_name
endlocal & exit /b 1
