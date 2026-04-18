@echo off
setlocal enabledelayedexpansion
rem =============================================================
rem copy-ssh-remote.cmd - copy project to remote server via SSH/scp
rem
rem  Config: *.remote.ini or *.local.ini in current folder (not in git)
rem  Requires: ssh, scp
rem
rem  Two modes:
rem
rem  1. Config file:
rem       /config:file.ini    config file  (default: first *.remote.ini)
rem       /profile:name       profile      (default: default_profile from config)
rem       /list               list profiles and exit
rem
rem  2. Inline (no config file needed):
rem       /user:name          SSH user
rem       /server:host        SSH server
rem       /ssh_key:path       SSH key file
rem       /local_dir:path     local folder
rem       /remote_dir:path    remote folder
rem       /deploy_hint:cmd    (optional) shown after copy
rem
rem  Common:
rem       /copy               run copy (default: check only)
rem       /check              check only
rem
rem  Examples:
rem    copy-ssh-remote.cmd
rem    copy-ssh-remote.cmd /copy
rem    copy-ssh-remote.cmd /profile:ai-agent /copy
rem    copy-ssh-remote.cmd /config:C:\other\cfg.ini /profile:ai-agent /copy
rem    copy-ssh-remote.cmd /user:me /server:host /ssh_key:C:\key /local_dir:C:\proj /remote_dir:/home/me/proj /copy
rem =============================================================
rem  Config file format (save as *.remote.ini):
rem
rem    default_profile=my-project
rem
rem    [my-project]
rem    description=My Project - myserver.com
rem    user=myuser
rem    server=myserver.com
rem    ssh_key=C:\Users\Me\.ssh\id_rsa
rem    local_dir=C:\Projects\my-project
rem    remote_dir=/home/myuser/my-project
rem    deploy_hint=cd /home/myuser/my-project && docker compose up -d
rem
rem    [another-project]
rem    description=Another Project - myserver.com
rem    user=myuser
rem    server=myserver.com
rem    ssh_key=C:\Users\Me\.ssh\id_rsa
rem    local_dir=C:\Projects\another-project
rem    remote_dir=/home/myuser/another-project
rem    deploy_hint=cd /home/myuser/another-project && npm start
rem =============================================================

set "CMD=check"
set "PROFILE="
set "CFG="
set "RUSER="
set "SERVER="
set "SSH_KEY="
set "LOCAL_DIR="
set "REMOTE_DIR="
set "DEPLOY_HINT="
set "PROFILE_DESC="

rem =============================================================
rem Parse arguments
rem =============================================================
:parse_args
if "%~1"=="" goto :args_done
set "ARG=%~1"

if /i "%ARG:~0,8%"=="/config:"      ( set "CFG=%ARG:~8%"          & shift & goto :parse_args )
if /i "%ARG:~0,9%"=="/profile:"     ( set "PROFILE=%ARG:~9%"       & shift & goto :parse_args )
if /i "%ARG:~0,6%"=="/user:"        ( set "RUSER=%ARG:~6%"         & shift & goto :parse_args )
if /i "%ARG:~0,8%"=="/server:"      ( set "SERVER=%ARG:~8%"        & shift & goto :parse_args )
if /i "%ARG:~0,9%"=="/ssh_key:"     ( set "SSH_KEY=%ARG:~9%"       & shift & goto :parse_args )
if /i "%ARG:~0,11%"=="/local_dir:"  ( set "LOCAL_DIR=%ARG:~11%"    & shift & goto :parse_args )
if /i "%ARG:~0,12%"=="/remote_dir:" ( set "REMOTE_DIR=%ARG:~12%"   & shift & goto :parse_args )
if /i "%ARG:~0,13%"=="/deploy_hint:"( set "DEPLOY_HINT=%ARG:~13%"  & shift & goto :parse_args )
if /i "%ARG%"=="/copy"              ( set "CMD=copy"               & shift & goto :parse_args )
if /i "%ARG%"=="/check"             ( set "CMD=check"              & shift & goto :parse_args )
if /i "%ARG%"=="/list"              ( set "CMD=list"               & shift & goto :parse_args )

echo.
echo  [ERROR]  Unknown argument: %ARG%
echo  Valid:   /config:  /profile:  /user:  /server:  /ssh_key:  /local_dir:  /remote_dir:  /deploy_hint:  /check  /copy  /list
echo.
exit /b 1

:args_done

rem Resolve LOCAL_DIR to absolute path (handles relative paths like ./nginx)
if defined LOCAL_DIR for %%F in ("%LOCAL_DIR%") do set "LOCAL_DIR=%%~fF"

rem =============================================================
rem Inline mode: use params directly if all required ones provided
rem =============================================================
if defined RUSER if defined SERVER if defined LOCAL_DIR if defined REMOTE_DIR goto :run_check

rem =============================================================
rem Config file mode
rem =============================================================
if "%CFG%"=="" (
    for %%F in ("*.remote.ini") do if not defined CFG set "CFG=%%~fF"
    for %%F in ("*.local.ini")  do if not defined CFG set "CFG=%%~fF"
)
if "%CFG%"=="" (
    echo.
    echo  [ERROR]  No config file found. Use inline params or create *.remote.ini
    echo  Config:  /config:file.ini  or place *.remote.ini in current folder
    echo  Inline:  /user:name /server:host /local_dir:path /remote_dir:path [/ssh_key:path]
    echo.
    exit /b 1
)
if not exist "%CFG%" (
    echo.
    echo  [ERROR]  Config not found: %CFG%
    echo.
    exit /b 1
)

if /i "%CMD%"=="list" goto :show_list

rem --- Get default_profile (top-level, before any section) ---
if "%PROFILE%"=="" (
    set "_IN_SECT=0"
    for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
        set "_K=%%A"
        if "!_K:~0,1!"=="[" ( set "_IN_SECT=1" ) else (
            if "!_IN_SECT!"=="0" if /i "!_K!"=="default_profile" if not defined PROFILE set "PROFILE=%%B"
        )
    )
)
if "%PROFILE%"=="" (
    echo.
    echo  [ERROR]  No profile specified and no default_profile in config.
    echo  Use /profile:name or add default_profile=name to config.
    echo  Run /list to see available profiles.
    echo.
    exit /b 1
)

rem --- Load profile section ---
set "_IN_PROF=0"
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    set "_K=%%A"
    set "_V=%%B"
    if "!_K:~0,1!"=="[" (
        if /i "!_K!"=="[%PROFILE%]" ( set "_IN_PROF=1" ) else ( set "_IN_PROF=0" )
    ) else if "!_IN_PROF!"=="1" (
        if /i "!_K!"=="user"        set "RUSER=!_V!"
        if /i "!_K!"=="server"      set "SERVER=!_V!"
        if /i "!_K!"=="ssh_key"     set "SSH_KEY=!_V!"
        if /i "!_K!"=="local_dir"   set "LOCAL_DIR=!_V!"
        if /i "!_K!"=="remote_dir"  set "REMOTE_DIR=!_V!"
        if /i "!_K!"=="description" set "PROFILE_DESC=!_V!"
        if /i "!_K!"=="deploy_hint" set "DEPLOY_HINT=!_V!"
    )
)

if "%RUSER%"=="" (
    echo.
    echo  [ERROR]  Profile not found in config: %PROFILE%
    echo  Run /list to see available profiles.
    echo.
    exit /b 1
)

rem =============================================================
:run_check
echo.
echo  ============================================
if defined PROFILE (
    echo   Profile : %PROFILE%  ^(%PROFILE_DESC%^)
) else (
    echo   Mode    : inline
)
echo   Command : %CMD%
if defined CFG echo   Config  : %CFG%
echo  ============================================
echo   Server  : %RUSER%@%SERVER%
if defined SSH_KEY ( echo   SSH key : %SSH_KEY% ) else ( echo   SSH key : ^(default^) )
echo   Local   : %LOCAL_DIR%
echo   Remote  : %REMOTE_DIR%
echo  ============================================
echo.

set "ALL_OK=1"
set "REMOTE_MISSING=0"
set "REMOTE_NOPERM=0"

if exist "%LOCAL_DIR%\" (
    echo  [OK]     Local folder found
) else (
    echo  [ERROR]  Local folder NOT FOUND: %LOCAL_DIR%
    set "ALL_OK=0"
)

if defined SSH_KEY (
    if exist "%SSH_KEY%" (
        echo  [OK]     SSH key found
    ) else (
        echo  [ERROR]  SSH key NOT FOUND: %SSH_KEY%
        set "ALL_OK=0"
    )
)

set "SSH_KEY_ARG="
if defined SSH_KEY set "SSH_KEY_ARG=-i "%SSH_KEY%""

echo  Checking SSH to %RUSER%@%SERVER%...
set "SSH_RESULT="
set "SSH_TMP=%TEMP%\ssh_chk.tmp"
ssh %SSH_KEY_ARG% -o ConnectTimeout=5 %RUSER%@%SERVER% "if [ -d '%REMOTE_DIR%' ]; then if [ -w '%REMOTE_DIR%' ]; then echo FOUND; else echo NOPERM; fi; else echo MISSING; fi" > "%SSH_TMP%" 2>&1
if exist "%SSH_TMP%" ( set /p SSH_RESULT=< "%SSH_TMP%" & del "%SSH_TMP%" 2>nul )

if not defined SSH_RESULT (
    echo  [FAILED] SSH connection failed: %RUSER%@%SERVER%
    set "ALL_OK=0"
) else if /i "%SSH_RESULT%"=="FOUND" (
    echo  [OK]     SSH OK - remote folder found
) else if /i "%SSH_RESULT%"=="MISSING" (
    echo  [WARN]   SSH OK - remote folder will be created: %REMOTE_DIR%
    set "REMOTE_MISSING=1"
) else if /i "%SSH_RESULT%"=="NOPERM" (
    echo  [WARN]   SSH OK - remote folder exists but needs sudo chown: %REMOTE_DIR%
    set "REMOTE_NOPERM=1"
) else (
    echo  [FAILED] SSH error: %SSH_RESULT%
    set "ALL_OK=0"
)

echo.
if "%ALL_OK%"=="0" ( echo  Fix errors above before copying. & echo. & exit /b 1 )

if /i "%CMD%"=="check" (
    echo  All checks passed. Run with /copy to start copying.
    echo.
    goto :eof
)

rem =============================================================
:do_copy
echo  Starting copy...
echo.

if "%REMOTE_MISSING%"=="1" (
    echo  Creating remote folder: %REMOTE_DIR%
    ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "sudo mkdir -p '%REMOTE_DIR%' && sudo chown %RUSER%:%RUSER% '%REMOTE_DIR%'"
    if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not create remote folder. & exit /b 1 )
    echo  [OK]     Remote folder created.
    echo.
)
if "%REMOTE_NOPERM%"=="1" (
    echo  Fixing permissions: %REMOTE_DIR%
    ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "sudo chown %RUSER%:%RUSER% '%REMOTE_DIR%'"
    if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not fix permissions. & exit /b 1 )
    echo  [OK]     Permissions fixed.
    echo.
)

scp %SSH_KEY_ARG% -r "%LOCAL_DIR%\." %RUSER%@%SERVER%:%REMOTE_DIR%/

if %ERRORLEVEL% equ 0 (
    echo.
    echo  [OK]  Copy completed.
    if defined DEPLOY_HINT ( echo. & echo  On server: & echo    %DEPLOY_HINT% )
) else (
    echo  [FAILED] scp failed with code %ERRORLEVEL%
    exit /b 1
)
echo.
goto :eof

rem =============================================================
:show_list
echo.
echo  Config: %CFG%

rem Find default_profile
set "_DEF="
set "_IN_SECT=0"
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    set "_K=%%A"
    if "!_K:~0,1!"=="[" ( set "_IN_SECT=1" ) else (
        if "!_IN_SECT!"=="0" if /i "!_K!"=="default_profile" set "_DEF=%%B"
    )
)

echo  Profiles (default: %_DEF%):
set "_CUR_NAME="
set "_CUR_DESC="
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    set "_K=%%A"
    set "_V=%%B"
    if "!_K:~0,1!"=="[" (
        if defined _CUR_NAME (
            set "_MARK= "
            if /i "!_CUR_NAME!"=="!_DEF!" set "_MARK=*"
            echo   !_MARK! !_CUR_NAME! - !_CUR_DESC!
        )
        set "_CUR_NAME=!_K:~1,-1!"
        set "_CUR_DESC="
    ) else if defined _CUR_NAME (
        if /i "!_K!"=="description" set "_CUR_DESC=!_V!"
    )
)
if defined _CUR_NAME (
    set "_MARK= "
    if /i "!_CUR_NAME!"=="!_DEF!" set "_MARK=*"
    echo   !_MARK! !_CUR_NAME! - !_CUR_DESC!
)
echo.
goto :eof
