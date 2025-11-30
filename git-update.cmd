@ECHO OFF

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

 if "%checkout_brach%" equ "true" (

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
rem { build -projectType net }
    if exist ps.cmd ( 
      ps.cmd measure-command  { build -projectType net }
    ) else if exist build-bin-debug.cmd (
      build-bin-debug.cmd
    ) else if exist build-common-debug.cmd (
      build-common-debug.cmd
    ) else if exist build-bin.cmd (
      build-bin.cmd
    ) else (
      rem copy ..\ps.cmd 
      rem ps.cmd measure-command { build  }
    )

                
  )
) && (
if "%exitonfinish%" equ "true" ( 
exit
)
) && (
popd ) 
rem -projectType net


goto EOF

:noFolder
  echo ERROR: '%sub_path%' path not found.
  echo.  
goto noArgs

:noArgs
  echo This cmd is used to update git branch to the latest.
  echo [Optional] The first parameter is the subfolder name where the branch is being updated. If parameter is missing then current folder is used.
  echo [Optional] The second parameter is the branch name. If parameter is missing then current local branch is used.
  echo Usage:
  echo   git-update.cmd   
  echo or
  echo   git-update.cmd subfolder_name  
  echo or
  echo   git-update.cmd subfolder_name branch_name 
goto EOF


:EOF
