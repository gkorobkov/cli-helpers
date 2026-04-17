@echo off
setlocal
rem =============================================================
rem copy-ssh-remote.cmd - copy project to remote server via SSH/scp
rem
rem  Config: *.local.json in current folder (not in git)
rem  Template: copy-remote.local.example.json
rem
rem  Parameters (all optional, named, any order):
rem    /config:path.json    config file  (default: first *.local.json in current dir)
rem    /profile:name        profile name (default: default_profile from config)
rem    /copy                run copy     (default: check only)
rem    /list                list available profiles and exit
rem
rem  Examples:
rem    copy-ssh-remote.cmd
rem    copy-ssh-remote.cmd /copy
rem    copy-ssh-remote.cmd /profile:ai-agent
rem    copy-ssh-remote.cmd /profile:ai-agent /copy
rem    copy-ssh-remote.cmd /config:C:\other\config.json /profile:ai-agent /copy
rem
rem =============================================================
rem  Config file format (save as *.local.json, e.g. copy-remote.local.json):
rem
rem  {
rem    "default_profile": "my-project",
rem    "profiles": {
rem      "my-project": {
rem        "description": "My Project - myserver.com",
rem        "user":        "myuser",
rem        "server":      "myserver.com",
rem        "ssh_key":     "C:\\Users\\Me\\.ssh\\id_rsa",
rem        "local_dir":   "C:\\Projects\\my-project",
rem        "remote_dir":  "/home/myuser/my-project",
rem        "deploy_hint": "cd /home/myuser/my-project && docker compose up -d"
rem      },
rem      "another-project": {
rem        "description": "Another Project - myserver.com",
rem        "user":        "myuser",
rem        "server":      "myserver.com",
rem        "ssh_key":     "C:\\Users\\Me\\.ssh\\id_rsa",
rem        "local_dir":   "C:\\Projects\\another-project",
rem        "remote_dir":  "/home/myuser/another-project",
rem        "deploy_hint": "cd /home/myuser/another-project && npm start"
rem      }
rem    }
rem  }
rem =============================================================

set "CMD=check"
set "PROFILE="
set "CFG="

rem =============================================================
rem Parse named arguments (any order)
rem =============================================================
:parse_args
if "%~1"=="" goto :args_done
set "ARG=%~1"

if /i "%ARG:~0,8%"=="/config:"  ( set "CFG=%ARG:~8%"     & shift & goto :parse_args )
if /i "%ARG:~0,9%"=="/profile:" ( set "PROFILE=%ARG:~9%" & shift & goto :parse_args )
if /i "%ARG%"=="/copy"          ( set "CMD=copy"          & shift & goto :parse_args )
if /i "%ARG%"=="/check"         ( set "CMD=check"         & shift & goto :parse_args )
if /i "%ARG%"=="/list"          ( set "CMD=list"          & shift & goto :parse_args )

echo.
echo  [ERROR]  Unknown argument: %ARG%
echo  Valid:   /config:file.json  /profile:name  /check  /copy  /list
echo.
exit /b 1

:args_done

rem =============================================================
rem Find config file
rem =============================================================
if "%CFG%"=="" (
    for %%F in ("*.local.json") do if not defined CFG set "CFG=%%~fF"
)
if "%CFG%"=="" (
    echo.
    echo  [ERROR]  No config file found in current folder.
    echo  Create a *.local.json file (see copy-remote.local.example.json)
    echo  or use /config:path.json
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

rem =============================================================
rem Load profile from JSON via PowerShell
rem =============================================================
if "%PROFILE%"=="" (
    for /f "tokens=*" %%V in ('powershell -NoProfile -Command "(Get-Content '%CFG%' -Raw | ConvertFrom-Json).default_profile" 2^>nul') do set "PROFILE=%%V"
)
if "%PROFILE%"=="" (
    echo.
    echo  [ERROR]  No profile specified and no default_profile set in config.
    echo  Use /profile:name or add "default_profile" to config.
    echo  Run /list to see available profiles.
    echo.
    exit /b 1
)

set "VARS_TMP=%TEMP%\ssh_profile.tmp"
powershell -NoProfile -Command ^
    "$c=Get-Content '%CFG%' -Raw|ConvertFrom-Json; $p=$c.profiles.'%PROFILE%'; if(-not $p){exit 1}; ^
    @('PROFILE_DESC='+$p.description,'RUSER='+$p.user,'SERVER='+$p.server, ^
      'SSH_KEY='+$p.ssh_key,'LOCAL_DIR='+$p.local_dir,'REMOTE_DIR='+$p.remote_dir, ^
      'DEPLOY_HINT='+$p.deploy_hint)" > "%VARS_TMP%" 2>nul

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [ERROR]  Profile not found in config: %PROFILE%
    echo  Run /list to see available profiles.
    echo.
    if exist "%VARS_TMP%" del "%VARS_TMP%"
    exit /b 1
)
for /f "tokens=1,* delims==" %%A in (%VARS_TMP%) do set "%%A=%%B"
del "%VARS_TMP%" 2>nul

rem =============================================================
:run_check
echo.
echo  ============================================
echo   Profile : %PROFILE%  (%PROFILE_DESC%)
echo   Command : %CMD%
echo   Config  : %CFG%
echo  ============================================
echo   Server  : %RUSER%@%SERVER%
echo   SSH key : %SSH_KEY%
echo   Local   : %LOCAL_DIR%
echo   Remote  : %REMOTE_DIR%
echo  ============================================
echo.

set "ALL_OK=1"
set "REMOTE_MISSING=0"

if exist "%LOCAL_DIR%\" (
    echo  [OK]     Local folder found
) else (
    echo  [ERROR]  Local folder NOT FOUND: %LOCAL_DIR%
    set "ALL_OK=0"
)

if exist "%SSH_KEY%" (
    echo  [OK]     SSH key found
) else (
    echo  [ERROR]  SSH key NOT FOUND: %SSH_KEY%
    set "ALL_OK=0"
)

echo  Checking SSH to %RUSER%@%SERVER%...
set "SSH_RESULT="
set "SSH_TMP=%TEMP%\ssh_chk.tmp"
ssh -i %SSH_KEY% -o ConnectTimeout=5 %RUSER%@%SERVER% "test -d %REMOTE_DIR% && echo FOUND || echo MISSING" > "%SSH_TMP%" 2>&1
if exist "%SSH_TMP%" ( set /p SSH_RESULT=< "%SSH_TMP%" & del "%SSH_TMP%" 2>nul )

if not defined SSH_RESULT (
    echo  [FAILED] SSH connection failed: %RUSER%@%SERVER%
    set "ALL_OK=0"
) else if /i "%SSH_RESULT%"=="FOUND" (
    echo  [OK]     SSH OK - remote folder found
) else if /i "%SSH_RESULT%"=="MISSING" (
    echo  [WARN]   SSH OK - remote folder will be created: %REMOTE_DIR%
    set "REMOTE_MISSING=1"
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
    ssh -i %SSH_KEY% %RUSER%@%SERVER% "mkdir -p %REMOTE_DIR%"
    if %ERRORLEVEL% neq 0 ( echo  [FAILED] Could not create remote folder. & exit /b 1 )
    echo  [OK]     Remote folder created.
    echo.
)

scp -i %SSH_KEY% -r "%LOCAL_DIR%\." %RUSER%@%SERVER%:%REMOTE_DIR%/

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
powershell -NoProfile -Command ^
    "$c=Get-Content '%CFG%' -Raw|ConvertFrom-Json; ^
    Write-Host '  Profiles (default: '+$c.default_profile+'):'; ^
    $c.profiles.PSObject.Properties | ForEach-Object { ^
        $mark = if ($_.Name -eq $c.default_profile) {'*'} else {' '}; ^
        Write-Host (' ' + $mark + ' {0,-20} - {1}' -f $_.Name, $_.Value.description) ^
    }"
echo.
goto :eof
