@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_PS1=%~dpn0.ps1"
set "UPDATE_MD_TOC_DRY_RUN="
set "UPDATE_MD_TOC_TOC_DEPTH="
set "UPDATE_MD_TOC_FILES="

:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--help" goto help
if /I "%~1"=="--dry-run" set "UPDATE_MD_TOC_DRY_RUN=1" & shift & goto parse_args
if /I "%~1"=="--toc-depth" goto set_toc_depth
if /I "%~1"=="--files" shift & goto collect_files
echo Error: Unknown argument: %~1
exit /b 2

:set_toc_depth
if "%~2"=="" (
    echo Error: Missing value for --toc-depth
    exit /b 2
)
set "UPDATE_MD_TOC_TOC_DEPTH=%~2"
shift
shift
goto parse_args

:collect_files
if "%~1"=="" goto run
if /I "%~1"=="--help" goto parse_args
if /I "%~1"=="--dry-run" goto parse_args
if /I "%~1"=="--toc-depth" goto parse_args
if /I "%~1"=="--files" goto parse_args
if defined UPDATE_MD_TOC_FILES (
    set "UPDATE_MD_TOC_FILES=%UPDATE_MD_TOC_FILES%|%~1"
) else (
    set "UPDATE_MD_TOC_FILES=%~1"
)
shift
goto collect_files

:help
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -Help
exit /b %errorlevel%

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -FromCmdWrapper
exit /b %errorlevel%
