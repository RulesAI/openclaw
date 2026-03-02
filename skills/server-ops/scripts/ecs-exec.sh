#!/bin/bash
# ecs-exec.sh — SSH wrapper for executing commands on Alibaba Cloud ECS
# Usage: ecs-exec.sh "<command>"
# Outputs command stdout; exits non-zero on SSH failure.

set -euo pipefail

SSH_KEY="${ECS_SSH_KEY:-$HOME/.openclaw/.ssh/id_aliyun}"
ECS_HOST="${ECS_HOST:-47.97.196.187}"
ECS_USER="${ECS_USER:-root}"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -o LogLevel=ERROR"

if [ ! -f "$SSH_KEY" ]; then
    echo '{"error":"SSH key not found at '"$SSH_KEY"'"}' >&2
    exit 1
fi

chmod 600 "$SSH_KEY" 2>/dev/null || true

COMMAND="${1:?Usage: ecs-exec.sh \"<command>\"}"

ssh -i "$SSH_KEY" $SSH_OPTS "${ECS_USER}@${ECS_HOST}" "$COMMAND"
