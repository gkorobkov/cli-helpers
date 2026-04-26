@ECHO OFF
:: git-update.cmd — Pulls the latest changes for a Git branch and optionally builds.
::
:: Updates a repository: optionally fetches, optionally checks out a branch,
:: pulls from origin, and prints git status. Branch defaults to the current
:: branch detected by git-branch-name.cmd if not specified.
::
:: Dependencies:
::   git              - https://git-scm.com/downloads
::                      Windows: winget install Git.Git
::   git-branch-name.cmd - sibling script, must be in the same folder or PATH
::
:: Usage:
::   git-update.cmd [sub_path] [branch_name]
::
:: Parameters:
::   sub_path    : Optional. Repository folder. Defaults to current directory.
::   branch_name : Optional. Branch to pull. Defaults to the current branch.
::
:: Environment variables:
::   fetch_origin=true       : Run git fetch origin before pull.
::   checkout_branch=true    : Run git checkout before pull.
::   auto_stash=true         : Enable auto-stash behavior.
::   build-after-update=true : Run a local build script after update.
::   exitonfinish=true       : Exit the shell when done.
::
:: Examples:
::   git-update.cmd
::   git-update.cmd C:\work\my-repo main
::   set fetch_origin=true && git-update.cmd

:: set fetch_origin=true
:: set checkout_branch=true

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
:: echo.
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

:: call git reset --hard HEAD  ) && (
echo.
:: echo ************************************************
echo [ Running: git pull origin %branch_name% ]
:: echo ************************************************

call git pull origin %branch_name% 
) && (

echo.
:: echo **************************************
echo [ Running: git status -s -b -v ]
:: echo **************************************

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
