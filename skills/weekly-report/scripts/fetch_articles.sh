#!/bin/bash
# SCI.AI Weekly Report — Fetch articles from WordPress REST API
# Usage: fetch_articles.sh <from-date> <to-date> [output-file]
# Dates: YYYY-MM-DD format
# Output: JSON array of articles (default: /tmp/sciai_weekly_articles.json)
#
# Environment:
#   SCIAI_API_BASE  — WordPress URL (default: https://news.yrules.com)
#   SCIAI_API_KEY   — API key for authentication

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <from-date> <to-date> [output-file]" >&2
    echo "Example: $0 2026-02-24 2026-03-01" >&2
    exit 1
fi

export REPORT_FROM_DATE="$1"
export REPORT_TO_DATE="$2"
export REPORT_OUTPUT="${3:-/tmp/sciai_weekly_articles.json}"
export SCIAI_API_BASE="${SCIAI_API_BASE:-https://news.yrules.com}"
export SCIAI_API_KEY="${SCIAI_API_KEY:-IeV6jDeworkGtupzlCh6Uk5SvZnqWxYe}"

python3 << 'PYEOF'
import json, sys, os, time, ssl
from urllib.request import Request, urlopen

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

api_base = os.environ["SCIAI_API_BASE"]
api_key = os.environ["SCIAI_API_KEY"]
from_date = os.environ["REPORT_FROM_DATE"]
to_date = os.environ["REPORT_TO_DATE"]
output = os.environ["REPORT_OUTPUT"]
per_page = 100

print(f"Fetching articles from {from_date} to {to_date}...", file=sys.stderr)
print(f"API: {api_base}/wp-json/sci/v1/report-articles", file=sys.stderr)

all_posts = []
page = 1
total_pages = 1

while page <= total_pages:
    url = (f"{api_base}/wp-json/sci/v1/report-articles"
           f"?after={from_date}&before={to_date}&lang=zh"
           f"&per_page={per_page}&page={page}")

    req = Request(url, headers={"X-API-Key": api_key})

    try:
        resp = urlopen(req, context=ctx, timeout=30)
        data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"API request failed (page {page}): {e}", file=sys.stderr)
        sys.exit(1)

    if "code" in data and "message" in data:
        print(f"API Error: {data['message']}", file=sys.stderr)
        sys.exit(1)

    posts = data.get("posts", [])
    total = data.get("total", 0)
    total_pages = data.get("pages", 1)

    if page == 1:
        print(f"Found {total} articles across {total_pages} page(s)", file=sys.stderr)

    all_posts.extend(posts)

    if page < total_pages:
        time.sleep(1)
    page += 1

with open(output, "w", encoding="utf-8") as f:
    json.dump(all_posts, f, ensure_ascii=False, indent=2)

print(f"Fetched {len(all_posts)} articles. Output: {output}", file=sys.stderr)
PYEOF
