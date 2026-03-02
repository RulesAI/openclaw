#!/bin/bash
# SCI.AI Weekly Report — Call DashScope API (OpenAI-compatible)
# Usage: dashscope_generate.sh <prompt-file> [model]
# Reads prompt from file, sends to DashScope, outputs response text to stdout.
# Exit code 1 if DashScope is unreachable or API key missing.
#
# Environment:
#   DASHSCOPE_API_KEY  — DashScope API key (required)

set -euo pipefail

DASHSCOPE_BASE="https://dashscope.aliyuncs.com/compatible-mode/v1"
MODEL="${2:-qwen-plus}"
DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <prompt-file> [model]" >&2
    exit 1
fi

PROMPT_FILE="$1"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: File not found: $PROMPT_FILE" >&2
    exit 1
fi

if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo "Error: DASHSCOPE_API_KEY not set" >&2
    echo "DASHSCOPE_OFFLINE" >&2
    exit 1
fi

# Read prompt and escape for JSON
PROMPT=$(python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    print(json.dumps(f.read()))
" "$PROMPT_FILE")

# Call DashScope (OpenAI-compatible chat completions)
RESPONSE=$(curl -sf "${DASHSCOPE_BASE}/chat/completions" \
    -H "Authorization: Bearer ${DASHSCOPE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL}\",
        \"messages\": [{\"role\": \"user\", \"content\": ${PROMPT}}],
        \"temperature\": 0.3,
        \"max_tokens\": 8192
    }" \
    --max-time 300)

if [ $? -ne 0 ]; then
    echo "DASHSCOPE_OFFLINE" >&2
    exit 1
fi

# Extract content from response
echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
choices = data.get('choices', [])
if choices:
    print(choices[0].get('message', {}).get('content', ''))
else:
    error = data.get('error', {})
    if error:
        print(f'API Error: {error.get(\"message\", \"unknown\")}', file=sys.stderr)
        sys.exit(1)
"
