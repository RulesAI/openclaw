# Clash 自动切换工具 - 通用部署指南

## 📋 概述

这是一个**通用的** Clash 代理自动切换解决方案，可以部署到任何运行 Clash/Clash Premium 的环境。

### 核心特性

- ✅ **跨平台**：支持 Linux、macOS、WSL
- ✅ **通用性**：适配任何 Clash 部署方式
- ✅ **智能**：自动延迟测试，选择最快节点
- ✅ **可靠**：多目标健康检查
- ✅ **灵活**：可自定义优先区域和检查频率
- ✅ **自动化**：支持定时任务自动运维

---

## 🎯 适用场景

### 1. 个人电脑

- **Windows** (WSL)
- **macOS**
- **Linux** 桌面

### 2. 服务器

- **云服务器** (阿里云、腾讯云、AWS等)
- **VPS**
- **物理服务器**

### 3. NAS 设备

- **群晖 Synology**
- **威联通 QNAP**
- **极空间 ZSpace**
- **其他 Linux NAS**

### 4. 容器/虚拟化

- **Docker** 容器
- **Kubernetes** Pod
- **虚拟机**

### 5. 特殊环境

- **树莓派**
- **OpenWrt/LEDE** 路由器
- **软路由**

---

## 📦 部署方式

### 方式 1：一键安装（推荐）⭐

**适用于**：大多数 Linux/macOS 环境

```bash
# 1. 下载安装脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/install-clash-auto-switch.sh -o install.sh

# 2. 执行安装
bash install.sh

# 3. 按照提示配置
# - Clash API 地址（默认 http://127.0.0.1:9090）
# - Clash Secret（在 config.yaml 中查看）
# - 代理地址（默认 http://127.0.0.1:7890）
# - 优先区域（如：美国 新加坡）

# 4. 测试
clash-auto-switch.sh check
```

### 方式 2：手动安装

**适用于**：需要自定义配置的高级用户

```bash
# 1. 下载脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/clash-auto-switch.sh -o clash-auto-switch.sh
chmod +x clash-auto-switch.sh

# 2. 安装 jq（如果未安装）
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq

# 3. 编辑配置
vim clash-auto-switch.sh

# 修改以下变量：
# CLASH_API="http://127.0.0.1:9090"
# CLASH_SECRET="your-secret"
# PROXY_URL="http://127.0.0.1:7890"
# PREFERRED_REGIONS=("美国" "US" "新加坡" "SG")

# 4. 安装到系统
sudo cp clash-auto-switch.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/clash-auto-switch.sh

# 5. 测试
clash-auto-switch.sh check
```

### 方式 3：Docker 环境

**适用于**：Clash 运行在 Docker 中

```bash
# 1. 确保 Clash 容器网络可访问
docker network ls | grep clash

# 2. 修改配置（使用容器名或网络地址）
CLASH_API="http://clash:9090"  # 如果在同一网络
# 或
CLASH_API="http://172.17.0.2:9090"  # 使用容器 IP

# 3. 部署到宿主机或另一个容器
# 宿主机部署
bash install.sh

# 或在另一个容器中运行
docker run -d --name clash-switcher \
  --network clash-net \
  -v /path/to/script:/usr/local/bin/clash-auto-switch.sh \
  alpine:latest \
  /bin/sh -c "apk add bash curl jq && crond -f"
```

### 方式 4：systemd 服务（推荐生产环境）

**适用于**：需要服务化部署的环境

```bash
# 1. 创建服务文件
sudo tee /etc/systemd/system/clash-auto-switch.service > /dev/null <<EOF
[Unit]
Description=Clash Auto Switch Service
After=network.target

[Service]
Type=oneshot
User=$USER
ExecStart=/usr/local/bin/clash-auto-switch.sh auto
StandardOutput=append:/var/log/clash/auto-switch.log
StandardError=append:/var/log/clash/auto-switch.log

[Install]
WantedBy=multi-user.target
EOF

# 2. 创建定时器
sudo tee /etc/systemd/system/clash-auto-switch.timer > /dev/null <<EOF
[Unit]
Description=Clash Auto Switch Timer
Requires=clash-auto-switch.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF

# 3. 启用并启动
sudo systemctl daemon-reload
sudo systemctl enable clash-auto-switch.timer
sudo systemctl start clash-auto-switch.timer

# 4. 查看状态
sudo systemctl status clash-auto-switch.timer
sudo journalctl -u clash-auto-switch.service -f
```

---

## ⚙️ 配置指南

### 基础配置

脚本中的关键配置变量：

```bash
# Clash API 地址
CLASH_API="http://127.0.0.1:9090"

# Clash API 密钥（在 Clash config.yaml 中查看）
CLASH_SECRET="your-secret-here"

# 代理地址（用于健康检查）
PROXY_URL="http://127.0.0.1:7890"

# 健康检查目标
TEST_TARGETS=(
    "https://api.telegram.org"
    "https://api.anthropic.com"
    "https://generativelanguage.googleapis.com"
)

# 优先区域
PREFERRED_REGIONS=("美国" "🇺🇲" "US" "新加坡" "🇸🇬" "SG")
```

### 查找 Clash 配置

**Clash Secret 位置**：

```bash
# 方法 1：查看配置文件
cat ~/.config/clash/config.yaml | grep secret

# 方法 2：如果是 Docker
docker exec clash cat /root/.config/clash/config.yaml | grep secret

# 输出示例：
# secret: "openclaw2026"
```

**Clash API 端口**：

```bash
# 查看配置
cat ~/.config/clash/config.yaml | grep external-controller

# 输出示例：
# external-controller: 0.0.0.0:9090
```

### 不同环境的配置示例

#### 1. 本机 Clash

```bash
CLASH_API="http://127.0.0.1:9090"
CLASH_SECRET="your-secret"
PROXY_URL="http://127.0.0.1:7890"
```

#### 2. Docker Clash（同一主机）

```bash
# 使用宿主机 IP
CLASH_API="http://127.0.0.1:9090"
PROXY_URL="http://127.0.0.1:7890"

# 或使用 Docker 网络
CLASH_API="http://clash:9090"
PROXY_URL="http://clash:7890"
```

#### 3. 远程 Clash

```bash
CLASH_API="http://192.168.1.100:9090"
CLASH_SECRET="your-secret"
PROXY_URL="http://192.168.1.100:7890"
```

#### 4. Clash with Authentication

```bash
# 如果 Clash 启用了 HTTP 认证
PROXY_URL="http://username:password@127.0.0.1:7890"
```

### 自定义优先区域

根据您的需求修改优先区域：

```bash
# 示例 1：只优先香港和台湾
PREFERRED_REGIONS=("香港" "🇭🇰" "HK" "台湾" "🇹🇼" "TW")

# 示例 2：日本优先
PREFERRED_REGIONS=("日本" "🇯🇵" "JP" "Japan")

# 示例 3：多区域优先（按优先级排序）
PREFERRED_REGIONS=("美国" "🇺🇲" "US" "日本" "🇯🇵" "JP" "新加坡" "🇸🇬" "SG")
```

---

## 🧪 测试与验证

### 1. 验证 Clash API 连接

```bash
# 测试 API 可达性
curl -H "Authorization: Bearer YOUR_SECRET" http://127.0.0.1:9090/proxies

# 应该返回 JSON 格式的节点列表
```

### 2. 测试脚本功能

```bash
# 健康检查
clash-auto-switch.sh check

# 列出节点
clash-auto-switch.sh list

# 测试区域切换（不会真正切换）
clash-auto-switch.sh us --dry-run  # 如果支持
```

### 3. 手动测试切换

```bash
# 切换到美国节点
clash-auto-switch.sh us

# 验证当前节点
curl -H "Authorization: Bearer YOUR_SECRET" \
  http://127.0.0.1:9090/proxies/PROXY | jq -r '.now'
```

---

## 📊 监控与日志

### 查看日志

```bash
# 实时监控
tail -f /var/log/clash/auto-switch.log

# 或（用户目录）
tail -f ~/.local/log/clash/auto-switch.log

# 查看最近的切换记录
grep "已切换到节点" /var/log/clash/auto-switch.log | tail -10

# 查看健康检查结果
grep "健康检查完成" /var/log/clash/auto-switch.log | tail -10
```

### 监控脚本运行

```bash
# 查看 cron 任务
crontab -l | grep clash

# 查看 systemd 服务状态
systemctl status clash-auto-switch.timer

# 查看定时器下次运行时间
systemctl list-timers | grep clash
```

---

## 🔧 故障排查

### 问题 1：脚本无法连接 Clash API

**症状**：

```
[ERROR] 未找到可用节点
```

**解决方法**：

1. 检查 Clash 是否运行

   ```bash
   ps aux | grep clash
   # 或
   docker ps | grep clash
   ```

2. 检查 API 端口

   ```bash
   netstat -tlnp | grep 9090
   # 或
   lsof -i :9090
   ```

3. 测试 API 连接

   ```bash
   curl -v http://127.0.0.1:9090/proxies
   ```

4. 检查防火墙

   ```bash
   # Ubuntu/Debian
   sudo ufw status

   # CentOS/RHEL
   sudo firewall-cmd --list-ports
   ```

### 问题 2：jq 命令未找到

**症状**：

```
jq: command not found
```

**解决方法**：

```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq

# 或下载预编译版本
sudo curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 \
  -o /usr/local/bin/jq
sudo chmod +x /usr/local/bin/jq
```

### 问题 3：定时任务不执行

**症状**：

- 日志文件没有更新
- 节点从未自动切换

**解决方法**：

1. 检查 cron 服务

   ```bash
   # Linux
   systemctl status cron

   # macOS
   sudo launchctl list | grep cron
   ```

2. 查看 cron 日志

   ```bash
   # Ubuntu/Debian
   grep CRON /var/log/syslog | tail -20

   # CentOS/RHEL
   grep CROND /var/log/cron | tail -20
   ```

3. 验证 crontab 配置

   ```bash
   crontab -l

   # 确保包含类似以下行：
   # */10 * * * * /usr/local/bin/clash-auto-switch.sh auto >> /var/log/clash/auto-switch.log 2>&1
   ```

4. 手动执行测试
   ```bash
   /usr/local/bin/clash-auto-switch.sh auto
   ```

### 问题 4：权限错误

**症状**：

```
Permission denied
```

**解决方法**：

1. 检查脚本权限

   ```bash
   ls -l /usr/local/bin/clash-auto-switch.sh
   # 应该是 -rwxr-xr-x
   ```

2. 修复权限

   ```bash
   sudo chmod +x /usr/local/bin/clash-auto-switch.sh
   ```

3. 确保日志目录可写
   ```bash
   mkdir -p ~/.local/log/clash
   # 或
   sudo mkdir -p /var/log/clash
   sudo chown $USER:$USER /var/log/clash
   ```

---

## 🌍 不同环境部署示例

### Ubuntu Server 20.04

```bash
# 1. 安装依赖
sudo apt-get update
sudo apt-get install -y curl jq

# 2. 确认 Clash 运行
systemctl status clash

# 3. 安装脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/install-clash-auto-switch.sh | bash

# 4. 配置 systemd 定时器（推荐）
sudo systemctl enable clash-auto-switch.timer
sudo systemctl start clash-auto-switch.timer
```

### macOS

```bash
# 1. 安装 Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. 安装 jq
brew install jq

# 3. 安装脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/install-clash-auto-switch.sh | bash

# 4. 使用 launchd（macOS 定时任务）
# 创建 plist 文件
cat > ~/Library/LaunchAgents/com.clash.autoswitch.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clash.autoswitch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/clash-auto-switch.sh</string>
        <string>auto</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>StandardOutPath</key>
    <string>/tmp/clash-auto-switch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clash-auto-switch.error.log</string>
</dict>
</plist>
EOF

# 加载定时任务
launchctl load ~/Library/LaunchAgents/com.clash.autoswitch.plist
```

### Docker 环境（Clash 在容器中）

```bash
# 1. 创建共享网络
docker network create clash-net

# 2. 重启 Clash 容器并加入网络
docker stop clash
docker rm clash
docker run -d \
  --name clash \
  --network clash-net \
  --restart unless-stopped \
  -p 7890:7890 \
  -p 9090:9090 \
  -v /path/to/clash/config.yaml:/root/.config/clash/config.yaml \
  dreamacro/clash-premium

# 3. 在宿主机部署脚本
# 配置使用 Docker 网络地址
CLASH_API="http://clash:9090"
PROXY_URL="http://clash:7890"

bash install.sh

# 4. 验证
clash-auto-switch.sh check
```

### 群晖 NAS (DSM 7)

```bash
# 1. SSH 登录
ssh admin@192.168.1.100

# 2. 切换到 root
sudo -i

# 3. 安装 jq（如未安装）
# 方法 1：使用 Community Packages
# 在套件中心搜索并安装 "Entware"

# 方法 2：手动下载
cd /tmp
wget https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
mv jq-linux-amd64 /usr/local/bin/jq
chmod +x /usr/local/bin/jq

# 4. 安装脚本
curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/install-clash-auto-switch.sh | bash

# 5. 配置定时任务（使用 DSM 任务计划器）
# 控制面板 > 任务计划器 > 新增 > 用户自定义脚本
# 计划：每10分钟
# 脚本：/usr/local/bin/clash-auto-switch.sh auto
```

---

## 📚 高级配置

### 自定义健康检查目标

编辑脚本，修改 `TEST_TARGETS` 数组：

```bash
TEST_TARGETS=(
    "https://api.telegram.org"           # Telegram
    "https://api.openai.com"             # OpenAI
    "https://www.google.com"             # Google
    "https://api.github.com"             # GitHub
    "https://api.twitter.com"            # Twitter
)
```

### 调整检查频率

**cron 方式**：

```bash
# 每5分钟
*/5 * * * * /usr/local/bin/clash-auto-switch.sh auto

# 每30分钟
*/30 * * * * /usr/local/bin/clash-auto-switch.sh auto

# 每小时
0 * * * * /usr/local/bin/clash-auto-switch.sh auto
```

**systemd 方式**：

```bash
# 编辑 timer
sudo systemctl edit clash-auto-switch.timer

# 修改 OnUnitActiveSec
[Timer]
OnUnitActiveSec=5min  # 改为5分钟
```

### 集成通知

添加切换成功通知（以 Telegram 为例）：

```bash
# 在 auto_switch 函数末尾添加
if [ $? -eq 0 ]; then
    curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
        -d "chat_id=<CHAT_ID>" \
        -d "text=🔄 Clash 已自动切换到: $best_proxy"
fi
```

---

## 🤝 社区与支持

- **GitHub**: https://github.com/openclaw/openclaw
- **文档**: https://docs.openclaw.ai
- **Issues**: https://github.com/openclaw/openclaw/issues

---

## 📄 许可证

与 OpenClaw 项目保持一致。

---

## 🔄 更新日志

### v1.0 (2026-02-26)

- ✨ 初始版本
- ✨ 支持智能节点切换
- ✨ 支持多平台部署
- ✨ 完整的通用部署文档
