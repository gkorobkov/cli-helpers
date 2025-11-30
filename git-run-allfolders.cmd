@echo off

REM Usage: find-123-folder.cmd [folder_path] [folder_name]
REM If no path is provided, uses current directory
REM If no folder_name is provided, uses ".git"

setlocal EnableDelayedExpansion

set "run_command=%~1"
if "%run_command%"=="update" set "run_command=git-update.cmd ""%%path_to_git_folder%%"" "
if "%run_command%"=="" set "run_command=git -C ""%%path_to_git_folder%%"" status -s -b -v"

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
rem pause
exit /b

:search_folders
set "current_path=%~1"

if exist "!current_path!\!search_folder!" (
    echo.
    echo *************************************************************
    echo * Found "%search_folder%" folder in: !current_path!
    echo *************************************************************
    set "path_to_git_folder=!current_path!"
    echo Running:
    echo %run_command%
    call %run_command%
) else (
    rem echo Searching "%search_folder%" folder in: !current_path!
    for /d %%d in ("!current_path!\*") do (
        rem echo Searching "%search_folder%" folder in: !current_path!
        call :search_folders "%%d"
    )
)

exit /b
