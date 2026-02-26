#!/bin/bash

################################################################################
# OpenClaw Docker 网络修复脚本
# 版本: 1.0
# 用途: 修复已部署的 OpenClaw 和 Clash 容器网络配置
#       解决容器间无法通过名称互相访问的问题
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_success() { echo -e "${GREEN}${BOLD}✓ $1${NC}"; }

echo "═══════════════════════════════════════════════════════════"
echo "          OpenClaw Docker 网络修复脚本 v1.0"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 权限运行 (sudo -i)"
fi

# 检查容器是否存在
log_info "检查容器状态..."
CLASH_EXISTS=$(docker ps -a --filter "name=clash" --format "{{.Names}}" 2>/dev/null)
OPENCLAW_EXISTS=$(docker ps -a --filter "name=openclaw-gateway" --format "{{.Names}}" 2>/dev/null)

if [ -z "$CLASH_EXISTS" ]; then
    log_error "未找到 clash 容器"
fi

if [ -z "$OPENCLAW_EXISTS" ]; then
    log_error "未找到 openclaw-gateway 容器"
fi

log_success "容器检查完成"
echo ""

# 创建 openclaw-net 网络
log_info "创建自定义 Docker 网络..."
if docker network inspect openclaw-net >/dev/null 2>&1; then
    log_info "网络 openclaw-net 已存在"
else
    docker network create openclaw-net || log_error "网络创建失败"
    log_success "网络 openclaw-net 创建成功"
fi
echo ""

# 连接 Clash 容器到网络
log_info "连接 Clash 容器到 openclaw-net..."
if docker network inspect openclaw-net | grep -q "clash"; then
    log_info "Clash 已连接到 openclaw-net"
else
    docker network connect openclaw-net clash || log_error "Clash 连接失败"
    log_success "Clash 已连接到 openclaw-net"
fi
echo ""

# 连接 OpenClaw 容器到网络
log_info "连接 OpenClaw 容器到 openclaw-net..."
if docker network inspect openclaw-net | grep -q "openclaw-gateway"; then
    log_info "OpenClaw 已连接到 openclaw-net"
else
    docker network connect openclaw-net openclaw-gateway || log_error "OpenClaw 连接失败"
    log_success "OpenClaw 已连接到 openclaw-net"
fi
echo ""

# 测试网络连通性
log_info "测试网络连通性..."
if docker exec openclaw-gateway sh -c 'curl -x http://clash:7890 -s -m 5 -I https://api.telegram.org' >/dev/null 2>&1; then
    log_success "网络连通性测试通过！"
else
    log_warn "网络测试失败，可能需要重启容器"
fi
echo ""

# 询问是否重启容器
read -p "$(echo -e ${YELLOW}是否重启 OpenClaw 容器以应用新配置？[y/N]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "重启 OpenClaw 容器..."
    docker restart openclaw-gateway

    log_info "等待服务启动（30秒）..."
    sleep 30

    log_info "检查服务状态..."
    docker logs --tail 20 openclaw-gateway

    echo ""
    log_success "容器已重启！"
else
    log_info "跳过重启，请稍后手动重启: docker restart openclaw-gateway"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "              🎉 网络修复完成！"
echo "═══════════════════════════════════════════════════════════"
echo ""
log_info "容器现在已连接到 openclaw-net 网络"
log_info "OpenClaw 可以通过 'clash' 主机名访问代理服务"
echo ""
log_info "验证命令："
echo "  docker network inspect openclaw-net"
echo "  docker exec openclaw-gateway curl -x http://clash:7890 -I https://api.telegram.org"
echo ""
