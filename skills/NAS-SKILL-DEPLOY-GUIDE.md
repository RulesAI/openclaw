# NAS (ZSpace) Skill 部署指南

本文档记录如何将 OpenClaw Skill 部署到 NAS 上的 OpenClaw Agent。

---

## 1. NAS 架构概览

```
┌──────────────────────────────────────────────────────┐
│  ZSpace NAS (ZOS Linux 5.8.18)                       │
│  IP: 192.168.3.185    Port: 10000                    │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  Docker: openclaw-gateway                      │  │
│  │  Image:  openclaw:local-amd64                  │  │
│  │  Node:   22.22.0                               │  │
│  │  User:   node (HOME=/home/node)                │  │
│  │  Proxy:  http://clash:7890                     │  │
│  │                                                │  │
│  │  容器内路径:                                    │  │
│  │    /home/node/.openclaw/          ← 主配置     │  │
│  │    /home/node/.openclaw/skills/   ← Skills     │  │
│  │    /home/node/.openclaw/workspace/← 工作区     │  │
│  └──────────────┬─────────────┬───────────────────┘  │
│                 │ bind mount  │ bind mount            │
│                 ▼             ▼                       │
│  宿主机路径:                                          │
│    /data_ZR5D8EL4/openclaw/config/       ← 主配置    │
│    /data_ZR5D8EL4/openclaw/config/skills/← Skills   │
│    /data_ZR5D8EL4/openclaw/workspace/    ← 工作区    │
└──────────────────────────────────────────────────────┘
```

### 关键路径映射

| 宿主机路径 (部署到这里)                  | 容器内路径 (Agent 看到的)         |
| ---------------------------------------- | --------------------------------- |
| `/data_ZR5D8EL4/openclaw/config/`        | `/home/node/.openclaw/`           |
| `/data_ZR5D8EL4/openclaw/config/skills/` | `/home/node/.openclaw/skills/`    |
| `/data_ZR5D8EL4/openclaw/config/agents/` | `/home/node/.openclaw/agents/`    |
| `/data_ZR5D8EL4/openclaw/workspace/`     | `/home/node/.openclaw/workspace/` |

### ⚠️ 常见错误

```bash
# ❌ 错误！这是宿主机的 /home/node，会被 bind mount 覆盖，容器看不到
/home/node/.openclaw/skills/my-skill/

# ✅ 正确！这是实际的数据盘路径，会映射到容器内
/data_ZR5D8EL4/openclaw/config/skills/my-skill/
```

**原理**: Docker bind mount 把宿主机 `/data_ZR5D8EL4/openclaw/config` 整个目录挂载到容器的 `/home/node/.openclaw`。宿主机 `/home/node/.openclaw/` 虽然也存在，但在容器内被 bind mount 完全覆盖，容器根本看不到它。

---

## 2. SSH 连接方式

### 方式一：expect 脚本（执行单条命令）

```bash
/Users/simon/.ssh/zspace-ssh "要执行的命令"
```

特点：自动 sudo 提权为 root，但只能执行一条命令。

### 方式二：sshpass + scp（传输文件）

```bash
sshpass -p "Simon2028" scp -P 10000 -o StrictHostKeyChecking=no \
  本地文件 13911033691@192.168.3.185:/tmp/
```

### 方式三：sshpass + ssh（执行命令，无 sudo）

```bash
sshpass -p "Simon2028" ssh -p 10000 -o StrictHostKeyChecking=no \
  13911033691@192.168.3.185 "命令"
```

---

## 3. Skill 部署流程（标准 3 步）

### Step 1: 本地打包

```bash
# 在 Mac 上打包 Skill
cd ~/.openclaw/skills/
tar czf /tmp/my-skill.tar.gz my-skill/
```

### Step 2: 传输到 NAS

```bash
sshpass -p "Simon2028" scp -P 10000 -o StrictHostKeyChecking=no \
  /tmp/my-skill.tar.gz 13911033691@192.168.3.185:/tmp/
```

### Step 3: 解压到正确路径 + 清理 macOS 元数据

```bash
/Users/simon/.ssh/zspace-ssh "tar xzf /tmp/my-skill.tar.gz -C /data_ZR5D8EL4/openclaw/config/skills/ && chmod +x /data_ZR5D8EL4/openclaw/config/skills/my-skill/scripts/*.sh 2>/dev/null; find /data_ZR5D8EL4/openclaw/config/skills/my-skill -name '._*' -delete 2>/dev/null; echo 'DEPLOYED'"
```

> **注意**: macOS tar 会包含 `._` 开头的元数据文件（AppleDouble），在 Linux 上无用且可能干扰，务必清理。

### 验证部署

```bash
# 在容器内确认文件存在
/Users/simon/.ssh/zspace-ssh "docker exec openclaw-gateway ls /home/node/.openclaw/skills/my-skill/"

# 在容器内测试运行
/Users/simon/.ssh/zspace-ssh "docker exec openclaw-gateway bash /home/node/.openclaw/skills/my-skill/scripts/xxx.sh"
```

---

## 4. 一键部署脚本模板

将以下保存为可复用的部署脚本：

```bash
#!/bin/bash
# deploy-skill-to-nas.sh <skill-name>
# 用法: ./deploy-skill-to-nas.sh daily-supply-news-digest

set -euo pipefail

SKILL_NAME="${1:?用法: $0 <skill-name>}"
LOCAL_SKILLS_DIR="$HOME/.openclaw/skills"
NAS_SKILLS_DIR="/data_ZR5D8EL4/openclaw/config/skills"
NAS_HOST="13911033691@192.168.3.185"
NAS_PORT="10000"
NAS_PASS="Simon2028"

if [ ! -d "$LOCAL_SKILLS_DIR/$SKILL_NAME" ]; then
    echo "Error: Skill not found: $LOCAL_SKILLS_DIR/$SKILL_NAME" >&2
    exit 1
fi

echo "[1/3] Packing $SKILL_NAME ..."
tar czf "/tmp/${SKILL_NAME}.tar.gz" -C "$LOCAL_SKILLS_DIR" "$SKILL_NAME"

echo "[2/3] Transferring to NAS ..."
sshpass -p "$NAS_PASS" scp -P "$NAS_PORT" -o StrictHostKeyChecking=no \
  "/tmp/${SKILL_NAME}.tar.gz" "${NAS_HOST}:/tmp/"

echo "[3/3] Extracting on NAS ..."
/Users/simon/.ssh/zspace-ssh "tar xzf /tmp/${SKILL_NAME}.tar.gz -C ${NAS_SKILLS_DIR}/ && chmod -R +x ${NAS_SKILLS_DIR}/${SKILL_NAME}/scripts/ 2>/dev/null; find ${NAS_SKILLS_DIR}/${SKILL_NAME} -name '._*' -delete 2>/dev/null; echo 'OK'"

echo ""
echo "Verifying in container ..."
/Users/simon/.ssh/zspace-ssh "docker exec openclaw-gateway ls /home/node/.openclaw/skills/${SKILL_NAME}/"

echo ""
echo "✅ ${SKILL_NAME} deployed to NAS successfully"
```

---

## 5. Skill 编写注意事项（NAS 兼容性）

### 环境差异

| 项目      | Mac (本地)      | NAS (Docker 容器) |
| --------- | --------------- | ----------------- |
| OS        | macOS (ARM64)   | Linux (AMD64)     |
| Python    | 3.12 (Anaconda) | 3.8.5 (系统自带)  |
| Node      | 22.x            | 22.22.0           |
| Shell     | zsh             | bash              |
| date 命令 | BSD date        | GNU date          |
| Proxy     | 直连            | http://clash:7890 |

### Python 兼容性（3.8.5）

```python
# ❌ Python 3.10+ 语法，NAS 上会报错
match value:
    case "a": ...
result: dict | None = None

# ✅ 兼容写法
if value == "a": ...
result: Optional[dict] = None
```

### Shell 兼容性

```bash
# ❌ macOS BSD date
date -v+1d +%Y-%m-%d

# ✅ 跨平台写法（用 Python 处理日期）
python3 -c "from datetime import date, timedelta; print((date.today() + timedelta(days=1)).strftime('%Y-%m-%d'))"
```

### 网络访问

NAS 容器内通过 `http://clash:7890` 代理访问外网。
如果 Skill 脚本需要访问被墙的 API（如 Google），确保 `HTTP_PROXY`/`HTTPS_PROXY` 已设置（容器已默认配置）。

### 依赖

Skill 只能使用容器内已有的工具：

- `bash`, `curl`, `python3`, `node`, `bun`
- 不能依赖 `brew`、`pip install` 等需要额外安装的包
- Python 标准库可用，第三方库不保证

---

## 6. 目录结构总览

```
/data_ZR5D8EL4/openclaw/
├── config/                          ← 容器内 /home/node/.openclaw/
│   ├── openclaw.json                ← 主配置文件
│   ├── skills/                      ← ⭐ Skills 部署到这里
│   │   ├── daily-supply-news-digest/
│   │   ├── weekly-report/
│   │   ├── xiaohongshu-publisher/
│   │   ├── supply-news-publisher/
│   │   └── ...
│   ├── agents/                      ← Agents 配置
│   ├── memory/                      ← Agent 记忆存储
│   ├── credentials/                 ← 认证信息
│   ├── cron/                        ← 定时任务
│   ├── logs/                        ← 日志
│   └── ...
└── workspace/                       ← 容器内 /home/node/.openclaw/workspace/
    └── ...                          ← 工作区数据
```

---

## 7. 更新已部署的 Skill

```bash
# 直接重新执行部署流程即可（tar 会覆盖旧文件）
./deploy-skill-to-nas.sh my-skill

# 如果需要重启 OpenClaw 使配置生效（通常不需要，Skill 是运行时读取的）
/Users/simon/.ssh/zspace-ssh "docker restart openclaw-gateway"
```

---

## 8. 排查问题

### Skill 找不到

```bash
# 检查宿主机文件是否在正确路径
/Users/simon/.ssh/zspace-ssh "ls /data_ZR5D8EL4/openclaw/config/skills/ | grep my-skill"

# 检查容器内是否可见
/Users/simon/.ssh/zspace-ssh "docker exec openclaw-gateway ls /home/node/.openclaw/skills/my-skill/"
```

### 脚本运行报错

```bash
# 在容器内手动运行脚本看报错
/Users/simon/.ssh/zspace-ssh "docker exec openclaw-gateway bash /home/node/.openclaw/skills/my-skill/scripts/xxx.sh 2>&1"

# 常见原因：
# 1. 脚本没有执行权限 → chmod +x
# 2. Python 语法不兼容 3.8 → 检查语法
# 3. 依赖其他 Skill 但路径不对 → 检查路径引用
# 4. macOS ._* 元数据文件干扰 → find . -name '._*' -delete
```

### 权限问题

```bash
# 容器内以 root 运行，一般不会有权限问题
# 如果有，修复宿主机文件权限：
/Users/simon/.ssh/zspace-ssh "chmod -R 755 /data_ZR5D8EL4/openclaw/config/skills/my-skill/"
```

---

**最后更新**: 2026-03-02
**维护者**: Claude (AI Assistant)
