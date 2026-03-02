#!/bin/bash
# log-scan.sh — Container log error scanner
# Usage: log-scan.sh [--container <name>] [--since <duration>]
# Output: JSON array of log scan results

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ECS_EXEC="$SKILL_DIR/scripts/ecs-exec.sh"
CONFIG="$SKILL_DIR/references/servers.json"

CONTAINER_FILTER=""
SINCE="1h"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --container) CONTAINER_FILTER="$2"; shift 2 ;;
        --since) SINCE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Get target containers
if [ -n "$CONTAINER_FILTER" ]; then
    CONTAINERS="$CONTAINER_FILTER"
else
    CONTAINERS=$(python3 -c "
import json
with open('$CONFIG') as f:
    config = json.load(f)
print(' '.join(config['ecs_containers']))
")
fi

# Build a single SSH command that scans all containers
SCAN_CMD=""
for CONTAINER in $CONTAINERS; do
    SCAN_CMD+="echo '===CONTAINER:${CONTAINER}==='; "
    SCAN_CMD+="docker logs --since ${SINCE} ${CONTAINER} 2>&1 | grep -ciE 'error|fatal|panic|exception|critical' || echo 0; "
    SCAN_CMD+="echo '---LINES---'; "
    SCAN_CMD+="docker logs --since ${SINCE} ${CONTAINER} 2>&1 | grep -iE 'error|fatal|panic|exception|critical' | tail -5 || true; "
    SCAN_CMD+="echo '===END==='; "
done

RAW=$(bash "$ECS_EXEC" "$SCAN_CMD") || {
    echo '{"error":"Failed to connect to ECS"}'
    exit 1
}

python3 -c "
import json, re

raw = '''$RAW'''
results = []

# Split by container sections
sections = re.split(r'===CONTAINER:(\w[\w-]*)===', raw)
# sections[0] is before first marker (empty), then alternating: name, content

i = 1
while i < len(sections) - 1:
    name = sections[i].strip()
    content = sections[i + 1].strip()
    i += 2

    # Split content by ---LINES---
    parts = content.split('---LINES---', 1)
    count_str = parts[0].strip()
    try:
        error_count = int(count_str)
    except:
        error_count = 0

    recent_errors = []
    if len(parts) > 1:
        lines_section = parts[1].split('===END===')[0].strip()
        if lines_section:
            recent_errors = [line.strip() for line in lines_section.split('\n') if line.strip()]

    results.append({
        'container': name,
        'error_count': error_count,
        'recent_errors': recent_errors,
        'ok': error_count == 0
    })

print(json.dumps(results))
"
