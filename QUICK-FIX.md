# 🚀 OpenClaw 网络问题快速修复

## 症状

- ✅ OpenClaw 容器运行正常
- ✅ Clash 代理容器运行正常
- ❌ Telegram 报错：`Network request for 'xxx' failed!`
- ❌ OpenClaw 无法访问需要代理的服务

## 一行命令修复

```bash
# 在 NAS 上以 root 身份执行：
curl -sSL https://raw.githubusercontent.com/openclaw/openclaw/main/fix-openclaw-network.sh | bash
```

或者手动上传并执行：

```bash
# 1. 上传脚本
scp fix-openclaw-network.sh 13911033691@192.168.3.185:/tmp/

# 2. SSH 登录
ssh -p 10000 13911033691@192.168.3.185

# 3. 执行修复（需要 root）
sudo bash /tmp/fix-openclaw-network.sh
```

## 验证修复

```bash
# 应该看到 HTTP/1.1 200
docker exec openclaw-gateway curl -x http://clash:7890 -I https://api.telegram.org

# 应该没有 "failed" 错误
docker logs --tail 50 openclaw-gateway | grep telegram
```

## 问题原因

Docker 默认 bridge 网络不支持容器名称解析。修复脚本会：

1. 创建 `openclaw-net` 自定义网络
2. 将两个容器连接到该网络
3. 使容器可以通过名称互相访问

详细说明请查看 [NETWORK-FIX-GUIDE.md](./NETWORK-FIX-GUIDE.md)
