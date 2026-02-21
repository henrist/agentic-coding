#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cmd="$1"
shift 1

printf "Run %s [s]andboxed  [u]nsandboxed  [o]ptions? " "$cmd"
read -r -n1 choice
echo

if [[ "$choice" == "u" || "$choice" == "U" ]]; then
  export PATH="$SCRIPT_DIR/bin:$PATH"
  exec "$cmd" "$@"
fi

export PATH="$SCRIPT_DIR/bin:$PATH"

if [[ ! -S "$SCRIPT_DIR/.credential-server.sock" ]]; then
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

exec safehouse \
  --add-dirs="/Users/henrste/coding-agents" \
  --add-dirs="/Users/henrste/.claude" \
  ${CWD_ARGS[@]+"${CWD_ARGS[@]}"} \
  --add-dirs-ro="/Users/henrste/.gitignore" \
  --add-dirs-ro="/Users/henrste/.config/gh" \
  --add-dirs-ro="/Users/henrste/.aws/config" \
  ${AZURE_ARGS[@]+"${AZURE_ARGS[@]}"} \
  --env-pass=PATH,TERM,GIT_CONFIG_COUNT,GIT_CONFIG_KEY_0,GIT_CONFIG_VALUE_0,GIT_CONFIG_KEY_1,GIT_CONFIG_VALUE_1 \
  -- \
  "$cmd" \
  "$@"
