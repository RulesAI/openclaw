# OpenClaw Docker 网络修复指南

## 问题描述

在 OpenClaw 部署中，如果 Clash 代理容器和 OpenClaw Gateway 容器未连接到同一个自定义 Docker 网络，会导致以下问题：

- ❌ OpenClaw 无法通过容器名 `clash` 访问代理
- ❌ Telegram 通道连接失败（Network request failed）
- ❌ 所有需要代理的 API 请求失败（Google Gemini、Claude API 等）

**根本原因**：Docker 的默认 `bridge` 网络不支持容器名称解析，容器只能通过 IP 地址互相访问。

## 解决方案

### 方案 1：使用快速修复脚本（推荐）

适用于已部署的系统，无需重建容器。

#### 步骤：

1. **上传脚本到 NAS**

   ```bash
   scp fix-openclaw-network.sh 13911033691@192.168.3.185:/tmp/
   ```

2. **SSH 登录 NAS**

   ```bash
   ssh -p 10000 13911033691@192.168.3.185
   ```

3. **切换到 root**

   ```bash
   sudo -i
   ```

4. **执行修复脚本**

   ```bash
   bash /tmp/fix-openclaw-network.sh
   ```

5. **验证修复**

   ```bash
   # 检查网络配置
   docker network inspect openclaw-net

   # 测试 Telegram API 连通性
   docker exec openclaw-gateway curl -x http://clash:7890 -I https://api.telegram.org

   # 查看日志确认无错误
   docker logs --tail 50 openclaw-gateway | grep telegram
   ```

### 方案 2：重新部署（适用于新部署）

使用更新后的部署脚本：

#### Docker Compose 版本

```bash
bash deploy-openclaw-nas.sh
```

#### 纯 Docker Run 版本

```bash
bash deploy-openclaw-nas-no-compose.sh
```

## 修复内容说明

### 1. 创建自定义 Docker 网络

```bash
docker network create openclaw-net
```

### 2. 连接容器到自定义网络

**Clash 容器：**

```bash
docker network connect openclaw-net clash
```

**OpenClaw 容器：**

```bash
docker network connect openclaw-net openclaw-gateway
```

### 3. 网络配置对比

#### 修复前（❌ 错误配置）

```yaml
services:
  clash:
    network_mode: bridge # 默认 bridge 网络，不支持名称解析

  openclaw-gateway:
    network_mode: bridge # 默认 bridge 网络
    environment:
      - HTTP_PROXY=http://192.168.3.185:7890 # 必须使用 IP 地址
```

#### 修复后（✅ 正确配置）

```yaml
networks:
  openclaw-net:
    external: true

services:
  clash:
    networks:
      - openclaw-net # 自定义网络，支持名称解析

  openclaw-gateway:
    networks:
      - openclaw-net # 同一自定义网络
    environment:
      - HTTP_PROXY=http://clash:7890 # 可以使用容器名
```

## 验证清单

修复完成后，验证以下内容：

- [ ] 两个容器都在 `openclaw-net` 网络中
- [ ] OpenClaw 可以通过 `clash` 主机名访问代理
- [ ] Telegram 通道无连接错误
- [ ] API 请求正常工作

### 验证命令

```bash
# 1. 检查网络配置
docker network inspect openclaw-net

# 2. 测试容器名解析（在 openclaw-gateway 内）
docker exec openclaw-gateway getent hosts clash

# 3. 测试代理连通性
docker exec openclaw-gateway curl -x http://clash:7890 -I https://api.telegram.org

# 4. 查看 OpenClaw 日志（应该没有 "Network request failed" 错误）
docker logs --tail 100 openclaw-gateway | grep -E "(telegram|error)"

# 5. 检查通道状态
docker exec openclaw-gateway openclaw channels status 2>/dev/null || echo "需要安装 openclaw CLI"
```

## 常见问题

### Q1: 修复后仍然报错怎么办？

**A:** 需要重启 OpenClaw 容器以应用新的网络配置：

```bash
docker restart openclaw-gateway
```

### Q2: 如何查看容器的网络连接？

**A:** 使用以下命令：

```bash
docker inspect openclaw-gateway | grep -A 10 Networks
docker inspect clash | grep -A 10 Networks
```

### Q3: 可以删除旧的 bridge 网络连接吗？

**A:** 不建议删除。容器可以同时连接多个网络：

- `bridge`：用于端口映射（外部访问）
- `openclaw-net`：用于容器间通信

### Q4: 如何回滚？

**A:** 如果需要回滚，只需断开自定义网络：

```bash
docker network disconnect openclaw-net clash
docker network disconnect openclaw-net openclaw-gateway
docker network rm openclaw-net
```

## 技术原理

### Docker 网络类型对比

| 网络类型          | 容器名解析 | 用途               | 隔离性 |
| ----------------- | ---------- | ------------------ | ------ |
| **bridge (默认)** | ❌ 不支持  | 基本容器通信       | 低     |
| **自定义 bridge** | ✅ 支持    | 生产环境推荐       | 高     |
| **host**          | N/A        | 直接使用宿主机网络 | 无     |
| **none**          | N/A        | 完全隔离           | 完全   |

### 为什么需要自定义网络？

1. **DNS 解析**：自定义 bridge 网络内置 DNS 服务器，支持容器名解析
2. **网络隔离**：不同项目的容器可以使用不同的自定义网络，互不干扰
3. **安全性**：只有显式加入网络的容器才能互相访问
4. **灵活性**：容器可以同时连接多个网络，实现复杂的网络拓扑

### OpenClaw 网络架构

```
┌─────────────────────────────────────────────────┐
│               openclaw-net                      │
│  (自定义 bridge 网络 - 支持容器名解析)         │
│                                                 │
│  ┌──────────────────┐      ┌─────────────────┐ │
│  │  clash           │      │ openclaw-gateway│ │
│  │  (代理服务)      │◄─────┤  (AI Gateway)   │ │
│  │  172.18.0.2      │      │  172.18.0.3     │ │
│  └──────┬───────────┘      └────────┬────────┘ │
│         │                            │          │
└─────────┼────────────────────────────┼──────────┘
          │                            │
          │  (端口映射)                │  (端口映射)
          ▼                            ▼
    0.0.0.0:7890                 0.0.0.0:18789
    0.0.0.0:9090                 0.0.0.0:18790
```

## 更新日志

### 2026-02-26

- 🐛 修复：部署脚本默认使用 bridge 网络导致容器无法通信
- ✨ 新增：`fix-openclaw-network.sh` 快速修复脚本
- ✨ 新增：`create_network()` 函数到部署脚本
- 📝 更新：所有部署脚本使用 `openclaw-net` 自定义网络
- 📝 更新：代理配置从 IP 地址改为容器名（`http://clash:7890`）

## 参考资料

- [Docker 网络文档](https://docs.docker.com/network/)
- [OpenClaw CLAUDE.md](./CLAUDE.md) - 环境配置章节
- [Docker Networking Best Practices](https://docs.docker.com/network/bridge/)
