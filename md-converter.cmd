@echo off
REM md-converter.cmd - Converts Markdown to HTML or Jupyter Notebook.
REM Runs the dependency-free PowerShell implementation from this script's directory.
REM Dependencies:
REM   Windows PowerShell 5.1 - built into supported Windows versions
REM   md-converter.ps1      - sibling script in the same directory
REM Usage:
REM   md-converter.cmd [INPUT.md] [PowerShell options]
REM Examples:
REM   md-converter.cmd
REM   md-converter.cmd README.md
REM   md-converter.cmd README.md -Format html,ipynb -OutputDirectory dist
REM   md-converter.cmd README.md -Format html -Force
REM Limitations:
REM   Supports HTML and IPYNB output. Run without arguments for complete help.

setlocal

echo [ Running: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0md-converter.ps1" %* ]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0md-converter.ps1" %*

set "MD_CONVERTER_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %MD_CONVERTER_EXIT_CODE%
