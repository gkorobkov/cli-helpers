@echo off
:: update-md-toc.cmd — Updates Table of Contents sections in Markdown files.
::
:: Finds a heading named "Оглавление", "TOC", "Table of contents", or "Contents"
:: and replaces the block below it (until the next heading) with generated TOC links.
::
:: Dependencies:
::   PowerShell        - built-in on Windows 10/11 (no install needed)
::   update-md-toc.ps1 - sibling script in the same folder
::
:: Usage:
::   update-md-toc.cmd [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--toc-depth hN]
::
:: Examples:
::   update-md-toc.cmd                              Process all *.md in current dir
::   update-md-toc.cmd setup.md                    Process a single file
::   update-md-toc.cmd a.md b.md                   Process multiple files
::   update-md-toc.cmd setup.md --dry-run           Preview changes without writing
::   update-md-toc.cmd setup.md --toc-depth h2      Include H1-H2 headings only
::   update-md-toc.cmd --files a.md b.md --dry-run  Explicit --files form also works
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
goto collect_files

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
