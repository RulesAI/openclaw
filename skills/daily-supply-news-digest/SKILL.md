---
name: daily-supply-news-digest
description: |
  生成适合微信群分享的 SCI.AI 供应链新闻日报。从 news.yrules.com 获取当日最新文章，提取关键数据与洞察，按固定模板输出格式化日报。
  触发关键词: 日报、daily digest、每日新闻、供应链日报、新闻简报、今日新闻、morning brief、早报
  适用场景: 每日早晨生成供应链新闻简报、微信群分享、邮件推送
  不适用: 周报生成、文章发布、深度分析
version: 1.0
user-invocable: true
---

# 每日供应链新闻日报生成器

从 SCI.AI (news.yrules.com) 获取当日发布的文章，提取关键数据与洞察，生成适合微信群分享的格式化日报。

## 参数

| 参数       | 类型   | 必填 | 默认值  | 说明                                                         |
| ---------- | ------ | ---- | ------- | ------------------------------------------------------------ |
| `--date`   | string | 否   | 今天    | 指定日期 (YYYY-MM-DD)                                        |
| `--count`  | int    | 否   | 6       | 文章数量 (4-8)                                               |
| `--output` | string | 否   | console | 输出方式: console / file / both                              |
| `--focus`  | string | 否   | all     | 聚焦板块: all / logistics / esg / ai / finance / procurement |

## Workflow

### Step 1: 解析参数与确定日期

解析用户传入的参数。如未指定日期，默认使用今天。

```bash
# 确定目标日期
TARGET_DATE="${DATE_PARAM:-$(date +%Y-%m-%d)}"
ARTICLE_COUNT="${COUNT_PARAM:-6}"
OUTPUT_MODE="${OUTPUT_PARAM:-console}"
FOCUS="${FOCUS_PARAM:-all}"

# 验证参数
if [ "$ARTICLE_COUNT" -lt 4 ] || [ "$ARTICLE_COUNT" -gt 8 ]; then
    echo "文章数量应在 4-8 之间，将使用默认值 6"
    ARTICLE_COUNT=6
fi

# 生成显示用的中文日期
DISPLAY_DATE=$(python3 -c "
from datetime import datetime
d = datetime.strptime('$TARGET_DATE', '%Y-%m-%d')
weekdays = ['一','二','三','四','五','六','日']
wd = weekdays[d.weekday()]
print(f'{d.month}月{d.day}日 周{wd}')
")
echo "目标日期: ${TARGET_DATE} (${DISPLAY_DATE})"
echo "文章数量: ${ARTICLE_COUNT}"
echo "输出方式: ${OUTPUT_MODE}"
echo "聚焦板块: ${FOCUS}"
```

### Step 2: 获取当日文章

调用 WordPress REST API 获取指定日期的所有中文文章。

```bash
SKILL_DIR="$HOME/.openclaw/skills/daily-supply-news-digest"
WEEKLY_SKILL_DIR="$HOME/.openclaw/skills/weekly-report"

# 复用 weekly-report 的 fetch_articles.sh，日期范围设为同一天
bash "$WEEKLY_SKILL_DIR/scripts/fetch_articles.sh" "$TARGET_DATE" "$TARGET_DATE"
```

输出文件: `/tmp/sciai_weekly_articles.json`（复用 weekly-report 脚本的默认输出路径）

检查文章数量:

```bash
TOTAL_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/sciai_weekly_articles.json'))))")
echo "当日共 ${TOTAL_COUNT} 篇文章"
```

如果文章数为 0，告知用户当日无文章并终止。
如果文章数少于 `ARTICLE_COUNT`，调整为实际数量。

### Step 3: 准备文章摘要列表

提取每篇文章的结构化信息，供后续 AI 筛选使用:

```bash
python3 -c "
import json, re

with open('/tmp/sciai_weekly_articles.json') as f:
    articles = json.load(f)

# Load category names (reuse from weekly-report)
try:
    with open('$WEEKLY_SKILL_DIR/references/category-names.json') as f:
        cat_names = json.load(f)
except:
    cat_names = {}

# Load emoji mapping
try:
    with open('$SKILL_DIR/references/category-emoji.json') as f:
        emoji_map = json.load(f)
except:
    emoji_map = {}

summary = []
for a in articles:
    title = a.get('title', '')
    if isinstance(title, dict):
        title = title.get('rendered', '')
    # Strip HTML entities
    title = title.replace('&#8211;', '—').replace('&#8212;', '—').replace('&amp;', '&')

    excerpt = a.get('excerpt', '')
    if isinstance(excerpt, dict):
        excerpt = excerpt.get('rendered', '')
    excerpt = re.sub(r'<[^>]+>', '', excerpt).strip()[:300]

    content = a.get('content', '')
    if isinstance(content, dict):
        content = content.get('rendered', '')
    content_text = re.sub(r'<[^>]+>', '', content).strip()[:2000]

    cats = a.get('categories', [])
    cat_labels = [cat_names.get(str(c), {}).get('zh', str(c)) for c in cats]
    cat_groups = list(set(cat_names.get(str(c), {}).get('group', '') for c in cats))
    cat_groups = [g for g in cat_groups if g]

    url = f\"https://news.yrules.com/archives/{a['id']}\"

    summary.append({
        'id': a['id'],
        'title': title,
        'excerpt': excerpt,
        'content_preview': content_text,
        'date': a.get('date', '')[:10],
        'categories': cat_labels,
        'groups': cat_groups,
        'url': url
    })

with open('/tmp/sciai_daily_summary.json', 'w') as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)
print(f'Prepared {len(summary)} article summaries')
"
```

### Step 4: AI 筛选文章

如果文章总数超过 `ARTICLE_COUNT`，需要 AI 辅助筛选出最值得推送的文章。

将以下 prompt 写入临时文件:

```bash
cat > /tmp/sciai_daily_select_prompt.txt << 'PROMPT_END'
你是 SCI.AI 的供应链新闻编辑，负责每日新闻简报的文章筛选。

请从以下文章中选出最适合今日推送的文章（数量见要求），并排定顺序。

## 筛选原则

1. **多样性优先**：覆盖不同地理区域（北美/欧洲/中东/东南亚/中国等）和板块（物流/采购/ESG/AI/金融等）
2. **数据驱动**：优先选择有具体数据、趋势、政策变化的文章
3. **影响力**：优先选择影响范围大的全行业/全球性新闻
4. **时效性**：同一事件如有多篇报道，选最全面/最新的一篇
5. **排除项**：重复主题、纯广告性质、信息量极低的文章

## 地域板块分配建议

理想分布（可根据当日实际灵活调整）：
- 至少覆盖 3 个不同地理区域
- 至少覆盖 3 个不同板块

PROMPT_END
```

追加文章列表和返回格式要求:

```bash
echo "" >> /tmp/sciai_daily_select_prompt.txt
echo "## 候选文章列表" >> /tmp/sciai_daily_select_prompt.txt
echo "" >> /tmp/sciai_daily_select_prompt.txt
# 只传入 id/title/excerpt/categories/groups，不传 content_preview（节省 token）
python3 -c "
import json
with open('/tmp/sciai_daily_summary.json') as f:
    data = json.load(f)
slim = [{'id': a['id'], 'title': a['title'], 'excerpt': a['excerpt'][:150], 'categories': a['categories'], 'groups': a['groups']} for a in data]
print(json.dumps(slim, ensure_ascii=False, indent=2))
" >> /tmp/sciai_daily_select_prompt.txt

cat >> /tmp/sciai_daily_select_prompt.txt << PROMPT_END2

## 要求

请选出 ${ARTICLE_COUNT} 篇文章，按推荐顺序排列。

## 返回格式

严格返回以下 JSON 格式（不要有其他内容）：

\`\`\`json
{
  "selected": [
    {"id": 123, "title": "文章标题", "region": "北美", "sector": "物流", "reason": "为什么选这篇（1句话）"}
  ]
}
\`\`\`

region 可选值: 北美、欧洲、中东、东南亚、中国、日韩、南亚、拉丁美洲、非洲、全球
sector 可选值: 物流、采购、制造、ESG、AI与科技、金融、政策、风险
PROMPT_END2
```

调用 DashScope:

```bash
SELECT_RESULT=$(bash "$WEEKLY_SKILL_DIR/scripts/dashscope_generate.sh" /tmp/sciai_daily_select_prompt.txt qwen-plus)
echo "$SELECT_RESULT" > /tmp/sciai_daily_selection.json
```

**解析筛选结果**:

```bash
python3 -c "
import json, re, sys

with open('/tmp/sciai_daily_selection.json') as f:
    text = f.read()

# Extract JSON from markdown code block if present
match = re.search(r'\`\`\`json?\s*\n(.*?)\n\`\`\`', text, re.DOTALL)
if match:
    text = match.group(1)

match = re.search(r'\{.*\}', text, re.DOTALL)
if match:
    data = json.loads(match.group())
    selected = data.get('selected', [])
    with open('/tmp/sciai_daily_selection_parsed.json', 'w') as f:
        json.dump(selected, f, ensure_ascii=False, indent=2)
    print(f'Selected {len(selected)} articles')
    for s in selected:
        print(f'  - [{s[\"region\"]}/{s[\"sector\"]}] {s[\"title\"]}')
else:
    print('ERROR: Could not parse selection JSON', file=sys.stderr)
    sys.exit(1)
"
```

**如果筛选文章不足**（文章总数 <= ARTICLE_COUNT），跳过此步骤，直接使用全部文章。

### Step 5: 为每篇文章生成结构化洞察

对选中的每篇文章，获取完整内容并用 DashScope 提取结构化信息。

将所有选中文章组成一个批量 prompt:

````bash
python3 << 'PYEOF'
import json, re

with open('/tmp/sciai_daily_summary.json') as f:
    all_articles = {a['id']: a for a in json.load(f)}

# Load selected articles
try:
    with open('/tmp/sciai_daily_selection_parsed.json') as f:
        selected = json.load(f)
    selected_ids = [s['id'] for s in selected]
except:
    # If no selection file, use all articles
    selected_ids = list(all_articles.keys())

# Build prompt with full content
prompt_parts = []
prompt_parts.append("""你是 SCI.AI 的资深供应链分析师。对以下每篇文章提取结构化信息，用于生成每日新闻简报。

对每篇文章输出以下 JSON 格式（返回一个 JSON 数组）：

```json
[
  {
    "id": 文章ID,
    "emoji": "最匹配的emoji（1个）",
    "headline": "标题（可优化为更吸引人的表达，15-25字）",
    "key_data": "关键数据（提取最重要的1-2个数字/百分比/金额，无则写'—'）",
    "core_change": "核心变化（一句话概括发生了什么，25字以内）",
    "global_impact": "全球影响（对中国/全球供应链的具体影响，30字以内）"
  }
]
````

写作要求：

1. headline 可以适当优化为疑问句或数字句，但必须忠于原文
2. key_data 必须包含具体数字，如"营收增长23%"、"投资$5亿"、"覆盖15个港口"
3. core_change 回答"发生了什么"，简洁有力
4. global_impact 回答"对供应链意味着什么"，要有具体指向（哪个环节/哪些企业/哪个区域）
5. emoji 选择与文章主题最匹配的（如 🚢 海运、🤖 AI、🌱 ESG、📦 物流、💰 金融、⚠️ 风险、🏭 制造、📊 数据等）
6. 禁止空泛表述如"影响深远"、"值得关注"

---

文章列表：
""")

for idx, aid in enumerate(selected_ids):
article = all_articles.get(aid)
if not article:
continue
content = article.get('content_preview', article.get('excerpt', ''))
prompt_parts.append(f"""
=== 文章 {idx+1} ===
ID: {aid}
标题: {article['title']}
内容:
{content}
URL: {article['url']}
""")

with open('/tmp/sciai_daily_insight_prompt.txt', 'w') as f:
f.write('\n'.join(prompt_parts))

print(f'Prompt prepared for {len(selected_ids)} articles')
PYEOF

````

调用 DashScope:

```bash
INSIGHT_RESULT=$(bash "$WEEKLY_SKILL_DIR/scripts/dashscope_generate.sh" /tmp/sciai_daily_insight_prompt.txt qwen-plus)
echo "$INSIGHT_RESULT" > /tmp/sciai_daily_insights.json
````

**解析洞察结果**:

```bash
python3 -c "
import json, re, sys

with open('/tmp/sciai_daily_insights.json') as f:
    text = f.read()

# Extract JSON array from markdown code block if present
match = re.search(r'\`\`\`json?\s*\n(.*?)\n\`\`\`', text, re.DOTALL)
if match:
    text = match.group(1)

match = re.search(r'\[.*\]', text, re.DOTALL)
if match:
    data = json.loads(match.group())
    with open('/tmp/sciai_daily_insights_parsed.json', 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'Parsed insights for {len(data)} articles')
else:
    print('ERROR: Could not parse insights JSON', file=sys.stderr)
    sys.exit(1)
"
```

**DashScope 不可用时的回退方案**：使用你自身的 LLM 能力，对每篇文章阅读 `content_preview` 后直接生成上述结构化字段。

### Step 6: 组装最终日报

按固定模板组装最终输出:

```bash
python3 << 'PYEOF'
import json, sys
from datetime import datetime

target_date = "$TARGET_DATE"
display_date = "$DISPLAY_DATE"

# Load insights
with open('/tmp/sciai_daily_insights_parsed.json') as f:
    insights = json.load(f)

# Load selection metadata (for region/sector info)
try:
    with open('/tmp/sciai_daily_selection_parsed.json') as f:
        selection = {s['id']: s for s in json.load(f)}
except:
    selection = {}

# Number emojis for ordered list
num_emojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣']

# Load article URLs
with open('/tmp/sciai_daily_summary.json') as f:
    url_map = {a['id']: a['url'] for a in json.load(f)}

lines = []
lines.append(f'┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓')
lines.append(f'┃  📰 SCI.AI 全球供应链早报  {display_date}  ┃')
lines.append(f'┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛')
lines.append('')
lines.append('🔥 今日全球热点｜5分钟速览')
lines.append('')

for idx, item in enumerate(insights):
    aid = item.get('id', 0)
    url = url_map.get(aid, item.get('url', f'https://news.yrules.com/archives/{aid}'))
    emoji = item.get('emoji', '📋')
    headline = item.get('headline', '')
    key_data = item.get('key_data', '—')
    core_change = item.get('core_change', '')
    global_impact = item.get('global_impact', '')

    num = num_emojis[idx] if idx < len(num_emojis) else f'{idx+1}.'
    lines.append(f'{num} {emoji} {headline}')
    lines.append(f'   ├─ 关键数据：{key_data}')
    lines.append(f'   ├─ 核心变化：{core_change}')
    lines.append(f'   └─ 全球影响：{global_impact}')
    lines.append(f'   📎 {url}')
    lines.append('')

lines.append('━━━━━━━━━━━━━━━━━━')
lines.append('📬 支持个性化订阅 👉 https://accounts.yrules.com')
lines.append('每日推送定制化全球供应链资讯')
lines.append('')
lines.append('🌐 SCI.AI ｜ 全球供应链深度资讯｜中英双语｜独家数据')
lines.append('📧 marketing@yrules.com')
lines.append('')

# Generate hashtags from article sectors
sectors = set()
for item in insights:
    aid = item.get('id', 0)
    sel = selection.get(aid, {})
    if sel.get('sector'):
        sectors.add(sel['sector'])
    if sel.get('region'):
        sectors.add(sel['region'])

# Default hashtags
tags = ['#供应链', '#全球贸易', '#SCI_AI']
for s in list(sectors)[:4]:
    tags.append(f'#{s}')
lines.append(' '.join(tags[:6]))

output = '\n'.join(lines)

with open('/tmp/sciai_daily_digest.txt', 'w') as f:
    f.write(output)

print(output)
PYEOF
```

### Step 7: 输出与保存

根据 `OUTPUT_MODE` 参数处理输出:

**console 模式**（默认）:

- 直接将 `/tmp/sciai_daily_digest.txt` 内容输出到控制台
- 用户可直接复制粘贴到微信

**file 模式**:

```bash
PROJECT_DIR="$HOME/GitHub_Source_Code/Supply-New-Agent"
OUTPUT_DIR="$PROJECT_DIR/reports/daily"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/${TARGET_DATE}.md"
cp /tmp/sciai_daily_digest.txt "$OUTPUT_FILE"
echo "日报已保存: ${OUTPUT_FILE}"
```

**both 模式**: 同时输出到控制台并保存文件。

输出完成信息:

```
━━━━━━━━━━━━━━━━━━
日报生成完成！
日期: {TARGET_DATE} ({DISPLAY_DATE})
文章数: {实际文章数} / {候选文章总数}
输出: {console/file路径}
━━━━━━━━━━━━━━━━━━
```

## 注意事项

### API 复用

- 文章获取脚本复用 `~/.openclaw/skills/weekly-report/scripts/fetch_articles.sh`
- DashScope 调用脚本复用 `~/.openclaw/skills/weekly-report/scripts/dashscope_generate.sh`
- 分类映射复用 `~/.openclaw/skills/weekly-report/references/category-names.json`

### 文章 URL 格式

- URL 格式固定为 `https://news.yrules.com/archives/{ID}`
- ID 来自 WordPress REST API，保证准确
- **绝不能**猜测或编造 URL

### 微信分享适配

- 避免过长的行（微信单行显示约 35 个中文字符）
- 使用 Unicode 框线字符（┏┃┗━）增强视觉效果
- emoji 增加可读性和扫描效率
- 链接单独一行，方便点击

### DashScope 回退

- 如果 `DASHSCOPE_API_KEY` 未设置或 DashScope 调用失败
- 回退到 Agent 自身的 LLM 能力完成筛选和洞察提取
- 回退时直接读取文章内容，逐篇生成结构化字段

### 跨平台兼容（Mac + NAS）

- 脚本仅依赖 `bash`, `curl`, `python3`（标准 POSIX + Python3）
- 不依赖 macOS 特有工具（如 `gdate`）
- `date` 命令仅用于获取当前日期（`date +%Y-%m-%d`），兼容 Linux/macOS
- Python 日期处理使用标准库 `datetime`（无需第三方包）
- 环境变量传递配置: `SCIAI_API_BASE`, `DASHSCOPE_API_KEY`
- 临时文件放 `/tmp/`
- NAS 环境确保有 `python3` 和 `curl`

### 聚焦板块过滤

当 `--focus` 不是 `all` 时，在 Step 3 增加过滤逻辑:

| focus 值    | 匹配的 group                 |
| ----------- | ---------------------------- |
| logistics   | 物流与运输                   |
| esg         | 可持续发展                   |
| ai          | 科技创新                     |
| finance     | 采购与供应商（含供应链金融） |
| procurement | 采购与供应商                 |

过滤后如果文章不足 `ARTICLE_COUNT`，从其他板块补充。

### 错误处理

- API 获取失败 → 提示用户检查网络和 API 地址
- DashScope 不可用 → 回退到 Agent 自身 LLM 能力
- 筛选 JSON 解析失败 → 按发布时间倒序取前 N 篇
- 洞察 JSON 解析失败 → 对每篇文章使用 title + excerpt 作为简单替代
- 文章数为 0 → 提示"当日暂无新发布文章"并终止
- 文章数 < 4 → 全部使用，跳过筛选步骤

### 默认配置

- 文章语言: `zh`（中文）
- 文章数量: 6
- DashScope model: `qwen-plus`
- 输出: console
- API 基础地址: `https://news.yrules.com`
