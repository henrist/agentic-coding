#!/bin/bash
set -eu

cmd=$1
echo "Running $1 through safehouse"
shift 1

echo "Modify $0 if needed"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$PATH"

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
  --env-pass=PATH,TERM,GIT_CONFIG_COUNT,GIT_CONFIG_KEY_0,GIT_CONFIG_VALUE_0,GIT_CONFIG_KEY_1,GIT_CONFIG_VALUE_1 \
  -- \
  "$cmd" \
  "$@"
