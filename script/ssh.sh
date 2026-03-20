#!/usr/bin/env bash
set -euo pipefail

SSH_PORT="${SSH_PORT:-2222}"
TARGET="codex@localhost"

if [[ $# -gt 0 ]]; then
  SSH_PORT="$1"
fi

exec ssh -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" "$TARGET"
