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

REM set fetch_origin=true
REM set checkout_branch=true

set sub_path=%1
if not defined sub_path set sub_path=%cd% 
if not exist %sub_path% goto noFolder
cd %sub_path%

set branch_name=%2
if defined branch_name goto gitUpdate
FOR /F "tokens=*" %%a in ('git-branch-name.cmd') do SET branch_name=%%a

:gitUpdate

echo.       
echo ********************************************************************************
echo * Running git UPDATE. Branch: '%branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title  Running git UPDATE. Branch: '%branch_name%'. Folder: '%sub_path%'

pushd . && (

:gitStash
REM echo.
if "%auto_stash%" equ "true" (
  echo "Auto stash on %date%_%time%" 
  rem git -c diff.mnemonicprefix=false -c core.quotepath=false stash save "Auto stash on %date%_%time%"
)
) && (

if "%fetch_origin%" equ "true" (
  rem title UPDATING %sub_path% %branch_name%
  echo.
  rem echo ************************************************
  echo [ Running: git fetch origin  %branch_name% ]
  rem echo ************************************************
  call git fetch origin  %branch_name% 
 )
) && (

 if "%checkout_branch%" equ "true" (

  echo.
  rem echo ************************************************
  echo [ Running: git checkout %branch_name% ]
  rem echo ************************************************
  call git checkout  %branch_name%  
 ) 

) && (

REM call git reset --hard HEAD  ) && (
echo.
REM echo ************************************************
echo [ Running: git pull origin %branch_name% ]
REM echo ************************************************

call git pull origin %branch_name% 
) && (

echo.
REM echo **************************************
echo [ Running: git status -s -b -v ]
REM echo **************************************

call git status -s -b -v
  ) && (
  

echo.       
echo ********************************************************************************
echo * UPDATE FINISHED. Branch: '%branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title UPDATE FINISHED. Branch: '%branch_name%'. Folder: '%sub_path%'

) && (
  if "%build-after-update%" equ "true" (
    ECHO %sub_path% %branch_name% BUILDING  
    title %sub_path% %branch_name% BUILDING
 
    if exist command1.cmd ( 
      command1.cmd  
    ) else if exist command2.cmd (
      command2.cmd
    ) else (
       ECHO NO BUILD COMMAND FOUND FOR %sub_path% %branch_name%   
    )
  )
) && (
if "%exitonfinish%" equ "true" ( 
exit
)
) && (
popd ) 


goto EOF

:noFolder
  echo ERROR: '%sub_path%' path not found.
  echo.  
goto noArgs

:noArgs
  echo This command updates a Git branch to the latest state.
  echo [Optional] The first parameter is the subfolder path where the branch is being updated. If the parameter is missing, the current folder is used.
  echo [Optional] The second parameter is the branch name. If the parameter is missing, the current local branch is used.
  echo Usage:
  echo   git-update.cmd   
  echo or
  echo   git-update.cmd subfolder_name  
  echo or
  echo   git-update.cmd subfolder_name branch_name 
goto EOF


:EOF
