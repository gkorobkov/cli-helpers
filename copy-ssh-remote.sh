#!/usr/bin/env bash
# =============================================================
# copy-ssh-remote.sh - copy project to remote server via SSH/scp
#
#  Config: *.remote.ini or *.local.ini in current folder (not in git)
#
#  Dependencies:
#    ssh, scp  - OpenSSH (standard on Linux/macOS; on some distros: sudo apt install openssh-client)
#
#    rsync     - required only for folder sync (excludes .env and .gitignore files)
#                sudo apt install rsync  /  brew install rsync  /  scoop install rsync
#
#  Transfer options (edit defaults below variable declarations to customize):
#
#    SCP_OPTS    scp flags for file copy      (default: empty)
#                  -C        compress during transfer
#                  -p        preserve timestamps and permissions
#                  -l 1000   limit bandwidth in kbit/s
#
#    RSYNC_FLAGS rsync flags for folder copy  (default: -avz)
#                  -a        archive: recursive + preserve permissions, timestamps, symlinks
#                  -v        verbose output (show each transferred file)
#                  -z        compress during transfer
#                  -n        dry run: show what would be copied without copying
#                  --delete  remove remote files that are absent in source
#
#    RSYNC_EXCL  rsync exclude pattern        (default: --exclude=.env)
#                  .gitignore rules are always applied via --filter=':- .gitignore'
#
#  Two modes:
#
#  1. Config file:
#       --config=file.ini    config file  (default: first *.remote.ini)
#       --profile=name       profile      (default: default_profile from config)
#       --list               list profiles and exit
#
#  2. Inline (no config file needed):
#       --user=name          SSH user
#       --server=host        SSH server
#       --ssh_key=path       SSH key file
#       --from=path --to=path  local->remote pair (repeat for multiple)
#       --local_dir=path --remote_dir=path  (legacy single pair)
#       --deploy_hint=cmd    (optional) shown after copy
#
#  Common:
#       --copy               run copy (default: check only)
#       --check              check only
#
#  Examples:
#    ./copy-ssh-remote.sh
#    ./copy-ssh-remote.sh --copy
#    ./copy-ssh-remote.sh --profile=ai-agent --copy
#    ./copy-ssh-remote.sh --config=/other/cfg.ini --profile=ai-agent --copy
#    ./copy-ssh-remote.sh --user=me --server=host --ssh_key=~/.ssh/id_rsa --from=/home/me/proj --to=/remote/proj --copy
#    ./copy-ssh-remote.sh --user=me --server=host --from=/home/me/a.txt --to=/remote/a.txt --from=/home/me/dir --to=/remote/dir --copy
#    ./copy-ssh-remote.sh --user=me --server=host --local_dir=/home/me/proj --remote_dir=/remote/proj --copy
# =============================================================
#  Config file format (save as *.remote.ini):
#
#    default_profile=my-project
#
#    [my-project]
#    description=My Project - myserver.com
#    user=myuser
#    server=myserver.com
#    ssh_key=~/.ssh/id_rsa
#    local_dir=/home/me/projects/my-project
#    remote_dir=/home/myuser/my-project
#    deploy_hint=cd /home/myuser/my-project && docker compose up -d
#    ; additional pairs (optional):
#    from_1=/home/me/projects/config.txt
#    to_1=/home/myuser/config.txt
#    from_2=/home/me/projects/scripts
#    to_2=/home/myuser/scripts
#
#    [another-project]
#    description=Another Project - myserver.com
#    user=myuser
#    server=myserver.com
#    ssh_key=~/.ssh/id_rsa
#    local_dir=/home/me/projects/another-project
#    remote_dir=/home/myuser/another-project
#    deploy_hint=cd /home/myuser/another-project && npm start
# =============================================================

CMD="check"
PROFILE=""
CFG=""
RUSER=""
SERVER=""
SSH_KEY=""
LOCAL_DIR=""
REMOTE_DIR=""
DEPLOY_HINT=""
PROFILE_DESC=""

declare -a PAIR_LOCALS=()
declare -a PAIR_REMOTES=()
declare -a PAIR_IS_DIR=()
declare -a PAIR_REMOTE_MISSING=()
declare -a PAIR_REMOTE_NOPERM=()

_pending_from=""

# --- Transfer options (edit here to customize) ---
SCP_OPTS=()
RSYNC_FLAGS=(-avz)
RSYNC_EXCL=(--exclude=.env)

# =============================================================
# Parse arguments
# =============================================================
for ARG in "$@"; do
    case "$ARG" in
        --config=*)      CFG="${ARG#--config=}" ;;
        --profile=*)     PROFILE="${ARG#--profile=}" ;;
        --user=*)        RUSER="${ARG#--user=}" ;;
        --server=*)      SERVER="${ARG#--server=}" ;;
        --ssh_key=*)     SSH_KEY="${ARG#--ssh_key=}" ;;
        --local_dir=*)   LOCAL_DIR="${ARG#--local_dir=}" ;;
        --remote_dir=*)  REMOTE_DIR="${ARG#--remote_dir=}" ;;
        --deploy_hint=*) DEPLOY_HINT="${ARG#--deploy_hint=}" ;;
        --from=*)        _pending_from="${ARG#--from=}" ;;
        --to=*)
            _remote="${ARG#--to=}"
            if [[ -z "$_pending_from" ]]; then
                echo ""
                echo "  [ERROR]  --to= without preceding --from="
                echo ""
                exit 1
            fi
            PAIR_LOCALS+=("$(realpath -m "$_pending_from")")
            PAIR_REMOTES+=("$_remote")
            _pending_from=""
            ;;
        --copy)          CMD="copy" ;;
        --check)         CMD="check" ;;
        --list)          CMD="list" ;;
        *)
            echo ""
            echo "  [ERROR]  Unknown argument: $ARG"
            echo "  Valid:   --config=  --profile=  --user=  --server=  --ssh_key=  --local_dir=  --remote_dir=  --deploy_hint=  --from=  --to=  --check  --copy  --list"
            echo ""
            exit 1 ;;
    esac
done

if [[ -n "$_pending_from" ]]; then
    echo ""
    echo "  [ERROR]  --from= without following --to= for path: $_pending_from"
    echo ""
    exit 1
fi

# Convert legacy --local_dir/--remote_dir to a pair
if [[ -n "$LOCAL_DIR" && -n "$REMOTE_DIR" ]]; then
    PAIR_LOCALS+=("$(realpath -m "$LOCAL_DIR")")
    PAIR_REMOTES+=("$REMOTE_DIR")
fi

# =============================================================
# Config file mode (skip if all inline params provided)
# =============================================================
if [[ -z "$RUSER" || -z "$SERVER" || ${#PAIR_LOCALS[@]} -eq 0 ]]; then

    if [[ -z "$CFG" ]]; then
        for f in *.remote.ini; do [[ -f "$f" ]] && CFG="$(realpath "$f")" && break; done
    fi
    if [[ -z "$CFG" ]]; then
        for f in *.local.ini; do [[ -f "$f" ]] && CFG="$(realpath "$f")" && break; done
    fi

    if [[ -z "$CFG" ]]; then
        echo ""
        echo "  [ERROR]  No config file found. Use inline params or create *.remote.ini"
        echo "  Config:  --config=file.ini  or place *.remote.ini in current folder"
        echo "  Inline:  --user=name --server=host --from=local --to=remote [--from=local --to=remote ...]"
        echo ""
        exit 1
    fi

    if [[ ! -f "$CFG" ]]; then
        echo ""
        echo "  [ERROR]  Config not found: $CFG"
        echo ""
        exit 1
    fi

    # List profiles
    if [[ "$CMD" == "list" ]]; then
        _default=""
        while IFS= read -r line; do
            line="${line#"${line%%[! ]*}"}"
            [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
            [[ "$line" == \[* ]] && break
            key="${line%%=*}"; val="${line#*=}"
            [[ "${key,,}" == "default_profile" ]] && _default="$val"
        done < "$CFG"
        echo ""
        echo "  Config: $CFG"
        echo "  Profiles (default: $_default):"
        _cur_name="" _cur_desc=""
        while IFS= read -r line; do
            line="${line#"${line%%[! ]*}"}"
            [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
            if [[ "$line" == \[* ]]; then
                if [[ -n "$_cur_name" ]]; then
                    _mark=" "; [[ "$_cur_name" == "$_default" ]] && _mark="*"
                    printf "  %s %-20s - %s\n" "$_mark" "$_cur_name" "$_cur_desc"
                fi
                _cur_name="${line:1:${#line}-2}"; _cur_desc=""
            else
                key="${line%%=*}"; val="${line#*=}"
                [[ "${key,,}" == "description" ]] && _cur_desc="$val"
            fi
        done < "$CFG"
        if [[ -n "$_cur_name" ]]; then
            _mark=" "; [[ "$_cur_name" == "$_default" ]] && _mark="*"
            printf "  %s %-20s - %s\n" "$_mark" "$_cur_name" "$_cur_desc"
        fi
        echo ""
        exit 0
    fi

    # Get default_profile (top-level, before any section)
    if [[ -z "$PROFILE" ]]; then
        while IFS= read -r line; do
            line="${line#"${line%%[! ]*}"}"
            [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
            [[ "$line" == \[* ]] && break
            key="${line%%=*}"; val="${line#*=}"
            [[ "${key,,}" == "default_profile" ]] && PROFILE="$val"
        done < "$CFG"
    fi

    if [[ -z "$PROFILE" ]]; then
        echo ""
        echo "  [ERROR]  No profile specified and no default_profile in config."
        echo "  Use --profile=name or add default_profile=name to config."
        echo "  Run --list to see available profiles."
        echo ""
        exit 1
    fi

    # Load profile section
    _in_profile=0
    _cfg_local=""
    _cfg_remote=""
    declare -A _cfg_from=()
    declare -A _cfg_to=()
    while IFS= read -r line; do
        line="${line#"${line%%[! ]*}"}"
        [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
        if [[ "$line" == "[$PROFILE]" ]]; then
            _in_profile=1; continue
        fi
        [[ "$line" == \[* ]] && { _in_profile=0; continue; }
        [[ $_in_profile -eq 0 ]] && continue
        key="${line%%=*}"; val="${line#*=}"; _lkey="${key,,}"
        case "$_lkey" in
            user)                    RUSER="$val" ;;
            server)                  SERVER="$val" ;;
            ssh_key)                 SSH_KEY="$val" ;;
            local_dir|local_path)    _cfg_local="$val" ;;
            remote_dir|remote_path)  _cfg_remote="$val" ;;
            description)             PROFILE_DESC="$val" ;;
            deploy_hint)             DEPLOY_HINT="$val" ;;
            from_[0-9]*)             _cfg_from["${_lkey#from_}"]="$val" ;;
            to_[0-9]*)               _cfg_to["${_lkey#to_}"]="$val" ;;
        esac
    done < "$CFG"

    if [[ -z "$RUSER" ]]; then
        echo ""
        echo "  [ERROR]  Profile not found in config: $PROFILE"
        echo "  Run --list to see available profiles."
        echo ""
        exit 1
    fi

    # Add legacy local_dir/remote_dir pair
    if [[ -n "$_cfg_local" && -n "$_cfg_remote" ]]; then
        PAIR_LOCALS+=("$(realpath -m "$_cfg_local")")
        PAIR_REMOTES+=("$_cfg_remote")
    fi

    # Add from_N/to_N pairs from config (sorted numerically)
    for idx in $(echo "${!_cfg_from[@]}" | tr ' ' '\n' | sort -n); do
        if [[ -n "${_cfg_from[$idx]:-}" && -n "${_cfg_to[$idx]:-}" ]]; then
            PAIR_LOCALS+=("$(realpath -m "${_cfg_from[$idx]}")")
            PAIR_REMOTES+=("${_cfg_to[$idx]}")
        fi
    done

    if [[ ${#PAIR_LOCALS[@]} -eq 0 ]]; then
        echo ""
        echo "  [ERROR]  No paths defined in profile: $PROFILE"
        echo "  Add local_dir/remote_dir or from_N/to_N pairs to the profile."
        echo ""
        exit 1
    fi

fi  # end config mode

# expand ~ in SSH_KEY
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# =============================================================
# Show config header
# =============================================================
echo ""
echo "  ============================================"
if [[ -n "$PROFILE" ]]; then
    echo "   Profile : $PROFILE  ($PROFILE_DESC)"
else
    echo "   Mode    : inline"
fi
echo "   Command : $CMD"
[[ -n "$CFG" ]] && echo "   Config  : $CFG"
echo "  ============================================"
echo "   Server  : $RUSER@$SERVER"
if [[ -n "$SSH_KEY" ]]; then echo "   SSH key : $SSH_KEY"; else echo "   SSH key : (default)"; fi
echo "  ============================================"
echo ""

SSH_KEY_ARG=()
[[ -n "$SSH_KEY" ]] && SSH_KEY_ARG=(-i "$SSH_KEY")

ALL_OK=1

# SSH key check (once)
if [[ -n "$SSH_KEY" ]]; then
    if [[ -f "$SSH_KEY" ]]; then
        echo "  [OK]     SSH key found"
    else
        echo "  [ERROR]  SSH key NOT FOUND: $SSH_KEY"
        ALL_OK=0
    fi
fi

# =============================================================
# Check each pair
# =============================================================
for i in "${!PAIR_LOCALS[@]}"; do
    _local="${PAIR_LOCALS[$i]}"
    _remote="${PAIR_REMOTES[$i]}"
    PAIR_IS_DIR[$i]=0
    PAIR_REMOTE_MISSING[$i]=0
    PAIR_REMOTE_NOPERM[$i]=0

    echo ""
    echo "  --- Pair $i: $_local  ->  $_remote"

    if [[ -d "$_local" ]]; then
        echo "  [OK]     Local folder found"
        PAIR_IS_DIR[$i]=1
        if ! command -v rsync &>/dev/null; then
            echo "  [ERROR]  rsync not found - required for folder copy (excludes .env and .gitignore files)"
            echo "  Install: sudo apt install rsync"
            ALL_OK=0
        fi
    elif [[ -f "$_local" ]]; then
        echo "  [OK]     Local file found"
    else
        echo "  [ERROR]  Local path NOT FOUND: $_local"
        ALL_OK=0
    fi

    echo "  Checking SSH to $RUSER@$SERVER..."
    if [[ "${PAIR_IS_DIR[$i]}" -eq 1 ]]; then
        SSH_RESULT=$(ssh "${SSH_KEY_ARG[@]}" -o ConnectTimeout=5 -o BatchMode=yes \
            "$RUSER@$SERVER" \
            "if [ -d '$_remote' ]; then if [ -w '$_remote' ]; then echo FOUND; else echo NOPERM; fi; else echo MISSING; fi" \
            2>/dev/null || true)
    else
        SSH_RESULT=$(ssh "${SSH_KEY_ARG[@]}" -o ConnectTimeout=5 -o BatchMode=yes \
            "$RUSER@$SERVER" \
            "RPAR=\$(dirname '$_remote'); if [ -d '$_remote' ] && [ -w '$_remote' ]; then echo FOUND; elif [ -d \$RPAR ] && [ -w \$RPAR ]; then echo FOUND; elif [ -d \$RPAR ]; then echo NOPERM; else echo MISSING; fi" \
            2>/dev/null || true)
    fi

    if [[ -z "$SSH_RESULT" ]]; then
        echo "  [FAILED] SSH connection failed: $RUSER@$SERVER"
        ALL_OK=0
    elif [[ "$SSH_RESULT" == "FOUND" ]]; then
        echo "  [OK]     SSH OK - remote path found"
    elif [[ "$SSH_RESULT" == "MISSING" ]]; then
        if [[ "${PAIR_IS_DIR[$i]}" -eq 1 ]]; then
            echo "  [WARN]   SSH OK - remote folder will be created: $_remote"
        else
            echo "  [WARN]   SSH OK - remote parent folder will be created for: $_remote"
        fi
        PAIR_REMOTE_MISSING[$i]=1
    elif [[ "$SSH_RESULT" == "NOPERM" ]]; then
        echo "  [WARN]   SSH OK - remote path exists but needs sudo chown: $_remote"
        PAIR_REMOTE_NOPERM[$i]=1
    else
        echo "  [FAILED] SSH error: $SSH_RESULT"
        ALL_OK=0
    fi
done

echo ""
if [[ "$ALL_OK" -eq 0 ]]; then
    echo "  Fix errors above before copying."
    echo ""
    exit 1
fi

if [[ "$CMD" == "check" ]]; then
    echo "  All checks passed. Run with --copy to start copying."
    echo ""
    exit 0
fi

# =============================================================
# Copy each pair
# =============================================================
echo "  Starting copy..."
echo ""

for i in "${!PAIR_LOCALS[@]}"; do
    _local="${PAIR_LOCALS[$i]}"
    _remote="${PAIR_REMOTES[$i]}"
    _is_dir="${PAIR_IS_DIR[$i]}"
    _remote_missing="${PAIR_REMOTE_MISSING[$i]}"
    _remote_noperm="${PAIR_REMOTE_NOPERM[$i]}"

    echo "  --- Pair $i: $_local  ->  $_remote"
    echo ""

    if [[ "$_is_dir" -eq 1 ]]; then
        if [[ "$_remote_missing" -eq 1 ]]; then
            echo "  Creating remote folder: $_remote"
            ssh "${SSH_KEY_ARG[@]}" "$RUSER@$SERVER" "sudo mkdir -p '$_remote' && sudo chown $RUSER:$RUSER '$_remote'"
            if [[ $? -ne 0 ]]; then echo "  [FAILED] Could not create remote folder."; exit 1; fi
            echo "  [OK]     Remote folder created."
            echo ""
        fi
        if [[ "$_remote_noperm" -eq 1 ]]; then
            echo "  Fixing permissions: $_remote"
            ssh "${SSH_KEY_ARG[@]}" "$RUSER@$SERVER" "sudo chown $RUSER:$RUSER '$_remote'"
            if [[ $? -ne 0 ]]; then echo "  [FAILED] Could not fix permissions."; exit 1; fi
            echo "  [OK]     Permissions fixed."
            echo ""
        fi
        _rsync_e="ssh"
        [[ -n "$SSH_KEY" ]] && _rsync_e="ssh -i $SSH_KEY"
        echo "  Command: rsync ${RSYNC_FLAGS[*]} ${RSYNC_EXCL[*]} --filter=':- .gitignore' -e \"$_rsync_e\" \"$_local/\" $RUSER@$SERVER:$_remote/"
        echo ""
        rsync "${RSYNC_FLAGS[@]}" "${RSYNC_EXCL[@]}" --filter=':- .gitignore' -e "$_rsync_e" "$_local/" "$RUSER@$SERVER:$_remote/"
    else
        if [[ "$_remote_missing" -eq 1 ]]; then
            echo "  Creating remote parent folder for: $_remote"
            ssh "${SSH_KEY_ARG[@]}" "$RUSER@$SERVER" "RPAR=\$(dirname '$_remote'); sudo mkdir -p \$RPAR && sudo chown $RUSER:$RUSER \$RPAR"
            if [[ $? -ne 0 ]]; then echo "  [FAILED] Could not create remote parent folder."; exit 1; fi
            echo "  [OK]     Remote parent folder created."
            echo ""
        fi
        if [[ "$_remote_noperm" -eq 1 ]]; then
            echo "  Fixing permissions for parent of: $_remote"
            ssh "${SSH_KEY_ARG[@]}" "$RUSER@$SERVER" "RPAR=\$(dirname '$_remote'); sudo chown $RUSER:$RUSER \$RPAR"
            if [[ $? -ne 0 ]]; then echo "  [FAILED] Could not fix permissions."; exit 1; fi
            echo "  [OK]     Permissions fixed."
            echo ""
        fi
        echo "  Command: scp ${SCP_OPTS[*]} ${SSH_KEY_ARG[*]} \"$_local\" $RUSER@$SERVER:$_remote"
        echo ""
        scp "${SCP_OPTS[@]}" "${SSH_KEY_ARG[@]}" "$_local" "$RUSER@$SERVER:$_remote"
    fi

    if [[ $? -eq 0 ]]; then
        echo "  [OK]  Copied: pair $i"
    else
        echo "  [FAILED] scp failed for pair $i"
        exit 1
    fi
    echo ""
done

echo "  All pairs copied successfully."
if [[ -n "$DEPLOY_HINT" ]]; then
    echo ""
    echo "  On server:"
    echo "    $DEPLOY_HINT"
fi
echo ""

# =============================================================
# rsync reference (https://linux.die.net/man/1/rsync):
#
#  Mode flags:
#    -a, --archive         archive mode = -rlptgoD (recursive, preserve all attributes)
#    -r, --recursive       recurse into directories
#    -v, --verbose         show each transferred file name
#    -z, --compress        compress data during transfer (useful on slow links)
#    -n, --dry-run         show what would be transferred without doing it
#    -P                    shorthand for --partial --progress (resume + show progress)
#    -h, --human-readable  output file sizes in human-readable format (KB, MB)
#        --stats           print transfer statistics at the end
#
#  File selection:
#        --delete          delete remote files not present in source (mirror mode)
#        --exclude=PAT     exclude files matching pattern  e.g. --exclude='*.log'
#        --include=PAT     force-include files (overrides --exclude)
#        --filter=RULE     general filter rule  e.g. --filter=':- .gitignore'
#        --ignore-existing skip files that already exist on the remote
#        --update          skip files that are newer on the remote
#        --checksum        compare by checksum instead of size+timestamp
#
#  Transfer:
#    -e CMD                remote shell  e.g. -e "ssh -i ~/.ssh/key"
#        --bwlimit=KBPS    limit bandwidth  e.g. --bwlimit=5000 for ~5 Mbit/s
#        --partial         keep partially transferred files (allows resume)
#        --progress        show per-file transfer progress
#
#  Backup:
#        --backup          make backups of changed/deleted files
#        --backup-dir=DIR  store backups in DIR on remote
#        --suffix=.bak     suffix for backup files (default: ~)
#
#  rsync examples (set RSYNC_FLAGS / RSYNC_EXCL arrays above to apply):
#    RSYNC_FLAGS=(-avzn)                                 dry run (show without copying)
#    RSYNC_FLAGS=(-avz --delete)                         mirror (remove extra remote files)
#    RSYNC_FLAGS=(-avzP)                                 show progress + allow resume
#    RSYNC_FLAGS=(-avz --bwlimit=5000)                   limit to ~5 Mbit/s
#    RSYNC_EXCL=(--exclude='*.log')                      exclude log files
#    RSYNC_EXCL=(--exclude=.env --exclude='*.log')       exclude multiple patterns
#
# =============================================================
#  scp reference:
#
#    -C          compress during transfer
#    -p          preserve timestamps and permissions
#    -l KBPS     limit bandwidth in Kbit/s  e.g. -l 5000
#    -P PORT     remote port (default: 22)
#    -q          quiet mode (suppress progress)
#    -o OPT      pass SSH option  e.g. -o ConnectTimeout=10
#
#  scp examples (set SCP_OPTS array above to apply):
#    SCP_OPTS=(-C)             compress during transfer
#    SCP_OPTS=(-p)             preserve timestamps and permissions
#    SCP_OPTS=(-C -p)          compress and preserve timestamps
#    SCP_OPTS=(-l 5000)        limit bandwidth to ~5 Mbit/s
#    SCP_OPTS=(-P 2222)        use non-default SSH port
