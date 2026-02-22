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

# Allowed project dirs — added read-write only when cwd is inside one
ALLOWED_DIRS=(
  "/Users/henrste/Code/entailor"
  "/Users/henrste/Code/blindern"
  "/Users/henrste/Code/henrist"
)

CWD_ARGS=()
CWD="$(pwd)"
for dir in "${ALLOWED_DIRS[@]}"; do
  if [[ "$CWD" == "$dir" || "$CWD" == "$dir/"* ]]; then
    CWD_ARGS+=(--add-dirs="$dir")
    break
  fi
done

SAFEHOUSE_ARGS=(
  --add-dirs="/Users/henrste/Code/henrist/agentic-coding"
  --add-dirs="/Users/henrste/.claude"
  --add-dirs="/Users/henrste/.ansible"
  --append-profile="$SCRIPT_DIR/profiles/posix-ipc.sb"
  ${CWD_ARGS[@]+"${CWD_ARGS[@]}"}
  --add-dirs-ro="/Users/henrste/.gitignore"
  --add-dirs-ro="/Users/henrste/.config/gh"
  --add-dirs-ro="/Users/henrste/.aws/config"
  ${AZURE_ARGS[@]+"${AZURE_ARGS[@]}"}
  --env-pass=PATH,TERM,GIT_CONFIG_COUNT,GIT_CONFIG_KEY_0,GIT_CONFIG_VALUE_0,GIT_CONFIG_KEY_1,GIT_CONFIG_VALUE_1
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
