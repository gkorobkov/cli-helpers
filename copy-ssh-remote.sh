#!/usr/bin/env bash
# =============================================================
# copy-ssh-remote.sh - copy project to remote server via SSH/scp
#
#  Config: *.local.json in current folder (not in git)
#  Template: copy-remote.local.example.json
#  Requires: python3 (for JSON parsing)
#
#  Parameters (all optional, named, any order):
#    --config=path.json    config file  (default: first *.local.json in current dir)
#    --profile=name        profile name (default: default_profile from config)
#    --copy                run copy     (default: check only)
#    --list                list available profiles and exit
#
#  Examples:
#    ./copy-ssh-remote.sh
#    ./copy-ssh-remote.sh --copy
#    ./copy-ssh-remote.sh --profile=ai-agent
#    ./copy-ssh-remote.sh --profile=ai-agent --copy
#    ./copy-ssh-remote.sh --config=/other/config.json --profile=ai-agent --copy
#
# =============================================================
#  Config file format (save as *.local.json, e.g. copy-remote.local.json):
#
#  {
#    "default_profile": "my-project",
#    "profiles": {
#      "my-project": {
#        "description": "My Project - myserver.com",
#        "user":        "myuser",
#        "server":      "myserver.com",
#        "ssh_key":     "~/.ssh/id_rsa",
#        "local_dir":   "/home/me/projects/my-project",
#        "remote_dir":  "/home/myuser/my-project",
#        "deploy_hint": "cd /home/myuser/my-project && docker compose up -d"
#      },
#      "another-project": {
#        "description": "Another Project - myserver.com",
#        "user":        "myuser",
#        "server":      "myserver.com",
#        "ssh_key":     "~/.ssh/id_rsa",
#        "local_dir":   "/home/me/projects/another-project",
#        "remote_dir":  "/home/myuser/another-project",
#        "deploy_hint": "cd /home/myuser/another-project && npm start"
#      }
#    }
#  }
# =============================================================

CMD="check"
PROFILE=""
CFG=""

# =============================================================
# Parse named arguments (any order)
# =============================================================
for ARG in "$@"; do
    case "$ARG" in
        --config=*)   CFG="${ARG#--config=}" ;;
        --profile=*)  PROFILE="${ARG#--profile=}" ;;
        --copy)       CMD="copy" ;;
        --check)      CMD="check" ;;
        --list)       CMD="list" ;;
        *)
            echo ""
            echo "  [ERROR]  Unknown argument: $ARG"
            echo "  Valid:   --config=file.json  --profile=name  --check  --copy  --list"
            echo ""
            exit 1 ;;
    esac
done

# =============================================================
# Find config file
# =============================================================
if [[ -z "$CFG" ]]; then
    for f in *.local.json; do
        [[ -f "$f" ]] && CFG="$(realpath "$f")" && break
    done
fi

if [[ -z "$CFG" ]]; then
    echo ""
    echo "  [ERROR]  No config file found in current folder."
    echo "  Create a *.local.json file (see copy-remote.local.example.json)"
    echo "  or use --config=path.json"
    echo ""
    exit 1
fi

if [[ ! -f "$CFG" ]]; then
    echo ""
    echo "  [ERROR]  Config not found: $CFG"
    echo ""
    exit 1
fi

# =============================================================
# List profiles
# =============================================================
if [[ "$CMD" == "list" ]]; then
    echo ""
    echo "  Config: $CFG"
    python3 - "$CFG" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
default = c.get("default_profile", "")
print(f"  Profiles (default: {default}):")
for name, p in c.get("profiles", {}).items():
    mark = "*" if name == default else " "
    print(f"  {mark} {name:<20} - {p.get('description', '')}")
PYEOF
    echo ""
    exit 0
fi

# =============================================================
# Load profile from JSON via python3
# =============================================================
if [[ -z "$PROFILE" ]]; then
    PROFILE=$(python3 -c "import json; print(json.load(open('$CFG')).get('default_profile',''))" 2>/dev/null)
fi

if [[ -z "$PROFILE" ]]; then
    echo ""
    echo "  [ERROR]  No profile specified and no default_profile set in config."
    echo "  Use --profile=name or add \"default_profile\" to config."
    echo "  Run --list to see available profiles."
    echo ""
    exit 1
fi

VARS_TMP=$(mktemp)
python3 - "$CFG" "$PROFILE" > "$VARS_TMP" <<'PYEOF'
import json, sys
cfg, profile = sys.argv[1], sys.argv[2]
with open(cfg) as f:
    c = json.load(f)
p = c.get("profiles", {}).get(profile)
if not p:
    sys.exit(1)
for k, v in [
    ("PROFILE_DESC", p.get("description", "")),
    ("RUSER",        p.get("user",        "")),
    ("SERVER",       p.get("server",      "")),
    ("SSH_KEY",      p.get("ssh_key",     "")),
    ("LOCAL_DIR",    p.get("local_dir",   "")),
    ("REMOTE_DIR",   p.get("remote_dir",  "")),
    ("DEPLOY_HINT",  p.get("deploy_hint", "")),
]:
    v = v.replace("'", "'\\''")
    print(f"{k}='{v}'")
PYEOF

if [[ $? -ne 0 ]]; then
    echo ""
    echo "  [ERROR]  Profile not found in config: $PROFILE"
    echo "  Run --list to see available profiles."
    echo ""
    rm -f "$VARS_TMP"
    exit 1
fi
source "$VARS_TMP"
rm -f "$VARS_TMP"

# expand ~ in SSH_KEY
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# =============================================================
# Show config and run checks
# =============================================================
echo ""
echo "  ============================================"
echo "   Profile : $PROFILE  ($PROFILE_DESC)"
echo "   Command : $CMD"
echo "   Config  : $CFG"
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
