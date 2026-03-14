#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cmd="$1"
shift 1

POLICY_ONLY=false
choice=""

# SAFEHOUSE_POLICY=1 skips interactive prompt and outputs sandbox policy to stdout
if [[ "${SAFEHOUSE_POLICY:-}" == "1" ]]; then
  POLICY_ONLY=true
else
  printf "Run %s [s]andboxed  [u]nsandboxed  [o]ptions  [p]olicy? " "$cmd"
  read -r -n1 choice
  echo

  if [[ "$choice" == "u" || "$choice" == "U" ]]; then
    exec "$cmd" "$@"
  fi
  if [[ "$choice" == "p" || "$choice" == "P" ]]; then
    POLICY_ONLY=true
  fi
fi

export PATH="$SCRIPT_DIR/bin:$PATH"

if [[ "$POLICY_ONLY" != true && ! -S "$SCRIPT_DIR/.credential-server.sock" ]]; then
  echo -e "\033[33mWarning: credential server not running — gh/aws/git auth will fail\033[0m"
  echo -e "\033[2mStart it in another terminal: $SCRIPT_DIR/credential-server\033[0m"
  echo
fi

AZURE_ARGS=()
if [[ "$choice" == "o" || "$choice" == "O" ]]; then
  printf "  Mount ~/.azure for az CLI? [y/N] "
  read -r -n1 azure_choice
  echo
  if [[ "$azure_choice" == "y" || "$azure_choice" == "Y" ]]; then
    AZURE_ARGS=(--add-dirs-ro="/Users/henrste/.azure")
  fi
fi

# Override git credential helper — keychain/GCM can't work inside sandbox
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="credential.helper"
export GIT_CONFIG_VALUE_0=""
export GIT_CONFIG_KEY_1="credential.helper"
export GIT_CONFIG_VALUE_1="$SCRIPT_DIR/bin/git-credential-helper"

# Generate sandbox AWS config with credential_process per profile (for SDK credential resolution)
# Strip SSO fields — credential_process handles auth; SSO fields cause boto3 to attempt SSO
# token resolution (which fails in sandbox since ~/.aws/sso/cache is inaccessible).
SANDBOX_AWS_CONFIG="$SCRIPT_DIR/.aws-config-sandbox"
if [[ "$POLICY_ONLY" != true && -f "$HOME/.aws/config" ]]; then
  python3 -c "
import re, sys
script_dir = sys.argv[1]
sso_keys = {'sso_session', 'sso_account_id', 'sso_role_name', 'sso_start_url', 'sso_region'}
out = []
skip_section = False
for line in open(sys.argv[2]):
    if re.match(r'^\[sso-session\s', line):
        skip_section = True
        continue
    if line.startswith('['):
        skip_section = False
    if skip_section:
        continue
    key = line.split('=')[0].strip().lower() if '=' in line else ''
    if key in sso_keys:
        continue
    out.append(line)
    m = re.match(r'^\[profile\s+(\S+)\]', line) or re.match(r'^\[(default)\]', line)
    if m:
        out.append('credential_process = ' + script_dir + '/bin/aws-credential-process ' + m.group(1) + '\n')
sys.stdout.write(''.join(out))
" "$SCRIPT_DIR" "$HOME/.aws/config" > "$SANDBOX_AWS_CONFIG"
fi
export AWS_CONFIG_FILE="$SANDBOX_AWS_CONFIG"

# Read sandbox config from config.toml
ALLOWED_DIRS=()
EXTRA_DIRS=()
extra_env_pass=""
eval "$(python3 -c "
import sys
try:
    import tomllib
except ImportError:
    sys.exit(0)
try:
    with open(sys.argv[1], 'rb') as f:
        sb = tomllib.load(f).get('sandbox', {})
    envs = sb.get('env-pass', [])
    if envs:
        print('extra_env_pass=' + ','.join(envs))
    for d in sb.get('allowed-dirs', []):
        print('ALLOWED_DIRS+=(\"' + d + '\")')
    for d in sb.get('add-dirs', []):
        print('EXTRA_DIRS+=(--add-dirs=\"' + d + '\")')
    for d in sb.get('add-dirs-ro', []):
        print('EXTRA_DIRS+=(--add-dirs-ro=\"' + d + '\")')
except Exception:
    pass
" "$SCRIPT_DIR/config.toml" 2>/dev/null)" 2>/dev/null || true

# Allowed project dirs - added read-write only when cwd is inside one
# Base dirs always included; config.toml [sandbox].allowed-dirs adds more

CWD_ARGS=()
CWD="$(pwd)"
for dir in ${ALLOWED_DIRS[@]+"${ALLOWED_DIRS[@]}"}; do
  if [[ "$CWD" == "$dir" || "$CWD" == "$dir/"* ]]; then
    CWD_ARGS+=(--add-dirs="$dir")
    break
  fi
done

SAFEHOUSE_ARGS=(
  --append-profile="$SCRIPT_DIR/profiles/posix-ipc.sb"
  --append-profile="$SCRIPT_DIR/profiles/audio.sb"
  --append-profile="$SCRIPT_DIR/profiles/notifications.sb"
  --append-profile="$SCRIPT_DIR/profiles/chromium.sb"
  --enable=clipboard,macos-gui,electron
  ${CWD_ARGS[@]+"${CWD_ARGS[@]}"}
  ${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"}
  ${AZURE_ARGS[@]+"${AZURE_ARGS[@]}"}
  --env-pass=${extra_env_pass:-PATH,TERM}
)

if [[ "$POLICY_ONLY" == true ]]; then
  if [[ "${SAFEHOUSE_POLICY:-}" == "1" ]]; then
    # Env var mode: output to stdout for programmatic use
    POLICY_FILE="$(mktemp)"
    safehouse "${SAFEHOUSE_ARGS[@]}" --output="$POLICY_FILE"
    cat "$POLICY_FILE"
    rm -f "$POLICY_FILE"
  else
    # Interactive mode: write to file
    POLICY_FILE="/tmp/safehouse-policy-$$.sb"
    safehouse "${SAFEHOUSE_ARGS[@]}" --output="$POLICY_FILE"
    echo "Policy written to: $POLICY_FILE"
  fi
  exit 0
fi

exec safehouse "${SAFEHOUSE_ARGS[@]}" -- "$cmd" "$@"
