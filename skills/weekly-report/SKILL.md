---
name: weekly-report
description: |
  生成供应链行业周报。从 SCI.AI (news.yrules.com) 已发布文章中筛选本周最重要的新闻，按三级层次生成 Markdown 周报。
  触发关键词: 周报、weekly report、生成周报、新闻周报、供应链周报、本周新闻总结
  适用场景: 每周末生成供应链行业新闻总结、行业动态回顾
  不适用: 发布文章、搜索新闻、财报分析
version: 1.1
---

# 供应链行业周报生成

从 SCI.AI 已发布文章中筛选本周 15-20 条最重要新闻，按三级层次（深度分析 / 结构化摘要 / 简讯）生成 Markdown 周报。

## Workflow

### Step 1: 确定日期范围

默认生成本周周报（周一至周日）。如用户指定了日期范围则使用用户指定的。

```bash
# 计算本周一和周日
FROM_DATE=$(python3 -c "
from datetime import date, timedelta
today = date.today()
monday = today - timedelta(days=today.weekday())
print(monday.strftime('%Y-%m-%d'))
")
TO_DATE=$(python3 -c "
from datetime import date, timedelta
today = date.today()
sunday = today - timedelta(days=today.weekday()) + timedelta(days=6)
print(sunday.strftime('%Y-%m-%d'))
")
WEEK_NUM=$(python3 -c "from datetime import date; print(date.today().isocalendar()[1])")
YEAR=$(date +%Y)
echo "周报范围: ${FROM_DATE} ~ ${TO_DATE} (第${WEEK_NUM}周)"
```

### Step 2: 获取文章

```bash
SKILL_DIR="$HOME/.openclaw/skills/weekly-report"
bash "$SKILL_DIR/scripts/fetch_articles.sh" "$FROM_DATE" "$TO_DATE"
```

输出文件: `/tmp/sciai_weekly_articles.json`

检查文章数量:

```bash
ARTICLE_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/sciai_weekly_articles.json'))))")
echo "本周共 ${ARTICLE_COUNT} 篇文章"
```

如果文章数为 0，告知用户本周无文章并终止。

### Step 3: 准备文章摘要列表

提取每篇文章的 id、标题、摘要、日期、分类、URL，生成精简列表供 AI 排序:

```bash
python3 -c "
import json

with open('/tmp/sciai_weekly_articles.json') as f:
    articles = json.load(f)

# Load category names
try:
    with open('$SKILL_DIR/references/category-names.json') as f:
        cat_names = json.load(f)
except:
    cat_names = {}

summary = []
for a in articles:
    title = a.get('title', '')
    if isinstance(title, dict):
        title = title.get('rendered', '')
    excerpt = a.get('excerpt', '')
    if isinstance(excerpt, dict):
        excerpt = excerpt.get('rendered', '')
    # Strip HTML tags from excerpt
    import re
    excerpt = re.sub(r'<[^>]+>', '', excerpt).strip()[:200]

    cats = a.get('categories', [])
    cat_labels = [cat_names.get(str(c), {}).get('zh', str(c)) for c in cats]

    summary.append({
        'id': a['id'],
        'title': title,
        'excerpt': excerpt,
        'date': a.get('date', '')[:10],
        'categories': cat_labels,
        'url': a.get('url', '')
    })

with open('/tmp/sciai_weekly_summary.json', 'w') as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)
print(f'Prepared {len(summary)} article summaries')
"
```

### Step 4: AI 筛选与分级

将文章摘要列表发给 DashScope (Qwen) 进行一次性筛选排序。

将以下 prompt 写入临时文件:

```bash
cat > /tmp/sciai_rank_prompt.txt << 'PROMPT_END'
你是供应链行业资深编辑，负责编辑每周的供应链行业周报。

以下是本周发布的所有文章。请筛选出最重要的约 20 篇，并分为三个层级：

## A级（3-5篇）：重大行业事件，值得深度分析
选择标准：
- 影响全球或全国供应链格局的重大事件
- 重大企业并购、重组、退市
- 标志性政策出台或贸易格局变化
- 重要企业财报显示行业趋势变化

## B级（8-10篇）：重要行业动态，需要结构化总结
选择标准：
- 企业战略调整或业务扩展
- 区域市场重要变化
- 技术创新和应用进展
- 行业数据发布、市场分析

## C级（5-7篇）：值得关注的行业简讯
选择标准：
- 企业人事变动
- 产品发布或服务升级
- 合作签约、会议活动
- 其他值得一提的行业动态

## 分级原则（严格遵守）
1. **每篇文章只能出现在一个层级中**，A/B/C 之间不得重复
2. **A 级文章之间主题不得高度重叠**——例如不能有 2 篇都讲欧盟跨境电商政策，应选最重要的 1 篇入 A 级，另一篇降为 B 级
3. 优先选择有具体数据和企业名称的文章
4. 涉及多个企业或全行业的文章优先级高于单一企业新闻
5. 同一事件的不同角度文章只选最好的一篇
6. 确保六大分类均有覆盖：供应链管理、物流与运输、科技创新、风险与韧性、采购与供应商、可持续发展

## B 级文章周报分类

对每篇 B 级文章，根据文章内容（而非 WordPress 原始分类）指定最匹配的周报分类，从以下 6 类中选择：
- 供应链管理
- 物流与运输
- 科技创新
- 风险与韧性
- 采购与供应商
- 可持续发展

PROMPT_END
```

然后追加文章列表:

````bash
echo "" >> /tmp/sciai_rank_prompt.txt
echo "## 本周文章列表" >> /tmp/sciai_rank_prompt.txt
echo "" >> /tmp/sciai_rank_prompt.txt
cat /tmp/sciai_weekly_summary.json >> /tmp/sciai_rank_prompt.txt
echo "" >> /tmp/sciai_rank_prompt.txt
cat >> /tmp/sciai_rank_prompt.txt << 'PROMPT_END2'

## 返回格式

严格返回以下 JSON 格式（不要有其他内容）：

```json
{
  "A": [
    {"id": 123, "title": "文章标题", "reason": "为什么列为A级（1句话）"}
  ],
  "B": [
    {"id": 456, "title": "文章标题", "category": "科技创新", "reason": "为什么列为B级（1句话）"}
  ],
  "C": [
    {"id": 789, "title": "文章标题", "reason": "简短理由"}
  ]
}
````

注意：B 级的 `category` 必须是以下 6 个值之一：供应链管理、物流与运输、科技创新、风险与韧性、采购与供应商、可持续发展。
PROMPT_END2

````

调用 DashScope:

```bash
RANKING_RESULT=$(bash "$SKILL_DIR/scripts/dashscope_generate.sh" /tmp/sciai_rank_prompt.txt qwen-plus)
echo "$RANKING_RESULT" > /tmp/sciai_weekly_ranking.json
````

**解析排序结果**: 从返回内容中提取 JSON（可能包裹在 ```json 代码块中）:

```bash
python3 -c "
import json, re, sys

with open('/tmp/sciai_weekly_ranking.json') as f:
    text = f.read()

# Extract JSON from markdown code block if present
match = re.search(r'\`\`\`json?\s*\n(.*?)\n\`\`\`', text, re.DOTALL)
if match:
    text = match.group(1)

# Try to find JSON object
match = re.search(r'\{.*\}', text, re.DOTALL)
if match:
    data = json.loads(match.group())
    with open('/tmp/sciai_weekly_ranking_parsed.json', 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    a_count = len(data.get('A', []))
    b_count = len(data.get('B', []))
    c_count = len(data.get('C', []))
    print(f'Ranking parsed: A={a_count}, B={b_count}, C={c_count}')
else:
    print('ERROR: Could not parse ranking JSON', file=sys.stderr)
    sys.exit(1)
"
```

### Step 5: 生成 A 级文章深度分析

对每篇 A 级文章，获取全文并生成深度分析。

**A 级文章使用你自身的 LLM 能力生成**（非 DashScope），因为深度分析需要更高质量。

对于每篇 A 级文章:

1. 从 `/tmp/sciai_weekly_articles.json` 中按 id 找到完整文章内容
2. 提取纯文本（去除 HTML 标签），保留前 3000 字
3. 按以下结构生成分析（注意"深度分析"部分的维度应根据事件性质灵活选择，不要机械套用固定模板）:

```markdown
### {重新拟定的标题——更有分析深度和冲击力} | [原文链接]({url})

> {一句话导语，概括这条新闻为什么重要}

**事件概述**

{2-3段，讲清楚事件的来龙去脉、关键细节。每个论点至少配一个数据支撑。
篇幅控制：事件描述占全文 30% 以下，分析占 70% 以上。}

**关键信息**

| 维度     | 内容                                  |
| -------- | ------------------------------------- |
| 事件类型 | {并购/政策/财报/技术突破/...}         |
| 涉及企业 | {主要企业名称}                        |
| 关键数据 | {最核心的 2-3 个数字，必须有具体数值} |
| 时间节点 | {关键日期}                            |

**深度分析**

{根据事件性质选择最相关的 2-4 个分析维度，从以下维度库中灵活选取，不要每篇都用相同的维度组合：

可选维度（选 2-4 个最相关的）：

- **影响链条**：谁是直接受影响方？传导路径是什么？对大企业/中小企业的差异化影响
- **成本结构**：对供应链总成本的量化影响（物流成本、合规成本、技术投入等）
- **竞争格局**：如何改变行业竞争态势？谁受益、谁受损？
- **政策与合规**：政策的执行机制和落地挑战是什么？
- **技术落地**：实施成本、落地障碍、成熟度评估（不能只描述愿景）
- **风险与挑战**：哪些假设可能不成立？可能推翻判断的因素
- **中国企业启示**：对中国供应链企业/从业者的具体行动建议

前瞻性判断必须标注前提条件和时间框架，使用条件式表达：
✅ "若 X 条件持续 Y 个月，预计 Z 将..."
❌ "X 必将成为行业标准" / "预计将看到更多类似趋势"

每个维度都必须包含因果推理链条：事实 → 传导机制 → 影响结论}
```

#### A 级内容质量要求

**写作原则**：

- 语言风格为**行业分析**而非新闻报道——重点回答 "Why / So What / What Next"
- 每个分析论点至少有 1 个数据支撑，数据需可溯源
- 不同类型企业（大/中/小、内贸/外贸）的差异化影响必须区分
- 不得只展示乐观视角，每篇至少包含 1 个风险/挑战/质疑观点

**禁用词汇和句式**：

- 禁止使用：历史性、颠覆式、前所未有、根本性变革、深远影响、全面/全方位
- 禁止句式："标志着行业进入新阶段"、"既是机遇也是挑战"、"值得注意的是"、"不可忽视的是"
- 如果想表达"重大"，应该用数据证明其规模/影响确实罕见
- 5 篇 A 级文章之间，分析维度的组合不应重复——避免每篇都是"行业影响+战略意义+未来展望"的三段式

将每篇 A 级文章的分析结果保存，后续组装用。

### Step 6: 生成 B 级文章结构化摘要

B 级文章使用 DashScope (Qwen) 批量生成，降低成本。

将所有 B 级文章的完整内容整理为一次请求，prompt 格式:

```
你是供应链行业分析师。对以下每篇文章生成结构化摘要。

写作要求：
1. 核心要点必须包含具体数据或企业名称，不得使用空泛概括
2. 行业影响部分要说明"对谁有什么影响"，区分不同规模/类型企业
3. 禁止使用"历史性"、"颠覆式"、"前所未有"等夸张修饰
4. 禁止使用"值得注意的是"、"不可忽视的是"等AI模板化过渡语

每篇文章的输出格式（严格遵守，包括原文链接）：

### {原标题} | [原文链接]({url})

> {一句话导语：点明核心事件和关键数字}

**核心要点**
- {要点1：必须包含具体数据}
- {要点2：必须包含企业名称或政策名称}
- {要点3}

**行业影响**：{一段话总结这个动态对行业的意义，需区分对头部企业和中小企业的差异化影响}

---

文章列表：
[文章1全文...]
原文链接: {url1}
===
[文章2全文...]
原文链接: {url2}
===
...
```

调用:

```bash
bash "$SKILL_DIR/scripts/dashscope_generate.sh" /tmp/sciai_b_prompt.txt qwen-plus
```

注意：如果 B 级文章超过 8 篇，可能需要分两批调用以避免超出 token 限制。每批不超过 5 篇。

### Step 7: 生成 C 级文章简讯

C 级文章使用 DashScope (Qwen) 一次性生成:

```
对以下每篇文章生成一句话新闻简讯。

标题要求：
- 精简到 15 字以内，只写"核心主体 + 动作"
- ❌ 错误示范："从实验室走向车间流水线：丰田引入七台Digit人形机器人，RaaS模式如何重塑供应链自动化"
- ✅ 正确示范："丰田部署 Digit 人形机器人"

输出格式（每条一行）：
- **{精简标题}** — {一句话描述核心事件，包含关键数据}（{YYYY-MM-DD}）[原文]({url})

文章列表：
[{id, title, excerpt, date, url}]
```

### Step 8: 生成周报概览

使用你自身的 LLM 能力，基于已生成的所有 A/B/C 级内容，写 3-5 句话的周报概览:

- 概括本周供应链行业的整体态势，提炼 1 个核心主线
- 点出 2-3 个最值得关注的趋势，每个趋势至少引用 1 个具体数据
- 语言风格：总编辑社论视角，有明确判断和立场，不做"面面俱到"的流水账
- 最后一句应指出"本周最值得关注的信号/风险"，给读者一个行动导向
- 禁止使用"值得注意"、"不可忽视"、"既是机遇也是挑战"等套话

### Step 9: 按分类分组 B 级文章

使用 Step 4 排序结果中 B 级文章的 `category` 字段进行分组（该字段由 AI 根据文章内容指定，比 WordPress 原始分类更准确）。分组顺序:

1. 供应链管理
2. 物流与运输
3. 科技创新
4. 风险与韧性
5. 采购与供应商
6. 可持续发展

如果某个分组下没有 B 级文章，跳过该分组。

### Step 10: 组装最终 Markdown

按以下结构组装完整周报:

```markdown
# SCI.AI 供应链行业周报

**{YEAR}年第{WEEK}周 ({FROM_DATE} - {TO_DATE})**

---

## 本周概览

{Step 8 生成的概览}

---

## 重点关注

{Step 5 生成的 A 级文章深度分析，每篇之间用 --- 分隔}

---

## 行业动态

### {分类名称1}

{该分类下的 B 级文章摘要}

### {分类名称2}

{该分类下的 B 级文章摘要}

...

---

## 行业简讯

{Step 7 生成的 C 级简讯列表}

---

> SCI.AI 供应链行业周报 | 自动生成于 {TODAY} | https://news.yrules.com
```

### Step 11: 保存输出

```bash
PROJECT_DIR="$HOME/GitHub_Source_Code/Supply-New-Agent"
OUTPUT_DIR="$PROJECT_DIR/reports/weekly"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/${YEAR}-W$(printf '%02d' ${WEEK_NUM}).md"
```

将组装好的 Markdown 写入 `$OUTPUT_FILE`。

输出完成信息:

```
周报已生成: {OUTPUT_FILE}
文章统计: A级 {a_count} 篇 | B级 {b_count} 篇 | C级 {c_count} 篇
日期范围: {FROM_DATE} ~ {TO_DATE}
```

## 内容质量规范

以下规范适用于所有层级（A/B/C）的内容生成：

### 分析方法论

供应链事件的分析应从以下六个维度中选择最相关的 2-3 个深入：

| 维度   | 核心问题                          | 常用指标                             |
| ------ | --------------------------------- | ------------------------------------ |
| 成本   | 对总物流成本/供应链成本的影响？   | 物流费用占比、单票成本、运价指数     |
| 时效   | 对交付速度和响应能力的影响？      | 履约周期、准时率、库存周转天数       |
| 韧性   | 是否增加/减少了单点故障？         | 供应商集中度、安全库存、替代方案     |
| 可见性 | 对信息透明度和决策质量的影响？    | 追踪覆盖率、数据共享节点、预测准确率 |
| 合规   | 涉及监管/政策变化？合规成本如何？ | 法规条款、合规投入、违规风险         |
| 可持续 | 对碳排放/ESG 的影响？             | 碳排放变化、绿色比例、ESG 评级       |

### 语言风格

- **行业分析**而非新闻报道——回答 Why / So What / What Next，而非仅描述 What / When / Who
- 事件描述 ≤ 30%，分析 ≥ 70%
- 每个论点至少配 1 个数据支撑
- 对不同类型企业（大/中/小、国企/民企、内贸/外贸）的差异化影响需区分
- 前瞻性判断必须标注前提条件和时间框架

### 全局禁用清单

**禁用词汇**：历史性、颠覆式、前所未有、根本性变革、深远影响、全面/全方位、里程碑式

**禁用句式**：

- "标志着行业进入新阶段"（改为具体说明什么阶段、与之前有何不同）
- "既是机遇也是挑战"（改为明确立场：对谁利大于弊，对谁弊大于利）
- "值得注意的是" / "不可忽视的是"（直接陈述事实）
- "预计将看到更多类似趋势"（改为条件式预判+具体时间框架）
- "随着 X 的深入推进，Y 将..."（需补充传导机制）

### 因果分析四步法

所有分析段落应遵循：

1. **事实层**：发生了什么？关键数字是什么？
2. **机制层**：通过什么路径产生影响？（成本、效率、竞争、政策）
3. **影响层**：对谁产生什么影响？正面/负面分别是什么？
4. **不确定层**：哪些因素可能改变上述判断？

## 注意事项

### DashScope 调用

- timeout 至少 180 秒（长文生成耗时）
- 如果 `DASHSCOPE_API_KEY` 未设置，回退到 Agent 自身 LLM 能力生成所有内容
- 每次 DashScope 调用之间间隔 2 秒

### 文章内容处理

- WordPress REST API 返回的 `title` 和 `excerpt` 是 `{"rendered": "..."}` 格式，需要提取 `rendered` 值
- `content.rendered` 包含 HTML，生成分析时需要先转为纯文本
- 注意去除 `<p class="source">` 来源标注段落，避免干扰分析

### 跨平台兼容

- 脚本仅依赖 `bash`, `curl`, `python3`
- API 密钥通过环境变量传递: `SCIAI_API_BASE`, `DASHSCOPE_API_KEY`
- 临时文件放 `/tmp/`
- 输出目录 `~/GitHub_Source_Code/Supply-New-Agent/reports/weekly/`

### 错误处理

- API 获取失败 → 提示用户检查网络和 API 地址
- DashScope 不可用 → 回退到 Agent 自身 LLM
- 排序 JSON 解析失败 → 重试一次，仍失败则按文章日期倒序取前 20 篇均分为 B 级
- 文章数不足 5 篇 → 全部列为 B 级，不分 A/C 级

### 默认配置

- 文章语言: `zh`（中文）
- 分级数量: A(3-5) + B(8-10) + C(5-7) ≈ 20 篇
- DashScope model: `qwen-plus`
- 输出: Markdown 文件
