# Clash 自动切换解决方案

## 📋 目录

- [问题背景](#问题背景)
- [解决方案](#解决方案)
- [快速部署](#快速部署)
- [使用指南](#使用指南)
- [配置说明](#配置说明)
- [故障排查](#故障排查)

---

## 问题背景

**症状**：

- VPN 代理线路不稳定
- 连接经常超时或失败
- 需要手动切换美国/新加坡线路
- 影响 OpenClaw 的 Telegram/API 连接

**需求**：

- 自动检测代理健康状态
- 故障时自动切换到可用线路
- 优先选择美国/新加坡节点

---

## 解决方案

### 三层保障架构

```
┌─────────────────────────────────────────────────┐
│  第一层: Clash 智能选择 (url-test)              │
│  - 每5分钟自动测速                               │
│  - 自动选择最快节点                             │
│  - 延迟差<100ms不切换（避免频繁抖动）            │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  第二层: 定时健康检查 (cron)                    │
│  - 每10分钟检测连通性                           │
│  - 测试多个目标（Telegram/Claude/Google）        │
│  - 自动触发节点切换                             │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  第三层: 手动切换工具 (命令行)                  │
│  - 快速切换美国/新加坡线路                      │
│  - 列出所有可用节点                             │
│  - 应急备用方案                                 │
└─────────────────────────────────────────────────┘
```

---

## 快速部署

### 方式 1：一键部署（推荐）

```bash
# 1. 上传文件到 NAS
scp clash-auto-switch.sh setup-clash-auto-switch.sh 13911033691@192.168.3.185:/tmp/

# 2. SSH 登录
ssh -p 10000 13911033691@192.168.3.185

# 3. 切换 root
sudo -i

# 4. 进入目录并执行部署
cd /tmp
bash setup-clash-auto-switch.sh
```

### 方式 2：手动部署

```bash
# 1. 安装脚本
sudo cp clash-auto-switch.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/clash-auto-switch.sh

# 2. 测试功能
clash-auto-switch.sh check

# 3. 添加定时任务
sudo crontab -e

# 添加以下内容：
*/10 * * * * /usr/local/bin/clash-auto-switch.sh auto >> /var/log/clash/auto-switch.log 2>&1
```

---

## 使用指南

### 基础命令

#### 1. 健康检查

```bash
clash-auto-switch.sh check
```

**输出示例**：

```
[INFO] 2026-02-26 10:00:00 开始健康检查...
[OK]   2026-02-26 10:00:01 ✓ https://api.telegram.org 可达
[OK]   2026-02-26 10:00:02 ✓ https://api.anthropic.com 可达
[OK]   2026-02-26 10:00:03 ✓ https://generativelanguage.googleapis.com 可达
[INFO] 2026-02-26 10:00:03 健康检查完成: 3/3 (100%)
```

#### 2. 自动切换（推荐）

```bash
clash-auto-switch.sh auto
```

**工作流程**：

1. 检查当前代理健康状态
2. 如果健康，直接返回
3. 如果不健康，测试所有节点
4. 优先选择美国/新加坡节点
5. 切换到最佳节点并重新验证

#### 3. 列出所有节点

```bash
clash-auto-switch.sh list
```

**输出示例**：

```
[INFO] 2026-02-26 10:00:00 ========== 可用节点列表 ==========
★ 美国 01 [优先]
  美国 02 [优先]
  新加坡 01 [优先]
  新加坡 02 [优先]
  日本 01
  香港 01
```

（★ 表示当前选中的节点）

### 区域切换

#### 切换到美国节点

```bash
clash-auto-switch.sh us
```

**效果**：

- 自动找出所有美国节点
- 测试延迟并选择最快的
- 切换并验证连通性

#### 切换到新加坡节点

```bash
clash-auto-switch.sh sg
```

### 手动指定节点

```bash
clash-auto-switch.sh switch "美国 01"
```

---

## 配置说明

### Clash 配置文件优化

**位置**：`/volume1/openclaw-deploy/clash/config.yaml`

**关键配置**：

#### 1. 主策略组（自动选择）

```yaml
proxy-groups:
  - name: "PROXY"
    type: url-test # 自动测速选择
    interval: 300 # 每5分钟测速
    tolerance: 100 # 延迟差小于100ms不切换
    proxies:
      - "美国优选"
      - "新加坡优选"
      - "自动选择"
```

**参数说明**：

- `type: url-test` - 自动选择最快节点
- `interval: 300` - 每5分钟重新测速
- `tolerance: 100` - 只有当新节点比当前节点快100ms以上时才切换（避免频繁抖动）

#### 2. 区域优选组

```yaml
- name: "美国优选"
  type: url-test
  interval: 300
  tolerance: 50
  proxies:
    - "美国 01"
    - "美国 02"
    - "US 01"
```

#### 3. 故障转移组

```yaml
- name: "故障转移"
  type: fallback # 故障转移模式
  interval: 180 # 每3分钟检测
  proxies:
    - "美国优选"
    - "新加坡优选"
```

**特点**：

- 第一个节点挂了自动切换到第二个
- 适合需要高可用性的场景

### 自动切换脚本配置

**位置**：`/usr/local/bin/clash-auto-switch.sh`

**可修改参数**：

```bash
# Clash API 地址
CLASH_API="http://127.0.0.1:9090"
CLASH_SECRET="openclaw2026"

# 代理地址
PROXY_URL="http://127.0.0.1:7890"

# 测试目标（用于验证连通性）
TEST_TARGETS=(
    "https://api.telegram.org"
    "https://api.anthropic.com"
    "https://generativelanguage.googleapis.com"
)

# 优先区域（按优先级排序）
PREFERRED_REGIONS=("美国" "US" "United States" "新加坡" "SG" "Singapore")
```

### 定时任务配置

**查看当前配置**：

```bash
crontab -l
```

**默认配置**：

```bash
# 每10分钟自动检查和切换
*/10 * * * * /usr/local/bin/clash-auto-switch.sh auto >> /var/log/clash/auto-switch.log 2>&1

# 每天凌晨3点清理日志
0 3 * * * tail -n 100 /var/log/clash/auto-switch.log > /var/log/clash/auto-switch.log.tmp && mv /var/log/clash/auto-switch.log.tmp /var/log/clash/auto-switch.log
```

**修改检查频率**：

```bash
# 改为每5分钟
*/5 * * * * /usr/local/bin/clash-auto-switch.sh auto >> /var/log/clash/auto-switch.log 2>&1

# 改为每30分钟
*/30 * * * * /usr/local/bin/clash-auto-switch.sh auto >> /var/log/clash/auto-switch.log 2>&1
```

---

## 故障排查

### 问题 1：脚本无法连接 Clash API

**症状**：

```
[ERROR] 未找到可用节点
```

**排查步骤**：

1. **检查 Clash 运行状态**

   ```bash
   docker ps | grep clash
   ```

2. **测试 API 连接**

   ```bash
   curl -H "Authorization: Bearer openclaw2026" http://127.0.0.1:9090/proxies
   ```

3. **检查密钥配置**

   ```bash
   # 查看 Clash 配置
   cat /volume1/openclaw-deploy/clash/config.yaml | grep secret

   # 应该看到: secret: "openclaw2026"
   ```

### 问题 2：节点列表为空

**症状**：

```
[INFO] 未找到 美国 区域节点
```

**原因**：

- Clash 配置中没有订阅节点
- 订阅链接未更新

**解决方法**：

1. **重新下载订阅配置**

   ```bash
   cd /volume1/openclaw-deploy/clash

   # 备份当前配置
   cp config.yaml config.yaml.backup

   # 下载新配置
   curl -o config.yaml "你的订阅链接"

   # 重启 Clash
   docker restart clash
   ```

2. **验证节点列表**
   ```bash
   clash-auto-switch.sh list
   ```

### 问题 3：自动切换不生效

**症状**：

- 代理故障但没有自动切换
- 日志没有更新

**排查步骤**：

1. **检查定时任务是否运行**

   ```bash
   # 查看定时任务
   crontab -l

   # 查看 cron 日志
   grep clash /var/log/cron
   ```

2. **查看自动切换日志**

   ```bash
   tail -n 50 /var/log/clash/auto-switch.log
   ```

3. **手动执行测试**

   ```bash
   /usr/local/bin/clash-auto-switch.sh auto
   ```

4. **检查脚本权限**
   ```bash
   ls -l /usr/local/bin/clash-auto-switch.sh
   # 应该是 -rwxr-xr-x
   ```

### 问题 4：切换后仍不可用

**症状**：

```
[ERROR] 切换后仍不健康
```

**可能原因**：

- 所有节点都不可用
- 订阅过期或被封禁
- 网络环境问题

**解决方法**：

1. **测试所有节点延迟**

   ```bash
   clash-auto-switch.sh list

   # 然后逐个测试
   for node in $(clash-auto-switch.sh list | grep -v "===" | awk '{print $2}'); do
       echo "Testing: $node"
       clash-auto-switch.sh switch "$node"
       sleep 5
       clash-auto-switch.sh check
   done
   ```

2. **更新订阅**

   ```bash
   # 联系 VPN 提供商获取最新订阅链接
   ```

3. **检查 Clash 日志**
   ```bash
   docker logs clash
   ```

### 问题 5：频繁切换节点

**症状**：

- 节点每隔几分钟就切换
- 日志显示频繁的切换操作

**原因**：

- `tolerance` 参数设置过小
- 节点延迟波动大

**解决方法**：

修改 Clash 配置中的 `tolerance` 参数：

```yaml
proxy-groups:
  - name: "PROXY"
    type: url-test
    tolerance: 200 # 增大到 200ms（原来是 100ms）
```

然后重启 Clash：

```bash
docker restart clash
```

---

## 高级技巧

### 1. 自定义测试目标

编辑脚本，添加更多测试目标：

```bash
TEST_TARGETS=(
    "https://api.telegram.org"
    "https://api.anthropic.com"
    "https://generativelanguage.googleapis.com"
    "https://api.openai.com"          # 新增
    "https://www.google.com"          # 新增
)
```

### 2. 设置区域优先级

修改优先区域列表：

```bash
# 优先美国，然后新加坡，最后日本
PREFERRED_REGIONS=("美国" "US" "新加坡" "SG" "日本" "JP")
```

### 3. 结合 OpenClaw 健康检查

在 OpenClaw 监控脚本中调用：

```bash
#!/bin/bash
# openclaw-health-check.sh

# 检查 OpenClaw 服务
if ! docker exec openclaw-gateway curl -s http://localhost:18789/health; then
    echo "OpenClaw 不健康，检查代理..."

    # 触发代理切换
    /usr/local/bin/clash-auto-switch.sh auto

    # 重启 OpenClaw
    docker restart openclaw-gateway
fi
```

### 4. 发送通知

切换成功后发送 Telegram 通知：

```bash
# 在 clash-auto-switch.sh 的 auto_switch 函数末尾添加：

if [ $? -eq 0 ]; then
    # 通过 OpenClaw 发送通知
    curl -X POST http://localhost:18789/api/send \
        -H "Content-Type: application/json" \
        -d '{"message":"代理已自动切换到: '"$best_proxy"'"}'
fi
```

---

## 性能优化

### 减少测速开销

**问题**：测试所有节点会花费较长时间

**解决**：只测试部分节点

```bash
# 修改 get_best_proxy 函数
get_best_proxy() {
    # 只测试前10个节点
    local proxies=$(get_all_proxies | grep -v "DIRECT\|REJECT" | head -10)

    # ... 其余代码保持不变
}
```

### 调整测速超时

```bash
# 修改测速超时时间
test_proxy_delay() {
    local proxy_name="$1"
    # 超时从5000ms改为3000ms
    local delay=$(clash_api_get "/proxies/${proxy_name}/delay?timeout=3000&url=http://www.gstatic.com/generate_204" | jq -r '.delay')
    # ...
}
```

---

## 参考资料

- [Clash 官方文档](https://github.com/Dreamacro/clash/wiki)
- [Clash 配置示例](https://github.com/Dreamacro/clash/wiki/configuration)
- [OpenClaw 网络修复指南](./NETWORK-FIX-GUIDE.md)
- [OpenClaw 部署文档](./CLAUDE.md)

---

## 更新日志

### 2026-02-26 v1.0

- ✨ 初始版本
- ✨ 支持自动健康检查
- ✨ 支持智能节点切换
- ✨ 支持区域优先选择
- ✨ 定时任务自动化
- 📝 完整使用文档
