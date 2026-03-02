#!/bin/bash
# resource-monitor.sh — CPU/memory/disk resource monitoring
# Usage: resource-monitor.sh [--target ecs|nas|all]
# Output: JSON object with ecs and/or nas resource data

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ECS_EXEC="$SKILL_DIR/scripts/ecs-exec.sh"
TARGET="${1:-all}"
if [ "$TARGET" = "--target" ]; then
    TARGET="${2:-all}"
fi

get_ecs_resources() {
    # Gather all ECS metrics in a single SSH call to minimize connections
    local RAW
    RAW=$(bash "$ECS_EXEC" '
        echo "===CPU==="
        top -bn1 | grep "Cpu(s)" | head -1
        echo "===MEM==="
        free -m | grep "Mem:"
        echo "===DISK==="
        df -h / /data 2>/dev/null || df -h /
        echo "===END==="
    ') || { echo '{"error":"SSH failed"}'; return 1; }

    python3 -c "
import re, sys

raw = '''$RAW'''

# Parse CPU
cpu_match = re.search(r'(\d+\.?\d*)\s*id', raw)
cpu_idle = float(cpu_match.group(1)) if cpu_match else 0
cpu_used = round(100.0 - cpu_idle, 1)

# Parse Memory
mem_match = re.search(r'Mem:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)', raw)
if mem_match:
    mem_total = int(mem_match.group(1))
    mem_used = int(mem_match.group(2))
    mem_pct = round(mem_used / mem_total * 100, 1) if mem_total > 0 else 0
else:
    mem_total = mem_used = 0
    mem_pct = 0

# Parse Disks (deduplicate by mount point)
disks = []
seen_mounts = set()
for line in raw.split('\n'):
    if line.startswith('/dev/'):
        parts = line.split()
        if len(parts) >= 6:
            mount = parts[5]
            if mount in seen_mounts:
                continue
            seen_mounts.add(mount)
            use_pct = int(parts[4].replace('%', ''))
            disks.append({
                'mount': mount,
                'size': parts[1],
                'used': parts[2],
                'avail': parts[3],
                'use_pct': use_pct
            })

import json
result = {
    'cpu_pct': cpu_used,
    'mem_total_mb': mem_total,
    'mem_used_mb': mem_used,
    'mem_pct': mem_pct,
    'disks': disks
}
print(json.dumps(result))
"
}

get_nas_resources() {
    python3 -c "
import json, os

# CPU load (from /proc/loadavg — reflects host kernel)
try:
    with open('/proc/loadavg') as f:
        load = f.read().strip().split()
    load_1m = float(load[0])
    # Get CPU count for percentage
    cpu_count = os.cpu_count() or 1
    cpu_pct = round(load_1m / cpu_count * 100, 1)
except:
    load_1m = 0
    cpu_pct = 0

# Memory (from /proc/meminfo — reflects host kernel)
try:
    meminfo = {}
    with open('/proc/meminfo') as f:
        for line in f:
            parts = line.split(':')
            if len(parts) == 2:
                key = parts[0].strip()
                val = int(parts[1].strip().split()[0])  # kB
                meminfo[key] = val
    mem_total = meminfo.get('MemTotal', 0) // 1024  # MB
    mem_avail = meminfo.get('MemAvailable', 0) // 1024
    mem_used = mem_total - mem_avail
    mem_pct = round(mem_used / mem_total * 100, 1) if mem_total > 0 else 0
except:
    mem_total = mem_used = mem_pct = 0

# Disk (df for /home/node — shows bind-mounted host volume)
import subprocess
try:
    df = subprocess.run(['df', '-h', '/home/node'], capture_output=True, text=True, timeout=5)
    lines = df.stdout.strip().split('\n')
    disks = []
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 6:
            use_pct = int(parts[4].replace('%', ''))
            disks.append({
                'mount': parts[5],
                'size': parts[1],
                'used': parts[2],
                'avail': parts[3],
                'use_pct': use_pct
            })
except:
    disks = []

result = {
    'cpu_pct': cpu_pct,
    'load_1m': load_1m,
    'mem_total_mb': mem_total,
    'mem_used_mb': mem_used,
    'mem_pct': mem_pct,
    'disks': disks
}
print(json.dumps(result))
"
}

# Build combined output
if [ "$TARGET" = "ecs" ]; then
    ECS_DATA=$(get_ecs_resources)
    echo "{\"ecs\":$ECS_DATA}"
elif [ "$TARGET" = "nas" ]; then
    NAS_DATA=$(get_nas_resources)
    echo "{\"nas\":$NAS_DATA}"
else
    ECS_DATA=$(get_ecs_resources)
    NAS_DATA=$(get_nas_resources)
    echo "{\"ecs\":$ECS_DATA,\"nas\":$NAS_DATA}"
fi
