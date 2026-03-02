#!/bin/bash
# SCI.AI Daily Digest — Fetch today's articles from WordPress REST API
# Usage: fetch_daily_articles.sh [date] [output-file]
# Date: YYYY-MM-DD (default: today)
# Output: JSON array of articles (default: /tmp/sciai_daily_articles.json)
#
# This is a thin wrapper around weekly-report's fetch_articles.sh
# that defaults the date range to a single day.
#
# Environment:
#   SCIAI_API_BASE  — WordPress URL (default: https://news.yrules.com)
#   SCIAI_API_KEY   — API key for authentication

set -euo pipefail

TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
OUTPUT_FILE="${2:-/tmp/sciai_daily_articles.json}"

WEEKLY_SKILL_DIR="$HOME/.openclaw/skills/weekly-report"

if [ ! -f "$WEEKLY_SKILL_DIR/scripts/fetch_articles.sh" ]; then
    echo "Error: weekly-report skill not found at $WEEKLY_SKILL_DIR" >&2
    echo "This script depends on weekly-report/scripts/fetch_articles.sh" >&2
    exit 1
fi

echo "Fetching articles for ${TARGET_DATE}..." >&2

# Call weekly-report's fetch script with same start and end date
bash "$WEEKLY_SKILL_DIR/scripts/fetch_articles.sh" "$TARGET_DATE" "$TARGET_DATE" "$OUTPUT_FILE"

ARTICLE_COUNT=$(python3 -c "import json; print(len(json.load(open('$OUTPUT_FILE'))))")
echo "Found ${ARTICLE_COUNT} articles for ${TARGET_DATE}" >&2
