#!/bin/bash

################################################################################
# Clash 代理简单切换脚本（无需 jq）
# 版本: 1.0-simple
# 功能: 美国/新加坡节点切换 + 健康检查
################################################################################

set -e

# 配置变量
CLASH_API="http://127.0.0.1:9090"
CLASH_SECRET="openclaw2026"
PROXY_URL="http://127.0.0.1:7890"

# 测试目标
TEST_TARGET="https://api.telegram.org"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }

# 测试代理连通性
test_proxy() {
    if curl -x "${PROXY_URL}" -s -m 10 -I "${TEST_TARGET}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 健康检查
health_check() {
    log_info "开始健康检查..."

    if test_proxy; then
        log_success "✓ ${TEST_TARGET} 可达"
        log_success "代理健康"
        return 0
    else
        log_error "✗ ${TEST_TARGET} 不可达"
        log_error "代理不健康"
        return 1
    fi
}

# 获取当前选中的节点 (使用 grep 解析 JSON)
get_current_proxy() {
    local response=$(curl -s -H "Authorization: Bearer ${CLASH_SECRET}" "${CLASH_API}/proxies/🔰国外流量")
    # 简单解析: "now":"节点名"
    echo "$response" | grep -o '"now":"[^"]*"' | cut -d'"' -f4
}

# 切换到指定节点
switch_proxy() {
    local proxy_name="$1"
    local group="${2:-🔰国外流量}"  # 默认使用 🔰国外流量 组

    log_info "切换到节点: ${proxy_name} (组: ${group})"

    local result=$(curl -s -X PUT \
        -H "Authorization: Bearer ${CLASH_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${proxy_name}\"}" \
        "${CLASH_API}/proxies/${group}")

    if [ $? -eq 0 ]; then
        log_success "已切换到节点: ${proxy_name}"
        return 0
    else
        log_error "切换失败: ${proxy_name}"
        return 1
    fi
}

# 获取所有节点列表（简单版）
list_all_nodes() {
    log_info "获取所有节点列表..."

    # 获取 🔰国外流量 组的所有节点
    local response=$(curl -s -H "Authorization: Bearer ${CLASH_SECRET}" "${CLASH_API}/proxies/🔰国外流量")

    # 提取 "all":["节点1","节点2",...]
    # 使用 grep + sed 简单解析
    echo "$response" | grep -o '"all":\[.*\]' | sed 's/"all":\[//' | sed 's/\]//' | tr ',' '\n' | tr -d '"'
}

# 列出节点
list_proxies() {
    log_info "========== 可用节点列表 =========="

    local current=$(get_current_proxy)
    log_info "当前节点: ${current}"
    echo ""

    local nodes=$(list_all_nodes)

    echo "美国节点:"
    echo "$nodes" | grep -E "美国|🇺🇲" | while read node; do
        local marker=" "
        [ "$node" = "$current" ] && marker="★"
        echo "${marker} ${node}"
    done

    echo ""
    echo "新加坡节点:"
    echo "$nodes" | grep -E "新加坡|🇸🇬" | while read node; do
        local marker=" "
        [ "$node" = "$current" ] && marker="★"
        echo "${marker} ${node}"
    done

    echo ""
    echo "其他节点:"
    echo "$nodes" | grep -v -E "美国|🇺🇲|新加坡|🇸🇬|自动选择|♻️" | head -10 | while read node; do
        local marker=" "
        [ "$node" = "$current" ] && marker="★"
        echo "${marker} ${node}"
    done
}

# 切换到美国节点
switch_to_us() {
    log_info "正在搜索美国节点..."

    local nodes=$(list_all_nodes)
    local us_nodes=$(echo "$nodes" | grep -E "美国|🇺🇲")

    if [ -z "$us_nodes" ]; then
        log_error "未找到美国节点"
        return 1
    fi

    log_info "找到以下美国节点:"
    echo "$us_nodes" | nl

    # 选择第一个美国节点
    local first_us=$(echo "$us_nodes" | head -1)
    log_info "选择: ${first_us}"

    switch_proxy "$first_us" "🔰国外流量"
    sleep 3

    log_info "验证连接..."
    health_check
}

# 切换到新加坡节点
switch_to_sg() {
    log_info "正在搜索新加坡节点..."

    local nodes=$(list_all_nodes)
    local sg_nodes=$(echo "$nodes" | grep -E "新加坡|🇸🇬")

    if [ -z "$sg_nodes" ]; then
        log_error "未找到新加坡节点"
        return 1
    fi

    log_info "找到以下新加坡节点:"
    echo "$sg_nodes" | nl

    # 选择第一个新加坡节点
    local first_sg=$(echo "$sg_nodes" | head -1)
    log_info "选择: ${first_sg}"

    switch_proxy "$first_sg" "🔰国外流量"
    sleep 3

    log_info "验证连接..."
    health_check
}

# 自动切换
auto_switch() {
    log_info "========== Clash 自动切换 =========="

    # 1. 检查当前健康状态
    local current=$(get_current_proxy)
    log_info "当前节点: ${current}"

    if health_check; then
        log_success "当前代理健康，无需切换"
        return 0
    fi

    log_warn "当前代理不健康，开始切换..."

    # 2. 尝试切换到美国节点
    log_info "尝试切换到美国节点..."
    if switch_to_us && health_check; then
        log_success "切换到美国节点成功！"
        return 0
    fi

    # 3. 如果美国不行，尝试新加坡
    log_info "尝试切换到新加坡节点..."
    if switch_to_sg && health_check; then
        log_success "切换到新加坡节点成功！"
        return 0
    fi

    log_error "所有优选节点都不可用"
    return 1
}

# 使用说明
usage() {
    cat << EOF
Clash 代理简单切换脚本 v1.0-simple

用法: $0 [命令]

命令:
  check       健康检查当前代理
  list        列出所有可用节点
  us          切换到美国节点
  sg          切换到新加坡节点
  auto        自动切换（推荐）
  help        显示此帮助信息

示例:
  $0 check    # 检查当前代理健康状态
  $0 us       # 切换到美国节点
  $0 sg       # 切换到新加坡节点
  $0 auto     # 自动切换到可用节点
  $0 list     # 列出所有节点

配置:
  Clash API: ${CLASH_API}
  代理地址:  ${PROXY_URL}
  控制密钥:  ${CLASH_SECRET}

EOF
}

# 主函数
main() {
    local command="${1:-help}"

    case "$command" in
        check)
            health_check
            ;;
        list)
            list_proxies
            ;;
        us|usa|美国)
            switch_to_us
            ;;
        sg|singapore|新加坡)
            switch_to_sg
            ;;
        auto)
            auto_switch
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
