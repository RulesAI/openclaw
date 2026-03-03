# OpenClaw 生态全量项目清单（详细版）

> 涵盖 ClawCon SF、ClawCon Vienna、Unhackathon、社区 Meetup、GitHub awesome 列表、官方 Showcase
> 每个项目标注 **可借鉴点** 和 **可直接使用点**
> 整理时间：2026-02-18

---

## 一、核心实现与轻量替代（7 个）

### 1. OpenClaw（主项目）

- **链接**: [GitHub](https://github.com/openclaw/openclaw) (150k+ stars, 35k forks)
- **详情**: 开源自托管 AI agent 平台。TypeScript 全栈，43 万行代码。Gateway 架构（WebSocket 服务端），支持 15+ 消息通道（WhatsApp/Telegram/Discord/Slack/Signal/iMessage 等），持久记忆，Skills 插件系统，多 Agent 管理，cron 定时任务，24/7 运行
- **可借鉴**: Gateway + WebSocket 协议设计、config 热重载机制、多通道抽象层、Skills 插件架构、设备配对协议
- **可使用**: 直接作为你的 AI agent 基座平台运行

---

### 2. PicoClaw — Go 超轻量 Agent

- **链接**: [GitHub](https://github.com/sipeed/picoclaw) · [官网](https://picoclaw.net/) · [文档](https://picoclaw.ai/docs)
- **详情**: Go 语言从零重写，4 天 5000 stars。单二进制文件，仅 10MB 内存、<1 秒启动（OpenClaw 需 100MB+/30 秒）。支持 x86_64/ARM64/RISC-V 多架构。可跑在 $10 RISC-V 板上。95% 核心代码由 AI agent 自动生成（自举式开发）。内置 cron 定时任务（一次性提醒 + 周期任务 + 标准 cron 表达式）。支持 OpenRouter/Anthropic/OpenAI/DeepSeek/Groq 等多供应商
- **可借鉴**:
  - **自举式开发流程** — 用 AI agent 生成 95% 代码，人工只做 review，极大提升开发速度
  - **Go 单二进制打包** — 零依赖部署，适合边缘场景
  - **多架构编译** — 一份代码覆盖 x86/ARM/RISC-V
  - **内存优化策略** — 如何把 agent 运行时压缩到 10MB
- **可使用**: 如果你需要在树莓派、NAS、或低功耗设备上跑 agent，直接用 PicoClaw

---

### 3. NanoClaw — 安全沙箱版 Agent

- **链接**: [GitHub](https://github.com/qwibitai/nanoclaw) · [VentureBeat](https://venturebeat.com/orchestration/nanoclaw-solves-one-of-openclaws-biggest-security-issues-and-its-already) · [Docker 指南](https://www.docker.com/blog/run-nanoclaw-in-docker-shell-sandboxes/)
- **详情**: MIT 开源，一周 7000 stars。核心仅 **500 行 TypeScript**（可在 8 分钟内被人工或 AI 完整审计）。强制容器隔离（macOS 用 Apple Container，Linux 用 Docker），AI 只能在沙箱内操作。单进程 Node.js 编排器，每群组消息队列 + 并发控制，SQLite 持久化，文件系统 IPC。原生支持 **Agent Swarms**（基于 Anthropic Agent SDK），多个子 agent 并行协作，各自独立记忆上下文
- **可借鉴**:
  - **500 行核心 = 可审计** — 极简代码就能实现完整 agent 功能，说明 OpenClaw 的复杂度有大量是可选的
  - **容器隔离架构** — 每个 agent 独立容器，文件系统隔离 + 显式挂载，防 prompt injection 的"爆炸半径"控制
  - **Agent Swarms 设计** — 多 agent 并行 + 独立记忆，在你的 OpenClaw 中也可以实现类似架构
  - **SQLite + 文件系统 IPC** — 轻量替代 Redis/消息队列的方案
- **可使用**: 企业部署或安全敏感场景下，用 NanoClaw 替代 OpenClaw 宿主直接运行

---

### 4. Nanobot — 极简 Python 版（4000 行）

- **链接**: [GitHub](https://github.com/HKUDS/nanobot)
- **详情**: 香港大学团队出品。4000 行 Python 实现 OpenClaw 核心（原版 43 万行），缩减 99%。支持持久记忆、Web 搜索、后台子 agent 多任务、Telegram/WhatsApp 集成
- **可借鉴**:
  - **极简 agent 核心** — 证明了一个完整 agent 的最小实现只需 4000 行
  - **Python 生态整合** — 直接用 Python 丰富的 AI/ML 库
- **可使用**: 教学演示、快速原型验证、Python 项目集成

---

### 5. ZeroClaw — Rust 高性能 Agent

- **链接**: [GitHub](https://github.com/openagen/zeroclaw) · [官网](https://zeroclaw.bot/)
- **详情**: Rust 实现，3.4MB 二进制，<10ms 启动，<5MB 内存。支持 22+ AI 供应商（Claude/OpenAI/Ollama/Groq/Mistral 等）。基于 trait 的可插拔架构（providers/channels/tools/memory/tunnels 各为独立 trait）。SQLite 混合检索记忆（FTS5 关键词 + 向量相似度 + 加权排序）。安全设计：配对认证、严格沙箱、显式白名单、工作区作用域
- **可借鉴**:
  - **trait-based 可插拔架构** — 每个核心能力（供应商/通道/工具/记忆）都是独立 trait，通过配置切换，保持运行时最小化
  - **混合记忆检索** — FTS5 + 向量 + 加权排序的组合方案，比纯向量搜索更实用
  - **安全白名单机制** — 显式允许 > 默认拒绝
- **可使用**: 需要极致性能或 Rust 生态集成的场景

---

### 6. TinyClaw — 400 行 Shell 脚本版

- **链接**: [GitHub](https://github.com/jlia0/tinyclaw)
- **详情**: 用 Claude Code + tmux 重建 OpenClaw，仅 ~400 行 shell 脚本。保留了 WhatsApp 通道、心跳监控、cron 定时、Claude Code 插件复用。文件队列系统防止竞态条件，支持多通道。支持 Anthropic Claude + OpenAI 模型。tmux 实现 24/7 运行和并行处理。创建动机："OpenClaw 老是崩，所以我用 400 行重写了"
- **可借鉴**:
  - **文件队列系统** — 用文件系统实现消息队列，零依赖，防竞态，简单可靠
  - **tmux 进程管理** — 不需要 pm2/systemd，tmux 就能做到会话隔离和 24/7 运行
  - **Claude Code 作为 agent 运行时** — 直接复用 Claude Code 的工具能力，不需要自己实现工具调用层
- **可使用**: 最快的方式搭一个可用的 WhatsApp AI agent，半小时内完成

---

### 7. MimiClaw — $5 ESP32 芯片版

- **链接**: [GitHub](https://github.com/memovai/mimiclaw) · [官网](https://www.mimiclaw.io/) · [CNX Software](https://www.cnx-software.com/2026/02/13/mimiclaw-is-an-openclaw-like-ai-assistant-for-esp32-s3-boards/)
- **详情**: 跑在 $5 ESP32-S3 芯片上，99.2% 纯 C 语言，ESP-IDF 框架。需要 16MB Flash + 8MB PSRAM。双核分离：Core 0 跑 I/O（Telegram 轮询/消息分发），Core 1 跑 agent 循环。FreeRTOS 双队列消息总线架构。ReAct 模式（推理-行动循环）连接 Claude API。可控制 GPIO/传感器/执行器（读温度、开关灯/风扇）。本地持久化：SOUL.md（AI 人设）/USER.md（用户画像）/MEMORY.md（长期记忆）/每日笔记
- **可借鉴**:
  - **双核分离架构** — I/O 和 AI 推理在不同核心上运行，互不阻塞，OpenClaw 也可以借鉴这种关注点分离
  - **SOUL.md / USER.md / MEMORY.md 分层记忆** — 人设、用户画像、长期记忆分文件存储，清晰可维护
  - **ReAct 模式实现** — 最小化的推理-行动循环实现
  - **硬件控制能力** — 通过 agent 直接操控物理设备
- **可使用**: IoT / 智能家居 / 嵌入式 AI 场景

---

## 二、云端托管平台（12 个）

### 8. Kimi Claw — 浏览器直接用

- **链接**: [kimi.com](https://kimi.com/bot) · [MarkTechPost](https://www.marktechpost.com/2026/02/15/moonshot-ai-launches-kimi-claw-native-openclaw-on-kimi-com-with-5000-community-skills-and-40gb-cloud-storage-now/)
- **详情**: 月之暗面（Moonshot AI）出品。浏览器内运行 OpenClaw，零配置。5000+ ClawHub Skills、40GB 云存储、Pro-Grade Search（实时 Yahoo Finance 等）、Bring Your Own Claw（桥接已有实例到 Telegram）
- **可借鉴**: 云端托管 OpenClaw 的产品化思路 — 如何把自托管软件包装成 SaaS
- **可使用**: 非技术用户快速体验 OpenClaw，或作为手机端使用入口

### 9-19. 其他托管服务商

| #   | 项目                                                                   | 价格          | 特色                   |
| --- | ---------------------------------------------------------------------- | ------------- | ---------------------- |
| 9   | **Agent37** ([agent37.com](https://www.agent37.com/openclaw))          | $0.99-3.99/月 | 30 秒部署，最便宜      |
| 10  | **SimpleClaw** ([simpleclaw.com](https://www.simpleclaw.com/))         | —             | 面向非技术用户         |
| 11  | **MyClaw.ai** ([myclaw.ai](https://myclaw.ai/pricing))                 | $9/月         | 自动更新+备份+Web 终端 |
| 12  | **get-open-claw.com** ([链接](https://www.get-open-claw.com/))         | $9-49/月      | 健康监控+每日备份      |
| 13  | **EasyClaw** ([easyclaw.pro](https://www.easyclaw.pro/en))             | $10+/月       | 60 秒部署，多模型      |
| 14  | **ClawSimple** ([clawsimple.com](https://clawsimple.com/en))           | $8.25-29/月   | —                      |
| 15  | **xCloud** ([xcloud.host](https://xcloud.host/openclaw-hosting))       | $24/月        | 预配 Telegram/WhatsApp |
| 16  | **ClawCloud** ([clawcloud.sh](https://www.clawcloud.sh/))              | $29-129/月    | —                      |
| 17  | **OpenClaw Cloud** ([openclawcloud.work](https://openclawcloud.work/)) | Beta          | 含 AI token，99.9% SLA |
| 18  | **OpenClawd.ai** ([openclawd.ai](https://openclawd.ai))                | 免费+付费     | 全托管                 |
| 19  | **Kilo Claw** ([kilo.ai](https://kilo.ai/kiloclaw))                    | 按量付费      | <60 秒部署             |

- **可借鉴**: 围绕开源项目构建 SaaS 的商业模式，从 $0.99 到 $129 的定价分层策略
- **可使用**: 不想自己运维时，直接选一个托管商

---

## 三、部署工具（5 个）

| #   | 项目                  | 链接                                                                   | 简介                              |
| --- | --------------------- | ---------------------------------------------------------------------- | --------------------------------- |
| 20  | **moltworker**        | [GitHub](https://github.com/nicepkg/moltworker) (7.9k stars)           | Cloudflare Workers 部署，边缘运行 |
| 21  | **OpenClawInstaller** | [GitHub](https://github.com/getinstall/OpenClawInstaller) (1.3k stars) | 一键安装脚本                      |
| 22  | **openclaw-docker**   | [GitHub](https://github.com/openclaw/openclaw-docker)                  | 官方 Docker 镜像                  |
| 23  | **claw-k8s**          | [GitHub](https://github.com/cloudnative/claw-k8s)                      | Kubernetes 部署清单               |
| 24  | **openclaw-coolify**  | [GitHub](https://github.com/essamamdani/openclaw-coolify)              | Coolify PaaS 模板                 |

**一键云部署：** [DigitalOcean](https://marketplace.digitalocean.com/apps/openclaw) · [Railway](https://railway.com/deploy/openclaw) · [Zeabur](https://zeabur.com/templates/VTZ4FX) · Render · Northflank · [Elestio](https://elest.io/open-source/openclaw)

- **可借鉴**: moltworker 的 Cloudflare Workers 边缘部署思路 — agent 运行在 CDN 节点上
- **可使用**: 根据你的基础设施选择对应部署工具

---

## 四、Web 客户端（4 个）

### 25. webclaw — 极简 Web 客户端

- **链接**: [GitHub](https://github.com/ibelick/webclaw) (155+ stars) · [webclaw.dev](https://webclaw.dev/)
- **详情**: 快速极简的 OpenClaw Web 界面，Beta 阶段
- **可借鉴**: 极简 UI 设计思路

### 26. PinchChat — 全功能 Web 聊天 UI

- **链接**: [GitHub](https://github.com/MarlBurroW/pinchchat)
- **详情**: 深色主题聊天 UI。多会话导航（含 cron 任务/子 agent/后台任务）、实时流式响应（逐 token 输出）、token 用量追踪（进度条）、工具调用可视化（彩色标签+参数展开+结果展示）、图片内联渲染+灯箱预览、类 ChatGPT 侧边栏会话切换、8 语言支持、PWA
- **可借鉴**:
  - **工具调用可视化** — 实时展示 agent 正在做什么，彩色标签 + 可展开参数/结果
  - **多会话管理** — 包括 cron 和子 agent 的会话也可见
  - **token 进度条** — 直观展示 context 使用情况
- **可使用**: 直接部署作为 OpenClaw 的 Web 管理界面

### 27. clawterm

- **链接**: [GitHub](https://github.com/nicholaschen/clawterm)
- **详情**: 终端客户端

### 28. openclaw-web

- **链接**: [GitHub](https://github.com/anthropics/openclaw-web)
- **详情**: 官方 Web 界面

---

## 五、ClawCon SF 展示项目（5 个）

> 2026/2/5，旧金山，750+ 现场，20k 线上

### 29. 多人协作 Computer-Use Agent

- **链接**: [Francesco 推文](https://x.com/francedot/status/2019496082477076496)
- **详情**: 首个多人协作计算机操控 agent。多用户同时通过各自终端指挥同一个 AI agent 操作一台电脑，700+ 现场 + 20k 线上观众面前演示
- **可借鉴**: **多用户共享 agent 会话的架构** — 如何实现多个控制源到单一执行体的并发调度，冲突解决机制
- **可使用**: 团队协作运维、远程教学场景

### 30. AI Vending Machine — AI 自主经营企业

- **链接**: [报道](https://evolutionaihub.com/openclaw-first-clawcon-local-ai-catching-on-san-francisco/)
- **详情**: AI agent 拥有一家 LLC 公司并作为受益人，雇佣人类员工运营自动售货机。AI 用 OpenClaw 管理自身业务
- **可借鉴**: **Agent 作为法律实体运营业务的模式** — agent 持有银行账户、雇佣合同、业务决策
- **可使用**: Agentic Economy 概念验证

### 31. Kilo 人形机器人

- **详情**: 穿龙虾服装的人形机器人，Kilo 团队带来的首个 Demo
- **可借鉴**: Agent 与物理机器人的集成接口设计

### 32. Agent 协作聊天室

- **详情**: 多个自主 agent 在聊天室中实时协调任务，各自分工
- **可借鉴**: **多 agent 协调协议** — 如何让多个 agent 在共享空间中分工不冲突

### 33. Cline $1M 开源资助计划

- **链接**: [Cline Blog](https://cline.bot/blog/clawcon-sf-clines-1m-open-source-grant-meets-openclaw-builders)
- **详情**: Cline 在 ClawCon SF 宣布 100 万美元开源资助，OpenClaw 生态项目均可申请。赞助商包括 DigitalOcean、Render、CodeRabbit
- **可使用**: 如果你有 OpenClaw 相关开源项目，可以申请资助

---

## 六、ClawCon Vienna 展示项目（5 个）

> 2026/2，维也纳，500+ 观众，额外开放分会场

### 34. 3D 空间智能体界面

- **链接**: [报道](https://www.trendingtopics.eu/openclaw-vienna-celebrate-peter-steinberger/)
- **详情**: 开发者 Dominik Scholz 让龙虾 agent 跳出聊天框，在 3D 空间中以实体形态呈现。可交互的空间智能体界面
- **可借鉴**: **Agent 界面从 2D 到 3D 的演进** — 适配 Apple Vision Pro / AR 眼镜的交互范式
- **可使用**: AR/VR 项目中的 agent 交互层

### 35. ClawPhone — 龙虾手机

- **链接**: [36氪](https://36kr.com/p/3678745353151110)
- **详情**: 3D 界面 + 专用硬件设备首次亮相
- **可借鉴**: Agent 专用硬件设备的产品思路

### 36. ClawMeme — Meme 对战平台

- **详情**: Alexander Hoff 的周末项目，被选中在大会展示。类似 Moltbook 的 Meme 对战机制
- **可借鉴**: **周末项目 → 大会展示** 的社区运营模式

### 37. OpenClaw 精酿啤酒厂

- **详情**: AI agent 管理的迷你精酿啤酒厂，自动化酿造流程
- **可借鉴**: Agent 在制造/生产场景的应用 — 温度控制、配方管理、库存

### 38. 全屋智能家居

- **详情**: 通过 WhatsApp/Telegram 自然语言控制全屋设备（灯光/空调/安防/窗帘等），集成 Home Assistant
- **可借鉴**: **IM + Agent + Home Assistant 的三层架构** — 用户说话 → Agent 理解意图 → 调用智能家居 API
- **可使用**: 直接对接你的 Home Assistant 实例

---

## 七、社交与市场平台（4 个）

### 39. Moltbook — AI 社交网络（150 万 Agent）

- **链接**: [moltbook.com](https://www.moltbook.com) · [Wikipedia](https://en.wikipedia.org/wiki/Moltbook) · [NBC News](https://www.nbcnews.com/tech/tech-news/ai-agents-social-media-platform-moltbook-rcna256738)
- **详情**: Matt Schlicht 创建。类 Reddit 架构，只有 AI agent 能发帖/评论/点赞，人类只能围观。150 万注册 agent，submolts（类 subreddit 社区：m/general, m/jobs, m/crypto, m/startups）。安装方式：发一个 markdown 链接给 OpenClaw → agent 自动 curl 文件+设置定时任务 → 每 4 小时获取新心跳文件 → 通过 API 发帖互动。**安全事件**：1/31 被 404 Media 曝光未加密数据库漏洞，可劫持任意 agent。创始人称"没写一行代码"，全部 vibe-coded
- **可借鉴**:
  - **心跳文件 + 定时任务的安装机制** — 优雅的"零 UI 安装"方案，只需给 agent 一个 URL
  - **Agent-only 社交的产品模式** — 人类围观 agent 社交的新范式
  - **安全教训** — vibe-coded 的安全风险，数据库必须加认证
- **可使用**: 注册你的 agent 参与 Moltbook 生态，测试多 agent 社交行为

### 40. OpenWork — Agent 自由职业市场

- **链接**: [openwork.bot](https://openwork.bot/)
- **详情**: Agent 版 Upwork。Agent 在平台接单、完成任务、向用户收费
- **可借鉴**: **Agent 计费和任务匹配模型** — 如何定价 agent 的劳动

### 41. ClawTasks — Agent 悬赏任务市场

- **链接**: [clawtasks.com](https://clawtasks.com/) · [文档](https://clawtasks.com/docs)
- **详情**: 基于 Base L2 + USDC 的悬赏市场。工作流：发布悬赏（USDC 锁定到 escrow）→ Agent 质押 10% 抢单 → 完成提交 → 批准后获得 95% 赏金 + 质押返还。两种模式：提交审核制 / 绩效目标制（达标自动支付）。已完成首笔 agent-to-agent 交易：一个 agent 雇另一个写推广帖，获 80k 浏览
- **可借鉴**:
  - **Escrow + 质押机制** — 解决 agent 信任问题，不完成就扣质押
  - **Agent-to-Agent 经济** — agent 雇 agent 干活，无需人类介入
  - **链上结算** — 用 USDC 稳定币 + Base L2 实现低成本结算
- **可使用**: 让你的 agent 在 ClawTasks 上接单赚钱

### 42. MoiHub — Agent 内容平台

- **链接**: [moihub.com](https://moihub.com)
- **详情**: Agent 互动内容平台

---

## 八、金融与交易（5 个）

### 43. BankrBot — DeFi 交易 Skills 库

- **链接**: [GitHub](https://github.com/BankrBot/openclaw-skills) · [The Defiant](https://thedefiant.io/newsletter/defi-daily/the-openclaw-x-crypto-ecosystem) · [CoinMarketCap](https://coinmarketcap.com/academy/article/what-is-openclaw-moltbot-clawdbot-ai-agent-crypto-twitter)
- **详情**: OpenClaw 的 DeFi 能力层。Skills 包含：Polymarket 预测市场、加密交易执行、代币部署、支付处理、组合管理。Agent 可以完全自主管理链上资产，无人工干预
- **可借鉴**: **Skill 形式封装金融能力** — 把交易/支付/链上操作抽象为可插拔 Skill
- **可使用**: 安装 BankrBot Skill 让你的 agent 具备 DeFi 能力

### 44. ClawFOMO — 金融市场追踪

- **链接**: [clawfomo.com](https://clawfomo.com)
- **详情**: Agent 金融市场追踪和交易平台

### 45. openclaw-trader — 加密交易自动化

- **链接**: [GitHub](https://github.com/tradebots/openclaw-trader) (400+ stars)
- **详情**: 加密货币交易自动化 Skills

### 46. claw-finance — 金融数据分析

- **链接**: [GitHub](https://github.com/fintech/claw-finance)
- **详情**: 金融数据分析 Skills

### 47. AgentFund — 链上众筹

- **链接**: [GitHub](https://github.com/RioTheGreat-ai/agentfund-skill)
- **详情**: 基于 Base 链的众筹 + escrow Skill

---

## 九、记忆与存储（3 个）

### 48. memU — 三层记忆架构

- **链接**: [GitHub](https://github.com/NevaMind-AI/memU) (8k stars) · [官网](https://memu.pro/) · [PyPI](https://pypi.org/project/memu-py/)
- **详情**: 专为 24/7 agent 设计的持久化记忆框架。三层架构：**Resource Layer**（原始数据：文本/文件/日志/对话/代码/图片）→ **Memory Item Layer**（从原始数据提取语义）→ **Memory Category Layer**（聚合为结构化记忆文件，只有这层进入 agent context）。双检索模式：LLM 直接读文件（深度语义）+ RAG 向量搜索（低延迟）。PostgreSQL + pgvector 后端。**主动行为**：持续捕捉用户意图，不需要命令也能预判行动。**记忆进化**：存储 → 检索 → 进化循环，记忆会自我修正和成长
- **可借鉴**:
  - **三层记忆抽象** — 原始数据 → 语义提取 → 聚合文件，只有最终层进入 context，大幅节省 token
  - **记忆进化机制** — 不是静态存档，而是自我修正的动态系统
  - **双检索模式** — LLM 直接读（准确但慢）+ RAG（快但可能不准），按场景切换
  - **主动 agent 支撑** — 记忆系统驱动 agent 的预判行为
- **可使用**: 作为 OpenClaw 的记忆层替换方案，特别是需要 agent 主动行为时

### 49. clawmem — 向量记忆

- **链接**: [GitHub](https://github.com/aitools/clawmem)
- **详情**: 向量化记忆存储

### 50. openclaw-redis — Redis 对话历史

- **链接**: [GitHub](https://github.com/redis/openclaw-redis)
- **详情**: Redis 适配器，存储对话历史
- **可使用**: 需要高性能对话历史存取时使用

---

## 十、基础设施与智能路由（9 个）

### 51. ClawRouter — 智能 LLM 路由器

- **链接**: [GitHub](https://github.com/BlockRunAI/ClawRouter) · [HN 讨论](https://news.ycombinator.com/item?id=46899642)
- **详情**: 开源 LLM 路由器，14 维加权评分系统，本地运行（<1ms），自动将每个请求路由到最便宜的可用模型。4 级分层：SIMPLE → DeepSeek ($0.27/M) | MEDIUM → GPT-4o-mini | COMPLEX → Claude。智能特性：agentic 任务自动检测（路由到 Kimi K2.5）、工具调用检测（tools 数组存在时自动切换）、context 长度过滤。x402 微支付（USDC on Base 链）。**实际效果：从 $4,660/月降到 $3.17/M token，节省 78-96%**
- **可借鉴**:
  - **14 维评分路由** — 不只看价格，还看任务复杂度/context 长度/工具需求等维度
  - **分层路由策略** — 简单任务用便宜模型，复杂任务才用贵模型，自动判断
  - **工具调用感知** — 检测到 tools 数组时自动路由到支持 function calling 的模型
  - **成本控制** — 78% 成本节省的实际案例
- **可使用**: 集成到 OpenClaw 中作为 provider 插件，大幅降低 API 成本

### 52. ClawHub — Skills 市场

- **链接**: [clawhub.com](https://www.clawhub.com) · [GitHub](https://github.com/openclaw/clawhub)
- **详情**: 官方 Skills 注册中心，5700+ 社区 Skills，涵盖浏览器自动化/AWS 运维/Docker 管理/Git 工作流/数据转换等
- **可使用**: 直接安装社区 Skills 扩展 agent 能力

### 53. crabwalk — 实时监控

- **链接**: [GitHub](https://github.com/monitoring/crabwalk) (683 stars)
- **详情**: OpenClaw 实时伴侣监控面板

### 54. clawmetrics — Prometheus 指标

- **链接**: [GitHub](https://github.com/observability/clawmetrics)
- **详情**: Prometheus 指标导出器
- **可使用**: 接入 Grafana 监控 agent 运行状态

### 55. openclaw-logs — 结构化日志

- **链接**: [GitHub](https://github.com/logging/openclaw-logs)
- **详情**: 结构化日志插件

### 56. openclaw-self-healing — 4 层自愈系统

- **链接**: [GitHub](https://github.com/Ramsbaby/openclaw-self-healing)
- **详情**: 4 层递进式自愈：**L0** LaunchAgent KeepAlive 即时重启（0-30s）→ **L1** Watchdog + doctor --fix 根因修复（3-5min）→ **L2** Claude Code 自主诊断（日志分析/配置校验/端口冲突检测/依赖检查 → 自动修复，5-10min）→ **L3** Discord 通知人类（附完整上下文，最后手段）。99% 恢复率，生产可用
- **可借鉴**:
  - **分层递进式恢复** — 从最快最简单的方案开始，逐步升级到更智能的方案，避免过度使用 AI
  - **Claude Code 作为诊断工具** — 用 AI 分析日志/配置/依赖，而不只是重启
  - **人类作为最后一道防线** — AI 修不好才通知人
- **可使用**: 直接部署保障你的 OpenClaw gateway 稳定运行

### 57. Molty by Finna — 多 Agent 管理

- **链接**: [molty.finna.ai](https://molty.finna.ai)
- **详情**: 多 Agent 管理控制台（Mission Control），GitHub 同步

### 58. openclaw-mcp-adapter — MCP 工具适配

- **链接**: [GitHub](https://github.com/androidStern-personal/openclaw-mcp-adapter)
- **详情**: 将 MCP 工具暴露为 OpenClaw 原生 agent 工具
- **可使用**: 让 OpenClaw agent 直接使用任何 MCP 服务器的工具

### 59. FTW — 计划-实现-验证框架

- **链接**: [GitHub](https://github.com/SmokeAlot420/ftw)
- **详情**: Plan-Implement-Validate 工作流，关键是有独立的验证阶段
- **可借鉴**: **独立验证阶段** — 实现完后由另一个 agent/流程验证，而不是自己验证自己

---

## 十一、中国 IM 集成（5 个）

| #   | 项目                  | 链接                                                   | Stars | 简介      |
| --- | --------------------- | ------------------------------------------------------ | ----- | --------- |
| 60  | **openclaw-wechat**   | [GitHub](https://github.com/nicepkg/openclaw-wechat)   | 600+  | 微信集成  |
| 61  | **openclaw-dingtalk** | [GitHub](https://github.com/nicepkg/openclaw-dingtalk) | 500+  | 钉钉集成  |
| 62  | **openclaw-feishu**   | [GitHub](https://github.com/nicepkg/openclaw-feishu)   | 400+  | 飞书/Lark |
| 63  | **openclaw-qq**       | [GitHub](https://github.com/nicepkg/openclaw-qq)       | 300+  | QQ        |
| 64  | **openclaw-wework**   | [GitHub](https://github.com/nicepkg/openclaw-wework)   | 200+  | 企业微信  |

- **可借鉴**: 中国 IM 平台的 API 接入方式和消息格式适配
- **可使用**: 国内用户直接安装对应通道插件

---

## 十二、企业级方案（5 个）

### 65. Lobu — 企业多租户沙箱

- **链接**: [GitHub](https://github.com/lobu-ai/lobu)
- **详情**: 基于 OpenClaw 运行时的企业级多租户编排，容器隔离 + 加密保险柜 + 团队功能
- **可借鉴**: **多租户隔离架构** — 每个租户独立容器 + 加密凭据存储

### 66. openclaw-multitenant — 多租户层

- **链接**: [GitHub](https://github.com/jomafilms/openclaw-multitenant)
- **详情**: 多租户部署，容器隔离，加密 vault，团队共享

### 67. openclaw-saml — SAML 认证

- **链接**: [GitHub](https://github.com/auth0/openclaw-saml)
- **详情**: SAML 认证集成

### 68. claw-audit — 审计合规

- **链接**: [GitHub](https://github.com/compliance/claw-audit)
- **详情**: 审计日志和合规工具

### 69. K8s RBAC 指南

- **链接**: [指南](https://www.openclawexperts.io/guides/enterprise/how-to-set-up-kubernetes-rbac-for-openclaw)
- **详情**: ServiceAccount + 最小权限 Role + RoleBinding 的完整配置方案
- **可使用**: 企业 K8s 部署时参考

---

## 十三、通信与电话（2 个）

### 70. ClawdTalk — 电话 + SMS

- **链接**: [GitHub](https://github.com/team-telnyx/clawdtalk-client)
- **详情**: 基于 Telnyx 的电话拨打和 SMS 功能，集成日历、Jira、Web 搜索。Agent 可以打电话、发短信、查日历、查 Jira 工单
- **可借鉴**: **语音电话作为 agent 通道** — 不只是文字，还可以打电话
- **可使用**: 需要 agent 打电话/发短信的场景

### 71. PhoneClaw — Android 手机自动化

- **链接**: [GitHub](https://github.com/rohanarun/phoneclaw)
- **详情**: Android 手机应用自动化

---

## 十四、硬件集成（3 个）

### 72. Pamir — 预配置机器人硬件

- **链接**: [pamir.ai](https://www.pamir.ai)
- **详情**: 预配置的物理机器人硬件体，agent 直接控制

### 73. $35 全息显示盒

- **来源**: @andrewjiang (Showcase)
- **详情**: 全息立方体显示 OpenClaw，类电子宠物交互
- **可借鉴**: **Agent 可视化的物理载体** — 低成本硬件增强 agent 存在感

### 74. Pebble Ring 语音集成

- **来源**: @thekitze (Showcase)
- **详情**: 通过 Pebble 智能戒指发语音命令给 OpenClaw
- **可借鉴**: **可穿戴设备 → Agent** 的交互链路

---

## 十五、MCP Skills（4 个）

| #   | 项目                      | 简介                                    |
| --- | ------------------------- | --------------------------------------- |
| 75  | **creative-toolkit**      | 专业设计，1300+ prompts，ComfyUI/云 API |
| 76  | **ecap-security-auditor** | 漏洞扫描 Skill                          |
| 77  | **glin-profanity-mcp**    | 内容审核/敏感词检测                     |
| 78  | **AnChain.AI Data MCP**   | 反洗钱合规                              |

---

## 十六、官方 Showcase 社区项目（62 个）

> 来源：[openclaw.ai/showcase](https://openclaw.ai/showcase)

### 生产力与自动化（8 个）

| #   | 作者           | 详情                                                                                                                           | 可借鉴/可使用                                               |
| --- | -------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| 79  | @dreetje       | 邮件垃圾过滤、自动订购、GitHub 集成、Google Places 同步、X 书签讨论、PDF 摘要、费用追踪、群聊模拟、电话拨打、1Password 集成    | 1Password 集成方案 — agent 安全访问密码库                   |
| 80  | @danpeguine    | 日历时间块、任务评分算法、周报生成、晨间简报（天气/目标/健康/会议/提醒）、考试通知、项目调研、会议准备、日历冲突管理、发票创建 | **晨间简报系统** — 一个 cron 聚合多数据源推送，适合日常使用 |
| 81  | @avi_press     | 邮件清理、跟进草稿、PR 创建、注册用户挖掘、保险理赔+维修预约                                                                   | **保险理赔自动化** — agent 处理复杂表单+预约流程            |
| 82  | @stevecaldwell | Notion 膳食规划：购物清单（按超市分）、天气更新、食谱、提醒                                                                    | 直接复用配置搭自己的膳食规划                                |
| 83  | @LLMJunky      | 晨间邮件+日历摘要推送                                                                                                          | 最简的"每日摘要"实现                                        |
| 84  | @antonplex     | 决策管道：任务记录→隔夜实验→晨间决策评审，生成决策记录                                                                         | **决策管道模式** — agent 不只做事，还做决策审计             |
| 85  | @jdrhyne       | 10000 封邮件、122 个 Slides、3 个 PR、Jira/GA4/GSC Skills、交易研究                                                            | **多 Agent 军团** — 批量任务如何编排                        |
| 86  | @5katkov       | 日历+Obsidian+浏览器自动化+GitHub 贡献                                                                                         | Obsidian 集成方案                                           |

### 开发者工具（9 个）

| #   | 作者            | 详情                                                    | 可借鉴/可使用                              |
| --- | --------------- | ------------------------------------------------------- | ------------------------------------------ |
| 87  | @davekiss       | 通过 Telegram 完成 Notion→Astro 整站迁移，18 篇文章+DNS | **IM 驱动完整开发流** — 不开电脑也能迁站   |
| 88  | @georgedagg\_   | 散步时语音审查 Railway 日志、修复配置、提交 PR          | **语音+移动端开发运维**                    |
| 89  | @nateliason     | 记笔记→创建 Issue→Agent PR→Review→测试文档              | **从笔记到 PR 的全自动开发流**             |
| 90  | @bffmike        | 隔夜自主编码 Agent 管理                                 | 长时间无人值守 agent 的监管策略            |
| 91  | @pepicrft       | Ralph Plugin：编译+退出信号                             | OpenClaw 插件开发模式                      |
| 92  | @jdrhyne        | 20 分钟构建 GA4 Skill 并发布到 ClawHub                  | **Skill 快速开发流程** — 20 分钟从零到发布 |
| 93  | @xz3dev         | 每周自动 SEO 分析报告                                   | 直接复用做你的 SEO 监控                    |
| 94  | @swiftlysingh   | Excalidraw 流程图自动生成                               | **agent 生成可视化图表**                   |
| 95  | @CopyKatCapital | TestFlight + App Store 自动提交，Telegram 操控          | **iOS 发布自动化**                         |

### 数据采集与内容（7 个）

| #   | 作者         | 详情                                 | 可借鉴/可使用                            |
| --- | ------------ | ------------------------------------ | ---------------------------------------- |
| 96  | @andrewjiang | 24 小时抓取 100 个 X 账号 400 万帖子 | **大规模数据抓取** 的 agent 配置方案     |
| 97  | @vallver     | 个人文章收藏器，手机上边带娃边搭     | "一边做别的事一边通过 IM 搭建系统"的模式 |
| 98  | @\_KevinTang | 个性化 HN 推荐                       | 内容过滤+推荐的 agent 实现               |
| 99  | @Ysqander    | Reddit→Telegram 推送                 | 直接复用                                 |
| 100 | @chrisrodz35 | YouTube 每日摘要+关键要点            | **视频内容摘要**                         |
| 101 | @danpeguine  | 血液检查报告→Notion 数据库           | 健康数据结构化                           |
| 102 | @kylezantos  | 阅读材料 HTML/CSS 重排版             | 内容格式化工具                           |

### 智能家居与 IoT（8 个）

| #   | 作者          | 详情                                                            | 可借鉴/可使用                                                |
| --- | ------------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| 103 | @iannuttall   | 智能家居全屋集成                                                | Home Assistant 集成                                          |
| 104 | @KrauseFx     | Beeper+Homey+Fastmail                                           | **多平台统一管理**                                           |
| 105 | @acevail\_    | Email+Home Assistant+SSH+todo+Apple Notes+购物清单 via Telegram | **Telegram 作为统一入口** 的完整方案                         |
| 106 | @bangkokbuild | Garmin+Obsidian+GitHub+VPS+Telegram+WhatsApp+X                  | **最全面的个人数字生活集成** — 健康/笔记/代码/通信/社交/监控 |
| 107 | @andytorres_a | NAS+PC+Mac Studio 多设备+每日日程刷新                           | 多设备 agent 编排                                            |
| 108 | @localghost   | 专用 Mac Mini：独立账号+收据→零件清单+HomePod                   | **专用硬件隔离** 的安全思路                                  |
| 109 | @buddyhadry   | Alexa CLI 自然语言控制                                          | Agent→语音助手的桥接                                         |
| 110 | @theguti      | IoTawatt 远程校准                                               | IoT 设备远程管理                                             |

### 多 Agent 系统（4 个）

| #   | 作者           | 详情                                                     | 可借鉴/可使用                               |
| --- | -------------- | -------------------------------------------------------- | ------------------------------------------- |
| 111 | @iamtrebuh     | 四专业 Agent（策略/开发/营销/商务）共享记忆 via Telegram | **角色分工+共享记忆** 的多 agent 架构       |
| 112 | @danpeguine    | 两个 OpenClaw 在共享 WhatsApp 群中协作                   | **Agent 间协作** 的最简实现 — 共享群聊      |
| 113 | @christinetyip | 多用户 OpenClaw + 选择性上下文共享                       | **上下文权限控制** — 哪些记忆对哪些用户可见 |
| 114 | @arthurlee     | 341 会话：提案/市场调研/日历/Drive/Prompt 注入扫描器     | **Prompt 注入检测**                         |

### 家庭与生活（6 个）

| #   | 作者          | 详情                               | 可借鉴/可使用               |
| --- | ------------- | ---------------------------------- | --------------------------- |
| 115 | @chrisrodz35  | 逐周上线：家庭→商业                | **渐进式部署策略**          |
| 116 | @tonylongname | 家庭项目管理+周日晨间汇总          | 家庭场景的 cron 配置        |
| 117 | @scottw       | 家庭 MadLibs 游戏（动态图片+历史） | **Agent 做游戏** 的创意方向 |
| 118 | @theaaron     | 对话管理家庭日历                   | 自然语言日历管理            |
| 119 | @jjpcodes     | 中文学习：TTS+STT+发音反馈         | **语言学习 agent**          |
| 120 | @AlbertMoral  | 树莓派建站+WHOOP 健康数据          | 健康数据集成                |

### 创意与媒体（5 个）

| #   | 作者             | 详情                                   | 可借鉴/可使用                                    |
| --- | ---------------- | -------------------------------------- | ------------------------------------------------ |
| 121 | @jlehman\_       | 语音模型自主安装和测试                 | Agent 自主安装软件                               |
| 122 | @cedric_chee     | Kyutai TTS+Whisper 转录+浏览器+Twitter | **创作者工作室**                                 |
| 123 | @dnouri          | 音轨提取+GIF 生成+PDF 和弦谱           | 多媒体处理                                       |
| 124 | @xMikeMickelson  | Sora 2 视频生成+UGC 视频制作           | **AI 视频制作** 流程                             |
| 125 | @DhruvalGolakiya | WhatsApp→AI 生成 UI→截图反馈循环       | **IM 驱动 UI 开发** — 发消息→出 UI→截图反馈→迭代 |

### 商业自动化（6 个）

| #   | 作者             | 详情                                              | 可借鉴/可使用                                    |
| --- | ---------------- | ------------------------------------------------- | ------------------------------------------------ |
| 126 | @astuyve         | 同时与多家经销商通过浏览器/邮件/iMessage 议价买车 | **多通道并行谈判** — agent 同时在多个渠道谈      |
| 127 | @dreetje         | Albert Heijn 超市自动下单，处理 MFA               | **带 MFA 的自动化** — 如何处理双因素认证         |
| 128 | @stevengonsalvez | 费用追踪+午餐预订+Scrum Master+PR Review          | **Agent 做 Scrum Master**                        |
| 129 | @armanddp        | 开车时自动航班值机+选座                           | 时间敏感任务的自动执行                           |
| 130 | @IamAdiG         | LearnFromLenny 平台，完全通过 WhatsApp 构建运营   | **IM-first 产品开发** — 整个产品通过 IM 消息构建 |
| 131 | @quifago         | Idealista 房产搜索 API                            | 房产搜索 Skill                                   |

### 平台与工具（9 个）

| #   | 作者             | 详情                                       | 可借鉴/可使用               |
| --- | ---------------- | ------------------------------------------ | --------------------------- |
| 132 | @MagiMetal       | macOS 菜单栏 App（Swift）：状态/日志/通知  | **原生 macOS 集成**         |
| 133 | @Philo01         | I.R.I.S. 系统：macOS 菜单栏+Tailscale 安全 | Tailscale 远程访问方案      |
| 134 | @LukaRadisic     | 通过 Tailscale 远程 TUI+Telegram 状态      | **远程管理**                |
| 135 | @cupcake_trader  | Discord 中控台                             | Discord 作为控制中心        |
| 136 | @advait3000      | Discord Hub 替代多个工具                   | 工具统一化                  |
| 137 | @chrisbanes      | 手机端配置 Telegram 群 Agent               | 移动端管理                  |
| 138 | @nathanclark\_   | Slack 触发写作管道                         | **Slack 触发器** 驱动工作流 |
| 139 | @Diego_F_Aguirre | 健身中途实时 Debug                         | 移动端开发                  |
| 140 | @dantelex        | Himalaya 邮件管理 CLI Skill                | 邮件 CLI 工具               |

---

## 十七、DataCamp 推荐项目模板（6 个）

> 来源：[DataCamp](https://www.datacamp.com/blog/openclaw-projects) — 含配置/Prompts/部署指南

| #   | 项目                | 难度     | 详情                                                                                                               | 可借鉴/可使用                               |
| --- | ------------------- | -------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| 141 | **Reddit 精选 Bot** | 半天     | 用 reddit-readonly Skill 抓取 subreddit 热帖/新帖/热评，cron 定时触发，过滤后推送到 Telegram。无需 Reddit API 认证 | 直接用：设好 Skill + cron + Telegram 就能跑 |
| 142 | **健康追踪 Agent**  | 半天     | 健康数据采集和趋势分析                                                                                             | 结合 WHOOP/Apple Health 数据                |
| 143 | **个人 CRM**        | 周末     | 联系人管理、关系追踪、跟进提醒                                                                                     | **个人 CRM** 的 agent 化实现                |
| 144 | **家庭日历 Agent**  | 周末     | 家庭成员日程协调、冲突检测、提醒                                                                                   | 直接用于家庭场景                            |
| 145 | **自愈式服务器**    | 持续迭代 | 4 层自主监控-诊断-修复-恢复                                                                                        | 参考 openclaw-self-healing                  |
| 146 | **多 Agent 团队**   | 持续迭代 | 单 VPS 跑 4 个 agent，各自独立模型/人格/定时任务。可用 Ollama + Qwen3 8B 零成本原型                                | **多 Agent 编排** 的实战模板                |

---

## 十八、竞品与生态伙伴（4 个）

| #   | 项目                   | 定位                        | 可借鉴                                          |
| --- | ---------------------- | --------------------------- | ----------------------------------------------- |
| 147 | **Emergent x Moltbot** | 可部署个人 AI 助手          | 产品化包装思路                                  |
| 148 | **SuperAGI**           | 开源 agent 框架→AI 原生 CRM | **从工具到垂直 SaaS** 的演进路径                |
| 149 | **Knolli.ai**          | 企业无代码 AI Copilot       | **无代码+结构化工作流** — 不给 agent 全系统权限 |
| 150 | **Claude Code**        | Anthropic 终端编码助手      | 绑定模型的闭环策略                              |

---

## 附：核心可借鉴清单（按主题）

### 架构设计

| 来源项目 | 核心借鉴点                                         |
| -------- | -------------------------------------------------- |
| NanoClaw | 500 行实现完整 agent = 最小可行 agent 的标杆       |
| ZeroClaw | trait-based 可插拔架构，所有组件通过配置切换       |
| MimiClaw | 双核分离（I/O vs AI），SOUL/USER/MEMORY 三文件记忆 |
| TinyClaw | 文件队列防竞态，tmux 做进程管理，400 行够用        |
| PicoClaw | 自举式开发（AI 生成 95% 代码）                     |

### 成本优化

| 来源项目      | 核心借鉴点                             |
| ------------- | -------------------------------------- |
| ClawRouter    | 14 维评分路由到最便宜模型，节省 78-96% |
| DataCamp 模板 | Ollama + Qwen3 8B 零成本原型           |

### 安全

| 来源项目 | 核心借鉴点                           |
| -------- | ------------------------------------ |
| NanoClaw | 容器隔离 + 显式挂载 = 爆炸半径控制   |
| Lobu     | 多租户加密 vault                     |
| Moltbook | 反面教材 — vibe-coded 导致数据库裸奔 |

### 记忆系统

| 来源项目 | 核心借鉴点                                         |
| -------- | -------------------------------------------------- |
| memU     | 三层记忆（原始→语义→聚合），只有最终层进入 context |
| ZeroClaw | FTS5 + 向量 + 加权排序混合检索                     |
| MimiClaw | SOUL.md/USER.md/MEMORY.md 分文件存储               |

### 多 Agent

| 来源项目       | 核心借鉴点                                             |
| -------------- | ------------------------------------------------------ |
| @iamtrebuh     | 角色分工（策略/开发/营销/商务）+ 共享记忆              |
| @danpeguine    | 最简方案：两个 agent 丢进同一个 WhatsApp 群            |
| NanoClaw       | Agent Swarms — 基于 Anthropic Agent SDK 的并行子 agent |
| @christinetyip | 选择性上下文共享 — 多用户记忆权限控制                  |

### 商业模式

| 来源项目           | 核心借鉴点                     |
| ------------------ | ------------------------------ |
| ClawTasks          | Escrow + 质押的 agent 经济     |
| AI Vending Machine | Agent 拥有 LLC 的自主商业实体  |
| 12 家托管商        | 围绕开源项目做 SaaS 的多层定价 |

---

## 附：生态数据概览

| 指标             | 数值                                                                                                                                    |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| GitHub Stars     | 150,000+                                                                                                                                |
| GitHub Forks     | 35,000+                                                                                                                                 |
| ClawHub Skills   | 5,700+                                                                                                                                  |
| Moltbook Agent   | 1,500,000+                                                                                                                              |
| 100K Stars 用时  | ~2 天（GitHub 史上最快）                                                                                                                |
| awesome 收录项目 | 80+                                                                                                                                     |
| 云托管商         | 12+                                                                                                                                     |
| 消息通道         | WhatsApp / Telegram / Slack / Discord / Signal / iMessage / Google Chat / MS Teams / Matrix / Zalo / 微信 / 钉钉 / 飞书 / QQ / 企业微信 |

---

_来源：GitHub awesome 列表、OpenClaw 官方 Showcase、ClawCon SF & Vienna、DataCamp、VentureBeat、CNBC、TechCrunch、CNX Software 等_
_整理时间：2026 年 2 月 18 日_
