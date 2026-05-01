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

set from_branch_name=%1
if not defined from_branch_name goto noArgs

set to_branch_name=%2
if not defined to_branch_name goto noArgs

set sub_path=%3
if not defined sub_path set sub_path=%cd% 
if not exist %sub_path% goto noFolder
cd %sub_path%

:gitMerge

echo.       
echo ********************************************************************************
echo * Running git MERGE. From branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title  Running git MERGE. From branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'

pushd . && (

call git-update.cmd %sub_path% %from_branch_name% ) && (
call git-update.cmd %sub_path% %to_branch_name% ) && (

REM call git commit -a -m "fix CRLF"  ) && (
REM call git push  ) && (

echo.       
echo ********************************************************************************
echo * MERGE from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title  MERGE from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'

call git merge --allow-unrelated-histories  %from_branch_name%  ) && (

REM echo ***************
REM echo *  git commit *
REM echo ***************
REM call git commit  ) && (
REM pause

echo.
echo ***************
echo *  git push *
echo ***************
call git push  ) && (

echo. 
echo *******************
echo *  git status -s  *
echo *******************
call git status -s  ) && (

ECHO MERGE finished from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
title %comspec% ) && (
popd )


goto EOF

:noFolder
  echo ERROR: '%sub_path%' path not found.
  echo.  
goto noArgs

:noArgs
  echo This command merges two Git branches.
  echo [Required] The first parameter is the source branch name.
  echo [Required] The second parameter is the destination branch name.
  echo [Optional] The third parameter is the subfolder path where the branch is being updated. If the parameter is missing, the current folder is used.
  echo Usage:
  echo   git-merge.cmd from_branch_name to_branch_name 
  echo or
  echo   git-merge.cmd from_branch_name to_branch_name subfolder_name  
  
goto EOF


:EOF
