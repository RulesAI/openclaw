#!/bin/bash

################################################################################
# OpenClaw 极空间 NAS 一键部署脚本（无需 Docker Compose）
# 版本: 2.1
# 说明: 使用纯 docker run 命令，不依赖 docker-compose
################################################################################

set -e
set -o pipefail

# 配置变量
DEPLOY_BASE="/volume1/openclaw-deploy"
CLASH_DIR="${DEPLOY_BASE}/clash"
OPENCLAW_DIR="${DEPLOY_BASE}/openclaw"
OPENCLAW_SOURCE_DIR="${DEPLOY_BASE}/openclaw-source"
NAS_IP="192.168.3.185"
CLASH_PROXY_PORT="7890"
CLASH_CONTROL_PORT="9090"
OPENCLAW_PORT="18789"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}${BOLD}▶ $1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}✓ $1${NC}"; }

# 显示欢迎信息
show_welcome() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "     OpenClaw 极空间 NAS 一键部署脚本 v2.1"
    echo "     (无需 Docker Compose 版本)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "本脚本将自动完成以下任务："
    echo "  1. 部署 Clash 科学上网代理"
    echo "  2. 配置 Docker 全局代理"
    echo "  3. 构建 OpenClaw Docker 镜像"
    echo "  4. 部署 OpenClaw AI Gateway"
    echo "  5. 配置多个 LLM 提供商"
    echo ""
    log_warn "预计耗时：20-30分钟（取决于网络速度）"
    echo ""
    read -p "$(echo -e ${CYAN}是否继续？[y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "部署已取消"
    fi
}

# 收集配置信息
collect_config() {
    log_step "【阶段 1/7】收集配置信息"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Clash 订阅配置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}Clash订阅链接用于科学上网${NC}"
    echo ""
    read -p "请输入 Clash 订阅链接: " CLASH_SUBSCRIPTION_URL
    if [ -z "$CLASH_SUBSCRIPTION_URL" ]; then
        log_warn "未提供订阅链接，将创建空配置模板"
    fi
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Claude API 配置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入 Claude API Key [留空跳过]: " CLAUDE_API_KEY
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Google Gemini API 配置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入 Google API Key [留空跳过]: " GOOGLE_API_KEY
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}OpenAI API 配置（可选）${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入 OpenAI API Key [留空跳过]: " OPENAI_API_KEY
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Gateway 访问配置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入 Gateway Token [留空自动生成]: " GATEWAY_TOKEN
    if [ -z "$GATEWAY_TOKEN" ]; then
        GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        log_info "已生成随机 Token: ${GATEWAY_TOKEN}"
    fi
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}配置信息确认${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Clash 订阅: ${CLASH_SUBSCRIPTION_URL:0:50}..."
    echo "Claude API: ${CLAUDE_API_KEY:+已配置}${CLAUDE_API_KEY:-未配置}"
    echo "Google API: ${GOOGLE_API_KEY:+已配置}${GOOGLE_API_KEY:-未配置}"
    echo "OpenAI API: ${OPENAI_API_KEY:+已配置}${OPENAI_API_KEY:-未配置}"
    echo "Gateway Token: ${GATEWAY_TOKEN:0:20}..."
    echo ""

    read -p "$(echo -e ${CYAN}确认配置无误？[y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "已取消"
    fi

    echo ""
    sleep 2
}

# 环境检查
check_environment() {
    log_step "【阶段 2/7】环境检查"
    echo ""

    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行 (sudo -i)"
    fi
    log_success "Root 权限检查通过"

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
    fi
    log_success "Docker 已安装: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"

    if ! docker ps &> /dev/null; then
        log_error "Docker 未运行"
    fi
    log_success "Docker 运行正常"

    AVAILABLE_SPACE=$(df -BG /volume1 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        log_warn "可用空间不足 10GB，当前: ${AVAILABLE_SPACE}GB"
    else
        log_success "可用空间: ${AVAILABLE_SPACE}GB"
    fi

    mkdir -p "${DEPLOY_BASE}"
    log_success "部署目录: ${DEPLOY_BASE}"

    echo ""
    sleep 2
}

# 创建 Docker 网络
create_network() {
    log_step "【阶段 2.5/7】创建 Docker 网络"
    echo ""

    # 检查网络是否已存在
    if docker network inspect openclaw-net >/dev/null 2>&1; then
        log_info "检测到已存在的 openclaw-net 网络"
    else
        log_info "创建自定义 Docker 网络: openclaw-net"
        docker network create openclaw-net || log_error "网络创建失败"
        log_success "Docker 网络创建成功"
    fi

    echo ""
    sleep 2
}

# 部署 Clash
deploy_clash() {
    log_step "【阶段 3/7】部署 Clash 代理"
    echo ""

    mkdir -p "${CLASH_DIR}"
    cd "${CLASH_DIR}"

    # 下载 GeoIP
    log_info "下载 GeoIP 数据库..."
    if [ ! -f "Country.mmdb" ]; then
        curl -sL https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb -o Country.mmdb 2>/dev/null || \
        curl -sL https://ghproxy.com/https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb -o Country.mmdb || \
        touch Country.mmdb
    fi
    log_success "GeoIP 数据库准备完成"

    # Clash 配置
    log_info "配置 Clash..."
    if [ -n "$CLASH_SUBSCRIPTION_URL" ]; then
        curl -sL "$CLASH_SUBSCRIPTION_URL" -o config.yaml || log_error "订阅下载失败"
        log_success "订阅配置下载成功"
    else
        log_warn "创建基础配置模板"
        cat > config.yaml << 'EOF'
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: "openclaw2026"

proxies:
  - name: "DIRECT"
    type: direct

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

rules:
  - DOMAIN-SUFFIX,anthropic.com,PROXY
  - DOMAIN-SUFFIX,claude.ai,PROXY
  - DOMAIN-SUFFIX,googleapis.com,PROXY
  - DOMAIN-SUFFIX,google.com,PROXY
  - DOMAIN-SUFFIX,openai.com,PROXY
  - DOMAIN-SUFFIX,github.com,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
EOF
    fi

    # 停止旧容器
    docker stop clash 2>/dev/null || true
    docker rm clash 2>/dev/null || true

    # 启动 Clash
    log_info "启动 Clash 容器..."
    docker run -d \
        --name clash \
        --restart unless-stopped \
        --network openclaw-net \
        -p ${CLASH_PROXY_PORT}:7890 \
        -p ${CLASH_CONTROL_PORT}:9090 \
        -v "${CLASH_DIR}/config.yaml:/root/.config/clash/config.yaml" \
        -v "${CLASH_DIR}/Country.mmdb:/root/.config/clash/Country.mmdb" \
        -e TZ=Asia/Shanghai \
        dreamacro/clash-premium:latest

    # 等待启动
    log_info "等待 Clash 启动..."
    for i in {1..30}; do
        if curl -s http://127.0.0.1:${CLASH_CONTROL_PORT} >/dev/null 2>&1; then
            log_success "Clash 启动成功！"
            break
        fi
        [ $i -eq 30 ] && log_error "Clash 启动超时"
        sleep 1
    done

    # 测试代理
    if curl -x http://127.0.0.1:${CLASH_PROXY_PORT} -s -m 5 https://www.google.com >/dev/null 2>&1; then
        log_success "代理工作正常！"
    else
        log_warn "代理测试失败（可能需要手动配置节点）"
    fi

    echo ""
    log_info "Clash 控制面板: http://${NAS_IP}:${CLASH_CONTROL_PORT}"
    log_info "控制面板密钥: openclaw2026"
    echo ""
    sleep 2
}

# 构建 OpenClaw
build_openclaw() {
    log_step "【阶段 4/7】构建 OpenClaw 镜像"
    echo ""

    if docker images | grep -q "openclaw.*local"; then
        log_warn "检测到已存在的 OpenClaw 镜像"
        read -p "$(echo -e ${CYAN}是否重新构建？[y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "跳过构建，使用现有镜像"
            return 0
        fi
    fi

    cd "${DEPLOY_BASE}"

    if [ ! -d "${OPENCLAW_SOURCE_DIR}" ]; then
        log_info "克隆 OpenClaw 仓库..."

        export HTTP_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"
        export HTTPS_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"

        if ! git clone --depth=1 https://github.com/openclaw/openclaw.git "${OPENCLAW_SOURCE_DIR}" 2>/dev/null; then
            log_info "使用国内镜像..."
            git clone --depth=1 https://ghproxy.com/https://github.com/openclaw/openclaw.git "${OPENCLAW_SOURCE_DIR}" || \
                log_error "仓库克隆失败"
        fi
        log_success "仓库克隆完成"

        unset HTTP_PROXY HTTPS_PROXY
    else
        log_info "使用已存在的源码目录"
    fi

    cd "${OPENCLAW_SOURCE_DIR}"

    log_info "开始构建 Docker 镜像（预计 10-15 分钟）..."
    log_warn "构建过程较长，请耐心等待..."
    echo ""

    docker build \
        --build-arg HTTP_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}" \
        --build-arg HTTPS_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}" \
        -t openclaw:local \
        -f Dockerfile . || log_error "镜像构建失败"

    echo ""
    log_success "OpenClaw 镜像构建完成！"
    docker images | grep openclaw
    echo ""
    sleep 2
}

# 部署 OpenClaw
deploy_openclaw() {
    log_step "【阶段 5/7】部署 OpenClaw 服务"
    echo ""

    mkdir -p "${OPENCLAW_DIR}"/{config,workspace,data,logs}
    cd "${OPENCLAW_DIR}"

    log_info "创建配置文件..."

    # 创建 .env 文件（用于记录）
    cat > .env << EOF
# OpenClaw 环境变量配置
# 生成时间: $(date)

OPENCLAW_IMAGE=openclaw:local
OPENCLAW_CONFIG_DIR=${OPENCLAW_DIR}/config
OPENCLAW_WORKSPACE_DIR=${OPENCLAW_DIR}/workspace
OPENCLAW_GATEWAY_PORT=${OPENCLAW_PORT}
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}

HTTP_PROXY=http://${NAS_IP}:${CLASH_PROXY_PORT}
HTTPS_PROXY=http://${NAS_IP}:${CLASH_PROXY_PORT}

CLAUDE_AI_SESSION_KEY=${CLAUDE_API_KEY}
GOOGLE_API_KEY=${GOOGLE_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}

TZ=Asia/Shanghai
NODE_ENV=production
EOF

    log_success "配置文件已创建"

    # 停止旧容器
    docker stop openclaw-gateway 2>/dev/null || true
    docker rm openclaw-gateway 2>/dev/null || true

    # 启动 OpenClaw
    log_info "启动 OpenClaw 服务..."
    docker run -d \
        --name openclaw-gateway \
        --restart unless-stopped \
        --init \
        --network openclaw-net \
        -p ${OPENCLAW_PORT}:18789 \
        -p 18790:18790 \
        -v "${OPENCLAW_DIR}/config:/home/node/.openclaw" \
        -v "${OPENCLAW_DIR}/workspace:/home/node/.openclaw/workspace" \
        -e HOME=/home/node \
        -e TERM=xterm-256color \
        -e TZ=Asia/Shanghai \
        -e NODE_ENV=production \
        -e OPENCLAW_GATEWAY_TOKEN="${GATEWAY_TOKEN}" \
        -e OPENCLAW_GATEWAY_BIND=lan \
        -e HTTP_PROXY="http://clash:${CLASH_PROXY_PORT}" \
        -e HTTPS_PROXY="http://clash:${CLASH_PROXY_PORT}" \
        -e NO_PROXY=localhost,127.0.0.1 \
        -e CLAUDE_AI_SESSION_KEY="${CLAUDE_API_KEY}" \
        -e GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
        -e GOOGLE_GENERATIVE_AI_API_KEY="${GOOGLE_API_KEY}" \
        -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
        openclaw:local \
        node dist/index.js gateway --allow-unconfigured

    # 等待服务启动
    log_info "等待服务启动（可能需要 1-2 分钟）..."
    for i in {1..60}; do
        if curl -s http://127.0.0.1:${OPENCLAW_PORT}/health >/dev/null 2>&1; then
            log_success "OpenClaw 服务启动成功！"
            break
        fi
        [ $i -eq 60 ] && log_warn "服务启动超时，请检查日志"
        sleep 2
    done

    echo ""
    sleep 2
}

# 配置远程访问
configure_remote_access() {
    log_step "【阶段 6/7】配置远程访问"
    echo ""

    log_info "远程访问配置选项："
    echo "  1. 节点小宝（P2P 内网穿透）- 推荐"
    echo "  2. DDNS（需要公网 IP）"
    echo "  3. 极空间官方远程访问"
    echo "  4. 稍后手动配置"
    echo ""

    read -p "$(echo -e ${CYAN}请选择 [1-4，默认 4]: ${NC})" -n 1 -r REMOTE_CHOICE
    echo ""

    case $REMOTE_CHOICE in
        1)
            log_info "请在极空间 Web 界面配置节点小宝："
            echo "  1. 点击'节点小宝'图标"
            echo "  2. 登录极空间账号并完成绑定"
            echo "  3. 获取虚拟 IP 后配置远程访问"
            ;;
        2)
            log_info "请在极空间 Web 界面配置 DDNS："
            echo "  1. 点击 'DDNS' 图标"
            echo "  2. 选择服务商并填写配置"
            echo "  3. 配置路由器端口转发：${OPENCLAW_PORT}"
            ;;
        3)
            log_info "请在极空间 Web 界面配置官方远程访问"
            ;;
        *)
            log_info "跳过远程访问配置"
            ;;
    esac

    echo ""
    sleep 2
}

# 显示结果
show_result() {
    log_step "【阶段 7/7】部署完成"
    echo ""

    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "              🎉 部署成功完成！"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_success "OpenClaw AI Gateway 已成功部署！"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 访问信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "OpenClaw Gateway:"
    echo "  局域网地址: http://${NAS_IP}:${OPENCLAW_PORT}"
    echo "  Gateway Token: ${GATEWAY_TOKEN}"
    echo ""
    echo "Clash 控制面板:"
    echo "  访问地址: http://${NAS_IP}:${CLASH_CONTROL_PORT}"
    echo "  控制密钥: openclaw2026"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 重要文件位置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Clash 配置:   ${CLASH_DIR}/config.yaml"
    echo "  OpenClaw 配置: ${OPENCLAW_DIR}/.env"
    echo "  工作目录:     ${OPENCLAW_DIR}/workspace"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 常用命令"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  # 查看 OpenClaw 状态"
    echo "  docker ps | grep openclaw"
    echo ""
    echo "  # 查看 OpenClaw 日志"
    echo "  docker logs -f openclaw-gateway"
    echo ""
    echo "  # 重启 OpenClaw"
    echo "  docker restart openclaw-gateway"
    echo ""
    echo "  # 停止 OpenClaw"
    echo "  docker stop openclaw-gateway"
    echo ""
    echo "  # 更新 API 密钥后重启"
    echo "  vi ${OPENCLAW_DIR}/.env"
    echo "  docker restart openclaw-gateway"
    echo ""

    # 保存部署信息
    cat > "${DEPLOY_BASE}/deployment-info.txt" << EOF
OpenClaw 部署信息
部署时间: $(date)

访问地址:
- OpenClaw: http://${NAS_IP}:${OPENCLAW_PORT}
- Clash 面板: http://${NAS_IP}:${CLASH_CONTROL_PORT}

重要配置:
- Gateway Token: ${GATEWAY_TOKEN}
- Clash 密钥: openclaw2026

容器管理:
- Clash 容器: docker logs -f clash
- OpenClaw 容器: docker logs -f openclaw-gateway

文件位置:
- Clash: ${CLASH_DIR}/config.yaml
- OpenClaw: ${OPENCLAW_DIR}/.env
- 工作目录: ${OPENCLAW_DIR}/workspace
EOF

    log_success "部署信息已保存到: ${DEPLOY_BASE}/deployment-info.txt"
    echo ""

    echo "═══════════════════════════════════════════════════════════"
    echo "  🎉 所有步骤已完成！享受你的 OpenClaw AI 助手吧！"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# 主函数
main() {
    show_welcome
    collect_config
    check_environment
    create_network
    deploy_clash
    build_openclaw
    deploy_openclaw
    configure_remote_access
    show_result
}

# 执行主函数
main
