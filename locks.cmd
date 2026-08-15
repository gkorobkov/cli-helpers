@echo off
REM locks.cmd - Finds processes whose command lines reference a file or directory.
REM Optionally terminates all matching processes or selected PIDs.
REM
REM Dependencies:
REM   Windows PowerShell - built-in on Windows 10/11
REM
REM Usage:
REM   locks.cmd [path] [--kill] [--help]
REM
REM Examples:
REM   locks.cmd
REM   locks.cmd package.json
REM   locks.cmd "C:\Projects\my-app"
REM   locks.cmd --kill
REM   locks.cmd "C:\Projects\my-app" --kill
REM
REM Notes:
REM   Without a path, the current working directory is checked.
REM   Detection is based on process command lines containing the target path.
REM   This is not a complete Windows file-handle scan.

setlocal

echo [ Running: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0locks.ps1" %* ]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0locks.ps1" %*

set "LOCKS_EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %LOCKS_EXIT_CODE%