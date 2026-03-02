#!/bin/bash
# ============================================================
# SCI.AI Daily Supply Chain News Digest Generator
# 独立运行脚本 — 无需 OpenClaw，仅依赖 bash + curl + python3
#
# 用法:
#   ./generate-daily-digest.sh [--date YYYY-MM-DD] [--count N] [--output console|file|both]
#
# 环境变量:
#   SCIAI_API_BASE     — WordPress API (默认: https://news.yrules.com)
#   SCIAI_API_KEY      — API Key (已内置默认值)
#   DASHSCOPE_API_KEY  — DashScope Key (可选，不设则跳过 AI 筛选)
#   DIGEST_OUTPUT_DIR  — file 模式输出目录 (默认: ~/reports/daily)
# ============================================================

set -euo pipefail

# === 参数解析 ===
TARGET_DATE=""
ARTICLE_COUNT=6
OUTPUT_MODE="console"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date)   TARGET_DATE="$2"; shift 2 ;;
        --count)  ARTICLE_COUNT="$2"; shift 2 ;;
        --output) OUTPUT_MODE="$2"; shift 2 ;;
        --focus)  shift 2 ;; # reserved for future use
        *)        shift ;;
    esac
done

TARGET_DATE="${TARGET_DATE:-$(date +%Y-%m-%d)}"
SCIAI_API_BASE="${SCIAI_API_BASE:-https://news.yrules.com}"
SCIAI_API_KEY="${SCIAI_API_KEY:-IeV6jDeworkGtupzlCh6Uk5SvZnqWxYe}"
DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-}"
DIGEST_OUTPUT_DIR="${DIGEST_OUTPUT_DIR:-$HOME/reports/daily}"

echo "======================================" >&2
echo " SCI.AI Daily Digest Generator" >&2
echo " Date: $TARGET_DATE" >&2
echo " Count: $ARTICLE_COUNT" >&2
echo " Output: $OUTPUT_MODE" >&2
echo "======================================" >&2

# === Step 1: 获取文章 ===
echo "[Step 1] Fetching articles for $TARGET_DATE ..." >&2

ARTICLES_JSON=$(python3 << PYEOF
import json, sys, ssl, os
from urllib.request import Request, urlopen

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

api_base = "$SCIAI_API_BASE"
api_key = "$SCIAI_API_KEY"
target_date = "$TARGET_DATE"

url = (f"{api_base}/wp-json/sci/v1/report-articles"
       f"?after={target_date}&before={target_date}&lang=zh&per_page=100&page=1")

req = Request(url, headers={"X-API-Key": api_key})

try:
    resp = urlopen(req, context=ctx, timeout=30)
    data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    print(f"API request failed: {e}", file=sys.stderr)
    sys.exit(1)

if "code" in data and "message" in data:
    print(f"API Error: {data['message']}", file=sys.stderr)
    sys.exit(1)

posts = data.get("posts", [])
total = data.get("total", 0)
print(f"Found {total} articles", file=sys.stderr)

# Output JSON to stdout
print(json.dumps(posts, ensure_ascii=False))
PYEOF
)

TOTAL_COUNT=$(echo "$ARTICLES_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
echo "  Found $TOTAL_COUNT articles" >&2

if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "当日暂无新发布文章 ($TARGET_DATE)" >&2
    exit 0
fi

# Adjust count if not enough articles
if [ "$TOTAL_COUNT" -lt "$ARTICLE_COUNT" ]; then
    ARTICLE_COUNT=$TOTAL_COUNT
    echo "  Adjusted count to $ARTICLE_COUNT (not enough articles)" >&2
fi

# === Step 2: 准备摘要 + 筛选 + 生成洞察 + 组装输出 ===
echo "[Step 2-6] Processing articles and generating digest ..." >&2

# Save articles to temp file (heredoc overrides stdin, can't use pipe)
echo "$ARTICLES_JSON" > /tmp/sciai_daily_articles_raw.json

export TARGET_DATE ARTICLE_COUNT DASHSCOPE_API_KEY

DIGEST_OUTPUT=$(python3 << 'PYEOF'
import json, sys, re, ssl, os
from urllib.request import Request, urlopen
from datetime import datetime

target_date = os.environ.get("TARGET_DATE", "")
article_count = int(os.environ.get("ARTICLE_COUNT", "6"))
dashscope_key = os.environ.get("DASHSCOPE_API_KEY", "")

with open("/tmp/sciai_daily_articles_raw.json") as f:
    articles = json.load(f)

# Parse display date
try:
    d = datetime.strptime(target_date, "%Y-%m-%d")
    weekdays = ["一","二","三","四","五","六","日"]
    wd = weekdays[d.weekday()]
    display_date = f"{d.month}月{d.day}日 周{wd}"
except:
    display_date = target_date

# Prepare summaries
summaries = []
for a in articles:
    title = a.get("title", "")
    if isinstance(title, dict):
        title = title.get("rendered", "")
    title = title.replace("&#8211;", "—").replace("&#8212;", "—").replace("&amp;", "&")

    excerpt = a.get("excerpt", "")
    if isinstance(excerpt, dict):
        excerpt = excerpt.get("rendered", "")
    excerpt = re.sub(r"<[^>]+>", "", excerpt).strip()[:300]

    content = a.get("content", "")
    if isinstance(content, dict):
        content = content.get("rendered", "")
    content_text = re.sub(r"<[^>]+>", "", content).strip()[:2000]

    url = f"https://news.yrules.com/archives/{a['id']}"

    summaries.append({
        "id": a["id"],
        "title": title,
        "excerpt": excerpt,
        "content": content_text,
        "url": url
    })

# === AI Selection via DashScope (if key available) ===
selected_ids = []

if dashscope_key and len(summaries) > article_count:
    print(f"  Using DashScope for article selection ...", file=sys.stderr)

    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    # Build selection prompt
    slim = [{"id": s["id"], "title": s["title"], "excerpt": s["excerpt"][:150]} for s in summaries]
    prompt = f"""你是 SCI.AI 的供应链新闻编辑。从以下文章中选出 {article_count} 篇最值得推送的文章。

筛选原则：多样性优先（不同地区、不同板块）、数据驱动、影响力大、无重复主题。

文章列表：
{json.dumps(slim, ensure_ascii=False, indent=2)}

严格返回 JSON 格式（不要其他内容）：
```json
{{"selected": [{{"id": 123, "emoji": "🚢", "headline": "标题15-25字", "key_data": "关键数字", "core_change": "核心变化25字内", "global_impact": "全球影响30字内"}}]}}
```"""

    payload = json.dumps({
        "model": "qwen-plus",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 4096
    }).encode("utf-8")

    req = Request(
        "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {dashscope_key}",
            "Content-Type": "application/json"
        }
    )

    try:
        resp = urlopen(req, context=ssl_ctx, timeout=120)
        result = json.loads(resp.read().decode("utf-8"))
        content = result.get("choices", [{}])[0].get("message", {}).get("content", "")

        # Parse JSON from response
        match = re.search(r'```json?\s*\n(.*?)\n```', content, re.DOTALL)
        if match:
            content = match.group(1)
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            data = json.loads(match.group())
            selected_items = data.get("selected", [])
            if selected_items:
                print(f"  DashScope selected {len(selected_items)} articles", file=sys.stderr)
                # Output directly as insights
                insights = []
                for item in selected_items[:article_count]:
                    aid = item.get("id", 0)
                    url_map = {s["id"]: s["url"] for s in summaries}
                    insights.append({
                        "id": aid,
                        "emoji": item.get("emoji", "📋"),
                        "headline": item.get("headline", ""),
                        "key_data": item.get("key_data", "—"),
                        "core_change": item.get("core_change", ""),
                        "global_impact": item.get("global_impact", ""),
                        "url": url_map.get(aid, f"https://news.yrules.com/archives/{aid}")
                    })
                selected_ids = [i["id"] for i in insights]
    except Exception as e:
        print(f"  DashScope failed: {e}, falling back to simple selection", file=sys.stderr)

# === Fallback: simple selection (by diversity heuristic) ===
if not selected_ids:
    print(f"  Using simple selection (first {article_count} articles) ...", file=sys.stderr)
    # Take first N articles (API returns newest first)
    selected_summaries = summaries[:article_count]
    insights = []
    for s in selected_summaries:
        # Extract key data from excerpt using simple heuristics
        numbers = re.findall(r'[\d,.]+[%亿万美元欧元]', s["excerpt"])
        key_data = "、".join(numbers[:3]) if numbers else "—"

        # Use first sentence of excerpt as core_change
        sentences = re.split(r'[。！？]', s["excerpt"])
        core_change = sentences[0][:30] if sentences else ""

        insights.append({
            "id": s["id"],
            "emoji": "📋",
            "headline": s["title"][:30],
            "key_data": key_data,
            "core_change": core_change,
            "global_impact": sentences[1][:30] if len(sentences) > 1 else "",
            "url": s["url"]
        })

# === Assemble output ===
num_emojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣"]

lines = []
lines.append("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
lines.append(f"┃  📰 SCI.AI 全球供应链早报  {display_date}  ┃")
lines.append("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
lines.append("")
lines.append("🔥 今日全球热点｜5分钟速览")
lines.append("")

for idx, item in enumerate(insights):
    emoji = item.get("emoji", "📋")
    headline = item.get("headline", "")
    key_data = item.get("key_data", "—")
    core_change = item.get("core_change", "")
    global_impact = item.get("global_impact", "")
    url = item.get("url", "")

    num = num_emojis[idx] if idx < len(num_emojis) else f"{idx+1}."
    lines.append(f"{num} {emoji} {headline}")
    lines.append(f"   ├─ 关键数据：{key_data}")
    lines.append(f"   ├─ 核心变化：{core_change}")
    lines.append(f"   └─ 全球影响：{global_impact}")
    lines.append(f"   📎 {url}")
    lines.append("")

lines.append("━━━━━━━━━━━━━━━━━━")
lines.append("📬 支持个性化订阅 👉 https://accounts.yrules.com")
lines.append("每日推送定制化全球供应链资讯")
lines.append("")
lines.append("🌐 SCI.AI ｜ 全球供应链深度资讯｜中英双语｜独家数据")
lines.append("📧 marketing@yrules.com")
lines.append("")
lines.append("#供应链 #全球贸易 #SCI_AI")

print("\n".join(lines))
PYEOF
)

# === Step 7: Output ===
if [ "$OUTPUT_MODE" = "console" ] || [ "$OUTPUT_MODE" = "both" ]; then
    echo "$DIGEST_OUTPUT"
fi

if [ "$OUTPUT_MODE" = "file" ] || [ "$OUTPUT_MODE" = "both" ]; then
    mkdir -p "$DIGEST_OUTPUT_DIR"
    OUTPUT_FILE="${DIGEST_OUTPUT_DIR}/${TARGET_DATE}.md"
    echo "$DIGEST_OUTPUT" > "$OUTPUT_FILE"
    echo "" >&2
    echo "日报已保存: ${OUTPUT_FILE}" >&2
fi

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━" >&2
echo "日报生成完成！" >&2
echo "日期: $TARGET_DATE" >&2
echo "文章: $ARTICLE_COUNT / $TOTAL_COUNT" >&2
echo "输出: $OUTPUT_MODE" >&2
echo "━━━━━━━━━━━━━━━━━━" >&2
