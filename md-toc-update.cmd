@echo off
:: md-toc-update.cmd — Creates or updates Table of Contents in Markdown files.
::
:: Finds a heading named "Оглавление", "TOC", "Table of contents", or "Contents"
:: and replaces the block below it (until the next heading) with generated TOC links.
:: If no TOC marker heading is found, inserts "# Table of contents" at the top.
::
:: Without file arguments: scans for *.md files, shows TOC status per file,
:: and prints ready-to-run example commands — nothing is written.
::
:: Dependencies:
::   PowerShell        - built-in on Windows 10/11 (no install needed)
::   md-toc-update.ps1 - sibling script in the same folder
::
:: Usage:
::   md-toc-update.cmd [FILE ...] [--files FILE [FILE ...]] [--dry-run] [--hN] [--help]
::
:: Examples:
::   md-toc-update.cmd                              List MD files and show example commands
::   md-toc-update.cmd setup.md                    Update TOC in a single file
::   md-toc-update.cmd a.md b.md                   Update multiple files
::   md-toc-update.cmd setup.md --dry-run           Preview changes without writing
::   md-toc-update.cmd setup.md --h3                Include H1-H3 headings only
::   md-toc-update.cmd --files a.md b.md --dry-run  Explicit --files form also works
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_PS1=%~dp0md-toc-update.ps1"
set "UPDATE_MD_TOC_DRY_RUN="
set "UPDATE_MD_TOC_HN="
set "UPDATE_MD_TOC_FILES="

:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--help" goto help
if /I "%~1"=="--dry-run" set "UPDATE_MD_TOC_DRY_RUN=1" & shift & goto parse_args
if /I "%~1"=="--h1" set "UPDATE_MD_TOC_HN=h1" & shift & goto parse_args
if /I "%~1"=="--h2" set "UPDATE_MD_TOC_HN=h2" & shift & goto parse_args
if /I "%~1"=="--h3" set "UPDATE_MD_TOC_HN=h3" & shift & goto parse_args
if /I "%~1"=="--h4" set "UPDATE_MD_TOC_HN=h4" & shift & goto parse_args
if /I "%~1"=="--h5" set "UPDATE_MD_TOC_HN=h5" & shift & goto parse_args
if /I "%~1"=="--h6" set "UPDATE_MD_TOC_HN=h6" & shift & goto parse_args
if /I "%~1"=="--files" shift & goto collect_files
goto collect_files

:collect_files
if "%~1"=="" goto run
if /I "%~1"=="--help" goto parse_args
if /I "%~1"=="--dry-run" goto parse_args
if /I "%~1"=="--h1" goto parse_args
if /I "%~1"=="--h2" goto parse_args
if /I "%~1"=="--h3" goto parse_args
if /I "%~1"=="--h4" goto parse_args
if /I "%~1"=="--h5" goto parse_args
if /I "%~1"=="--h6" goto parse_args
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
