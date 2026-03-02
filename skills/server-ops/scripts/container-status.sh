#!/bin/bash
# container-status.sh — Docker container status monitoring
# Usage: container-status.sh [--container <name>]
# Output: JSON array of container status objects

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ECS_EXEC="$SKILL_DIR/scripts/ecs-exec.sh"
CONFIG="$SKILL_DIR/references/servers.json"

CONTAINER_FILTER="${1:-}"
if [ "$CONTAINER_FILTER" = "--container" ]; then
    CONTAINER_FILTER="${2:-}"
fi

# Get target containers from config, or use filter
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

# Get all container info in one SSH call
DOCKER_OUTPUT=$(bash "$ECS_EXEC" "docker ps -a --format '{{.Names}}|{{.Status}}|{{.State}}' 2>/dev/null") || {
    echo '{"error":"Failed to connect to ECS"}'
    exit 1
}

# Get inspect data for restart counts (single SSH call with all containers)
INSPECT_CMD="docker inspect --format '{{.Name}}|{{.RestartCount}}|{{.State.StartedAt}}' $CONTAINERS 2>/dev/null || true"
INSPECT_OUTPUT=$(bash "$ECS_EXEC" "$INSPECT_CMD") || INSPECT_OUTPUT=""

python3 -c "
import json, sys

docker_output = '''$DOCKER_OUTPUT'''
inspect_output = '''$INSPECT_OUTPUT'''
target_containers = '$CONTAINERS'.split()

# Parse docker ps output
ps_data = {}
for line in docker_output.strip().split('\n'):
    if '|' not in line:
        continue
    parts = line.split('|', 2)
    if len(parts) >= 3:
        name, status, state = parts[0].strip(), parts[1].strip(), parts[2].strip()
        ps_data[name] = {'status': status, 'state': state}

# Parse inspect output for restart counts
inspect_data = {}
for line in inspect_output.strip().split('\n'):
    if '|' not in line:
        continue
    parts = line.split('|', 2)
    if len(parts) >= 3:
        name = parts[0].strip().lstrip('/')
        restart_count = int(parts[1].strip()) if parts[1].strip().isdigit() else 0
        started_at = parts[2].strip()
        inspect_data[name] = {'restart_count': restart_count, 'started_at': started_at}

# Build result
results = []
for container in target_containers:
    entry = {'name': container}
    if container in ps_data:
        entry['state'] = ps_data[container]['state']
        entry['status'] = ps_data[container]['status']
        entry['ok'] = ps_data[container]['state'] == 'running'
    else:
        entry['state'] = 'not_found'
        entry['status'] = 'Container not found'
        entry['ok'] = False

    if container in inspect_data:
        entry['restart_count'] = inspect_data[container]['restart_count']
        entry['started_at'] = inspect_data[container]['started_at']
    else:
        entry['restart_count'] = 0
        entry['started_at'] = ''

    results.append(entry)

print(json.dumps(results))
"
