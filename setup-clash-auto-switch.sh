#!/bin/bash

################################################################################
# Clash 自动切换服务部署脚本
# 版本: 1.0
# 功能: 部署定时健康检查和自动切换服务
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

echo "═══════════════════════════════════════════════════════════"
echo "       Clash 自动切换服务部署脚本 v1.0"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 权限运行 (sudo -i)"
fi

# 配置变量
SCRIPT_NAME="clash-auto-switch.sh"
INSTALL_DIR="/usr/local/bin"
LOG_DIR="/var/log/clash"
CRON_INTERVAL="*/10"  # 每10分钟检查一次

# 检查脚本是否存在
if [ ! -f "$SCRIPT_NAME" ]; then
    log_error "未找到 ${SCRIPT_NAME}，请确保脚本在当前目录"
fi

# 1. 安装脚本
log_info "安装切换脚本到 ${INSTALL_DIR}..."
cp "$SCRIPT_NAME" "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
log_success "脚本已安装"

# 2. 创建日志目录
log_info "创建日志目录..."
mkdir -p "$LOG_DIR"
log_success "日志目录: ${LOG_DIR}"

# 3. 测试脚本
log_info "测试脚本功能..."
if "${INSTALL_DIR}/${SCRIPT_NAME}" check >/dev/null 2>&1; then
    log_success "脚本测试通过"
else
    log_warn "脚本测试失败，但将继续安装"
fi

# 4. 配置定时任务
log_info "配置定时任务..."

# 检查是否已存在定时任务
if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
    log_warn "检测到已存在的定时任务，将先删除"
    crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | crontab -
fi

# 添加定时任务
(
    crontab -l 2>/dev/null || true
    echo "# Clash 自动健康检查和切换（每10分钟）"
    echo "${CRON_INTERVAL} * * * * ${INSTALL_DIR}/${SCRIPT_NAME} auto >> ${LOG_DIR}/auto-switch.log 2>&1"
    echo ""
    echo "# 每天清理日志（保留最近100行）"
    echo "0 3 * * * tail -n 100 ${LOG_DIR}/auto-switch.log > ${LOG_DIR}/auto-switch.log.tmp && mv ${LOG_DIR}/auto-switch.log.tmp ${LOG_DIR}/auto-switch.log"
) | crontab -

log_success "定时任务已配置"

# 5. 立即执行一次测试
log_info "立即执行一次自动切换..."
"${INSTALL_DIR}/${SCRIPT_NAME}" auto | tee "${LOG_DIR}/auto-switch.log"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "              🎉 部署完成！"
echo "═══════════════════════════════════════════════════════════"
echo ""
log_success "Clash 自动切换服务已成功部署"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 服务信息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "脚本位置: ${INSTALL_DIR}/${SCRIPT_NAME}"
echo "日志目录:  ${LOG_DIR}/"
echo "定时任务:  每10分钟自动检查并切换"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 常用命令"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  # 手动检查健康状态"
echo "  ${SCRIPT_NAME} check"
echo ""
echo "  # 手动触发自动切换"
echo "  ${SCRIPT_NAME} auto"
echo ""
echo "  # 列出所有节点"
echo "  ${SCRIPT_NAME} list"
echo ""
echo "  # 切换到美国节点"
echo "  ${SCRIPT_NAME} us"
echo ""
echo "  # 切换到新加坡节点"
echo "  ${SCRIPT_NAME} sg"
echo ""
echo "  # 查看自动切换日志"
echo "  tail -f ${LOG_DIR}/auto-switch.log"
echo ""
echo "  # 查看定时任务"
echo "  crontab -l"
echo ""
echo "  # 临时禁用自动切换"
echo "  crontab -e  # 注释掉相关行"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
