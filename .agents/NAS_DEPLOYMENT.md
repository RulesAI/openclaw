# NAS (ZSpace) OpenClaw 部署文档

> 本文档记录 NAS 上 OpenClaw 容器的完整部署架构，供日常运维和排障参考。
> 最后更新：2026-03-03

## 1. 宿主机信息

| 项目     | 值                                        |
| -------- | ----------------------------------------- |
| 设备     | ZSpace NAS (Z4-B37M)                      |
| OS       | ZOS (GNU/Linux 5.8.18-z4-generic+ x86_64) |
| 内网 IP  | `192.168.3.185`                           |
| SSH 端口 | `10000`                                   |
| SSH 用户 | `13911033691`                             |
| SSH 密码 | `Simon2028`                               |
| SSH 认证 | 密码认证（非公钥），需 `sshpass`          |
| 总内存   | 7.6 GiB                                   |

### SSH 访问方式

```bash
# 方式 1：sshpass 直接登录
sshpass -p "Simon2028" ssh -p 10000 13911033691@192.168.3.185

# 方式 2：sshpass SCP 传文件
sshpass -p "Simon2028" scp -P 10000 <file> 13911033691@192.168.3.185:/tmp/

# 方式 3：expect 脚本（自动 sudo）
~/.ssh/zspace-ssh "<command>"
```

## 2. 容器架构

### 单容器部署

所有 Agent 运行在**同一个容器** `openclaw-gateway` 中，由单个 gateway 进程管理。

```
NAS (ZSpace, 192.168.3.185)
└── Docker: openclaw-gateway (单容器, 单进程)
    ├── 8 个 Agent（通过 agents.list 定义）
    ├── 8 个 Telegram 通道 (7 启用 + 1 禁用)
    └── ~21 个 Cron 定时任务
```

### 容器基本信息

| 项目      | 值                                                                     |
| --------- | ---------------------------------------------------------------------- |
| 容器名    | `openclaw-gateway`                                                     |
| 容器 ID   | `c6fbaffd38f7`                                                         |
| 镜像      | `openclaw:local-amd64`（本地构建，非 Docker Hub）                      |
| 创建时间  | 2026-02-25                                                             |
| 运行用户  | `node`                                                                 |
| 工作目录  | `/app`                                                                 |
| 入口命令  | `docker-entrypoint.sh node dist/index.js gateway --allow-unconfigured` |
| Node 版本 | v22.22.0                                                               |
| 重启策略  | `unless-stopped`                                                       |
| Init      | `true`（使用 tini 管理子进程）                                         |

### 挂载卷（Bind Mounts）

| 宿主机路径                          | 容器路径                         | 读写 | 说明                                                 |
| ----------------------------------- | -------------------------------- | ---- | ---------------------------------------------------- |
| `/data_ZR5D8EL4/openclaw/config`    | `/home/node/.openclaw`           | RW   | 主配置目录（agents、skills、sessions、config.json5） |
| `/data_ZR5D8EL4/openclaw/workspace` | `/home/node/.openclaw/workspace` | RW   | 默认工作空间                                         |

**重要路径映射：**

- 宿主机 `/data_ZR5D8EL4/openclaw/config/config.json5` = 容器 `/home/node/.openclaw/config.json5`
- 宿主机 `/data_ZR5D8EL4/openclaw/config/openclaw.json` = 容器 `/home/node/.openclaw/openclaw.json`
- 宿主机 `/data_ZR5D8EL4/openclaw/config/agents/` = 容器 `/home/node/.openclaw/agents/`
- 宿主机 `/data_ZR5D8EL4/openclaw/config/skills/` = 容器 `/home/node/.openclaw/skills/`

### 网络配置

| 网络           | 容器 IP    | 说明                            |
| -------------- | ---------- | ------------------------------- |
| `bridge`       | 172.17.0.2 | 默认桥接网络                    |
| `openclaw-net` | 172.18.0.3 | 自定义网络，连接 Clash 代理容器 |

### 端口映射

| 容器端口 | 宿主机端口 | 绑定地址     | 用途           |
| -------- | ---------- | ------------ | -------------- |
| 18789    | 18789      | 0.0.0.0 + :: | Gateway 主端口 |
| 18790    | 18790      | 0.0.0.0 + :: | 附加服务       |
| 18791    | 18791      | 0.0.0.0 + :: | 附加服务       |

### 环境变量

| 变量                   | 值                  | 说明                    |
| ---------------------- | ------------------- | ----------------------- |
| `NODE_ENV`             | `production`        | 生产模式                |
| `TZ`                   | `Asia/Shanghai`     | 时区                    |
| `HTTP_PROXY`           | `http://clash:7890` | HTTP 代理（Clash 容器） |
| `HTTPS_PROXY`          | `http://clash:7890` | HTTPS 代理              |
| `OPENCLAW_PREFER_PNPM` | `1`                 | 优先使用 pnpm           |
| `HOME`                 | `/home/node`        | 用户主目录              |

> **注意**：容器环境变量中**不包含** LLM API Key。API Key 通过 `openclaw.json` 的 `models.providers.<provider>.apiKey` 和 per-agent `auth-profiles.json` 两种方式配置。

### 安全配置（实际 Docker 层面）

| 项目           | 配置值                 | 说明                 |
| -------------- | ---------------------- | -------------------- |
| Privileged     | `false`                | 非特权               |
| ReadonlyRootfs | `false`                | 根文件系统可写       |
| Memory         | 无限制                 | 未设 cgroup 内存限制 |
| CPU            | 无限制                 | 未设 cgroup CPU 限制 |
| PidsLimit      | 无限制                 | 未设进程数限制       |
| CapDrop        | 无                     | 未移除 capabilities  |
| AppArmor       | `docker-default`       | 默认 AppArmor 策略   |
| 日志           | json-file, 单文件 20MB | 日志轮转             |

> **注意**：`config.json5` 中的 `sandbox` 配置（`readOnlyRoot: true`、`memory: 2g`、`capDrop: ["ALL"]` 等）是 OpenClaw **内部**沙箱设置（用于隔离 cron job 等），不是 Docker 容器本身的安全限制。

## 3. Agent 清单

### 全部 Agent（8 个，定义在 `openclaw.json` → `agents.list`）

| Agent            | 角色名          | 模型                              | Workspace                                       | Telegram Bot           |
| ---------------- | --------------- | --------------------------------- | ----------------------------------------------- | ---------------------- |
| `main` (default) | Main Assistant  | `dashscope/qwen-plus`             | 默认                                            | `@Simon_Main_bot`      |
| `sciai-marketer` | SCI.AI Marketer | `google/gemini-2.5-flash`         | `/home/node/.openclaw/workspace-sciai-marketer` | `@SCIAI_Marketing_bot` |
| `ops-agent`      | 阿维            | `google/gemini-2.5-flash`         | 默认                                            | `@ServerOps_AW_bot`    |
| `sciai-user-ops` | 小暖            | `google/gemini-2.5-flash`         | 默认                                            | `@UserOps_bot`         |
| `virtual-lover`  | 苏曼琳          | `xai/grok-4-1-fast-non-reasoning` | `/home/node/.openclaw/workspace-virtual-lover`  | `@Mia_Ling_bot`        |
| `movie-dev`      | Movie Agent Dev | `openai/gpt-4o`                   | `/home/node/.openclaw/workspace-movie-dev`      | `@RL_Agent_Dev_bot`    |
| `wechat-editor`  | 智链进化论      | `dashscope/qwen-plus`             | `/home/node/.openclaw/workspace-wechat-editor`  | `@EvoChain_LinX_bot`   |
| `whatsapp-agent` | 林紫涵          | `moonshot/kimi-k2.5`              | `/home/node/.openclaw/workspace-whatsapp-agent` | `@linzihan_bot` (禁用) |

> **重要**：workspace 路径必须使用容器内路径（`/home/node/...`），不能用 Mac 路径（`/Users/simon/...`），否则会报 `EACCES: permission denied, mkdir '/Users'`。

### NAS 独有 Agent（2 个）

`ops-agent`、`sciai-user-ops` — 仅在 NAS 上定义和运行。

### 已迁移到 Mac 的 Agent

`whatsapp-agent`（对应 `@linzihan_bot`）— NAS 上通道已禁用、cron 任务已全部删除。

## 4. 消息通道

NAS 专门承载 Telegram 通道，不启用 WhatsApp（WhatsApp 仅在 Mac 端运行）。

### Telegram 通道（7 个启用 + 1 个已禁用）

> Bot token 归档见 `.agents/TELEGRAM_BOTS.md`。

| 通道名称         | Bot Username           | 角色名                       | 对应 Agent       | 状态      | allowFrom    |
| ---------------- | ---------------------- | ---------------------------- | ---------------- | --------- | ------------ |
| `default`        | `@SCIAI_Marketing_bot` | 诸葛亮-首席用户增长总监      | `sciai-marketer` | ✅ 运行中 | —            |
| `simon-main`     | `@Simon_Main_bot`      | 赵子龙Draco-首席内容运营总监 | `main`           | ✅ 运行中 | `8529197605` |
| `mia`            | `@Mia_Ling_bot`        | 米亚·凌                      | `virtual-lover`  | ✅ 运行中 | `8529197605` |
| `moviedev`       | `@RL_Agent_Dev_bot`    | Agent Dev                    | `movie-dev`      | ✅ 运行中 | `8529197605` |
| `serverops`      | `@ServerOps_AW_bot`    | 阿维-首席运维总监            | `ops-agent`      | ✅ 运行中 | `8529197605` |
| `sciai-user-ops` | `@UserOps_bot`         | 小暖-首席客户运营官          | `sciai-user-ops` | ✅ 运行中 | `8529197605` |
| `wechat-editor`  | `@EvoChain_LinX_bot`   | 链语者-智链进化论-主理人     | `wechat-editor`  | ✅ 运行中 | `8529197605` |
| `linzihan`       | `@linzihan_bot`        | 林紫涵-供应链AI自媒体主理人  | `whatsapp-agent` | ⏸ 已禁用  | `8529197605` |

> `linzihan`（`@linzihan_bot`）及其对应的 `whatsapp-agent` 已迁移到 Mac 端部署，NAS 上 cron 任务已全部删除。

### 通道→Agent 路由（bindings）

通道到 Agent 的路由通过 `openclaw.json` → `bindings` 配置。**每个非 default 的 Telegram 通道都必须有一条 binding 规则**，否则会 fallback 到 `main` Agent。

```json
"bindings": [
  { "agentId": "whatsapp-agent",  "match": { "channel": "whatsapp" } },
  { "agentId": "whatsapp-agent",  "match": { "channel": "telegram", "accountId": "linzihan" } },
  { "agentId": "wechat-editor",   "match": { "channel": "telegram", "accountId": "wechat-editor" } },
  { "agentId": "sciai-marketer",  "match": { "channel": "telegram", "accountId": "default" } },
  { "agentId": "virtual-lover",   "match": { "channel": "telegram", "accountId": "mia" } },
  { "agentId": "movie-dev",       "match": { "channel": "telegram", "accountId": "moviedev" } },
  { "agentId": "ops-agent",       "match": { "channel": "telegram", "accountId": "serverops" } },
  { "agentId": "sciai-user-ops",  "match": { "channel": "telegram", "accountId": "sciai-user-ops" } }
]
```

> `simon-main` 通道不需要 binding，因为 `main` Agent 设置了 `"default": true`，未匹配的通道自动路由到 `main`。

### WhatsApp（已禁用）

NAS 不启用 WhatsApp 通道。WhatsApp（+8613911033691）仅在 Mac 端运行。

## 5. Cron 定时任务

`whatsapp-agent` 的 19 个 cron 任务已在 2026-03-03 全部删除（迁移到 Mac 端）。当前剩余约 21 个任务。

### SCI.AI 新闻发布（16 个，每日轮转，agent=main）

| 任务                         | 时间（上海） |
| ---------------------------- | ------------ |
| sciai-01-logistics-transport | 00:00        |
| sciai-03-last-mile           | 01:00        |
| sciai-05-supplier-management | 02:00        |
| sciai-06-supply-chain-tech   | 02:30        |
| sciai-08-robotics            | 03:30        |
| sciai-09-digital-platform    | 04:00        |
| sciai-13-manufacturing       | 06:00        |
| sciai-14-strategy-planning   | 06:30        |
| sciai-15-southeast-asia      | 07:00        |
| sciai-16-north-america       | 07:30        |
| sciai-17-europe              | 08:00        |
| sciai-18-middle-east         | 08:30        |
| sciai-19-south-asia          | 09:00        |
| sciai-20-latin-america       | 09:30        |
| sciai-21-japan-korea         | 10:00        |
| sciai-22-africa              | 10:30        |

### 系统 & 其他

| 任务                    | 时间             | Agent         |
| ----------------------- | ---------------- | ------------- |
| WhatsApp 通道健康检查   | 每 10 分钟       | main          |
| Daily Tesla Stock Price | 06:00 UTC        | main          |
| Daily AI news           | 09:00 UTC        | main          |
| Daily Anthropic search  | 10:00 UTC        | main          |
| sciai-research-papers   | 11:00 周一/三/五 | main          |
| 每日 SCI.AI 合作转载    | 08:00            | wechat-editor |

## 6. 模型与 API Key 配置

### 模型直连配置

NAS 使用**直连**方式调用各 LLM provider（不通过 OpenRouter 路由）。API Key 配置在 `openclaw.json` → `models.providers.<provider>.apiKey`。

| Provider    | 模型                          | 使用的 Agent                              | API Key 前缀           |
| ----------- | ----------------------------- | ----------------------------------------- | ---------------------- |
| `google`    | `gemini-2.5-flash`            | sciai-marketer, ops-agent, sciai-user-ops | `AIzaSy...`            |
| `dashscope` | `qwen-plus`                   | main, wechat-editor                       | `sk-d01...`            |
| `xai`       | `grok-4-1-fast-non-reasoning` | virtual-lover                             | `xai-XjS...`           |
| `openai`    | `gpt-4o`                      | movie-dev                                 | `sk-proj...`           |
| `moonshot`  | `kimi-k2.5`                   | whatsapp-agent (已停用)                   | `sk-SFs...` (⚠ 已过期) |

### API Key 解析优先级

OpenClaw 按以下顺序解析 API Key：

1. **Per-agent auth-profiles.json**（`~/.openclaw/agents/<id>/agent/auth-profiles.json`）
2. **环境变量**（如 `GEMINI_API_KEY`、`OPENAI_API_KEY`）
3. **Provider 静态配置**（`openclaw.json` → `models.providers.<provider>.apiKey`）

> **注意**：新建 Agent 如果 auth-profiles.json 为空（`{}`），会**继承 `main` Agent 的 auth-profiles**。如果 main 的 profiles 中包含失效的 key，新 Agent 也会受影响。

### 默认模型回退链（config.json5 → agents.defaults.model）

| 优先级     | 模型                                 | 成本     |
| ---------- | ------------------------------------ | -------- |
| Primary    | `google/gemini-2.5-flash`            | $0.075/M |
| Fallback 1 | `dashscope/qwen3.5-flash-2026-02-23` | 极低     |
| Fallback 2 | `zhipu/glm-4-flash`                  | 免费     |
| Fallback 3 | `groq/llama-3.3-70b-versatile`       | 免费     |

## 7. 代码部署流程

NAS 不从 npm/GitHub 拉取，而是从 Mac 本地构建后手动推送：

```bash
# 1. Mac 端构建
pnpm build && tar czf /tmp/openclaw-dist.tar.gz dist/

# 2. 传到 NAS
sshpass -p "Simon2028" scp -P 10000 /tmp/openclaw-dist.tar.gz 13911033691@192.168.3.185:/tmp/

# 3. NAS 解压 + 复制进容器（需 sudo）
~/.ssh/zspace-ssh "cd /tmp && tar xzf openclaw-dist.tar.gz && docker cp /tmp/dist/. openclaw-gateway:/app/dist/"

# 4. 重启容器
~/.ssh/zspace-ssh "docker restart openclaw-gateway"

# 5. 容器重启后修复（必须执行）
~/.ssh/zspace-ssh "docker exec -u root openclaw-gateway ln -sf /app/openclaw.mjs /usr/local/bin/openclaw && docker exec -u root openclaw-gateway chown -R node:node /home/node/.openclaw/skills/"
```

Skills 部署使用专用脚本：`~/.openclaw/skills/deploy-skill-to-nas.sh <skill-name>`

### 技能三端同步

新 Skill 必须同步到 Mac、MateBook X、NAS 三端。三端操作系统不同，安装方式有差异：

| 机器       | 系统           | Skills 路径                           | 安装方式                                             |
| ---------- | -------------- | ------------------------------------- | ---------------------------------------------------- |
| Mac        | macOS          | `~/.openclaw/skills/`                 | `clawhub install <slug>` 直接安装                    |
| MateBook X | Ubuntu 24.04   | `/home/simon/.openclaw/skills/`       | SSH 后 `clawhub install <slug>` 或从 Mac scp         |
| NAS        | Linux (Docker) | 容器内 `/home/node/.openclaw/skills/` | 不能在容器内跑 clawhub，必须 scp → docker cp → chown |

#### 从 Mac 批量同步技能到 NAS + MateBook X

```bash
# 1. 打包需要同步的技能
cd ~/.openclaw/skills
tar czf /tmp/skills-sync.tar.gz --no-xattrs skill-a skill-b skill-c

# 2. 同步到 MateBook X（直接 scp + 解压）
sshpass -p '1q2w3e4r' scp -o PreferredAuthentications=password \
  /tmp/skills-sync.tar.gz simon@192.168.3.119:/tmp/
sshpass -p '1q2w3e4r' ssh -o PreferredAuthentications=password \
  simon@192.168.3.119 "cd /home/simon/.openclaw/skills && tar xzf /tmp/skills-sync.tar.gz"

# 3. 同步到 NAS（scp → 解压 → docker cp → chown）
sshpass -p "Simon2028" scp -P 10000 -o StrictHostKeyChecking=no \
  /tmp/skills-sync.tar.gz 13911033691@192.168.3.185:/tmp/
sshpass -p "Simon2028" ssh -p 10000 -o StrictHostKeyChecking=no \
  13911033691@192.168.3.185 "cd /tmp && tar xzf skills-sync.tar.gz"
# docker cp 每个技能目录（需 sudo）
sshpass -p "Simon2028" ssh -p 10000 -o StrictHostKeyChecking=no \
  13911033691@192.168.3.185 \
  "echo 'Simon2028' | sudo -S docker cp /tmp/skill-a openclaw-gateway:/home/node/.openclaw/skills/ && \
   echo 'Simon2028' | sudo -S docker cp /tmp/skill-b openclaw-gateway:/home/node/.openclaw/skills/ && \
   echo 'Simon2028' | sudo -S docker exec -u root openclaw-gateway chown -R node:node /home/node/.openclaw/skills/"
```

> **MateBook X SSH 注意**：必须加 `-o PreferredAuthentications=password`，否则 sshpass 会卡在 publickey 阶段。

## 8. 常用运维命令

```bash
# 查看容器状态
~/.ssh/zspace-ssh "docker ps --filter name=openclaw-gateway"

# 查看容器资源占用
~/.ssh/zspace-ssh "docker stats openclaw-gateway --no-stream"

# 查看容器日志（最近 50 行）
~/.ssh/zspace-ssh "docker logs --tail 50 openclaw-gateway"

# 查看频道状态
~/.ssh/zspace-ssh "docker exec openclaw-gateway openclaw channels status --probe"

# 查看 cron 任务列表
~/.ssh/zspace-ssh "docker exec openclaw-gateway openclaw cron list"

# 查看 Agent 目录
~/.ssh/zspace-ssh "docker exec openclaw-gateway ls /home/node/.openclaw/agents/"

# 查看运行时配置（含 agents.list、bindings）
~/.ssh/zspace-ssh "docker exec openclaw-gateway openclaw config get agents.list"
~/.ssh/zspace-ssh "docker exec openclaw-gateway openclaw config get bindings"

# 查看 config.json5（用户可编辑配置）
~/.ssh/zspace-ssh "docker exec openclaw-gateway cat /home/node/.openclaw/config.json5"

# 查看 per-agent auth profiles
~/.ssh/zspace-ssh "docker exec openclaw-gateway cat /home/node/.openclaw/agents/<agent-id>/agent/auth-profiles.json"

# 进入容器 shell
~/.ssh/zspace-ssh "docker exec -it openclaw-gateway bash"

# 完整修复脚本（宿主机上）
/data_ZR5D8EL4/openclaw/fix-openclaw-container.sh
```

## 9. 配置文件说明

| 文件                 | 位置                                                        | 说明                                                                               |
| -------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `config.json5`       | `/home/node/.openclaw/config.json5`                         | 用户可编辑配置（沙箱、默认模型回退链、web 搜索等）                                 |
| `openclaw.json`      | `/home/node/.openclaw/openclaw.json`                        | OpenClaw 管理的运行时配置（agents.list、bindings、channels、providers、skills 等） |
| `auth-profiles.json` | `/home/node/.openclaw/agents/<id>/agent/auth-profiles.json` | Per-agent API Key 存储（优先级最高）                                               |
| `models.json`        | `/home/node/.openclaw/agents/<id>/agent/models.json`        | Per-agent 模型配置（自动生成，包含从 provider 继承的 key）                         |

> `openclaw.json` 中的 API Key 会显示为 `__OPENCLAW_REDACTED__`，实际值已加密存储。

## 10. 已知问题与注意事项

1. **Telegram 双端冲突**：Mac 和 NAS 同时运行相同 Telegram bot 时会产生 `409 Conflict`（同一 token 只能有一个实例轮询）。如需在 NAS 独占某 bot，需在 Mac 端禁用对应通道。
2. **docker cp 权限问题**：从 Mac `docker cp` 到 NAS 容器的文件保留 Mac uid/gid (1006:1007)，容器内 `node` 用户 (uid=1000) 无法访问，需手动 `chown`。
3. **openclaw 符号链接丢失**：容器重启后 `/usr/local/bin/openclaw` 符号链接丢失，需重新创建。
4. **Workspace 路径必须用容器路径**：agents.list 中的 `workspace` 字段必须使用 `/home/node/...` 路径，不能使用 Mac 路径 `/Users/simon/...`，否则 Agent 处理消息时会报 `EACCES: permission denied, mkdir '/Users'`。
5. **新增 Agent 必须配 binding**：在 Telegram accounts 中新增通道后，必须在 `bindings` 中添加对应的路由规则，否则消息会 fallback 到 `main` Agent（错误的人设回复）。
6. **新增 Agent 的 API Key 继承**：新 Agent 的 auth-profiles.json 为空时，会自动继承 `main` Agent 的 auth-profiles。如果 main 的某个 provider key 已过期（如 Moonshot），新 Agent 用该 provider 模型也会 401。
7. **Moonshot API Key 已过期**：`sk-SFsYePH7Miok...` 已失效（2026-03-03 确认），如需使用 `moonshot/kimi-k2.5` 模型需更新 key。
