@ECHO OFF

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

rem call git commit -a -m "fix CRLF"  ) && (
rem call git push  ) && (

echo.       
echo ********************************************************************************
echo * MERGE from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'
echo ********************************************************************************
title  MERGE from branch: '%from_branch_name%', to branch: '%to_branch_name%'. Folder: '%sub_path%'

call git merge --allow-unrelated-histories  %from_branch_name%  ) && (

rem echo ***************
rem echo *  git commit *
rem echo ***************
rem call git commit  ) && (
rem pause

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
