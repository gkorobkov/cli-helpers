@echo off
setlocal enabledelayedexpansion
:: =============================================================
:: ssh-copy-remote.cmd - copy project to remote server via SSH/scp
::
::  Config: *.remote.ini or *.local.ini in current folder (not in git)
::  Requires: ssh, scp, rsync
::
::  Dependencies:
::    ssh, scp  - OpenSSH Client (built-in on Windows 10/11)
::                If missing: Settings > Apps > Optional features > OpenSSH Client
::                Or: winget install Microsoft.OpenSSH.Beta
::                Docs: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
::
::    rsync     - required only for folder copy (excludes .env and .gitignore files)
::                scoop  : scoop install rsync        (https://scoop.sh)
::                choco  : choco install rsync         (https://chocolatey.org)
::                direct : download cwRsync from https://itefix.net/cwrsync (free version)
::                         extract and add to PATH, or place rsync.exe next to this script
::
::  Transfer options (change defaults in the "set" lines below the argument block):
::
::    SCP_OPTS    scp flags for file copy      (default: empty)
::                  -C        compress during transfer
::                  -p        preserve timestamps and permissions
::                  -l 1000   limit bandwidth in kbit/s
::
::    RSYNC_FLAGS rsync flags for folder copy  (default: -avz)
::                  -a        archive: recursive + preserve permissions, timestamps, symlinks
::                  -v        verbose output (show each transferred file)
::                  -z        compress during transfer
::                  -n        dry run: show what would be copied without copying
::                  --delete  remove remote files that are absent in source
::
::    RSYNC_EXCL  rsync exclude pattern        (default: --exclude=.env)
::                  .gitignore rules are always applied via --filter=:- .gitignore
::  
::  See full options description, usage and examples in the end of this script.
::  
::  
:: ssh-copy-remote.cmd Two modes:
::
::  1. Config file:
::       --config=file.ini    config file  (default: first *.remote.ini)
::       --profile=name       profile      (default: default_profile from config)
::       --list               list profiles and exit
::
::  2. Inline (no config file needed):
::       --user=name          SSH user
::       --server=host        SSH server
::       --ssh_key=path       SSH key file
::       --from=path --to=path  local->remote pair (repeat for multiple)
::       --local_path=path --remote_path=path  (legacy single pair)
::       --deploy_hint=cmd    (optional) shown after copy
::
::  Common:
::       --copy               run copy (default: check only)
::       --check              check only
::
::  Examples:
::    ssh-copy-remote.cmd
::    ssh-copy-remote.cmd --copy
::    ssh-copy-remote.cmd --profile=ai-agent --copy
::    ssh-copy-remote.cmd --config=C:\other\cfg.ini --profile=ai-agent --copy
::    ssh-copy-remote.cmd --user=me --server=host --ssh_key=C:\key --from=C:\proj --to=/home/me/proj --copy
::    ssh-copy-remote.cmd --user=me --server=host --from=C:\a.txt --to=/home/me/a.txt --from=C:\dir --to=/home/me/dir --copy
::    ssh-copy-remote.cmd --user=me --server=host --local_path=C:\proj --remote_path=/home/me/proj --copy
:: =============================================================
::  Config file format (save as *.remote.ini):
::
::    default_profile=my-project
::
::    [my-project]
::    description=My Project - myserver.com
::    user=myuser
::    server=myserver.com
::    ssh_key=C:\Users\Me\.ssh\id_rsa
::    local_path=C:\Projects\my-project
::    remote_path=/home/myuser/my-project
::    deploy_hint=cd /home/myuser/my-project && docker compose up -d
::    ; additional pairs (optional):
::    from_1=C:\Projects\config.txt
::    to_1=/home/myuser/config.txt
::    from_2=C:\Projects\nginx
::    to_2=/home/myuser/nginx
::
::    [another-project]
::    description=Another Project - myserver.com
::    user=myuser
::    server=myserver.com
::    ssh_key=C:\Users\Me\.ssh\id_rsa
::    local_path=C:\Projects\another-project
::    remote_path=/home/myuser/another-project
::    deploy_hint=cd /home/myuser/another-project && npm start
:: =============================================================

:: --- Transfer options (edit here to customize) ---
set "SCP_OPTS="
set "RSYNC_FLAGS=-avz"
set "RSYNC_EXCL=--exclude=.env"

set "CMD=check"
set "PROFILE="
set "CFG="
set "RUSER="
set "SERVER="
set "SSH_KEY="
set "LOCAL_PATH="
set "REMOTE_PATH="
set "DEPLOY_HINT="
set "PROFILE_DESC="
set "PAIR_COUNT=0"
set "_PENDING_FROM="



:: =============================================================
:: Parse arguments
:: =============================================================
:parse_args
if "%~1"=="" goto :args_done
set "ARG=%~1"

if /i "%ARG:~0,9%"=="--config="       ( set "CFG=%ARG:~9%"           & shift & goto :parse_args )
if /i "%ARG:~0,10%"=="--profile="     ( set "PROFILE=%ARG:~10%"       & shift & goto :parse_args )
if /i "%ARG:~0,7%"=="--user="         ( set "RUSER=%ARG:~7%"          & shift & goto :parse_args )
if /i "%ARG:~0,9%"=="--server="       ( set "SERVER=%ARG:~9%"         & shift & goto :parse_args )
if /i "%ARG:~0,10%"=="--ssh_key="     ( set "SSH_KEY=%ARG:~10%"       & shift & goto :parse_args )
if /i "%ARG:~0,13%"=="--local_path="  ( set "LOCAL_PATH=%ARG:~13%"    & shift & goto :parse_args )
if /i "%ARG:~0,14%"=="--remote_path=" ( set "REMOTE_PATH=%ARG:~14%"   & shift & goto :parse_args )
if /i "%ARG:~0,14%"=="--deploy_hint=" ( set "DEPLOY_HINT=%ARG:~14%"   & shift & goto :parse_args )
if /i "%ARG:~0,7%"=="--from="         ( set "_PENDING_FROM=%ARG:~7%"  & shift & goto :parse_args )
if /i "%ARG:~0,5%"=="--to=" (
    if not defined _PENDING_FROM (
        echo.
        echo  [ERROR]  --to= without preceding --from=
        echo.
        exit /b 1
    )
    set "PAIR_!PAIR_COUNT!_LOCAL=!_PENDING_FROM!"
    set "PAIR_!PAIR_COUNT!_REMOTE=%ARG:~5%"
    set /a PAIR_COUNT+=1
    set "_PENDING_FROM="
    shift & goto :parse_args
)
if /i "%ARG%"=="--copy"               ( set "CMD=copy"                & shift & goto :parse_args )
if /i "%ARG%"=="--check"              ( set "CMD=check"               & shift & goto :parse_args )
if /i "%ARG%"=="--list"               ( set "CMD=list"                & shift & goto :parse_args )

echo.
echo  [ERROR]  Unknown argument: %ARG%
echo  Valid:   --config=  --profile=  --user=  --server=  --ssh_key=  --local_path=  --remote_path=  --deploy_hint=  --from=  --to=  --check  --copy  --list
echo.
exit /b 1

:args_done
if defined _PENDING_FROM (
    echo.
    echo  [ERROR]  --from= without following --to= for path: %_PENDING_FROM%
    echo.
    exit /b 1
)

:: --- Convert legacy /local_path: /remote_path: to a pair ---
if defined LOCAL_PATH if defined REMOTE_PATH (
    set "PAIR_!PAIR_COUNT!_LOCAL=!LOCAL_PATH!"
    set "PAIR_!PAIR_COUNT!_REMOTE=!REMOTE_PATH!"
    set /a PAIR_COUNT+=1
)
set "LOCAL_PATH="
set "REMOTE_PATH="

:: --- Resolve inline pair local paths to absolute ---
set /a _PAIR_LAST=PAIR_COUNT-1
for /l %%i in (0,1,%_PAIR_LAST%) do (
    set "_TMP=!PAIR_%%i_LOCAL!"
    for %%F in ("!_TMP!") do set "PAIR_%%i_LOCAL=%%~fF"
)

:: =============================================================
:: Inline mode: use params directly if all required ones provided
:: =============================================================
if defined RUSER if defined SERVER if !PAIR_COUNT! gtr 0 goto :run_check

:: =============================================================
:: Config file mode
:: =============================================================
if "%CFG%"=="" (
    for %%F in ("*.remote.ini") do if not defined CFG set "CFG=%%~fF"
    for %%F in ("*.local.ini")  do if not defined CFG set "CFG=%%~fF"
)
if "%CFG%"=="" (
    echo.
    echo  [ERROR]  No config file found. Use inline params or create *.remote.ini
    echo  Config:  --config=file.ini  or place *.remote.ini in current folder
    echo  Inline:  --user=name --server=host --from=local --to=remote [--from=local --to=remote ...]
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

:: --- Get default_profile (top-level, before any section) ---
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
    echo  Use --profile=name or add default_profile=name to config.
    echo  Run --list to see available profiles.
    echo.
    exit /b 1
)

:: --- Load profile section ---
set "_IN_PROF=0"
set "_CFG_LOCAL="
set "_CFG_REMOTE="
for /l %%i in (1,1,20) do ( set "_CFG_FROM_%%i=" & set "_CFG_TO_%%i=" )
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    set "_K=%%A"
    set "_V=%%B"
    if "!_K:~0,1!"=="[" (
        if /i "!_K!"=="[%PROFILE%]" ( set "_IN_PROF=1" ) else ( set "_IN_PROF=0" )
    ) else if "!_IN_PROF!"=="1" (
        if /i "!_K!"=="user"                                    set "RUSER=!_V!"
        if /i "!_K!"=="server"                                  set "SERVER=!_V!"
        if /i "!_K!"=="ssh_key"                                 set "SSH_KEY=!_V!"
        if /i "!_K!"=="local_path"                              set "_CFG_LOCAL=!_V!"
        if /i "!_K!"=="local_dir"                               set "_CFG_LOCAL=!_V!"
        if /i "!_K!"=="remote_path"                             set "_CFG_REMOTE=!_V!"
        if /i "!_K!"=="remote_dir"                              set "_CFG_REMOTE=!_V!"
        if /i "!_K!"=="description"                             set "PROFILE_DESC=!_V!"
        if /i "!_K!"=="deploy_hint"                             set "DEPLOY_HINT=!_V!"
        if /i "!_K:~0,5!"=="from_"                              set "_CFG_!_K!=!_V!"
        if /i "!_K:~0,3!"=="to_"                                set "_CFG_!_K!=!_V!"
    )
)

if "%RUSER%"=="" (
    echo.
    echo  [ERROR]  Profile not found in config: %PROFILE%
    echo  Run --list to see available profiles.
    echo.
    exit /b 1
)

:: --- Add legacy local_path/remote_path pair ---
if defined _CFG_LOCAL if defined _CFG_REMOTE (
    set "PAIR_!PAIR_COUNT!_LOCAL=!_CFG_LOCAL!"
    set "PAIR_!PAIR_COUNT!_REMOTE=!_CFG_REMOTE!"
    set /a PAIR_COUNT+=1
)

:: --- Add from_N/to_N pairs from config ---
for /l %%i in (1,1,20) do (
    if defined _CFG_FROM_%%i (
        set "PAIR_!PAIR_COUNT!_LOCAL=!_CFG_FROM_%%i!"
        set "PAIR_!PAIR_COUNT!_REMOTE=!_CFG_TO_%%i!"
        set /a PAIR_COUNT+=1
    )
)

if !PAIR_COUNT! equ 0 (
    echo.
    echo  [ERROR]  No paths defined in profile: %PROFILE%
    echo  Add local_path/remote_path or from_N/to_N pairs to the profile.
    echo.
    exit /b 1
)

:: --- Resolve config pair local paths ---
set /a _PAIR_LAST=PAIR_COUNT-1
for /l %%i in (0,1,%_PAIR_LAST%) do (
    set "_TMP=!PAIR_%%i_LOCAL!"
    for %%F in ("!_TMP!") do set "PAIR_%%i_LOCAL=%%~fF"
)

:: =============================================================
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
echo  ============================================
echo.

set "SSH_KEY_ARG="
if defined SSH_KEY set "SSH_KEY_ARG=-i "%SSH_KEY%""

set "ALL_OK=1"

:: --- Check SSH key once ---
if defined SSH_KEY (
    if exist "%SSH_KEY%" (
        echo  [OK]     SSH key found
    ) else (
        echo  [ERROR]  SSH key NOT FOUND: %SSH_KEY%
        set "ALL_OK=0"
    )
)

:: --- Check each pair ---
set /a _PAIR_LAST=PAIR_COUNT-1
for /l %%i in (0,1,%_PAIR_LAST%) do (
    set "_LOCAL=!PAIR_%%i_LOCAL!"
    set "_REMOTE=!PAIR_%%i_REMOTE!"
    set "PAIR_%%i_IS_DIR=0"
    set "PAIR_%%i_REMOTE_MISSING=0"
    set "PAIR_%%i_REMOTE_NOPERM=0"

    echo.
    echo  --- Pair %%i: !_LOCAL!  -^>  !_REMOTE!

    if exist "!_LOCAL!\" (
        echo  [OK]     Local folder found
        set "PAIR_%%i_IS_DIR=1"
        where rsync >nul 2>&1
        if !ERRORLEVEL! neq 0 (
            echo  [ERROR]  rsync not found - required for folder copy ^(excludes .env and .gitignore files^)
            echo  Install: scoop install rsync  or  choco install rsync  ^(see script header^)
            set "ALL_OK=0"
        )
    ) else if exist "!_LOCAL!" (
        echo  [OK]     Local file found
    ) else (
        echo  [ERROR]  Local path NOT FOUND: !_LOCAL!
        set "ALL_OK=0"
    )

    echo  Checking SSH to %RUSER%@%SERVER%...
    set "SSH_RESULT="
    set "_SSH_TMP=%TEMP%\ssh_chk_%%i.tmp"
    if "!PAIR_%%i_IS_DIR!"=="1" (
        ssh %SSH_KEY_ARG% -o ConnectTimeout=5 %RUSER%@%SERVER% "if [ -d '!_REMOTE!' ]; then if [ -w '!_REMOTE!' ]; then echo FOUND; else echo NOPERM; fi; else echo MISSING; fi" > "!_SSH_TMP!" 2>&1
    ) else (
        ssh %SSH_KEY_ARG% -o ConnectTimeout=5 %RUSER%@%SERVER% "RPAR=$(dirname '!_REMOTE!'); if [ -d '!_REMOTE!' ] && [ -w '!_REMOTE!' ]; then echo FOUND; elif [ -d $RPAR ] && [ -w $RPAR ]; then echo FOUND; elif [ -d $RPAR ]; then echo NOPERM; else echo MISSING; fi" > "!_SSH_TMP!" 2>&1
    )
    if exist "!_SSH_TMP!" ( set /p SSH_RESULT=< "!_SSH_TMP!" & del "!_SSH_TMP!" 2>nul )

    if not defined SSH_RESULT (
        echo  [FAILED] SSH connection failed: %RUSER%@%SERVER%
        set "ALL_OK=0"
    ) else if /i "!SSH_RESULT!"=="FOUND" (
        echo  [OK]     SSH OK - remote path found
    ) else if /i "!SSH_RESULT!"=="MISSING" (
        if "!PAIR_%%i_IS_DIR!"=="1" (
            echo  [WARN]   SSH OK - remote folder will be created: !_REMOTE!
        ) else (
            echo  [WARN]   SSH OK - remote parent folder will be created for: !_REMOTE!
        )
        set "PAIR_%%i_REMOTE_MISSING=1"
    ) else if /i "!SSH_RESULT!"=="NOPERM" (
        echo  [WARN]   SSH OK - remote path exists but needs sudo chown: !_REMOTE!
        set "PAIR_%%i_REMOTE_NOPERM=1"
    ) else (
        echo  [FAILED] SSH error: !SSH_RESULT!
        set "ALL_OK=0"
    )
)

echo.
if "%ALL_OK%"=="0" ( echo  Fix errors above before copying. & echo. & exit /b 1 )

if /i "%CMD%"=="check" (
    echo  All checks passed. Run with --copy to start copying.
    echo.
    goto :eof
)

:: =============================================================
:do_copy
echo  Starting copy...
echo.

set /a _PAIR_LAST=PAIR_COUNT-1
for /l %%i in (0,1,%_PAIR_LAST%) do (
    set "_LOCAL=!PAIR_%%i_LOCAL!"
    set "_REMOTE=!PAIR_%%i_REMOTE!"

    echo  --- Pair %%i: !_LOCAL!  -^>  !_REMOTE!
    echo.

    if "!PAIR_%%i_IS_DIR!"=="1" (
        rem --- Folder mode ---
        if "!PAIR_%%i_REMOTE_MISSING!"=="1" (
            echo  Creating remote folder: !_REMOTE!
            ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "sudo mkdir -p '!_REMOTE!' && sudo chown %RUSER%:%RUSER% '!_REMOTE!'"
            if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not create remote folder. & exit /b 1 )
            echo  [OK]     Remote folder created.
            echo.
        )
        if "!PAIR_%%i_REMOTE_NOPERM!"=="1" (
            echo  Fixing permissions: !_REMOTE!
            ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "sudo chown %RUSER%:%RUSER% '!_REMOTE!'"
            if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not fix permissions. & exit /b 1 )
            echo  [OK]     Permissions fixed.
            echo.
        )
        set "RSYNC_E=ssh"
        if defined SSH_KEY set "RSYNC_E=ssh -i !SSH_KEY!"
        echo  Command: rsync %RSYNC_FLAGS% %RSYNC_EXCL% "--filter=:- .gitignore" -e "!RSYNC_E!" "!_LOCAL!/" %RUSER%@%SERVER%:!_REMOTE!/
        echo.
        rsync %RSYNC_FLAGS% %RSYNC_EXCL% "--filter=:- .gitignore" -e "!RSYNC_E!" "!_LOCAL!/" %RUSER%@%SERVER%:!_REMOTE!/
    ) else (
        rem --- File mode ---
        if "!PAIR_%%i_REMOTE_MISSING!"=="1" (
            echo  Creating remote parent folder for: !_REMOTE!
            ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "RPAR=$(dirname '!_REMOTE!'); sudo mkdir -p $RPAR && sudo chown %RUSER%:%RUSER% $RPAR"
            if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not create remote parent folder. & exit /b 1 )
            echo  [OK]     Remote parent folder created.
            echo.
        )
        if "!PAIR_%%i_REMOTE_NOPERM!"=="1" (
            echo  Fixing permissions for parent of: !_REMOTE!
            ssh %SSH_KEY_ARG% %RUSER%@%SERVER% "RPAR=$(dirname '!_REMOTE!'); sudo chown %RUSER%:%RUSER% $RPAR"
            if !ERRORLEVEL! neq 0 ( echo  [FAILED] Could not fix permissions. & exit /b 1 )
            echo  [OK]     Permissions fixed.
            echo.
        )
        echo  Command: scp %SCP_OPTS% !SSH_KEY_ARG! "!_LOCAL!" %RUSER%@%SERVER%:!_REMOTE!
        echo.
        scp %SCP_OPTS% !SSH_KEY_ARG! "!_LOCAL!" %RUSER%@%SERVER%:!_REMOTE!
    )

    if !ERRORLEVEL! equ 0 (
        echo  [OK]  Copied: pair %%i
    ) else (
        echo  [FAILED] scp failed for pair %%i with code !ERRORLEVEL!
        exit /b 1
    )
    echo.
)

echo  All pairs copied successfully.
if defined DEPLOY_HINT ( echo. & echo  On server: & echo    %DEPLOY_HINT% )
echo.
goto :eof

:: =============================================================
:show_list
echo.
echo  Config: %CFG%

:: Find default_profile
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


::  rsync reference (https://linux.die.net/man/1/rsync):
::
::  Mode flags:
::    -a, --archive         archive mode = -rlptgoD (recursive, preserve all attributes)
::    -r, --recursive       recurse into directories
::    -v, --verbose         show each transferred file name
::    -z, --compress        compress data during transfer (useful on slow links)
::    -n, --dry-run         show what would be transferred without doing it
::    -P                    shorthand for --partial --progress (resume + show progress)
::    -h, --human-readable  output file sizes in human-readable format (KB, MB)
::        --stats           print transfer statistics at the end
::
::  File selection:
::        --delete          delete remote files not present in source (mirror mode)
::        --exclude=PAT     exclude files matching pattern  e.g. --exclude='*.log'
::        --include=PAT     force-include files (overrides --exclude)
::        --filter=RULE     general filter rule  e.g. --filter=':- .gitignore'
::        --ignore-existing skip files that already exist on the remote
::        --update          skip files that are newer on the remote
::        --checksum        compare by checksum instead of size+timestamp
::
::  Transfer:
::    -e CMD                remote shell  e.g. -e "ssh -i ~/.ssh/key"
::        --bwlimit=KBPS    limit bandwidth  e.g. --bwlimit=5000 for ~5 Mbit/s
::        --partial         keep partially transferred files (allows resume)
::        --progress        show per-file transfer progress
::
::  Backup:
::        --backup          make backups of changed/deleted files
::        --backup-dir=DIR  store backups in DIR on remote
::        --suffix=.bak     suffix for backup files (default: ~)
::
::  rsync examples (set RSYNC_FLAGS / RSYNC_EXCL variables above to apply):
::    RSYNC_FLAGS=-avzn                                 dry run (show without copying)
::    RSYNC_FLAGS=-avz --delete                         mirror (remove extra remote files)
::    RSYNC_FLAGS=-avzP                                 show progress + allow resume
::    RSYNC_FLAGS=-avz --bwlimit=5000                   limit to ~5 Mbit/s
::    RSYNC_EXCL=--exclude='*.log'                      exclude log files
::    RSYNC_EXCL=--exclude=.env --exclude='*.log'       exclude multiple patterns
::
:: =============================================================
::  scp reference:
::
::    -C          compress during transfer
::    -p          preserve timestamps and permissions
::    -l KBPS     limit bandwidth in Kbit/s  e.g. -l 5000
::    -P PORT     remote port (default: 22)
::    -q          quiet mode (suppress progress)
::    -o OPT      pass SSH option  e.g. -o ConnectTimeout=10
::
::  scp examples (set SCP_OPTS variable above to apply):
::    SCP_OPTS=-C             compress during transfer
::    SCP_OPTS=-p             preserve timestamps and permissions
::    SCP_OPTS=-C -p          compress and preserve timestamps
::    SCP_OPTS=-l 5000        limit bandwidth to ~5 Mbit/s
::    SCP_OPTS=-P 2222        use non-default SSH port