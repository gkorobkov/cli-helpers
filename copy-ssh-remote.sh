#!/usr/bin/env bash
# =============================================================
# copy-ssh-remote.sh - copy project to remote server via SSH/scp
#
#  Config: *.remote.ini or *.local.ini in current folder (not in git)
#  Requires: ssh, scp
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
#       --local_dir=path     local folder
#       --remote_dir=path    remote folder
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
#    ./copy-ssh-remote.sh --user=myuser --server=myserver.com --ssh_key=~/.ssh/id_rsa --local_dir=/home/me/proj --remote_dir=/home/user/proj --copy
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
        --copy)          CMD="copy" ;;
        --check)         CMD="check" ;;
        --list)          CMD="list" ;;
        *)
            echo ""
            echo "  [ERROR]  Unknown argument: $ARG"
            echo "  Valid:   --config=  --profile=  --user=  --server=  --ssh_key=  --local_dir=  --remote_dir=  --deploy_hint=  --check  --copy  --list"
            echo ""
            exit 1 ;;
    esac
done

# =============================================================
# Config file mode (skip if all inline params provided)
# =============================================================
if [[ -z "$RUSER" || -z "$SERVER" || -z "$SSH_KEY" || -z "$LOCAL_DIR" || -z "$REMOTE_DIR" ]]; then

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
        echo "  Inline:  --user=name --server=host --ssh_key=path --local_dir=path --remote_dir=path"
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
    while IFS= read -r line; do
        line="${line#"${line%%[! ]*}"}"
        [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue
        if [[ "$line" == "[$PROFILE]" ]]; then
            _in_profile=1; continue
        fi
        [[ "$line" == \[* ]] && { _in_profile=0; continue; }
        [[ $_in_profile -eq 0 ]] && continue
        key="${line%%=*}"; val="${line#*=}"
        case "${key,,}" in
            user)        RUSER="$val" ;;
            server)      SERVER="$val" ;;
            ssh_key)     SSH_KEY="$val" ;;
            local_dir)   LOCAL_DIR="$val" ;;
            remote_dir)  REMOTE_DIR="$val" ;;
            description) PROFILE_DESC="$val" ;;
            deploy_hint) DEPLOY_HINT="$val" ;;
        esac
    done < "$CFG"

    if [[ -z "$RUSER" ]]; then
        echo ""
        echo "  [ERROR]  Profile not found in config: $PROFILE"
        echo "  Run --list to see available profiles."
        echo ""
        exit 1
    fi

fi  # end config mode

# expand ~ in SSH_KEY
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# =============================================================
# Show config and run checks
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
echo "   SSH key : $SSH_KEY"
echo "   Local   : $LOCAL_DIR"
echo "   Remote  : $REMOTE_DIR"
echo "  ============================================"
echo ""

ALL_OK=1
REMOTE_MISSING=0

if [[ -d "$LOCAL_DIR" ]]; then
    echo "  [OK]     Local folder found"
else
    echo "  [ERROR]  Local folder NOT FOUND: $LOCAL_DIR"
    ALL_OK=0
fi

if [[ -f "$SSH_KEY" ]]; then
    echo "  [OK]     SSH key found"
else
    echo "  [ERROR]  SSH key NOT FOUND: $SSH_KEY"
    ALL_OK=0
fi

echo "  Checking SSH to $RUSER@$SERVER..."
SSH_RESULT=$(ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes \
    "$RUSER@$SERVER" "test -d '$REMOTE_DIR' && echo FOUND || echo MISSING" 2>/dev/null || true)

if [[ -z "$SSH_RESULT" ]]; then
    echo "  [FAILED] SSH connection failed: $RUSER@$SERVER"
    ALL_OK=0
elif [[ "$SSH_RESULT" == "FOUND" ]]; then
    echo "  [OK]     SSH OK - remote folder found"
elif [[ "$SSH_RESULT" == "MISSING" ]]; then
    echo "  [WARN]   SSH OK - remote folder will be created: $REMOTE_DIR"
    REMOTE_MISSING=1
else
    echo "  [FAILED] SSH error: $SSH_RESULT"
    ALL_OK=0
fi

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
# Copy
# =============================================================
echo "  Starting copy..."
echo ""

if [[ "$REMOTE_MISSING" -eq 1 ]]; then
    echo "  Creating remote folder: $REMOTE_DIR"
    ssh -i "$SSH_KEY" "$RUSER@$SERVER" "mkdir -p '$REMOTE_DIR'"
    if [[ $? -ne 0 ]]; then
        echo "  [FAILED] Could not create remote folder."
        exit 1
    fi
    echo "  [OK]     Remote folder created."
    echo ""
fi

scp -i "$SSH_KEY" -r "$LOCAL_DIR/." "$RUSER@$SERVER:$REMOTE_DIR/"

if [[ $? -eq 0 ]]; then
    echo ""
    echo "  [OK]  Copy completed."
    if [[ -n "$DEPLOY_HINT" ]]; then
        echo ""
        echo "  On server:"
        echo "    $DEPLOY_HINT"
    fi
else
    echo "  [FAILED] scp failed"
    exit 1
fi
echo ""
