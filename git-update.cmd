@ECHO OFF

rem set fetch_origin=true
rem set checkout_branch=true

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
rem echo.
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

rem call git reset --hard HEAD  ) && (
echo.
rem echo ************************************************
echo [ Running: git pull origin %branch_name% ]
rem echo ************************************************

call git pull origin %branch_name% 
) && (

echo.
rem echo **************************************
echo [ Running: git status -s -b -v ]
rem echo **************************************

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
