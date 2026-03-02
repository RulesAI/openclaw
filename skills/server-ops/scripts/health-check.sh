#!/bin/bash
# health-check.sh — HTTP endpoint health probes
# Usage: health-check.sh [--service <name>]
# Output: JSON array of service health results to stdout

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$SKILL_DIR/references/servers.json"

SERVICE_FILTER="${1:-}"
if [ "$SERVICE_FILTER" = "--service" ]; then
    SERVICE_FILTER="${2:-}"
fi

# Read services from config using python3 (available on both Mac and Linux)
SERVICES=$(python3 -c "
import json, sys
with open('$CONFIG') as f:
    config = json.load(f)
services = config['services']
sf = '$SERVICE_FILTER'
if sf:
    services = [s for s in services if sf.lower() in s['name'].lower()]
for s in services:
    expect = s['expect']
    if isinstance(expect, list):
        expect_str = ','.join(str(e) for e in expect)
    else:
        expect_str = str(expect)
    print(f\"{s['name']}|{s['url']}|{expect_str}\")
")

RESULTS="["
FIRST=true

while IFS='|' read -r name url expect; do
    [ -z "$name" ] && continue

    # Probe the endpoint
    HTTP_RESULT=$(curl -sS -o /dev/null -w '%{http_code} %{time_total}' \
        --connect-timeout 10 --max-time 30 "$url" 2>/dev/null) || HTTP_RESULT="000 0.000"

    STATUS_CODE=$(echo "$HTTP_RESULT" | awk '{print $1}')
    RESPONSE_TIME=$(echo "$HTTP_RESULT" | awk '{print $2}')

    # Check if status code matches expected
    OK=$(python3 -c "
expect = '$expect'
status = int('$STATUS_CODE')
codes = [int(c.strip()) for c in expect.split(',')]
print('true' if status in codes else 'false')
")

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        RESULTS+=","
    fi

    RESULTS+="{\"name\":\"$name\",\"url\":\"$url\",\"status\":$STATUS_CODE,\"time_s\":$RESPONSE_TIME,\"ok\":$OK}"
done <<< "$SERVICES"

RESULTS+="]"
echo "$RESULTS"
