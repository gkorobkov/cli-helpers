@ECHO OFF
REM git-merge.cmd — Merges one Git branch into another and pushes the result.
REM Updates both branches with git-update.cmd, checks out the destination branch,
REM merges the source with --allow-unrelated-histories, then pushes and prints git status.
REM Dependencies:
REM   git            - https://git-scm.com/downloads
REM                    Windows: winget install Git.Git
REM   git-update.cmd - sibling script, must be in the same folder or PATH
REM Usage:
REM   git-merge.cmd <from_branch> <to_branch> [sub_path]
REM Parameters:
REM   from_branch : Required. Source branch to merge from.
REM   to_branch   : Required. Destination branch to merge into.
REM   sub_path    : Optional. Repository folder. Defaults to current directory.
REM Examples:
REM   git-merge.cmd feature/main main
REM   git-merge.cmd feature/main main C:\work\my-repo

setlocal EnableExtensions

set "from_branch_name=%~1"
set "to_branch_name=%~2"
set "sub_path=%~3"

if not defined from_branch_name goto noArgs
if not defined to_branch_name goto noArgs
if not defined sub_path set "sub_path=%CD%"
if not exist "%sub_path%\" goto noFolder

pushd "%sub_path%" || (
  echo ERROR: Failed to enter repository folder: "%sub_path%"
  endlocal & exit /b 1
)

echo.
echo ********************************************************************************
echo * Running git MERGE. From branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title Running git MERGE. From branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'

echo [ Running: call "%~dp0git-update.cmd" "%sub_path%" "%from_branch_name%" ]
set "checkout_branch=true"
call "%~dp0git-update.cmd" "%sub_path%" "%from_branch_name%"
if errorlevel 1 goto failed

echo [ Running: call "%~dp0git-update.cmd" "%sub_path%" "%to_branch_name%" ]
call "%~dp0git-update.cmd" "%sub_path%" "%to_branch_name%"
if errorlevel 1 goto failed

echo [ Running: git merge --allow-unrelated-histories "%from_branch_name%" ]
git merge --allow-unrelated-histories "%from_branch_name%"
if errorlevel 1 goto failed

echo [ Running: git push ]
git push
if errorlevel 1 goto failed

echo [ Running: git status -s ]
git status -s
if errorlevel 1 goto failed

echo MERGE finished from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
title %comspec%
popd
endlocal & exit /b 0

:failed
set "merge_exit_code=%errorlevel%"
if "%merge_exit_code%"=="0" set "merge_exit_code=1"
echo ERROR: Git merge failed.
popd
endlocal & exit /b %merge_exit_code%

:noFolder
echo ERROR: "%sub_path%" path not found.
endlocal & exit /b 1

:noArgs
echo This command merges two Git branches.
echo Usage:
echo   git-merge.cmd from_branch_name to_branch_name
echo   git-merge.cmd from_branch_name to_branch_name subfolder_name
endlocal & exit /b 2
