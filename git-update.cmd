@ECHO OFF

set sub_path=%1
if not defined sub_path set sub_path=%cd% 
if not exist %sub_path% goto noFolder

set branch_name=%2
if defined branch_name goto gitUpdate
FOR /F "tokens=*" %%a in ('git-branch-name.cmd') do SET branch_name=%%a

:gitUpdate

echo  Running git update for the branch '%branch_name%' in the folder '%sub_path%'
title  Running git update for the branch '%branch_name%' in the folder '%sub_path%'

pushd . && (

cd %sub_path% ) && (
echo.       
echo ********************
echo * Folder: %sub_path%  
echo ********************
echo "Auto stash on %date%_%time%"
 git -c diff.mnemonicprefix=false -c core.quotepath=false stash save "Auto stash on %date%_%time%"
) && (

title UPDATING %sub_path% %branch_name%
echo.
echo ********************
echo *  UPDATING %sub_path% %branch_name%  
echo *********************
echo *********************
echo *  git fetch  %branch_name% 
echo *********************

call git fetch origin  %branch_name% ) && (

echo.
echo *********************
echo *  git checkout %branch_name%  
echo *********************

call git checkout  %branch_name%  ) && (
rem call git reset --hard HEAD  ) && (

echo.
echo ***********************
echo *  git pull origin %branch_name% 
echo ***********************

call git pull origin %branch_name% ) && (

echo.
echo *******************
echo *  git status -s  
echo *******************

call git status -s  ) && (
  
ECHO %sub_path% %branch_name% UPDATE FINISHED %build-after-update%
title %sub_path% %branch_name% UPDATE FINISHED) && (
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
  echo [Optional] The second parameter is the branch name. If parameter is missing then brach is used.
  echo Usage:
  echo   git-update.cmd   
  echo or
  echo   git-update.cmd subfolder_name  
  echo or
  echo   git-update.cmd subfolder_name branch_name 
goto EOF


:EOF