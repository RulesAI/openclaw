# Agent 自主学习与技能创造架构

> 目标：让 Agent 具备自主学习、自主优化、自主创造技能、自主搜索和安装技能的能力。

---

## 一、现有能力 vs 缺失能力

| 已有基础设施                     | 缺失能力                      |
| -------------------------------- | ----------------------------- |
| Skill 文件系统（SKILL.md 格式）  | Agent 自主创建 Skill 的元技能 |
| Cron 定时任务（isolated 模式）   | 执行结果的评分/反馈闭环       |
| Memory 语义搜索（SQLite + 向量） | 从成功模式中提炼 Skill        |
| Hook 事件系统（pre/post turn）   | Skill 发现/搜索集成           |
| 安装框架（brew/npm/download）    | 自动化安装决策                |
| 多 Agent 隔离 workspace          | Agent 间经验共享              |
| ClawHub 技能市场（3000+ skills） | Agent 主动搜索 ClawHub        |

---

## 二、五层自主能力架构

### 第 1 层：自主学习 — 反馈闭环

**核心思路**：每次任务执行后，记录"做了什么 → 结果如何 → 哪里可以改进"。

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│  执行任务  │───▶│ 评估结果  │───▶│ 更新记忆  │
└──────────┘    └──────────┘    └──────────┘
      ▲                               │
      └───────────────────────────────┘
```

**实现方式**：

1. **扩展 `compaction-memory` hook** — 已有 hook 在上下文压缩前保存重要信息，可扩展为保存任务成功/失败模式
2. **新增 `post-turn-reflection` hook** — 每次 agent turn 完成后：
   - 检查工具调用是否成功/失败
   - 记录失败原因到 `~/.openclaw/agents/<id>/learnings.jsonl`
   - 记录成功模式
   - Memory Search 能在下次类似任务时找到这些经验
3. **反思 Cron Job** — 每天凌晨回顾当天所有 session：
   ```yaml
   name: "daily-reflection"
   schedule: { kind: "cron", expr: "0 2 * * *", tz: "Asia/Shanghai" }
   sessionTarget: "isolated"
   payload:
     kind: "agentTurn"
     message: |
       Review today's sessions. For each:
       1. What task was attempted?
       2. Did it succeed or fail?
       3. What tools/skills were used?
       4. What could be done better?
       Write summary to ~/.openclaw/agents/main/learnings/YYYY-MM-DD.md
   ```

**ClawHub 可用技能**：

- `agent-reflect` — 自我反思，通过对话分析进行自我改进
- `inner-life-reflect` (DKistenev) — 触发检测 + 质量门控，仅在有意义的事件发生时写入 SELF.md

---

### 第 2 层：自主优化 — 从经验中改进

**核心思路**：Agent 有权限修改自己的 Skill 文件和配置。

创建一个 "self-optimize" 元技能：

```markdown
# ~/.openclaw/skills/self-optimize/SKILL.md

## Process

1. Read target skill's SKILL.md
2. Read recent execution logs from sessions/
3. Identify failure patterns or inefficiencies
4. Propose specific changes to SKILL.md
5. Write updated SKILL.md (backup original to .bak)
6. Log change to ~/.openclaw/skills/\_changelog.jsonl

## Safety Rules

- NEVER delete skills, only modify
- Always keep backup
- Changes must be logged with reason
- If unsure, create v2 variant instead of overwriting
```

**ClawHub 可用技能**：

- `agent-evolver` — AI Agent 自我进化引擎，从经验中学习、检测问题、提取洞察
- `inner-life-evolve` (DKistenev) — 自我进化提案 + 人工审批机制

---

### 第 3 层：自主创造技能 — Skill Generator

**核心思路**：当 Agent 成功完成一个多步骤任务且没有匹配的 skill 时，自动提炼为新技能。

**触发条件**：

- 成功完成了一个没有匹配 skill 的多步骤任务
- 同一类任务被重复执行 3+ 次
- Agent 即兴创建的工作流应该被标准化

**创建流程**：

```
分析成功模式 → 草拟 SKILL.md → 添加参考材料 → 测试验证 → 注册生效
```

**SKILL.md 模板**：

```yaml
---
name: <descriptive-name>
description: "<what this skill does>"
version: 1.0
metadata:
  openclaw:
    requires:
      bins: [<required binaries>]
      env: [<required env vars>]
---
# Instructions
[从成功的 session 中提炼的步骤]
```

**ClawHub 可用技能**：

- `advanced-skill-creator` — 自动化 OpenClaw 技能设计，执行官方五步研究流程（文档、ClawHub 侦察、社区搜索、融合分析、确定性输出）

---

### 第 4 层：自主搜索技能 — Skill Discovery

**核心思路**：Agent 收到任务时，先搜索是否已有现成技能可用。

**三种搜索路径**：

#### 方案 A：ClawHub 搜索（推荐）

```bash
# CLI 搜索
clawhub search "postgres backups"
clawhub inspect <slug>  # 安装前审查
clawhub install <slug>

# 或通过 find-skills 技能让 Agent 直接搜索
```

#### 方案 B：本地技能注册表

```json
// ~/.openclaw/skills/_index.json
{
  "capability_map": {
    "publish to wordpress": "supply-news-publisher",
    "generate weekly report": "weekly-report",
    "search academic papers": "academic-paper-search"
  }
}
```

Agent 收到任务时先查询 capability_map 匹配已有技能。

#### 方案 C：语义搜索匹配

利用已有 Memory 系统，将所有 SKILL.md 内容索引到向量库，任务到来时做语义搜索匹配。

**ClawHub 可用技能**：

- `find-skills` — 帮助用户发现和安装 agent 技能，当用户问 "how do I do X" 时自动搜索 ClawHub
- `clawhub` (bundled) — OpenClaw 内置的 ClawHub 集成技能

---

### 第 5 层：自行安装尝试 — Sandboxed Experimentation

**核心思路**：新技能先在沙箱环境验证，通过后才进入正式环境。

```
┌─────────────────────────────────────┐
│          Sandbox Agent              │
│  ┌─────────┐   ┌────────────────┐  │
│  │ 发现技能 │──▶│ 隔离环境安装试用 │  │
│  └─────────┘   └────────────────┘  │
│        │              │             │
│        ▼              ▼             │
│  ┌─────────┐   ┌────────────────┐  │
│  │ 评估结果 │◀──│ 运行测试用例    │  │
│  └─────────┘   └────────────────┘  │
│        │                            │
│        ▼                            │
│  成功 → 安装到正式环境              │
│  失败 → 记录原因，丢弃              │
└─────────────────────────────────────┘
```

**实现方式**：

- 利用 OpenClaw 的 `sandbox` 配置创建实验 Agent
- 使用 `subagents` spawn 隔离子 Agent 测试新技能
- 测试 Agent 使用独立 workspace，不影响正式环境
- 测试通过后 copy skill 到正式 skills 目录

**安装命令**：

```bash
clawhub install <slug>                    # 安装到当前 workspace
clawhub install <slug> --version 1.2.0    # 指定版本
clawhub update --all                      # 更新所有已安装技能
```

---

## 三、已安装技能盘点与冲突分析

### 当前已安装技能（85 个）

**Managed skills**（`~/.openclaw/skills/`，28 个）：
agents-skill-tdd-helper, clawra-selfie, code-mentor, daily-supply-news-digest, debug-pro, exa, manlin-media, new-user-watch, pdf-extract, sci-report-analyst, server-ops, su-manlin-photos, subscription-monitor, supply-news-publisher, test-runner, user-advocate, user-census, user-satisfaction, venice-ai, wechat-article-sync, weekly-report, word-docx, xiaohongshu-cover-image-generator, xiaohongshu-engager, xiaohongshu-publisher, youtube-transcript

**Workspace skills**（`skills/`，57 个）：
1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, bluebubbles, camsnap, canvas, **clawhub**, coding-agent, discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, model-usage, nano-banana-pro, nano-pdf, notion, obsidian, openai-image-gen, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, sag, server-ops, session-logs, sherpa-onnx-tts, **skill-creator**, slack, songsee, sonoscli, spotify-player, summarize, things-mac, tmux, trello, video-frames, voice-call, wacli, weather, weekly-report, xurl

### 与推荐技能的对比分析

| 推荐能力      | ClawHub 推荐             | 本地已有                    | 冲突/关系                                                                                                                      | 建议                                                                                                                            |
| ------------- | ------------------------ | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| **技能创造**  | `advanced-skill-creator` | `skill-creator` (workspace) | **功能重叠** — 本地版已有完整的 6 步创建流程（理解→规划→初始化→编辑→打包→迭代），含 `init_skill.py` 和 `package_skill.py` 脚本 | **不需要安装**。本地版更贴合项目，且已包含打包/发布能力。ClawHub 版侧重"五步研究流程"（文档侦察、社区搜索），可作为补充但非必需 |
| **技能搜索**  | `find-skills`            | `clawhub` (workspace)       | **功能互补** — `clawhub` 提供 CLI 操作（search/install/update/publish），`find-skills` 提供自然语言搜索（"how do I do X"）     | **建议安装 `find-skills`**。`clawhub` 已有但偏工具操作，`find-skills` 补充了"任务→技能"的语义匹配能力                           |
| **自我优化**  | `agent-evolver`          | 无直接对应                  | **无冲突** — 现有 `user-satisfaction`/`user-advocate` 是面向"用户"的反馈循环，不是面向"Agent 自身"的优化                       | **建议安装**                                                                                                                    |
| **自我反思**  | `agent-reflect`          | 无直接对应                  | **无冲突** — 现有 `compaction-memory` hook 只保存上下文，不做反思分析                                                          | **建议安装**                                                                                                                    |
| **技能市场**  | `clawhub` (bundled)      | `clawhub` (workspace)       | **已安装**                                                                                                                     | **不需要安装**                                                                                                                  |
| **情感+进化** | `inner-life-*` (6模块)   | 无对应                      | **无冲突** — 但注意 `inner-life-memory` 与现有 Memory 系统（SQLite + 向量搜索）可能有功能重叠                                  | **可选安装**。适合需要"拟人化"Agent 的场景，但会占用较多 context window                                                         |

### 需要注意的潜在冲突

1. **`skill-creator` vs `advanced-skill-creator`**
   - 本地 `skill-creator` 已包含完整的技能创建 pipeline（含 `init_skill.py`、`package_skill.py` 脚本）
   - ClawHub 的 `advanced-skill-creator` 增加了"ClawHub 侦察"步骤（搜索现有技能避免重复造轮子）
   - **结论**：如果同时安装，两者会在 skill 名称匹配时产生优先级冲突。建议**保留本地版**，仅在需要 ClawHub 侦察能力时参考 `advanced-skill-creator` 的文档

2. **`inner-life-memory` vs 内置 Memory 系统**
   - OpenClaw 已有成熟的 Memory 系统（SQLite + 向量搜索 + BM25 混合检索 + 时间衰减）
   - `inner-life-memory` 是一个更轻量的"置信度评分"记忆系统
   - **结论**：功能层面不冲突（一个是基础设施，一个是行为策略），但需评估 context window 开销

3. **`server-ops` 重复安装**
   - 同时存在于 managed skills 和 workspace skills 中
   - workspace 版优先级更高，managed 版不会生效
   - **结论**：可清理 managed 版（`~/.openclaw/skills/server-ops/`）避免混淆

4. **`weekly-report` 重复安装**
   - 同样存在于两个位置
   - **结论**：同上，清理 managed 版

### 最终安装建议

```bash
# 安装 clawhub CLI（如未安装）
npm i -g clawhub

# 必装：填补现有空白
clawhub install agent-evolver       # 自我优化（无现有替代）
clawhub install agent-reflect       # 自我反思（无现有替代）
clawhub install find-skills         # 语义技能搜索（补充现有 clawhub skill）

# 不需要安装
# advanced-skill-creator  → 本地 skill-creator 已覆盖
# clawhub                → 已安装

# 可选：inner-life 套件（评估 context window 开销后决定）
# clawhub install inner-life-core
# clawhub install inner-life-evolve

# 清理重复
# rm -rf ~/.openclaw/skills/server-ops/    （workspace 版优先）
# rm -rf ~/.openclaw/skills/weekly-report/ （workspace 版优先）
```

---

## 四、ClawHub 可直接复用的技能清单

| 我的建议                     | ClawHub 已有技能          | 说明                                                                 |
| ---------------------------- | ------------------------- | -------------------------------------------------------------------- |
| skill-creator（元技能）      | `advanced-skill-creator`  | 官方五步研究流程，自动化技能设计                                     |
| self-optimize（自我优化）    | `agent-evolver`           | 从经验中学习、检测问题、提取洞察                                     |
| daily-reflection（每日反思） | `agent-reflect`           | 通过对话分析进行自我改进                                             |
| skill discovery（技能发现）  | `find-skills`             | 当用户问 "how do I do X" 时自动搜索 ClawHub                          |
| 技能市场集成                 | `clawhub` (bundled)       | OpenClaw 内置，无需额外安装                                          |
| 情感+记忆+进化               | `inner-life-*` (6 个模块) | DKistenev 的内心生活套件：core/reflect/memory/dream/chronicle/evolve |

### inner-life 套件详细说明（DKistenev）

6 个模块化技能，赋予 Agent "内心生活"：

1. **inner-life-core** — 基础层：情感追踪（connection, curiosity, confidence, boredom, frustration, impatience），9 步 Brain Loop 协议
2. **inner-life-reflect** — 自我反思：触发检测 + 质量门控，仅在有意义的事件发生时写入 SELF.md（被纠正、发现模式 ≥2 次、发现盲点）
3. **inner-life-memory** — 记忆连续性：带置信度评分，置信度决定 Agent 是陈述事实还是请求确认
4. **inner-life-dream** — 创造性探索：安静时段的发散思维
5. **inner-life-chronicle** — 结构化日记：每日记录
6. **inner-life-evolve** — 自我进化提案：需人工审批才能生效

---

## 已实现：Task Manager（任务队列管理）

> 2026-03-05 部署，林紫涵 Agent (MateBook X) 试点。

### 解决的问题

- Simon 交代的临时任务无法持久化，session 切换后丢失
- 长任务阻塞主对话，Simon 无法同时聊天
- Agent 不会主动用 SubAgent 异步执行任务

### 组件

| 组件         | 路径                                                   | 说明                                        |
| ------------ | ------------------------------------------------------ | ------------------------------------------- |
| SKILL.md     | `~/.openclaw/skills/task-manager/SKILL.md`             | Skill 定义：触发词、任务流程、SubAgent 模板 |
| task-cli.mjs | `~/.openclaw/skills/task-manager/scripts/task-cli.mjs` | Node.js CLI，零依赖，原子写入 TASKS.json    |
| TASKS.json   | workspace 目录下                                       | 任务数据文件（由 CLI 维护，Agent 不手写）   |
| HEARTBEAT.md | workspace 目录下                                       | 心跳检查流程（每 30 分钟自动检查任务）      |
| AGENTS.md    | workspace 目录下                                       | 增加 Task Manager + SubAgent 调度规则段落   |

### task-cli.mjs 命令

```bash
node ~/.openclaw/skills/task-manager/scripts/task-cli.mjs <verb>
# add "标题" "详情"     → 输出 task ID
# list [--all]          → JSON 数组
# start <id> [key]      → 标记 in-progress
# done <id> "结果"      → 标记 done
# block <id> "原因"     → 标记 blocked
# cancel <id>           → 取消
# show <id>             → 查看详情
# report <id>           → 标记已汇报
```

### 工作流

```
Simon → "帮我调研竞品X" → Agent 主对话:
  1. task-cli add "调研竞品X" "..."   → task-a3f7b2
  2. sessions_spawn(SubAgent)
  3. task-cli start task-a3f7b2
  4. 回复 "已安排处理"
  ↓
SubAgent (共享 workspace):
  1. 执行调研
  2. task-cli done task-a3f7b2 "结果摘要"
  ↓
Heartbeat (每 30 分钟):
  task-cli list → 有 done+unreported → 汇报给 Simon → task-cli report
```

### 迁移到其他 Agent

1. 确保 `~/.openclaw/skills/task-manager/` 已部署（Mac/MateBook X 直接复制，NAS 需 docker cp + chown）
2. 更新目标 Agent workspace 的 HEARTBEAT.md（加入任务检查步骤 1-6，参考林紫涵版本）
3. 更新目标 Agent workspace 的 AGENTS.md（加入 Task Manager + SubAgent 调度规则段落）
4. 配置 heartbeat: `openclaw config set agents.list.<index>.heartbeat.every '30m'`
5. 配置 heartbeat target: `openclaw config set agents.list.<index>.heartbeat.target 'last'`
6. 重启 gateway

---

## 四、推荐实施路线图

### Phase 1：立即可做（纯安装 + 配置）

```bash
# 1. 安装 clawhub CLI
npm i -g clawhub

# 2. 安装核心技能
clawhub install advanced-skill-creator
clawhub install agent-evolver
clawhub install agent-reflect
clawhub install find-skills

# 3. 可选：安装 inner-life 套件
clawhub install inner-life-core
clawhub install inner-life-reflect
clawhub install inner-life-memory
clawhub install inner-life-evolve
```

### Phase 2：配置自主循环

1. 创建反思 Cron Job（daily-reflection）
2. 配置 Agent 的 `skills` 允许列表包含新安装的技能
3. 创建本地 capability_map（`_index.json`）
4. 设置 post-turn-reflection hook

### Phase 3：高级自主能力

1. 创建 sandbox Agent 用于技能测试
2. 实现技能版本管理 + 回滚
3. Agent 间经验共享（多 Agent memory 索引）
4. 自动化 A/B 测试框架

---

## 五、核心设计原则

1. **Skill 即文件** — 利用 SKILL.md 格式，Agent 只需会写 Markdown 就能创造技能
2. **Memory 即经验** — 利用向量搜索做经验检索，不需要额外基础设施
3. **Cron 即自省** — 用定时任务驱动反思和优化循环
4. **沙箱即安全网** — 新技能先在隔离环境验证，通过后才进入正式环境
5. **渐进式信任** — 新创建/安装的 skill 先在隔离 Agent 测试，确认有效后才推广到正式 Agent
6. **人在回路中** — 关键决策（删除技能、修改核心配置）仍需人工审批

---

## 六、参考链接

- ClawHub 技能市场：https://clawhub.ai/
- ClawHub 文档：https://docs.openclaw.ai/tools/clawhub
- Skills 文档：https://docs.openclaw.ai/tools/skills
- inner-life 套件：https://github.com/DKistenev/openclaw-inner-life
- awesome-openclaw-skills：https://github.com/VoltAgent/awesome-openclaw-skills
- 递归自我改进分析：https://kenhuangus.substack.com/p/openclaw-and-recursive-self-improvement
