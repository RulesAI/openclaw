---
name: server-ops
description: |
  服务器运维监控。监控阿里云 ECS 和 NAS 的服务健康、资源使用、容器状态、SSL 证书有效期、日志异常。
  纯只读监控，不执行任何变更操作。
  触发关键词: 服务器状态、server status、check servers、磁盘、disk、CPU、内存、容器状态、container、SSL、证书、日志错误、errors、巡检
  适用场景: 定时服务器巡检、服务健康检查、资源使用监控、SSL 证书预警、容器异常检测
  不适用: 代码部署、容器重启、配置修改、数据库操作
version: 1.0
user-invocable: true
metadata:
  openclaw:
    os: ["linux"]
    requires:
      bins: ["bash", "curl", "ssh", "openssl"]
    emoji: "🖥️"
---

# 服务器运维监控 (Server Ops Monitor)

纯只读监控 Agent。监控阿里云 ECS 和 NAS 服务器的健康状态，通过 Telegram 报告巡检结果。

## 监控目标

### 阿里云 ECS (47.97.196.187)

| 服务        | 域名                | 端口   | 用途           |
| ----------- | ------------------- | ------ | -------------- |
| WordPress   | news.yrules.com     | 80     | 主站           |
| AI Passport | accounts.yrules.com | 3002   | 身份认证       |
| Nginx       | —                   | 443/80 | 反向代理 + SSL |
| Supabase    | db.yrules.com       | —      | 自部署数据库   |

### NAS (本机)

- OpenClaw Gateway 容器

## 安全规则 (CRITICAL)

⛔ **只读监控模式 — 以下操作绝对禁止：**

- NEVER 执行 `docker restart`、`docker stop`、`docker rm`、`docker exec` 写操作
- NEVER 修改任何配置文件（nginx.conf、docker-compose.yml 等）
- NEVER 执行 `rm`、`mv`、`cp` 等文件操作
- NEVER 修改防火墙、SSH 配置、SSL 证书
- NEVER 安装/卸载任何软件包
- NEVER 在 Telegram 消息中暴露 SSH 密钥路径、密码、token

✅ **允许的操作：**

- `curl` HTTP 请求（健康探测）
- `ssh` 到 ECS 执行只读命令（df、free、top、docker ps、docker logs、docker inspect）
- `openssl s_client` 查看 SSL 证书
- 读取 `/proc/loadavg`、`/proc/meminfo` 等系统信息
- 读取 `servers.json` 配置

## 参数

| 参数       | 类型   | 必填 | 默认值 | 说明                                                       |
| ---------- | ------ | ---- | ------ | ---------------------------------------------------------- |
| `--check`  | string | 否   | all    | 检查类型: all / health / resource / container / ssl / logs |
| `--target` | string | 否   | all    | 目标: all / ecs / nas                                      |
| `--since`  | string | 否   | 1h     | 日志扫描时间范围                                           |

## Workflow

### Step 1: 判断检查范围

根据用户请求或 cron 触发消息，确定运行哪些检查。

**交互式查询映射：**

- "服务器状态" / "server status" / "full check" / "完整巡检" → 全部检查 (Step 3-7)
- "服务健康" / "services" / "网站正常吗" → 仅 Step 3
- "磁盘" / "CPU" / "内存" / "资源" / "disk" / "resource" → 仅 Step 4
- "容器" / "container" / "docker" → 仅 Step 5
- "SSL" / "证书" / "certificate" → 仅 Step 6
- "日志" / "错误" / "errors" / "logs" → 仅 Step 7

**Cron 触发映射：**

- 2小时轻量检查 → 仅 Step 3 (HTTP 健康检查)
- 4小时详细检查 → 全部 Step 3-7
- 每周 SSL 检查 → 仅 Step 6

```bash
# 确定检查范围
CHECK_TYPE="${CHECK_PARAM:-all}"
TARGET="${TARGET_PARAM:-all}"
SINCE="${SINCE_PARAM:-1h}"
```

### Step 2: 验证 ECS SSH 连通性

在执行 ECS 相关检查前，先验证 SSH 连接可用。

```bash
SKILL_DIR="$HOME/.openclaw/skills/server-ops"

# 测试 SSH 连接 (超时10秒)
bash "$SKILL_DIR/scripts/ecs-exec.sh" "echo ok" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️ ECS SSH 连接失败，跳过 ECS 相关检查"
    # 继续执行 NAS 本地检查和外部 HTTP 检查
fi
```

如果 SSH 失败，在最终报告中标注 "ECS SSH 不可达"，并继续执行不依赖 SSH 的检查（HTTP 健康检查仍可从容器外部访问）。

### Step 3: HTTP 健康检查

运行 health-check.sh 探测所有服务端点。

```bash
HEALTH_RESULT=$(bash "$SKILL_DIR/scripts/health-check.sh")
echo "$HEALTH_RESULT"
```

**输出格式：** JSON 数组

```json
[
  {
    "name": "WordPress",
    "url": "https://news.yrules.com",
    "status": 200,
    "time_s": 0.45,
    "ok": true
  },
  {
    "name": "AI Passport",
    "url": "https://accounts.yrules.com",
    "status": 200,
    "time_s": 0.32,
    "ok": true
  }
]
```

**判断逻辑：**

- status 不匹配 expect → ❌ CRITICAL
- time_s > 10.0 → ❌ CRITICAL (响应超时)
- time_s > 3.0 → ⚠️ WARNING (响应缓慢)
- 否则 → ✅ OK

### Step 4: 资源监控

运行 resource-monitor.sh 获取 ECS 和 NAS 的 CPU/内存/磁盘使用情况。

```bash
RESOURCE_RESULT=$(bash "$SKILL_DIR/scripts/resource-monitor.sh" --target "$TARGET")
echo "$RESOURCE_RESULT"
```

**输出格式：** JSON 对象

```json
{
  "ecs": {"cpu_pct": 23.5, "mem_total_mb": 2048, "mem_used_mb": 1200, "mem_pct": 58.6, "disks": [{"mount": "/", "use_pct": 45}, {"mount": "/data", "use_pct": 68}]},
  "nas": {"cpu_pct": 15.2, "load_1m": 0.5, "mem_total_mb": 8192, "mem_used_mb": 3600, "mem_pct": 43.9, "disks": [...]}
}
```

**判断逻辑（参考 servers.json thresholds）：**

- CPU > 95% → ❌ CRITICAL
- CPU > 80% → ⚠️ WARNING
- 内存 > 95% → ❌ CRITICAL
- 内存 > 85% → ⚠️ WARNING
- 磁盘 > 90% → ❌ CRITICAL
- 磁盘 > 80% → ⚠️ WARNING

### Step 5: 容器状态

运行 container-status.sh 检查 ECS 上的 Docker 容器。

```bash
CONTAINER_RESULT=$(bash "$SKILL_DIR/scripts/container-status.sh")
echo "$CONTAINER_RESULT"
```

**输出格式：** JSON 数组

```json
[
  {
    "name": "wordpress",
    "state": "running",
    "status": "Up 15 days",
    "ok": true,
    "restart_count": 0,
    "started_at": "2026-02-15T..."
  },
  {
    "name": "ai-passport",
    "state": "exited",
    "status": "Exited (137) 2 hours ago",
    "ok": false,
    "restart_count": 3,
    "started_at": "..."
  }
]
```

**判断逻辑：**

- state != "running" → ❌ CRITICAL
- restart_count > 0 (最近) → ⚠️ WARNING

### Step 6: SSL 证书检查

运行 ssl-check.sh 检查所有域名的 SSL 证书有效期。

```bash
SSL_RESULT=$(bash "$SKILL_DIR/scripts/ssl-check.sh")
echo "$SSL_RESULT"
```

**输出格式：** JSON 数组

```json
[
  {
    "domain": "news.yrules.com",
    "expires": "May 15 23:59:59 2026 GMT",
    "days_remaining": 74,
    "ok": true
  }
]
```

**判断逻辑：**

- days_remaining < 7 → ❌ CRITICAL
- days_remaining < 30 → ⚠️ WARNING

### Step 7: 日志错误扫描

运行 log-scan.sh 扫描容器日志中的错误。

```bash
LOG_RESULT=$(bash "$SKILL_DIR/scripts/log-scan.sh" --since "$SINCE")
echo "$LOG_RESULT"
```

**输出格式：** JSON 数组

```json
[
  {
    "container": "wordpress",
    "error_count": 2,
    "recent_errors": ["PHP Warning: ..."],
    "ok": false
  },
  { "container": "nginx", "error_count": 0, "recent_errors": [], "ok": true }
]
```

**判断逻辑：**

- error_count > 0 → ⚠️ WARNING（附带最近错误摘要）
- error_count == 0 → ✅ OK

### Step 8: 严重性评估

汇总所有检查结果，对比 `references/servers.json` 中的阈值，对每项分类为 OK / WARNING / CRITICAL。

```bash
# 读取阈值
THRESHOLDS=$(python3 -c "
import json
with open('$SKILL_DIR/references/servers.json') as f:
    print(json.dumps(json.load(f)['thresholds']))
")
```

**整体评估：**

- 任何一项 CRITICAL → 整体 CRITICAL（报告头部加 🚨）
- 有 WARNING 无 CRITICAL → 整体 WARNING（报告尾部列出需关注项）
- 全部 OK → 整体 OK

### Step 9: 格式化 Telegram 报告

根据检查范围和结果，组装 Telegram 友好的文本报告。

**4小时详细报告模板：**

```
🖥️ 服务器巡检 · {月}月{日}日 {时}:00

📡 服务健康
  ✅ WordPress — 200 (0.45s)
  ✅ AI Passport — 200 (0.32s)
  ✅ Supabase — 200 (0.28s)

📊 ECS 资源 (47.97.196.187)
  CPU {X}% {状态} | 内存 {X}% {状态}
  / 磁盘 {X}% {状态} | /data {X}% {状态}

📊 NAS 资源
  CPU {X}% {状态} | 内存 {X}% {状态} | 磁盘 {X}% {状态}

🐳 ECS 容器
  ✅ wordpress — Up 15d, 0 restarts
  ✅ ai-passport — Up 15d, 0 restarts
  ✅ nginx — Up 15d, 0 restarts

🔒 SSL 证书
  ✅ news.yrules.com — {N}天
  ✅ accounts.yrules.com — {N}天
  ✅ db.yrules.com — {N}天

📋 日志 ({since})
  ✅ 所有容器无异常
```

如有异常，在报告尾部添加：

```
⚠️ 关注: {异常项目列表}
```

如有严重异常，在报告头部添加：

```
🚨 严重告警: {严重异常项目}
```

**2小时轻量检查模板（全部正常时）：**

```
✅ All {N} services healthy ({最快}-{最慢}s)
```

**2小时轻量检查模板（有异常时）：**

```
🚨 服务异常

❌ {服务名} — {状态码或错误}
✅ 其他 {N} 个服务正常
```

### Step 10: 输出报告

将格式化的报告作为回复输出。如果是 cron 触发的 isolated session，报告会通过 delivery 自动发送到 Telegram。

**重要：**

- 2小时轻量检查：如果全部正常，只输出一行 `✅ All N services healthy`，不要输出详细报告
- 4小时详细检查：始终输出完整报告
- 交互式查询：根据用户请求的范围输出对应部分

## Cron 定时任务配置

部署后通过 Telegram 对话设置以下 cron 任务：

**Job 1: 轻量健康检查（每2小时）**

```
名称: ops:health-ping
间隔: 每2小时 (everyMs: 7200000)
消息: 运行轻量健康检查。仅探测 HTTP 端点。如果全部正常，只回复 "✅ All N services healthy (Xs-Xs)"。如果有异常，详细报告异常服务。
超时: 120秒
```

**Job 2: 完整巡检（每4小时）**

```
名称: ops:full-report
计划: 0 */4 * * * (Asia/Shanghai)
消息: 运行完整服务器巡检，包括：HTTP 健康检查、ECS 和 NAS 资源监控、容器状态、SSL 证书、日志错误扫描。输出完整巡检报告。
超时: 300秒
```

**Job 3: SSL 证书专项（每周一 09:00）**

```
名称: ops:ssl-weekly
计划: 0 9 * * 1 (Asia/Shanghai)
消息: 运行 SSL 证书专项检查，报告所有域名的证书剩余有效天数。
超时: 120秒
```

## 故障排查

**SSH 连接失败：**

1. 检查 SSH 密钥是否存在: `ls -la $HOME/.openclaw/.ssh/id_aliyun`
2. 检查权限: `stat $HOME/.openclaw/.ssh/id_aliyun` (应为 600)
3. 手动测试: `ssh -i $HOME/.openclaw/.ssh/id_aliyun -o ConnectTimeout=10 root@47.97.196.187 "echo ok"`
4. 检查网络: `curl -s --connect-timeout 5 https://news.yrules.com` (如果 curl 可达但 SSH 不行，可能是 SSH 端口被封)

**脚本执行失败：**

1. 检查脚本权限: `ls -la $HOME/.openclaw/skills/server-ops/scripts/`
2. 手动运行: `bash $HOME/.openclaw/skills/server-ops/scripts/health-check.sh`
3. 检查 python3 可用: `which python3`
4. 检查 openssl 可用: `which openssl`

**Cron 任务不触发：**

1. 检查 cron 状态: 在 Telegram 中发送 "cron status"
2. 查看任务列表: "cron list"
3. 查看执行历史: "cron runs"
