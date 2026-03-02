#!/bin/bash
# ssl-check.sh — SSL certificate expiry checker
# Usage: ssl-check.sh [--domain <domain>]
# Output: JSON array of SSL certificate status objects

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$SKILL_DIR/references/servers.json"

DOMAIN_FILTER="${1:-}"
if [ "$DOMAIN_FILTER" = "--domain" ]; then
    DOMAIN_FILTER="${2:-}"
fi

# Get domains from config
if [ -n "$DOMAIN_FILTER" ]; then
    DOMAINS="$DOMAIN_FILTER"
else
    DOMAINS=$(python3 -c "
import json
with open('$CONFIG') as f:
    config = json.load(f)
print(' '.join(config['ssl_domains']))
")
fi

RESULTS="["
FIRST=true

for DOMAIN in $DOMAINS; do
    # Get certificate expiry date
    CERT_END=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//') || CERT_END=""

    if [ -n "$CERT_END" ]; then
        # Calculate days remaining (cross-platform: works on both macOS and Linux)
        DAYS_LEFT=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    expiry = datetime.strptime('$CERT_END', '%b %d %H:%M:%S %Y %Z')
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    days = (expiry - now).days
    print(days)
except Exception as e:
    print(-1, file=sys.stderr)
    print(-1)
")
        OK="true"
        if [ "$DAYS_LEFT" -lt 7 ]; then
            OK="false"
        elif [ "$DAYS_LEFT" -lt 30 ]; then
            OK="true"  # warning but not critical
        fi

        ENTRY="{\"domain\":\"$DOMAIN\",\"expires\":\"$CERT_END\",\"days_remaining\":$DAYS_LEFT,\"ok\":$OK}"
    else
        ENTRY="{\"domain\":\"$DOMAIN\",\"expires\":null,\"days_remaining\":-1,\"ok\":false,\"error\":\"Failed to retrieve certificate\"}"
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        RESULTS+=","
    fi
    RESULTS+="$ENTRY"
done

RESULTS+="]"
echo "$RESULTS"
