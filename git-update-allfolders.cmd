@echo off

REM Usage: find-123-folder.cmd [folder_path] [folder_name]
REM If no path is provided, uses current directory
REM If no folder_name is provided, uses ".git"

setlocal enabledelayedexpansion

set "search_path=%~1"
if "%search_path%"=="" set "search_path=%cd%"

echo search_path: !search_path!

set "search_folder=%~2"
if "%search_folder%"=="" set "search_folder=.git"

echo search_folder: !search_folder!

echo.

call :search_folders "%search_path%"

echo.
echo Search completed.
rem pause
exit /b

:search_folders
set "current_path=%~1"

for /d %%d in ("!current_path!\*") do (
    rem echo Checking folder: %%d
    rem set "folder_name=%%~nxd"
    rem echo folder_name: !folder_name!

    if exist "%%d\!search_folder!" (
        echo.
        setlocal disabledelayedexpansion
        echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        echo  Found "%search_folder%" folder in: %%d 
        echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        setlocal enabledelayedexpansion
        call git-update.cmd %%d

    ) else (
        rem echo Run recursive searching in subfolders of: "%%d"
        call :search_folders "%%d"
    )

    rem echo.
    rem pause
)

exit /b

