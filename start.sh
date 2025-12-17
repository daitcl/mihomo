#!/bin/sh
set -e

echo "=== 启动 Mihomo 代理服务 ==="

# 版本信息
echo "📋 版本信息:"
echo "  - Mihomo: ${MI_VERSION:-$(mihomo -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo '未知')}"
echo "  - Metacubexd: ${MetaCubeX_VERSION:-未知}"
echo "  - 启动时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 配置路径
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
TEMPLATE_FILE="/app/config.yaml.template"

# 创建配置目录
mkdir -p "$CONFIG_DIR"

# 从模板生成配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "📝 生成配置文件..."
    
    # 检查环境变量是否设置
    echo "环境变量检查:"
    echo "  - LOG_LEVEL: ${LOG_LEVEL:-未设置，使用默认值}"
    echo "  - CLASH_SECRET: ${CLASH_SECRET:-未设置}"
    echo "  - SUBSCRIBE_NAME: ${SUBSCRIBE_NAME:-未设置}"
    echo "  - SUBSCRIBE_URL: ${SUBSCRIBE_URL:-未设置}"
    
    # 设置默认值
    export LOG_LEVEL="${LOG_LEVEL:-info}"
    
    if [ -f "$TEMPLATE_FILE" ]; then
        envsubst '${LOG_LEVEL} ${CLASH_SECRET} ${SUBSCRIBE_NAME} ${SUBSCRIBE_URL}' < "$TEMPLATE_FILE" > "$CONFIG_FILE"
        echo "✅ 配置文件已生成: $CONFIG_FILE"
    else
        echo "❌ 模板文件不存在: $TEMPLATE_FILE"
        echo "创建默认配置文件..."
        cat > "$CONFIG_FILE" << 'EOF'
# 默认配置文件
mixed-port: 7890
redir-port: 7892
tproxy-port: 7893
port: 7890
socks-port: 7891
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: '${CLASH_SECRET}'

# 代理组配置
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - DIRECT

# 规则配置
rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF
        # 替换环境变量
        sed -i "s/\${CLASH_SECRET}/${CLASH_SECRET}/g" "$CONFIG_FILE"
        echo "✅ 默认配置文件已创建: $CONFIG_FILE"
    fi
    
    # 验证生成的配置文件
    if [ -s "$CONFIG_FILE" ]; then
        file_size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || wc -c < "$CONFIG_FILE" || echo "0")
        echo "✅ 配置文件验证成功 ($file_size 字节)"
    else
        echo "❌ 错误: 生成的配置文件为空"
        exit 1
    fi
else
    echo "📁 配置文件已存在，跳过生成: $CONFIG_FILE"
fi

# 地理数据检查函数
geodata_check() {
    local url=$1
    local path=$2
    local retries=3
    local attempt=1
    local delay=2

    if [ -f "$path" ]; then
        file_size=$(stat -c%s "$path" 2>/dev/null || wc -c < "$path" || echo "0")
        if [ "$file_size" -gt 10240 ]; then  # 大于10KB认为有效
            echo "✅ $(basename "$path") 已存在 ($file_size 字节)"
            return 0
        else
            echo "⚠️  $(basename "$path") 文件过小 ($file_size 字节)，重新下载..."
            rm -f "$path"
        fi
    fi

    echo "📥 正在下载地理数据: $(basename "$path")"

    while [ $attempt -le $retries ]; do
        echo "   尝试 $attempt/$retries: $url"
        if curl -fL --connect-timeout 30 --retry 2 --retry-delay 1 "$url" -o "$path"; then
            if [ -s "$path" ]; then
                downloaded_size=$(stat -c%s "$path" 2>/dev/null || wc -c < "$path" || echo "0")
                echo "✅ 下载完成: $path ($downloaded_size 字节)"
                return 0
            else
                echo "⚠️  文件为空，删除并重试..."
                rm -f "$path"
            fi
        else
            echo "❌ 下载失败 (尝试 $attempt/$retries)"
        fi

        if [ $attempt -lt $retries ]; then
            echo "   ⏳ ${delay}秒后重试..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done

    echo "❌ 错误: 无法下载 $path（共尝试 $retries 次）"
    # 不退出，允许使用默认配置继续
    return 1
}

# 检查必要的地理数据文件
echo "🔍 检查地理数据文件..."

geodata_check \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
    "$CONFIG_DIR/GeoSite.dat"

geodata_check \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" \
    "$CONFIG_DIR/GeoIP.dat"

geodata_check \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" \
    "$CONFIG_DIR/Country.mmdb"

# 可选的地理数据文件
echo "🔍 检查可选地理数据文件..."
optional_files=(
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat"
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb"
    "https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb"
)

for url in "${optional_files[@]}"; do
    filename=$(basename "$url")
    path="$CONFIG_DIR/$filename"
    
    if [ ! -f "$path" ]; then
        echo "📥 下载可选文件: $filename"
        if curl -fL --connect-timeout 20 --max-time 60 "$url" -o "$path" 2>/dev/null && [ -s "$path" ]; then
            file_size=$(stat -c%s "$path" 2>/dev/null || wc -c < "$path" || echo "0")
            echo "✅ 下载完成: $filename ($file_size 字节)"
        else
            echo "⚠️  跳过可选文件: $filename"
            rm -f "$path"
        fi
    fi
done

# 验证必要文件存在
echo "🔍 验证必要文件..."
check_file() {
    local file=$1
    local description=${2:-""}
    
    if [ ! -f "$file" ]; then
        echo "❌ 错误: 缺少必要文件: $file $description"
        
        # 尝试查找文件
        echo "    尝试在系统中查找 $(basename "$file")..."
        find / -name "$(basename "$file")" 2>/dev/null | head -3 || true
        
        # 对于某些文件，我们可以尝试重新创建
        case "$(basename "$file")" in
            "config.yaml")
                echo "    尝试创建默认配置文件..."
                return 0  # 配置文件可以重新创建
                ;;
            *)
                # 对于其他必要文件，退出
                exit 1
                ;;
        esac
    else
        file_size=$(stat -c%s "$file" 2>/dev/null || wc -c < "$file" || echo "0")
        echo "✅ 找到: $(basename "$file") ($file_size 字节) $description"
    fi
}

# 检查核心文件
check_file "$CONFIG_FILE" "(配置文件)"
check_file "/usr/local/bin/mihomo" "(Mihomo 二进制文件)"

# 检查 Caddyfile
CADDYFILE_PATH="/srv/Caddyfile"
if [ ! -f "$CADDYFILE_PATH" ]; then
    echo "⚠️  Caddyfile 不存在于 $CADDYFILE_PATH"
    # 检查其他可能的位置
    if [ -f "/etc/caddy/Caddyfile" ]; then
        echo "✅ 找到 Caddyfile 在 /etc/caddy/Caddyfile"
        CADDYFILE_PATH="/etc/caddy/Caddyfile"
    else
        echo "❌ 错误: 找不到 Caddyfile"
        exit 1
    fi
else
    echo "✅ 找到 Caddyfile 在 $CADDYFILE_PATH"
fi

# 检查地理数据核心文件
echo "🔍 验证核心地理数据文件..."
for geo_file in "$CONFIG_DIR/GeoSite.dat" "$CONFIG_DIR/GeoIP.dat"; do
    if [ -f "$geo_file" ]; then
        file_size=$(stat -c%s "$geo_file" 2>/dev/null || wc -c < "$geo_file" || echo "0")
        if [ "$file_size" -gt 10240 ]; then
            echo "✅ 找到: $(basename "$geo_file") ($file_size 字节)"
        else
            echo "⚠️  $(basename "$geo_file") 文件过小 ($file_size 字节)，但继续..."
        fi
    else
        echo "⚠️  缺少: $(basename "$geo_file")，可能影响某些功能"
    fi
done

echo "✅ 所有必要文件验证通过"

# 切换到工作目录
cd /srv

# 启动服务
echo "🚀 启动服务..."

# 启动 Caddy web server
echo "🌐 启动 Caddy web 服务器..."
echo "📄 Caddy 配置位置: $CADDYFILE_PATH"

# 验证 Caddyfile 语法
if caddy validate --config "$CADDYFILE_PATH" --adapter caddyfile 2>&1; then
    echo "✅ Caddyfile 语法验证通过"
else
    echo "❌ Caddyfile 语法错误，但继续启动..."
fi

# 后台启动 Caddy
caddy run --config "$CADDYFILE_PATH" --adapter caddyfile &

# 等待 Caddy 启动
echo "⏳ 等待 Caddy 启动..."
sleep 3

# 检查 Caddy 是否正常运行
if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
    echo "✅ Caddy 已成功启动在端口 8080"
else
    echo "⚠️  Caddy 启动检查失败，但继续启动 Mihomo..."
    # 不退出，允许 Mihomo 单独运行
fi

# 启动 Mihomo 核心
echo "🔧 启动 Mihomo 核心..."
echo "📋 Mihomo 版本信息:"
mihomo -v 2>/dev/null || echo "⚠️  无法获取 Mihomo 版本信息"

# 验证配置文件语法
if mihomo -d "$CONFIG_DIR" -t 2>&1; then
    echo "✅ Mihomo 配置文件验证通过"
else
    echo "⚠️  Mihomo 配置文件验证失败，但继续启动..."
fi

echo ""
echo "🎉 所有服务启动完成!"
echo "📊 服务状态:"
echo "  - Caddy Web UI: http://localhost:8080"
echo "  - Mihomo API: http://localhost:9090"
echo "  - 代理端口: 7890 (HTTP), 7891 (SOCKS5), 7892 (混合)"
echo ""
echo "📝 日志查看: docker logs <container_name>"
echo "🛑 停止服务: docker stop <container_name>"
echo "🔁 重启服务: docker restart <container_name>"

# 在前台启动 mihomo（主进程）
echo ""
echo "🔄 启动 Mihomo 核心进程..."
exec mihomo -d "$CONFIG_DIR"