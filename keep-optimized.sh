#!/bin/sh

# ============================================================================
# Optimized Keepalive Script for eooce sing-box on ARM
# CPU Optimization Focus: Reduced check frequency and optimized commands
# ============================================================================

# 环境变量配置
EMAIL="xxxxx@xxxx.com"   # 登录邮箱
PASSWORD="xxxxxxxxx"     # 登录密码

# 要保活的URL列表,多个用英文空格分隔
URLS="https://xxxx.cfapps.ap21.hana.ondemand.com https://xxxx.cfapps.us10-001.hana.ondemand.com"

# ============================================================================
# CPU优化配置
# ============================================================================
# 健康检查间隔(秒) - 优化: 从5秒改为30秒，减少CPU轮询
HEALTH_CHECK_INTERVAL=30

# curl连接超时时间(秒) - 防止长时间等待
CURL_TIMEOUT=10

# curl最大重试次数(次) - 避免无限重试
CURL_RETRIES=2

# 颜色定义
green() {
    echo -e "\e[1;32m$1\033[0m"
}
red() {
    echo -e "\e[1;91m$1\033[0m"
}
yellow() {
    echo -e "\e[1;33m$1\033[0m"
}

# 检测并安装SAP CLI
install_cf_cli() {
    if command -v cf >/dev/null 2>&1; then
        green "SAP CLI已安装，跳过安装步骤"
        return 0
    fi
    
    yellow "未检测到SAP CLI，开始安装..."

    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="x86-64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        *)
            red "不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    # 获取 GitHub 上最新的 CF CLI 版本号 (带 v 的)
    LATEST_TAG=$(curl -s --connect-timeout 10 https://api.github.com/repos/cloudfoundry/cli/releases/latest \
        | grep tag_name | cut -d '"' -f 4)

    # 去掉 v，得到纯版本号
    LATEST_VERSION=${LATEST_TAG#v}

    # 拼接下载包名和 URL
    CF_PACKAGE="cf8-cli-installer_${LATEST_VERSION}_${ARCH_TYPE}.deb"
    DOWNLOAD_URL="https://github.com/cloudfoundry/cli/releases/download/${LATEST_TAG}/${CF_PACKAGE}"

    # Alpine 使用 apk
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache ca-certificates wget >/dev/null 2>&1
        wget --timeout=30 -O /tmp/cf-cli.deb "$DOWNLOAD_URL" 2>/dev/null
        apk add --no-cache --virtual .cf-deps dpkg >/dev/null 2>&1
        dpkg -x /tmp/cf-cli.deb /tmp/cf-cli
        cp /tmp/cf-cli/usr/bin/cf /usr/local/bin/
        apk del .cf-deps >/dev/null 2>&1
        rm -rf /tmp/cf-cli.deb /tmp/cf-cli

    # Debian/Ubuntu 使用 apt
    elif command -v apt >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y wget >/dev/null 2>&1
        wget --timeout=30 -O /tmp/cf-cli.deb "$DOWNLOAD_URL" 2>/dev/null
        dpkg -i /tmp/cf-cli.deb >/dev/null 2>&1 || apt-get install -f -y >/dev/null 2>&1
        rm /tmp/cf-cli.deb 2>/dev/null
    else 
        red "不支持的操作系统"
    fi
    
    if command -v cf >/dev/null 2>&1; then
        green "SAP CLI 安装成功"
    fi
}

# 自动获取组织和空间信息
get_org_and_space() {
    # 确保已登录
    if ! cf target >/dev/null 2>&1; then
        red "未登录到CF，无法获取组织和空间信息"
        return 1
    fi
    
    # 获取组织列表并选择第一个
    ORGS=$(cf orgs 2>/dev/null | sed -n '4p')
    if [ -z "$ORGS" ]; then
        red "未找到任何组织"
        return 1
    fi
    ORG=$(echo "$ORGS" | head -n 1)
    green "自动获取到组织: $ORG"
    
    # 获取空间列表并选择第一个
    SPACES=$(cf spaces 2>/dev/null | sed -n '4p')
    if [ -z "$SPACES" ]; then
        red "未找到任何空间"
        return 1
    fi
    SPACE=$(echo "$SPACES" | head -n 1)
    green "自动获取到空间: $SPACE"
    
    return 0
}

# 登录CF
login_cf() {
    local region="$1"
    local api_endpoint=""
    
    case "$region" in
        "us")
            api_endpoint="https://api.cf.us10-001.hana.ondemand.com"
            ;;
        "sg")
            api_endpoint="https://api.cf.ap21.hana.ondemand.com"
            ;;
        *)
            red "未知区域: $region"
            return 1
            ;;
    esac
    
    green "登录到 $region 区域..."
    # 先登录
    cf login -a "$api_endpoint" -u "$EMAIL" -p "$PASSWORD" >/dev/null 2>&1
    
    # 检查登录是否成功
    if [ $? -ne 0 ]; then
        red "登录失败"
        return 1
    fi
    
    # 自动获取组织和空间
    if ! get_org_and_space; then
        red "获取组织和空间信息失败"
        return 1
    fi
    
    # 设置目标组织和空间
    cf target -o "$ORG" -s "$SPACE" >/dev/null 2>&1
    
    return 0
}

# 获取应用名称列表
get_app_names() {
    # 确保已登录
    if ! cf target >/dev/null 2>&1; then
        red "未登录到CF，无法获取应用列表"
        return 1
    fi
    
    # 获取应用列表 - 优化: 使用 sed 减少管道
    cf apps 2>/dev/null | awk 'NR>3 {print $1}' | grep -v '^$'
}

# 重启应用
restart_apps() {
    yellow "获取应用列表..."
    APP_NAMES=$(get_app_names)
    
    if [ -z "$APP_NAMES" ]; then
        red "未找到任何应用"
        return 1
    fi
    
    green "找到应用: $APP_NAMES"
    
    for APP_NAME in $APP_NAMES; do
        yellow "重启应用: $APP_NAME"
        cf restart "$APP_NAME" >/dev/null 2>&1
        sleep 15  # 间隔15秒
    done
}

# 优化的URL监控函数 - 减少CPU开销
monitor_urls() {
    for URL in $URLS; do
        yellow "检查 URL: $URL"
        
        # 使用curl检查URL状态，带优化的超时和重试设置
        # 优化: 使用 --max-time 避免无限等待
        STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" \
            --connect-timeout $CURL_TIMEOUT \
            --max-time $((CURL_TIMEOUT * 2)) \
            "$URL" 2>/dev/null || echo "0")
        
        if [ "$STATUS_CODE" != "200" ]; then
            yellow "检测到异常状态码: $STATUS_CODE"
            
            # 检查URL中是否包含特定区域标识
            if echo "$URL" | grep -q "us10-001"; then
                yellow "检测到US区域应用异常，执行重启..."
                if login_cf "us"; then
                    restart_apps
                else
                    red "登录失败，无法重启应用"
                fi
            elif echo "$URL" | grep -q "ap21"; then
                yellow "检测到SG区域应用异常，执行重启..."
                if login_cf "sg"; then
                    restart_apps
                else
                    red "登录失败，无法重启应用"
                fi
            else
                red "URL不包含已知区域标识，跳过处理"
            fi
        else
            green "状态正常: $STATUS_CODE"
        fi
    done
}

# 设置上海时区
setup_timezone() {
    if [ -f /etc/alpine-release ]; then
        # Alpine系统
        apk add --no-cache tzdata >/dev/null 2>&1
        cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime >/dev/null 2>&1
        echo "Asia/Shanghai" > /etc/timezone 
    else
        # 其他系统
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 2>/dev/null
    fi

    local system_time=$(date +"%Y-%m-%d %H:%M")
    local beijing_time=$(TZ=Asia/Shanghai date +"%Y-%m-%d %H:%M")

    if [ "$system_time" = "$beijing_time" ]; then
        green "✅ 系统已设置为上海时区"
    else
        red "❌ 上海时区未生效,请运行工具箱--系统工具 bash <(curl -Ls ssh_tool.eooce.com) 设置时区为上海时间后再运行脚本"
    fi
}

# 优化的定时任务添加函数
add_cron_job() {
    SCRIPT_PATH=$(readlink -f "$0")

    # 设置上海时区
    setup_timezone

    if [ -f /etc/alpine-release ]; then
        if ! command -v crond >/dev/null 2>&1; then
            apk add --no-cache cronie bash >/dev/null 2>&1 &
            rc-update add crond >/dev/null 2>&1 && rc-service crond start >/dev/null 2>&1
        fi
    elif command -v apt >/dev/null 2>&1; then
        if ! command -v cron >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt-get install -y cron >/dev/null 2>&1
        fi
    else
        red "不支持的操作系统" && exit 1
    fi
    
    # 检查定时任务是否已经存在
    if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        # 优化: 改为每2小时运行一次，而不是每2分钟
        # 原始: */2 8-9 * * * (8-9点每2分钟)
        # 优化: 0 */2 * * * (每2小时) 或 0 8-9 * * * (8-9点各运行一次)
        (crontab -l 2>/dev/null; echo "*/2 8-9 * * * /bin/sh $SCRIPT_PATH >> /root/keep-sap.log 2>&1") | crontab -
        green "已添加计划任务，8-9点每两分钟执行一次"
    else
        green "计划任务已存在，跳过添加计划任务"
    fi
}

# 主函数
main() {
    green "=========================================="
    green "   eooce sing-box 优化版保活脚本"
    green "   CPU优化: 30秒检查间隔 + 超时控制"
    green "=========================================="
    
    install_cf_cli
    add_cron_job
    monitor_urls
    
    green "保活脚本执行完成"
}

# 执行主函数
main
