#!/bin/bash
# xiaohongshu-cover-image-generator: Generate AI background images for XHS covers
# Uses DashScope Tongyi Wanxiang wanx2.1-t2i-turbo (synchronous API)
# Output: JSON to stdout, logs to stderr

set -euo pipefail

# --- Configuration ---
API_KEY="${DASHSCOPE_API_KEY:-sk-d0134e6de24c4e04ae9a54524d1d5c39}"
API_URL="https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
MODEL="wan2.6-t2i"

# --- Defaults ---
STYLE="auto"
ASPECT="portrait"
SEED=""
PROMPT=""

CONCEPT_SUFFIX=", conceptual background image suitable for text overlay, high quality, 4K detail, no text, no watermark"
NEGATIVE_PROMPT="人物, 人像, 自拍, 肖像, 面部, 头像, 手, 身体, people, person, portrait, face, selfie, human, body, hands, fingers, text, watermark, logo, signature, words, letters, typography"

# --- Style presets (bash 3.2 compatible, no associative arrays) ---
get_style_prefix() {
    case "$1" in
        cyberpunk)         echo "Cyberpunk neon cityscape, dark background, vibrant neon lights, futuristic tech aesthetic, glowing circuits, digital rain" ;;
        minimalist)        echo "Clean minimalist flat design, solid color blocks, geometric shapes, ample white space, modern sans-serif aesthetic" ;;
        infographic)       echo "Professional infographic background, subtle icons, flowing data lines, clean grid layout, muted corporate colors" ;;
        realistic_scene)   echo "Realistic photography scene, professional lighting, shallow depth of field, cinematic composition, high-end commercial look" ;;
        watercolor)        echo "Watercolor painting style, soft pastel colors, artistic texture, flowing pigment edges, dreamy atmosphere" ;;
        gradient_abstract) echo "Abstract gradient background, modern color transitions, geometric patterns, soft bokeh elements, contemporary design" ;;
        tech_futuristic)   echo "Futuristic technology, circuit board patterns, holographic elements, dark tech background, blue and purple glow" ;;
        nature_zen)        echo "Serene zen landscape, natural elements, soft golden light, peaceful atmosphere, bamboo and water" ;;
        *) return 1 ;;
    esac
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --style)  STYLE="$2"; shift 2 ;;
        --aspect) ASPECT="$2"; shift 2 ;;
        --seed)   SEED="$2"; shift 2 ;;
        --help|-h)
            cat >&2 <<'USAGE'
Usage: generate.sh <prompt> [--style STYLE] [--aspect ASPECT] [--seed N]

  prompt              Image description (required)
  --style STYLE       cyberpunk|minimalist|infographic|realistic_scene|watercolor|gradient_abstract|tech_futuristic|nature_zen|auto (default: auto)
  --aspect ASPECT     portrait (1080x1440) | square (1080x1080) (default: portrait)
  --seed N            Random seed for reproducibility
USAGE
            exit 0 ;;
        -*)  echo "Unknown option: $1" >&2; exit 1 ;;
        *)   PROMPT="${PROMPT:+$PROMPT }$1"; shift ;;
    esac
done

if [ -z "$PROMPT" ]; then
    echo '{"status":"error","message":"No prompt provided. Usage: generate.sh <prompt> [--style STYLE] [--aspect ASPECT]"}'
    exit 1
fi

# --- Map aspect to DashScope size ---
case "$ASPECT" in
    portrait) DS_SIZE="1104*1472"; TARGET_W=1080; TARGET_H=1440 ;;
    square)   DS_SIZE="1280*1280"; TARGET_W=1080; TARGET_H=1080 ;;
    *)
        echo "{\"status\":\"error\",\"message\":\"Unknown aspect: $ASPECT. Use portrait or square.\"}"
        exit 1 ;;
esac

# --- Build final prompt ---
if [ "$STYLE" = "auto" ]; then
    FINAL_PROMPT="${PROMPT}${CONCEPT_SUFFIX}"
else
    PREFIX=$(get_style_prefix "$STYLE" 2>/dev/null) || {
        echo "{\"status\":\"error\",\"message\":\"Unknown style: $STYLE\"}"
        exit 1
    }
    FINAL_PROMPT="${PREFIX}, ${PROMPT}${CONCEPT_SUFFIX}"
fi

echo "Generating image..." >&2
echo "  Style: $STYLE | Aspect: $ASPECT ($DS_SIZE -> ${TARGET_W}x${TARGET_H})" >&2
echo "  Prompt: ${FINAL_PROMPT:0:120}..." >&2

# --- Build JSON payload, call API, parse response — all in one python3 block ---
# Using env vars avoids all shell escaping issues
export XHS_PROMPT="$FINAL_PROMPT"
export XHS_NEG_PROMPT="$NEGATIVE_PROMPT"
export XHS_MODEL="$MODEL"
export XHS_SIZE="$DS_SIZE"
export XHS_SEED="$SEED"
export XHS_API_URL="$API_URL"
export XHS_API_KEY="$API_KEY"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RAW_FILE="/tmp/xhs_cover_${TIMESTAMP}_raw.png"
export XHS_RAW_FILE="$RAW_FILE"

# Build payload and call API
echo "  Calling API..." >&2
RESPONSE_FILE="/tmp/xhs_api_response_${TIMESTAMP}.json"

python3 -c "
import json, os, sys, subprocess

payload = {
    'model': os.environ['XHS_MODEL'],
    'input': {
        'messages': [{
            'role': 'user',
            'content': [{'text': os.environ['XHS_PROMPT']}]
        }]
    },
    'parameters': {
        'size': os.environ['XHS_SIZE'],
        'n': 1,
        'negative_prompt': os.environ['XHS_NEG_PROMPT']
    }
}
seed = os.environ.get('XHS_SEED', '')
if seed:
    payload['parameters']['seed'] = int(seed)

with open('/tmp/xhs_payload_${TIMESTAMP}.json', 'w') as f:
    json.dump(payload, f, ensure_ascii=False)
" || { echo '{"status":"error","message":"Failed to build payload"}'; exit 1; }

curl -s --max-time 120 \
    -X POST "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"/tmp/xhs_payload_${TIMESTAMP}.json" \
    -o "$RESPONSE_FILE" 2>/dev/null

rm -f "/tmp/xhs_payload_${TIMESTAMP}.json"

# --- Parse API response and download image ---
export XHS_RESPONSE_FILE="$RESPONSE_FILE"

IMAGE_URL=$(python3 -c "
import json, os, sys

resp_file = os.environ['XHS_RESPONSE_FILE']
try:
    with open(resp_file) as f:
        data = json.load(f)
except Exception as e:
    print(f'Failed to parse API response: {e}', file=sys.stderr)
    sys.exit(1)

# wanx2.1-t2i-turbo response: output.choices[].message.content[].image
choices = data.get('output', {}).get('choices', [])
if choices:
    content = choices[0].get('message', {}).get('content', [])
    for item in content:
        if 'image' in item:
            print(item['image'])
            sys.exit(0)

# fallback: output.results[].url (older wanx format)
results = data.get('output', {}).get('results', [])
if results:
    url = results[0].get('url', '')
    if url:
        print(url)
        sys.exit(0)

# error
code = data.get('code', 'unknown')
msg = data.get('message', json.dumps(data)[:300])
print(f'API error [{code}]: {msg}', file=sys.stderr)
sys.exit(1)
" 2>&1) || {
    ERR_MSG="$IMAGE_URL"
    # Try to extract error from response file for JSON output
    RAW_RESP=$(python3 -c "
import json, os
try:
    with open(os.environ['XHS_RESPONSE_FILE']) as f:
        print(json.dumps(f.read()[:500]))
except:
    print('\"(no response)\"')
")
    rm -f "$RESPONSE_FILE"
    echo "{\"status\":\"error\",\"message\":$(python3 -c "import json; print(json.dumps('$ERR_MSG'))"),\"raw_response\":$RAW_RESP}"
    exit 1
}

rm -f "$RESPONSE_FILE"
echo "  Image URL: ${IMAGE_URL:0:80}..." >&2

# --- Download image ---
curl -sL --max-time 60 -o "$RAW_FILE" "$IMAGE_URL" 2>/dev/null
RAW_SIZE=$(wc -c < "$RAW_FILE" | tr -d ' ')
echo "  Downloaded: ${RAW_SIZE} bytes" >&2

if [ "$RAW_SIZE" -lt 5000 ]; then
    rm -f "$RAW_FILE"
    echo "{\"status\":\"error\",\"message\":\"Downloaded image too small (${RAW_SIZE} bytes)\"}"
    exit 1
fi

# --- Resize and convert to JPG with PIL ---
FINAL_FILE="/tmp/xhs_cover_${TIMESTAMP}.jpg"
export XHS_FINAL_FILE="$FINAL_FILE"
export XHS_TARGET_W="$TARGET_W"
export XHS_TARGET_H="$TARGET_H"

python3 << 'PYEOF'
import sys, os
try:
    from PIL import Image
except ImportError:
    print("Pillow not installed. Run: pip3 install Pillow", file=sys.stderr)
    sys.exit(1)

raw_file = os.environ['XHS_RAW_FILE']
final_file = os.environ['XHS_FINAL_FILE']
target_w = int(os.environ['XHS_TARGET_W'])
target_h = int(os.environ['XHS_TARGET_H'])

img = Image.open(raw_file)
print(f"  Original: {img.size[0]}x{img.size[1]}", file=sys.stderr)

if img.size != (target_w, target_h):
    img = img.resize((target_w, target_h), Image.LANCZOS)
    print(f"  Resized: {target_w}x{target_h}", file=sys.stderr)

if img.mode in ('RGBA', 'P'):
    img = img.convert('RGB')

img.save(final_file, 'JPEG', quality=95, optimize=True)
print(f"  Saved: {os.path.getsize(final_file)} bytes", file=sys.stderr)
PYEOF

if [ $? -ne 0 ]; then
    rm -f "$RAW_FILE"
    echo '{"status":"error","message":"Image processing failed (Pillow)"}'
    exit 1
fi

rm -f "$RAW_FILE"
FINAL_SIZE=$(wc -c < "$FINAL_FILE" | tr -d ' ')

# --- Output JSON result ---
export XHS_FINAL_SIZE="$FINAL_SIZE"
export XHS_STYLE="$STYLE"
export XHS_ASPECT="$ASPECT"

python3 -c "
import json, os
result = {
    'status': 'success',
    'file': os.environ['XHS_FINAL_FILE'],
    'width': int(os.environ['XHS_TARGET_W']),
    'height': int(os.environ['XHS_TARGET_H']),
    'size_bytes': int(os.environ['XHS_FINAL_SIZE']),
    'provider': 'dashscope/' + os.environ['XHS_MODEL'],
    'style': os.environ['XHS_STYLE'],
    'aspect': os.environ['XHS_ASPECT'],
    'prompt_used': os.environ['XHS_PROMPT']
}
print(json.dumps(result, ensure_ascii=False, indent=2))
"

echo "Done!" >&2
