#!/bin/bash
set -eu

cmd=$1
echo "Running $1 through safehouse"
shift 1

echo "Modify $0 if needed"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$PATH"

exec safehouse \
  --add-dirs="/Users/henrste/coding-agents" \
  --add-dirs="/Users/henrste/.claude" \
  --add-dirs="/Users/henrste/Code/entailor" \
  --add-dirs-ro="/Users/henrste/.gitignore" \
  --add-dirs-ro="/Users/henrste/.config/gh" \
  --add-dirs-ro="/Users/henrste/.aws/config" \
  --env-pass=PATH \
  -- \
  "$cmd" \
  "$@"
