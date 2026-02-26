#!/bin/bash

################################################################################
# Clash 自动切换通用安装脚本
# 版本: 1.0
# 支持: Linux, macOS, WSL
# 用途: 一键安装 Clash 代理自动切换工具
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_step() { echo -e "${BLUE}${BOLD}▶ $1${NC}"; }

# 显示欢迎信息
show_welcome() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "      Clash 自动切换工具通用安装脚本 v1.0"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "本脚本将自动完成以下任务："
    echo "  1. 检测系统环境"
    echo "  2. 安装必要依赖（jq）"
    echo "  3. 配置 Clash 连接参数"
    echo "  4. 安装自动切换脚本"
    echo "  5. 配置定时任务（可选）"
    echo ""
}

# 检测操作系统
detect_os() {
    log_step "【步骤 1/6】检测操作系统"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            log_success "Linux 系统: $PRETTY_NAME"
        else
            DISTRO="unknown"
            log_success "Linux 系统"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        log_success "macOS 系统"
    else
        log_error "不支持的操作系统: $OSTYPE"
    fi

    echo ""
}

# 检查依赖
check_dependencies() {
    log_step "【步骤 2/6】检查依赖"

    # 检查 curl
    if command -v curl &> /dev/null; then
        log_success "curl 已安装"
    else
        log_error "curl 未安装，请先安装 curl"
    fi

    # 检查 jq
    if command -v jq &> /dev/null; then
        JQ_INSTALLED=true
        log_success "jq 已安装: $(jq --version)"
    else
        JQ_INSTALLED=false
        log_warn "jq 未安装"
    fi

    echo ""
}

# 安装 jq
install_jq() {
    if [ "$JQ_INSTALLED" = true ]; then
        return 0
    fi

    log_step "【步骤 3/6】安装 jq"

    log_info "正在安装 jq..."

    case "$DISTRO" in
        ubuntu|debian)
            sudo apt-get update && sudo apt-get install -y jq
            ;;
        centos|rhel|fedora)
            sudo yum install -y jq || sudo dnf install -y jq
            ;;
        arch)
            sudo pacman -S --noconfirm jq
            ;;
        alpine)
            sudo apk add jq
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install jq
            else
                log_warn "未检测到 Homebrew，尝试下载预编译版本..."
                sudo curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-osx-amd64 -o /usr/local/bin/jq
                sudo chmod +x /usr/local/bin/jq
            fi
            ;;
        *)
            log_warn "自动安装不支持您的系统，尝试下载预编译版本..."
            if [ "$OS" = "linux" ]; then
                sudo curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o /usr/local/bin/jq
                sudo chmod +x /usr/local/bin/jq
            else
                log_error "无法自动安装 jq，请手动安装后重试"
            fi
            ;;
    esac

    if command -v jq &> /dev/null; then
        log_success "jq 安装成功"
    else
        log_error "jq 安装失败"
    fi

    echo ""
}

# 配置 Clash 连接
configure_clash() {
    log_step "【步骤 4/6】配置 Clash 连接"
    echo ""

    # Clash API 地址
    echo -e "${CYAN}请输入 Clash API 地址${NC}"
    echo -e "${YELLOW}默认: http://127.0.0.1:9090${NC}"
    read -p "Clash API: " CLASH_API
    CLASH_API=${CLASH_API:-http://127.0.0.1:9090}

    # Clash Secret
    echo ""
    echo -e "${CYAN}请输入 Clash API 密钥（secret）${NC}"
    echo -e "${YELLOW}查看方法: cat /path/to/clash/config.yaml | grep secret${NC}"
    read -p "Clash Secret: " CLASH_SECRET

    if [ -z "$CLASH_SECRET" ]; then
        log_warn "未设置密钥，某些 Clash 版本可能需要"
    fi

    # 代理地址
    echo ""
    echo -e "${CYAN}请输入代理地址（用于健康检查）${NC}"
    echo -e "${YELLOW}默认: http://127.0.0.1:7890${NC}"
    read -p "代理地址: " PROXY_URL
    PROXY_URL=${PROXY_URL:-http://127.0.0.1:7890}

    # 优先区域
    echo ""
    echo -e "${CYAN}请输入优先区域（空格分隔）${NC}"
    echo -e "${YELLOW}默认: 美国 🇺🇲 US 新加坡 🇸🇬 SG${NC}"
    echo -e "${YELLOW}示例: 香港 HK 台湾 TW${NC}"
    read -p "优先区域: " PREFERRED_REGIONS
    PREFERRED_REGIONS=${PREFERRED_REGIONS:-美国 🇺🇲 US 新加坡 🇸🇬 SG}

    echo ""
    log_success "配置完成"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "配置摘要："
    echo "  Clash API:  $CLASH_API"
    echo "  密钥:       ${CLASH_SECRET:+已设置}${CLASH_SECRET:-未设置}"
    echo "  代理地址:   $PROXY_URL"
    echo "  优先区域:   $PREFERRED_REGIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "$(echo -e ${CYAN}确认配置？[y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "已取消，请重新运行脚本"
    fi

    echo ""
}

# 安装脚本
install_script() {
    log_step "【步骤 5/6】安装自动切换脚本"
    echo ""

    # 确定安装路径
    if [ -w /usr/local/bin ]; then
        INSTALL_DIR="/usr/local/bin"
    elif [ -w "$HOME/.local/bin" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"
    else
        log_error "无可写的安装目录，请使用 sudo 运行"
    fi

    log_info "安装目录: $INSTALL_DIR"

    # 检查脚本是否存在
    if [ ! -f "clash-auto-switch.sh" ]; then
        log_info "下载脚本..."
        curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/clash-auto-switch.sh -o clash-auto-switch.sh
        if [ $? -ne 0 ]; then
            log_error "脚本下载失败"
        fi
    fi

    # 修改配置
    log_info "应用配置..."
    sed -i.bak \
        -e "s|CLASH_API=\".*\"|CLASH_API=\"${CLASH_API}\"|" \
        -e "s|CLASH_SECRET=\".*\"|CLASH_SECRET=\"${CLASH_SECRET}\"|" \
        -e "s|PROXY_URL=\".*\"|PROXY_URL=\"${PROXY_URL}\"|" \
        -e "s|PREFERRED_REGIONS=(.*)|PREFERRED_REGIONS=(${PREFERRED_REGIONS})|" \
        clash-auto-switch.sh

    # 安装
    if [ "$INSTALL_DIR" = "/usr/local/bin" ]; then
        sudo cp clash-auto-switch.sh "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/clash-auto-switch.sh"
    else
        cp clash-auto-switch.sh "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/clash-auto-switch.sh"
    fi

    # 清理
    rm -f clash-auto-switch.sh.bak

    log_success "脚本已安装到: $INSTALL_DIR/clash-auto-switch.sh"

    # 测试
    log_info "测试脚本..."
    if "$INSTALL_DIR/clash-auto-switch.sh" check &> /dev/null; then
        log_success "脚本测试通过"
    else
        log_warn "脚本测试失败，请检查 Clash 配置"
    fi

    echo ""
}

# 配置定时任务
configure_cron() {
    log_step "【步骤 6/6】配置定时任务（可选）"
    echo ""

    read -p "$(echo -e ${CYAN}是否配置定时任务（每10分钟自动检查）？[Y/n]: ${NC})" -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "配置定时任务..."

        # 创建日志目录
        LOG_DIR="${HOME}/.local/log/clash"
        mkdir -p "$LOG_DIR"

        # 添加到 crontab
        (
            crontab -l 2>/dev/null | grep -v "clash-auto-switch" || true
            echo ""
            echo "# Clash 自动健康检查和切换（每10分钟）"
            echo "*/10 * * * * $INSTALL_DIR/clash-auto-switch.sh auto >> $LOG_DIR/auto-switch.log 2>&1"
            echo ""
            echo "# 每天清理日志"
            echo "0 3 * * * tail -n 200 $LOG_DIR/auto-switch.log > $LOG_DIR/auto-switch.log.tmp && mv $LOG_DIR/auto-switch.log.tmp $LOG_DIR/auto-switch.log"
        ) | crontab -

        log_success "定时任务已配置"
        log_info "日志位置: $LOG_DIR/auto-switch.log"
    else
        log_info "跳过定时任务配置"
    fi

    echo ""
}

# 显示完成信息
show_completion() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "              🎉 安装成功完成！"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_success "Clash 自动切换工具已成功安装"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 安装信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "脚本位置: $INSTALL_DIR/clash-auto-switch.sh"
    if [ -n "$LOG_DIR" ]; then
        echo "日志位置: $LOG_DIR/auto-switch.log"
    fi
    echo "Clash API: $CLASH_API"
    echo "代理地址: $PROXY_URL"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 常用命令"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  # 健康检查"
    echo "  clash-auto-switch.sh check"
    echo ""
    echo "  # 列出所有节点"
    echo "  clash-auto-switch.sh list"
    echo ""
    echo "  # 自动切换"
    echo "  clash-auto-switch.sh auto"
    echo ""

    # 根据优先区域显示快捷命令
    if echo "$PREFERRED_REGIONS" | grep -qi "美国\|US"; then
        echo "  # 切换到美国节点"
        echo "  clash-auto-switch.sh us"
        echo ""
    fi

    if echo "$PREFERRED_REGIONS" | grep -qi "新加坡\|SG\|Singapore"; then
        echo "  # 切换到新加坡节点"
        echo "  clash-auto-switch.sh sg"
        echo ""
    fi

    if [ -n "$LOG_DIR" ]; then
        echo "  # 查看自动切换日志"
        echo "  tail -f $LOG_DIR/auto-switch.log"
        echo ""
    fi

    echo "  # 查看帮助"
    echo "  clash-auto-switch.sh help"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主函数
main() {
    show_welcome
    detect_os
    check_dependencies
    install_jq
    configure_clash
    install_script
    configure_cron
    show_completion
}

# 执行主函数
main
