#!/bin/bash

#########################################
# OpenClaw 极空间交互式一键部署脚本 v2.0
# 自动部署：Clash代理 + OpenClaw AI Gateway
#
# 使用方法：
# 1. SSH登录: ssh -p 10000 13911033691@192.168.3.185
# 2. 切换root: sudo -i
# 3. 执行脚本: bash <(curl -fsSL https://raw.githubusercontent.com/.../deploy.sh)
#    或直接复制本脚本内容执行
#########################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}${BOLD}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"; }

# 配置变量
DEPLOY_BASE="/volume1/openclaw-deploy"
CLASH_DIR="${DEPLOY_BASE}/clash"
OPENCLAW_DIR="${DEPLOY_BASE}/openclaw"
OPENCLAW_SOURCE_DIR="${DEPLOY_BASE}/openclaw-source"
NAS_IP="192.168.3.185"
CLASH_PROXY_PORT="7890"
CLASH_CONTROL_PORT="9090"
OPENCLAW_PORT="18789"

# 显示欢迎界面
show_banner() {
    clear
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗       ║
║    ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║       ║
║    ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║       ║
║    ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║       ║
║    ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗  ║
║     ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝  ║
║                                                           ║
║         极空间 NAS 交互式一键部署脚本 v2.0                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

BANNER
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
        exit 1
    fi
}

# 收集用户配置
collect_config() {
    log_step "收集配置信息..."
    echo ""

    # Clash订阅链接
    log_info "【1/5】Clash 订阅配置"
    echo "----------------------------------------"
    echo -e "${YELLOW}Clash订阅链接用于科学上网，访问Claude/Google等API${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}请输入Clash订阅链接: ${NC})" CLASH_SUBSCRIPTION_URL

    if [ -z "$CLASH_SUBSCRIPTION_URL" ]; then
        log_warn "未提供订阅链接，将创建空配置模板（稍后需手动配置）"
        CLASH_SUBSCRIPTION_URL=""
    fi
    echo ""

    # Claude API
    log_info "【2/5】Claude API 配置"
    echo "----------------------------------------"
    echo -e "${YELLOW}Claude Session Key 格式: sk-ant-xxxxx${NC}"
    echo -e "${YELLOW}留空表示暂不配置，可以稍后添加${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}请输入Claude Session Key [留空跳过]: ${NC})" CLAUDE_API_KEY
    echo ""

    # Google API
    log_info "【3/5】Google Gemini API 配置"
    echo "----------------------------------------"
    echo -e "${YELLOW}Google API Key 格式: AIzaSyxxxxx${NC}"
    echo -e "${YELLOW}留空表示暂不配置，可以稍后添加${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}请输入Google API Key [留空跳过]: ${NC})" GOOGLE_API_KEY
    echo ""

    # OpenAI API (可选)
    log_info "【4/5】OpenAI API 配置（可选）"
    echo "----------------------------------------"
    echo -e "${YELLOW}OpenAI API Key 格式: sk-xxxxx${NC}"
    echo -e "${YELLOW}留空表示暂不配置${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}请输入OpenAI API Key [留空跳过]: ${NC})" OPENAI_API_KEY
    echo ""

    # Gateway Token
    log_info "【5/5】Gateway 访问配置"
    echo "----------------------------------------"
    echo -e "${YELLOW}留空将自动生成随机Token${NC}"
    echo ""
    read -p "$(echo -e ${CYAN}请输入Gateway Token [留空自动生成]: ${NC})" GATEWAY_TOKEN

    if [ -z "$GATEWAY_TOKEN" ]; then
        GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        log_info "已生成随机Token: ${GATEWAY_TOKEN}"
    fi
    echo ""

    # 确认配置
    log_info "配置信息确认："
    echo "----------------------------------------"
    echo "Clash订阅: ${CLASH_SUBSCRIPTION_URL:0:50}..."
    echo "Claude API: ${CLAUDE_API_KEY:+已配置}${CLAUDE_API_KEY:-未配置}"
    echo "Google API: ${GOOGLE_API_KEY:+已配置}${GOOGLE_API_KEY:-未配置}"
    echo "OpenAI API: ${OPENAI_API_KEY:+已配置}${OPENAI_API_KEY:-未配置}"
    echo "Gateway Token: ${GATEWAY_TOKEN:0:20}..."
    echo ""

    read -p "$(echo -e ${CYAN}确认配置无误？[y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "已取消，请重新运行脚本"
        exit 1
    fi
}

# 环境检查
check_environment() {
    log_step "【阶段1/7】环境检查"
    echo ""

    # 检查是否为root
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本 (sudo -i)"
        exit 1
    fi
    log_info "✓ Root权限检查通过"

    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或未启动"
        exit 1
    fi
    log_info "✓ Docker已安装: $(docker --version | cut -d' ' -f3)"

    # 检查Docker运行状态
    if ! docker ps &> /dev/null; then
        log_error "Docker未运行"
        exit 1
    fi
    log_info "✓ Docker运行正常"

    # 检查docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        log_error "Docker Compose未安装"
        exit 1
    fi
    log_info "✓ Docker Compose已安装"

    # 检查磁盘空间
    AVAILABLE_SPACE=$(df -BG /volume1 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        log_warn "可用磁盘空间不足10GB，当前: ${AVAILABLE_SPACE}GB"
        read -p "$(echo -e ${CYAN}是否继续？[y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_info "✓ 可用磁盘空间: ${AVAILABLE_SPACE}GB"
    fi

    # 检查网络
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_info "✓ 网络连接正常"
    else
        log_warn "网络连接测试失败（可能会影响部署）"
    fi

    # 创建部署目录
    mkdir -p "${DEPLOY_BASE}"
    log_info "✓ 部署目录: ${DEPLOY_BASE}"

    echo ""
    log_success "环境检查完成！"
    sleep 2
}

# 部署Clash
deploy_clash() {
    log_step "【阶段2/7】部署 Clash 代理"
    echo ""

    mkdir -p "${CLASH_DIR}"
    cd "${CLASH_DIR}"

    # 下载GeoIP数据库
    log_info "下载 GeoIP 数据库..."
    if [ ! -f "Country.mmdb" ]; then
        curl -sL https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb -o Country.mmdb 2>/dev/null || \
        curl -sL https://ghproxy.com/https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb -o Country.mmdb || {
            log_warn "GeoIP下载失败，使用内置配置"
            touch Country.mmdb
        }
    fi
    log_info "✓ GeoIP 数据库准备完成"

    # 下载或创建Clash配置
    log_info "配置 Clash..."
    if [ -n "$CLASH_SUBSCRIPTION_URL" ]; then
        log_info "从订阅链接下载配置..."
        curl -sL "$CLASH_SUBSCRIPTION_URL" -o config.yaml || {
            log_error "订阅下载失败"
            exit 1
        }
        log_info "✓ 订阅配置下载成功"
    else
        # 创建基础配置
        log_warn "创建基础配置模板（需手动添加节点）"
        cat > config.yaml << 'CLASH_CONFIG'
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: "openclaw2026"

# 代理服务器配置
proxies:
  # 请手动添加你的代理节点
  # - name: "示例节点"
  #   type: ss
  #   server: server.com
  #   port: 443
  #   cipher: aes-256-gcm
  #   password: password

# 代理组
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

# 规则
rules:
  - DOMAIN-SUFFIX,anthropic.com,PROXY
  - DOMAIN-SUFFIX,claude.ai,PROXY
  - DOMAIN-SUFFIX,googleapis.com,PROXY
  - DOMAIN-SUFFIX,google.com,PROXY
  - DOMAIN-SUFFIX,openai.com,PROXY
  - DOMAIN-SUFFIX,github.com,PROXY
  - DOMAIN,api.anthropic.com,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
CLASH_CONFIG
    fi

    # 下载Clash Dashboard
    log_info "下载 Clash Dashboard UI..."
    if [ ! -d "ui" ]; then
        mkdir -p ui
        curl -sL https://github.com/haishanh/yacd/archive/gh-pages.tar.gz 2>/dev/null | tar xz -C ui --strip-components=1 || {
            log_warn "Dashboard下载失败，跳过（不影响使用）"
        }
    fi

    # 创建docker-compose.yml
    log_info "创建 Docker Compose 配置..."
    cat > docker-compose.yml << 'CLASH_COMPOSE'
version: '3.8'

services:
  clash:
    image: dreamacro/clash-premium:latest
    container_name: clash
    restart: unless-stopped
    network_mode: bridge
    ports:
      - "7890:7890"
      - "7891:7891"
      - "9090:9090"
    volumes:
      - ./config.yaml:/root/.config/clash/config.yaml
      - ./Country.mmdb:/root/.config/clash/Country.mmdb
      - ./ui:/ui
    environment:
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://127.0.0.1:9090"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
CLASH_COMPOSE

    # 启动Clash
    log_info "启动 Clash 容器..."
    $COMPOSE_CMD down 2>/dev/null || true
    $COMPOSE_CMD up -d

    # 等待Clash启动
    log_info "等待 Clash 启动..."
    for i in {1..30}; do
        if curl -s http://127.0.0.1:9090 >/dev/null 2>&1; then
            log_success "✓ Clash 启动成功！"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Clash启动超时"
            exit 1
        fi
        sleep 1
    done

    # 测试代理
    log_info "测试代理连接..."
    if curl -x http://127.0.0.1:7890 -s -m 5 https://www.google.com >/dev/null 2>&1; then
        log_success "✓ 代理工作正常！"
    else
        log_warn "代理测试失败（可能需要手动配置节点）"
    fi

    echo ""
    log_info "Clash 控制面板: http://${NAS_IP}:9090/ui"
    log_info "控制面板密钥: openclaw2026"
    echo ""

    sleep 2
}

# 配置Docker代理
configure_docker_proxy() {
    log_step "【阶段3/7】配置 Docker 代理"
    echo ""

    # 创建代理配置脚本
    cat > "${DEPLOY_BASE}/docker-proxy-env.sh" << EOF
#!/bin/bash
export HTTP_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"
export HTTPS_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8"
EOF

    chmod +x "${DEPLOY_BASE}/docker-proxy-env.sh"

    log_info "✓ Docker 代理配置已创建"
    log_info "  HTTP_PROXY: http://${NAS_IP}:${CLASH_PROXY_PORT}"
    echo ""

    sleep 1
}

# 构建OpenClaw
build_openclaw() {
    log_step "【阶段4/7】构建 OpenClaw 镜像"
    echo ""

    # 检查镜像是否已存在
    if docker images | grep -q "openclaw.*local"; then
        log_warn "检测到已存在的OpenClaw镜像"
        read -p "$(echo -e ${CYAN}是否重新构建？[y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "跳过构建，使用现有镜像"
            return 0
        fi
    fi

    cd "${DEPLOY_BASE}"

    # 克隆仓库
    if [ ! -d "${OPENCLAW_SOURCE_DIR}" ]; then
        log_info "克隆 OpenClaw 仓库..."

        # 尝试直接克隆
        if ! git clone --depth=1 https://github.com/openclaw/openclaw.git "${OPENCLAW_SOURCE_DIR}" 2>/dev/null; then
            log_info "使用国内镜像..."
            git clone --depth=1 https://ghproxy.com/https://github.com/openclaw/openclaw.git "${OPENCLAW_SOURCE_DIR}" || {
                log_error "仓库克隆失败"
                exit 1
            }
        fi
        log_info "✓ 仓库克隆完成"
    else
        log_info "使用已存在的源码目录"
    fi

    cd "${OPENCLAW_SOURCE_DIR}"

    # 设置代理环境变量
    export HTTP_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"
    export HTTPS_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}"

    # 构建镜像
    log_info "开始构建 Docker 镜像（预计 10-15 分钟）..."
    log_warn "构建过程较长，请耐心等待..."
    echo ""

    docker build \
        --build-arg HTTP_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}" \
        --build-arg HTTPS_PROXY="http://${NAS_IP}:${CLASH_PROXY_PORT}" \
        -t openclaw:local \
        -f Dockerfile . || {
        log_error "镜像构建失败"
        exit 1
    }

    # 清理代理变量
    unset HTTP_PROXY HTTPS_PROXY

    echo ""
    log_success "✓ OpenClaw 镜像构建完成！"
    docker images | grep openclaw
    echo ""

    sleep 2
}

# 部署OpenClaw
deploy_openclaw() {
    log_step "【阶段5/7】部署 OpenClaw 服务"
    echo ""

    mkdir -p "${OPENCLAW_DIR}"
    cd "${OPENCLAW_DIR}"

    # 创建必要目录
    mkdir -p config workspace data logs

    log_info "创建配置文件..."

    # 创建.env文件
    cat > .env << EOF
# OpenClaw 环境变量配置
# 生成时间: $(date)

# ===== 基础配置 =====
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_CONFIG_DIR=${OPENCLAW_DIR}/config
OPENCLAW_WORKSPACE_DIR=${OPENCLAW_DIR}/workspace
OPENCLAW_GATEWAY_PORT=${OPENCLAW_PORT}
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan

# ===== 访问控制 =====
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}

# ===== 代理配置 =====
HTTP_PROXY=http://${NAS_IP}:${CLASH_PROXY_PORT}
HTTPS_PROXY=http://${NAS_IP}:${CLASH_PROXY_PORT}
NO_PROXY=localhost,127.0.0.1

# ===== LLM 提供商配置 =====

# Anthropic Claude
CLAUDE_AI_SESSION_KEY=${CLAUDE_API_KEY}
CLAUDE_WEB_SESSION_KEY=
CLAUDE_WEB_COOKIE=

# Google Gemini
GOOGLE_API_KEY=${GOOGLE_API_KEY}
GOOGLE_GENERATIVE_AI_API_KEY=${GOOGLE_API_KEY}

# OpenAI
OPENAI_API_KEY=${OPENAI_API_KEY}
OPENAI_ORG_ID=

# Azure OpenAI
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_DEPLOYMENT=

# ===== 其他配置 =====
TZ=Asia/Shanghai
NODE_ENV=production
LOG_LEVEL=info
EOF

    log_info "✓ 环境变量配置已创建"

    # 创建docker-compose.yml
    cat > docker-compose.yml << 'OPENCLAW_COMPOSE'
version: '3.8'

services:
  openclaw-gateway:
    image: ${OPENCLAW_IMAGE:-openclaw:local}
    container_name: openclaw-gateway
    restart: unless-stopped
    init: true
    network_mode: bridge
    ports:
      - "${OPENCLAW_GATEWAY_PORT:-18789}:18789"
      - "${OPENCLAW_BRIDGE_PORT:-18790}:18790"
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    environment:
      - HOME=/home/node
      - TERM=xterm-256color
      - TZ=${TZ:-Asia/Shanghai}
      - NODE_ENV=${NODE_ENV:-production}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
      - OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND:-lan}
      - HTTP_PROXY=${HTTP_PROXY}
      - HTTPS_PROXY=${HTTPS_PROXY}
      - NO_PROXY=${NO_PROXY}
      - CLAUDE_AI_SESSION_KEY=${CLAUDE_AI_SESSION_KEY}
      - CLAUDE_WEB_SESSION_KEY=${CLAUDE_WEB_SESSION_KEY}
      - CLAUDE_WEB_COOKIE=${CLAUDE_WEB_COOKIE}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - GOOGLE_GENERATIVE_AI_API_KEY=${GOOGLE_GENERATIVE_AI_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENAI_ORG_ID=${OPENAI_ORG_ID}
      - AZURE_OPENAI_API_KEY=${AZURE_OPENAI_API_KEY}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_DEPLOYMENT=${AZURE_OPENAI_DEPLOYMENT}
    command: ["node", "dist/index.js", "gateway", "--allow-unconfigured"]
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:18789/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
OPENCLAW_COMPOSE

    log_info "✓ Docker Compose 配置已创建"

    # 启动服务
    log_info "启动 OpenClaw 服务..."
    $COMPOSE_CMD down 2>/dev/null || true
    $COMPOSE_CMD up -d

    # 等待服务启动
    log_info "等待服务启动（可能需要1-2分钟）..."
    for i in {1..60}; do
        if curl -s http://127.0.0.1:${OPENCLAW_PORT}/health >/dev/null 2>&1; then
            log_success "✓ OpenClaw 服务启动成功！"
            break
        fi
        if [ $i -eq 60 ]; then
            log_warn "服务启动超时，请检查日志"
        fi
        sleep 2
    done

    echo ""
    sleep 2
}

# 配置远程访问
configure_remote_access() {
    log_step "【阶段6/7】配置远程访问"
    echo ""

    log_info "远程访问配置选项："
    echo "  1. 节点小宝（P2P内网穿透）- 推荐"
    echo "  2. DDNS（需要公网IP）"
    echo "  3. 极空间官方远程访问"
    echo "  4. 稍后手动配置"
    echo ""

    read -p "$(echo -e ${CYAN}请选择 [1-4，默认4]: ${NC})" -n 1 -r REMOTE_CHOICE
    echo ""

    case $REMOTE_CHOICE in
        1)
            log_info "请在极空间Web界面手动配置节点小宝："
            echo "  1. 点击'节点小宝'图标"
            echo "  2. 登录极空间账号"
            echo "  3. 完成设备绑定"
            echo "  4. 获取虚拟IP后配置远程访问"
            ;;
        2)
            log_info "请在极空间Web界面配置DDNS："
            echo "  1. 点击'DDNS'图标"
            echo "  2. 选择服务商（阿里云/腾讯云）"
            echo "  3. 填写域名和密钥"
            echo "  4. 配置路由器端口转发：${OPENCLAW_PORT}"
            ;;
        3)
            log_info "请在极空间Web界面配置官方远程访问："
            echo "  1. 系统设置 → 远程访问"
            echo "  2. 开启远程访问"
            echo "  3. 添加端口映射：${OPENCLAW_PORT}"
            ;;
        *)
            log_info "✓ 跳过远程访问配置，可稍后手动设置"
            ;;
    esac

    echo ""
    sleep 2
}

# 显示部署结果
show_result() {
    log_step "【阶段7/7】部署完成"
    echo ""

    clear
    cat << 'RESULT'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              🎉 部署成功完成！                             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

RESULT

    echo ""
    log_success "OpenClaw AI Gateway 已成功部署到极空间NAS！"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}📱 访问信息${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}OpenClaw Gateway:${NC}"
    echo "  局域网地址: http://${NAS_IP}:${OPENCLAW_PORT}"
    echo "  Gateway Token: ${GATEWAY_TOKEN}"
    echo ""
    echo -e "${GREEN}Clash 控制面板:${NC}"
    echo "  访问地址: http://${NAS_IP}:9090/ui"
    echo "  控制密钥: openclaw2026"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}📁 重要文件位置${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Clash配置:   ${CLASH_DIR}/config.yaml"
    echo "  OpenClaw配置: ${OPENCLAW_DIR}/.env"
    echo "  工作目录:     ${OPENCLAW_DIR}/workspace"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}🔧 常用命令${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  # 查看OpenClaw状态"
    echo "  cd ${OPENCLAW_DIR} && docker-compose ps"
    echo ""
    echo "  # 查看OpenClaw日志"
    echo "  cd ${OPENCLAW_DIR} && docker-compose logs -f"
    echo ""
    echo "  # 重启OpenClaw"
    echo "  cd ${OPENCLAW_DIR} && docker-compose restart"
    echo ""
    echo "  # 查看Clash状态"
    echo "  cd ${CLASH_DIR} && docker-compose ps"
    echo ""
    echo "  # 更新API密钥"
    echo "  vi ${OPENCLAW_DIR}/.env"
    echo "  cd ${OPENCLAW_DIR} && docker-compose restart"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}⚠️  下一步操作${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ -z "$CLASH_SUBSCRIPTION_URL" ]; then
        echo -e "${YELLOW}1. 配置Clash代理节点${NC}"
        echo "   访问 http://${NAS_IP}:9090/ui 添加代理节点"
        echo ""
    fi

    if [ -z "$CLAUDE_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
        echo -e "${YELLOW}2. 添加LLM API密钥${NC}"
        echo "   编辑文件: vi ${OPENCLAW_DIR}/.env"
        echo "   重启服务: cd ${OPENCLAW_DIR} && docker-compose restart"
        echo ""
    fi

    echo -e "${YELLOW}3. 配置远程访问${NC}"
    echo "   在极空间Web界面配置：节点小宝/DDNS/官方远程访问"
    echo ""

    echo -e "${YELLOW}4. 配置消息渠道（可选）${NC}"
    echo "   通过OpenClaw Web界面配置 WhatsApp/Telegram/Discord 等"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}📖 帮助信息${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  官方文档: https://docs.openclaw.ai"
    echo "  问题反馈: https://github.com/openclaw/openclaw/issues"
    echo ""

    # 保存配置到文件
    cat > "${DEPLOY_BASE}/deployment-info.txt" << EOF
OpenClaw 部署信息
部署时间: $(date)

访问地址:
- OpenClaw: http://${NAS_IP}:${OPENCLAW_PORT}
- Clash面板: http://${NAS_IP}:9090/ui

重要配置:
- Gateway Token: ${GATEWAY_TOKEN}
- Clash密钥: openclaw2026

文件位置:
- Clash配置: ${CLASH_DIR}/config.yaml
- OpenClaw配置: ${OPENCLAW_DIR}/.env
- 工作目录: ${OPENCLAW_DIR}/workspace
EOF

    log_success "部署信息已保存到: ${DEPLOY_BASE}/deployment-info.txt"
    echo ""
}

# 主函数
main() {
    show_banner
    collect_config
    check_environment
    deploy_clash
    configure_docker_proxy
    build_openclaw
    deploy_openclaw
    configure_remote_access
    show_result

    echo ""
    log_success "🎉 所有步骤已完成！享受你的 OpenClaw AI 助手吧！"
    echo ""
}

# 执行主函数
main
