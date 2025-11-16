#!/bin/bash

# =============================================================================
# Zampto环境适配版 Argo隧道脚本
# 版本: 1.0.0
# 描述: 为zampto平台优化的Argo隧道部署脚本
# =============================================================================

# 颜色定义
print_info() {
    echo -e "\e[1;34m[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1\033[0m"
}

print_warn() {
    echo -e "\e[1;33m[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1\033[0m"
}

print_error() {
    echo -e "\e[1;91m[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1\033[0m"
}

print_success() {
    echo -e "\e[1;32m[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1\033[0m"
}

# =============================================================================
# 配置变量定义
# =============================================================================

# Zampto环境配置文件路径
CONFIG_FILE="/home/container/config.json"

# 默认配置值
DEFAULT_CF_DOMAIN=""
DEFAULT_CF_TOKEN=""
DEFAULT_UUID=""
DEFAULT_NEZHA_SERVER=""
DEFAULT_NEZHA_PORT="5555"
DEFAULT_NEZHA_KEY=""
DEFAULT_ARGO_PORT="27039"

# 服务端口配置
KEEPALIVE_PORT="27039"
CLOUDFLARED_PORT="27040"

# 工作目录
WORK_DIR="/tmp/zampto-argo"
BINARY_DIR="$WORK_DIR/bin"

# =============================================================================
# 配置加载函数
# =============================================================================

load_config() {
    print_info "开始加载配置文件: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warn "配置文件不存在，使用默认配置: $CONFIG_FILE"
        return 1
    fi
    
    # 检查jq是否可用
    if ! command -v jq >/dev/null 2>&1; then
        print_warn "jq命令不可用，尝试手动解析JSON"
        parse_config_without_jq
    else
        parse_config_with_jq
    fi
    
    print_info "配置加载完成"
}

parse_config_with_jq() {
    CF_DOMAIN=$(jq -r '.CF_DOMAIN // empty' "$CONFIG_FILE" 2>/dev/null)
    CF_TOKEN=$(jq -r '.CF_TOKEN // empty' "$CONFIG_FILE" 2>/dev/null)
    UUID=$(jq -r '.UUID // empty' "$CONFIG_FILE" 2>/dev/null)
    NEZHA_SERVER=$(jq -r '.NEZHA_SERVER // empty' "$CONFIG_FILE" 2>/dev/null)
    NEZHA_PORT=$(jq -r '.NEZHA_PORT // "5555"' "$CONFIG_FILE" 2>/dev/null)
    NEZHA_KEY=$(jq -r '.NEZHA_KEY // empty' "$CONFIG_FILE" 2>/dev/null)
    ARGO_PORT=$(jq -r '.ARGO_PORT // "27039"' "$CONFIG_FILE" 2>/dev/null)
}

parse_config_without_jq() {
    # 简单的JSON解析（不处理复杂JSON）
    CF_DOMAIN=$(grep -o '"CF_DOMAIN"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    CF_TOKEN=$(grep -o '"CF_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    UUID=$(grep -o '"UUID"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    NEZHA_SERVER=$(grep -o '"NEZHA_SERVER"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    NEZHA_PORT=$(grep -o '"NEZHA_PORT"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "5555")
    NEZHA_KEY=$(grep -o '"NEZHA_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    ARGO_PORT=$(grep -o '"ARGO_PORT"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "27039")
}

print_config() {
    print_info "当前配置信息:"
    echo "  CF_DOMAIN: ${CF_DOMAIN:-'未设置'}"
    echo "  CF_TOKEN: ${CF_TOKEN:+'已设置'}${CF_TOKEN:-'未设置'}"
    echo "  UUID: ${UUID:+'已设置'}${UUID:-'未设置'}"
    echo "  NEZHA_SERVER: ${NEZHA_SERVER:-'未设置'}"
    echo "  NEZHA_PORT: $NEZHA_PORT"
    echo "  NEZHA_KEY: ${NEZHA_KEY:+'已设置'}${NEZHA_KEY:-'未设置'}"
    echo "  ARGO_PORT: $ARGO_PORT"
}

# =============================================================================
# 环境准备函数
# =============================================================================

prepare_environment() {
    print_info "准备工作环境"
    
    # 创建工作目录
    mkdir -p "$WORK_DIR" "$BINARY_DIR"
    cd "$WORK_DIR" || {
        print_error "无法切换到工作目录: $WORK_DIR"
        return 1
    }
    
    # 检测系统架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)
            CLOUDFLARED_ARCH="amd64"
            NEZHA_ARCH="amd64"
            ;;
        aarch64|arm64)
            CLOUDFLARED_ARCH="arm64"
            NEZHA_ARCH="arm64"
            ;;
        armv7l|armhf)
            CLOUDFLARED_ARCH="arm"
            NEZHA_ARCH="armv7"
            ;;
        *)
            print_error "不支持的系统架构: $ARCH"
            return 1
            ;;
    esac
    
    print_info "系统架构: $ARCH (cloudflared: $CLOUDFLARED_ARCH, nezha: $NEZHA_ARCH)"
}

# =============================================================================
# Nezha Agent 部署函数
# =============================================================================

deploy_nezha_agent() {
    if [[ -z "$NEZHA_KEY" ]]; then
        print_info "NEZHA_KEY未设置，跳过哪吒监控部署"
        return 0
    fi
    
    if [[ -z "$NEZHA_SERVER" ]]; then
        print_warn "NEZHA_SERVER未设置，跳过哪吒监控部署"
        return 0
    fi
    
    print_info "开始部署哪吒监控Agent"
    
    # 处理服务器地址（是否包含端口）
    if echo "$NEZHA_SERVER" | grep -q ":"; then
        NEZHA_HOST=$(echo "$NEZHA_SERVER" | cut -d':' -f1)
        NEZHA_SERVER_PORT=$(echo "$NEZHA_SERVER" | cut -d':' -f2)
    else
        NEZHA_HOST="$NEZHA_SERVER"
        NEZHA_SERVER_PORT="443"
    fi
    
    print_info "哪吒服务器: $NEZHA_HOST:$NEZHA_SERVER_PORT"
    print_info "哪吒端口: $NEZHA_PORT"
    
    # 下载哪吒Agent
    NEZHA_URL="https://github.com/nezhahq/agent/releases/latest/download/agent-linux-$NEZHA_ARCH"
    NEZHA_BIN="$BINARY_DIR/nezha-agent"
    
    if [[ ! -f "$NEZHA_BIN" ]]; then
        print_info "下载哪吒Agent: $NEZHA_URL"
        if wget -O "$NEZHA_BIN" "$NEZHA_URL" 2>/dev/null || curl -L -o "$NEZHA_BIN" "$NEZHA_URL" 2>/dev/null; then
            chmod +x "$NEZHA_BIN"
            print_success "哪吒Agent下载成功"
        else
            print_error "哪吒Agent下载失败"
            return 1
        fi
    else
        print_info "哪吒Agent已存在，跳过下载"
    fi
    
    # 启动哪吒Agent
    print_info "启动哪吒Agent"
    nohup "$NEZHA_BIN" -s "$NEZHA_HOST:$NEZHA_SERVER_PORT" -p "$NEZHA_KEY" -n "zampto-$(hostname)" >/dev/null 2>&1 &
    NEZHA_PID=$!
    
    sleep 2
    if kill -0 "$NEZHA_PID" 2>/dev/null; then
        print_success "哪吒Agent启动成功 (PID: $NEZHA_PID)"
        echo "NEZHA_PID=$NEZHA_PID" > "$WORK_DIR/nezha.pid"
    else
        print_error "哪吒Agent启动失败"
        return 1
    fi
}

# =============================================================================
# Keepalive HTTP Server 函数
# =============================================================================

start_keepalive_server() {
    print_info "启动Keepalive HTTP服务器 (端口: $KEEPALIVE_PORT)"
    
    # 创建简单的HTML页面
    cat > "$WORK_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Zampto Keepalive</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Zampto Keepalive Server</h1>
    <p>Server is running: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
        setInterval(() => {
            document.getElementById('time').textContent = new Date().toLocaleString();
        }, 1000);
    </script>
</body>
</html>
EOF
    
    # 尝试使用Python3启动HTTP服务器
    if command -v python3 >/dev/null 2>&1; then
        print_info "使用Python3启动HTTP服务器"
        cd "$WORK_DIR"
        nohup python3 -m http.server "$KEEPALIVE_PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
        KEEPALIVE_PID=$!
        
        sleep 2
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            print_success "HTTP服务器启动成功 (PID: $KEEPALIVE_PID)"
            echo "KEEPALIVE_PID=$KEEPALIVE_PID" > "$WORK_DIR/keepalive.pid"
            return 0
        fi
    fi
    
    # 备用方案：使用nc (netcat)
    if command -v nc >/dev/null 2>&1; then
        print_warn "Python3不可用，使用nc启动简单HTTP服务器"
        while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nZampto Keepalive - $(date)" | nc -l -p "$KEEPALIVE_PORT" >/dev/null 2>&1 &
            NC_PID=$!
            echo "NC_PID=$NC_PID" > "$WORK_DIR/keepalive.pid"
            sleep 5
            kill -9 "$NC_PID" 2>/dev/null
        done &
        KEEPALIVE_PID=$!
        print_success "NC HTTP服务器启动成功 (PID: $KEEPALIVE_PID)"
        return 0
    fi
    
    print_error "无法启动HTTP服务器 (需要python3或nc)"
    return 1
}

# =============================================================================
# Cloudflared 隧道函数
# =============================================================================

deploy_cloudflared() {
    print_info "部署Cloudflared隧道"
    
    # 下载cloudflared
    CLOUDFLARED_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/download/v${CLOUDFLARED_VERSION}/cloudflared-linux-${CLOUDFLARED_ARCH}"
    CLOUDFLARED_BIN="$BINARY_DIR/cloudflared"
    
    if [[ ! -f "$CLOUDFLARED_BIN" ]]; then
        print_info "下载Cloudflared: $CLOUDFLARED_URL"
        if wget -O "$CLOUDFLARED_BIN" "$CLOUDFLARED_URL" 2>/dev/null || curl -L -o "$CLOUDFLARED_BIN" "$CLOUDFLARED_URL" 2>/dev/null; then
            chmod +x "$CLOUDFLARED_BIN"
            print_success "Cloudflared下载成功"
        else
            print_error "Cloudflared下载失败"
            return 1
        fi
    else
        print_info "Cloudflared已存在，跳过下载"
    fi
    
    # 配置隧道
    if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
        start_fixed_tunnel
    else
        start_temporary_tunnel
    fi
}

start_fixed_tunnel() {
    print_info "启动固定域名隧道: $CF_DOMAIN"
    
    # 创建tunnel配置
    cat > "$WORK_DIR/tunnel.yml" << EOF
tunnel: $CF_DOMAIN
credentials-file: $WORK_DIR/credentials.json

ingress:
  - hostname: $CF_DOMAIN
    service: http://127.0.0.1:$KEEPALIVE_PORT
  - service: http_status:404
EOF
    
    # 创建凭据文件
    cat > "$WORK_DIR/credentials.json" << EOF
{
  "AccountTag": "$(echo "$CF_TOKEN" | cut -d':' -f1)",
  "TunnelSecret": "$(echo "$CF_TOKEN" | cut -d':' -f2-)",
  "TunnelID": "$(echo "$CF_TOKEN" | cut -d':' -f3)"
}
EOF
    
    # 启动固定隧道
    nohup "$CLOUDFLARED_BIN" tunnel --config "$WORK_DIR/tunnel.yml" run >/dev/null 2>&1 &
    CLOUDFLARED_PID=$!
    
    sleep 3
    if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
        print_success "固定域名隧道启动成功 (PID: $CLOUDFLARED_PID)"
        echo "CLOUDFLARED_PID=$CLOUDFLARED_PID" > "$WORK_DIR/cloudflared.pid"
        echo "TUNNEL_URL=https://$CF_DOMAIN" > "$WORK_DIR/tunnel.url"
    else
        print_error "固定域名隧道启动失败，尝试临时隧道"
        start_temporary_tunnel
    fi
}

start_temporary_tunnel() {
    print_info "启动临时隧道 (trycloudflare)"
    
    # 启动临时隧道
    nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$KEEPALIVE_PORT" >/tmp/cloudflared.log 2>&1 &
    CLOUDFLARED_PID=$!
    
    sleep 5
    if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
        # 从日志中提取临时域名
        TUNNEL_URL=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/cloudflared.log | head -1)
        if [[ -n "$TUNNEL_URL" ]]; then
            print_success "临时隧道启动成功 (PID: $CLOUDFLARED_PID)"
            print_success "隧道地址: $TUNNEL_URL"
            echo "CLOUDFLARED_PID=$CLOUDFLARED_PID" > "$WORK_DIR/cloudflared.pid"
            echo "TUNNEL_URL=$TUNNEL_URL" > "$WORK_DIR/tunnel.url"
        else
            print_warn "隧道已启动但无法获取URL，请检查日志"
        fi
    else
        print_error "临时隧道启动失败"
        return 1
    fi
}

# =============================================================================
# 可选组件部署函数
# =============================================================================

deploy_optional_components() {
    print_info "开始部署可选组件"
    
    # TUIC部署（简化版本，跳过复杂安装）
    deploy_tuic_simple
    
    # Node.js Argo部署（可选）
    deploy_nodejs_argo_optional
}

deploy_tuic_simple() {
    print_info "TUIC组件部署已简化，跳过安装"
    # 如果需要TUIC，可以在这里添加简单的安装逻辑
}

deploy_nodejs_argo_optional() {
    if ! command -v node >/dev/null 2>&1; then
        print_info "Node.js不可用，跳过nodejs-argo部署"
        return 0
    fi
    
    print_info "尝试部署nodejs-argo（可选）"
    
    # 克隆nodejs-argo（如果不存在）
    if [[ ! -d "$WORK_DIR/nodejs-argo" ]]; then
        print_info "克隆nodejs-argo仓库"
        if git clone https://github.com/eooce/nodejs-argo.git "$WORK_DIR/nodejs-argo" 2>/dev/null; then
            cd "$WORK_DIR/nodejs-argo"
            
            # 尝试安装依赖
            if npm install >/dev/null 2>&1; then
                print_success "nodejs-argo依赖安装成功"
                
                # 启动nodejs-argo（后台）
                nohup node index.js >/dev/null 2>&1 &
                NODEJS_ARGO_PID=$!
                echo "NODEJS_ARGO_PID=$NODEJS_ARGO_PID" > "$WORK_DIR/nodejs-argo.pid"
                print_success "nodejs-argo启动成功 (PID: $NODEJS_ARGO_PID)"
            else
                print_warn "nodejs-argo依赖安装失败，继续其他流程"
            fi
        else
            print_warn "nodejs-argo克隆失败，继续其他流程"
        fi
    else
        print_info "nodejs-argo已存在，跳过克隆"
    fi
}

# =============================================================================
# 状态检查和摘要函数
# =============================================================================

check_service_status() {
    print_info "检查服务状态"
    
    # 检查Keepalive服务器
    if [[ -f "$WORK_DIR/keepalive.pid" ]]; then
        KEEPALIVE_PID=$(cat "$WORK_DIR/keepalive.pid" | cut -d'=' -f2)
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            print_success "Keepalive服务器运行中 (PID: $KEEPALIVE_PID)"
        else
            print_error "Keepalive服务器未运行"
        fi
    fi
    
    # 检查Cloudflared隧道
    if [[ -f "$WORK_DIR/cloudflared.pid" ]]; then
        CLOUDFLARED_PID=$(cat "$WORK_DIR/cloudflared.pid" | cut -d'=' -f2)
        if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
            print_success "Cloudflared隧道运行中 (PID: $CLOUDFLARED_PID)"
        else
            print_error "Cloudflared隧道未运行"
        fi
    fi
    
    # 检查哪吒Agent
    if [[ -f "$WORK_DIR/nezha.pid" ]]; then
        NEZHA_PID=$(cat "$WORK_DIR/nezha.pid" | cut -d'=' -f2)
        if kill -0 "$NEZHA_PID" 2>/dev/null; then
            print_success "哪吒Agent运行中 (PID: $NEZHA_PID)"
        else
            print_error "哪吒Agent未运行"
        fi
    fi
    
    # 检查Node.js Argo
    if [[ -f "$WORK_DIR/nodejs-argo.pid" ]]; then
        NODEJS_ARGO_PID=$(cat "$WORK_DIR/nodejs-argo.pid" | cut -d'=' -f2)
        if kill -0 "$NODEJS_ARGO_PID" 2>/dev/null; then
            print_success "Node.js Argo运行中 (PID: $NODEJS_ARGO_PID)"
        else
            print_error "Node.js Argo未运行"
        fi
    fi
}

print_service_summary() {
    print_success "========== 服务部署摘要 =========="
    
    echo "📍 Keepalive服务器:"
    echo "   端口: $KEEPALIVE_PORT"
    echo "   状态: $([ -f "$WORK_DIR/keepalive.pid" ] && echo "✅ 运行中" || echo "❌ 未运行")"
    
    echo ""
    echo "🌐 Cloudflared隧道:"
    if [[ -f "$WORK_DIR/tunnel.url" ]]; then
        TUNNEL_URL=$(cat "$WORK_DIR/tunnel.url")
        echo "   地址: $TUNNEL_URL"
    else
        echo "   地址: 未知"
    fi
    echo "   状态: $([ -f "$WORK_DIR/cloudflared.pid" ] && echo "✅ 运行中" || echo "❌ 未运行")"
    
    echo ""
    echo "📊 哪吒监控:"
    echo "   服务器: ${NEZHA_SERVER:-'未配置'}"
    echo "   状态: $([ -f "$WORK_DIR/nezha.pid" ] && echo "✅ 运行中" || echo "⚠️ 未部署")"
    
    echo ""
    echo "🟢 Node.js Argo:"
    echo "   状态: $([ -f "$WORK_DIR/nodejs-argo.pid" ] && echo "✅ 运行中" || echo "⚠️ 未部署")"
    
    echo ""
    echo "📁 工作目录: $WORK_DIR"
    echo "📋 日志文件: /tmp/cloudflared.log"
    
    print_success "================================"
}

# =============================================================================
# 清理函数
# =============================================================================

cleanup() {
    print_info "清理临时文件和进程"
    
    # 读取PID文件并终止进程
    for pid_file in "$WORK_DIR"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            PID=$(cat "$pid_file" | cut -d'=' -f2)
            if kill -0 "$PID" 2>/dev/null; then
                print_info "终止进程 $PID"
                kill -TERM "$PID" 2>/dev/null
                sleep 2
                kill -KILL "$PID" 2>/dev/null
            fi
        fi
    done
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    print_info "========== Zampto Argo隧道部署脚本启动 =========="
    
    # 设置信号处理
    trap cleanup EXIT
    
    # 1. 加载配置
    load_config
    print_config
    
    # 2. 准备环境
    prepare_environment || {
        print_error "环境准备失败"
        exit 1
    }
    
    # 3. 启动Keepalive服务器（必需）
    start_keepalive_server || {
        print_error "Keepalive服务器启动失败"
        exit 1
    }
    
    # 4. 部署Cloudflared隧道（必需）
    deploy_cloudflared || {
        print_error "Cloudflared隧道部署失败"
        exit 1
    }
    
    # 5. 部署哪吒监控（可选）
    deploy_nezha_agent
    
    # 6. 部署可选组件
    deploy_optional_components
    
    # 7. 检查服务状态
    sleep 3
    check_service_status
    
    # 8. 输出服务摘要
    print_service_summary
    
    print_success "Zampto Argo隧道部署完成！"
    print_info "脚本将持续运行，按Ctrl+C退出"
    
    # 保持脚本运行
    while true; do
        sleep 60
        check_service_status
    done
}

# =============================================================================
# 脚本入口
# =============================================================================

# 检查是否以root权限运行
if [[ $EUID -eq 0 ]]; then
    print_warn "检测到root权限，建议使用普通用户运行"
fi

# 执行主函数
main "$@"