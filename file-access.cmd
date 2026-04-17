@echo off
setlocal

::====================================================================
:: file-access.cmd — manage file access permissions
::
:: Usage:
::   file-access.cmd <file>                       — show current permissions
::   file-access.cmd <file> /grant <perms>        — grant permissions
::   file-access.cmd <file> /remove <user>        — remove permissions for user
::   file-access.cmd <file> /fix-ssh-access       — fix SSH key permissions
::
:: Parameters:
::   <file>   — path to the file (e.g. %USERPROFILE%\.ssh\id_rsa)
::   <perms>  — icacls permission mask:
::                F  — Full access
::                M  — Modify
::                RX — Read and execute
::                R  — Read only
::              Applied to current user, SYSTEM, Administrators;
::              inheritance is removed.
::   <user>   — account name to remove (e.g. "BUILTIN\Users", "Everyone")
::
:: /fix-ssh-access removes inheritance, strips BUILTIN\Users, Everyone, and
::                 NT AUTHORITY\Authenticated Users, then grants Full access
::                 to current user, SYSTEM, and Administrators.
::
:: SSH "bad permissions" fix:
::   If you see: Bad permissions. Try removing permissions for user:
::               BUILTIN\Users (S-1-5-32-545) on file ...
::   Run:
::     file-access.cmd %USERPROFILE%\.ssh\id_rsa_2 /fix-ssh-access
::   Or step by step:
::     file-access.cmd %USERPROFILE%\.ssh\id_rsa_2 /remove "BUILTIN\Users"
::     file-access.cmd %USERPROFILE%\.ssh\id_rsa_2 /grant F
::
:: Examples:
::   file-access.cmd %USERPROFILE%\.ssh\id_rsa
::   file-access.cmd %USERPROFILE%\.ssh\id_rsa /fix-ssh-access
::   file-access.cmd %USERPROFILE%\.ssh\id_rsa /grant F
::   file-access.cmd %USERPROFILE%\.ssh\id_rsa /remove "BUILTIN\Users"
::====================================================================

if "%~1"=="" goto :usage

set "KEY_FILE=%~1"

if not exist "%KEY_FILE%" (
    echo Error: file not found: %KEY_FILE%
    exit /b 1
)

if "%~2"=="" goto :show_perms
if /i "%~2"=="/fix-ssh-access" goto :do_fix
if /i "%~2"=="/grant"          goto :do_grant
if /i "%~2"=="/remove"         goto :do_remove

echo Error: unknown option: %~2
goto :usage

:: ------------------------------------------------------------------
:show_perms
echo Current permissions for: %KEY_FILE%
echo.
icacls "%KEY_FILE%"
goto :eof

:: ------------------------------------------------------------------
:do_fix
echo Applying SSH key permissions fix for: %KEY_FILE%
icacls "%KEY_FILE%" /inheritance:r
icacls "%KEY_FILE%" /remove "BUILTIN\Users"                    2>nul
icacls "%KEY_FILE%" /remove "Everyone"                         2>nul
icacls "%KEY_FILE%" /remove "NT AUTHORITY\Authenticated Users" 2>nul
icacls "%KEY_FILE%" /grant:r "%USERDOMAIN%\%USERNAME%:F" "SYSTEM:F" "Administrators:F"
if %errorlevel% equ 0 (
    echo Done. Verifying:
    icacls "%KEY_FILE%"
) else (
    echo Error: failed to apply fix.
    exit /b 1
)
goto :eof

:: ------------------------------------------------------------------
:do_grant
if "%~3"=="" (
    echo Error: /grant requires a permission mask ^(F, M, RX, R^).
    goto :usage
)
set "PERMS=%~3"
echo Granting [%PERMS%] on: %KEY_FILE%
icacls "%KEY_FILE%" /inheritance:r
icacls "%KEY_FILE%" /grant:r "%USERDOMAIN%\%USERNAME%:%PERMS%" "SYSTEM:%PERMS%" "Administrators:%PERMS%"
if %errorlevel% equ 0 (
    echo Permissions granted successfully.
) else (
    echo Error: failed to grant permissions.
    exit /b 1
)
goto :eof

:: ------------------------------------------------------------------
:do_remove
if "%~3"=="" (
    echo Error: /remove requires a user name ^(e.g. "BUILTIN\Users"^).
    goto :usage
)
set "TARGET_USER=%~3"
echo Removing permissions for [%TARGET_USER%] on: %KEY_FILE%
icacls "%KEY_FILE%" /remove "%TARGET_USER%"
if %errorlevel% equ 0 (
    echo Permissions removed successfully.
) else (
    echo Error: failed to remove permissions.
    exit /b 1
)
goto :eof

:: ------------------------------------------------------------------
:usage
echo.
echo  Usage:
echo    %~nx0 ^<file^>                   — show current permissions
echo    %~nx0 ^<file^> /fix-ssh-access   — SSH key permissions fix
echo    %~nx0 ^<file^> /grant ^<perms^>    — grant permissions
echo    %~nx0 ^<file^> /remove ^<user^>    — remove permissions for user
echo.
echo  ^<perms^>:  F=Full  M=Modify  RX=Read+Execute  R=Read
echo  ^<user^>:   e.g. "BUILTIN\Users"  "Everyone"
echo.
echo  Examples:
echo    %~nx0 %%USERPROFILE%%\.ssh\id_rsa
echo    %~nx0 %%USERPROFILE%%\.ssh\id_rsa /fix-ssh-access
echo    %~nx0 %%USERPROFILE%%\.ssh\id_rsa /grant F
echo    %~nx0 %%USERPROFILE%%\.ssh\id_rsa /remove "BUILTIN\Users"
echo.
exit /b 1
