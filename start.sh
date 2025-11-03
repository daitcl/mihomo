#!/bin/sh
set -e

echo "=== 启动 Mihomo 代理服务 ==="

# 版本信息 - 添加回退机制
echo "📋 版本信息:"
echo "  - Mihomo: ${MI_VERSION:-$(mihomo -v 2>/dev/null | head -1 || echo '未知')}"
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
    envsubst '${LOG_LEVEL} ${CLASH_SECRET} ${SUBSCRIBE_NAME} ${SUBSCRIBE_URL}' < "$TEMPLATE_FILE" > "$CONFIG_FILE"
    echo "✅ 配置文件已生成: $CONFIG_FILE"
    
    # 验证生成的配置文件
    if [ -s "$CONFIG_FILE" ]; then
        file_size=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "0")
        echo "✅ 配置文件验证成功 ($file_size 字节)"
    else
        echo "❌ 错误: 生成的配置文件为空"
        exit 1
    fi
else
    echo "📁 配置文件已存在，跳过生成: $CONFIG_FILE"
fi

# 地理数据检查函数（带重试机制）
geodata_check() {
    local url=$1
    local path=$2
    local retries=3
    local attempt=1
    local delay=2

    if [ -f "$path" ]; then
        file_size=$(stat -c%s "$path" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 1024 ]; then
            echo "✅ $(basename "$path") 已存在 ($file_size 字节)"
            return 0
        else
            echo "⚠️  $(basename "$path") 文件过小，重新下载..."
            rm -f "$path"
        fi
    fi

    echo "📥 正在下载地理数据: $(basename "$path")"

    while [ $attempt -le $retries ]; do
        echo "   尝试 $attempt/$retries: $url"
        if curl -fL --connect-timeout 30 --retry 2 --retry-delay 1 "$url" -o "$path"; then
            if [ -s "$path" ]; then
                downloaded_size=$(stat -c%s "$path" 2>/dev/null || echo "0")
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
    return 1
}

# 检查必要的地理数据文件（仅检查核心文件）
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

# 可选的地理数据文件（不强制要求）
optional_geodata_check() {
    local url=$1
    local path=$2
    
    if [ ! -f "$path" ]; then
        echo "📥 下载可选地理数据: $(basename "$path")"
        if curl -fL --connect-timeout 20 --retry 2 "$url" -o "$path" 2>/dev/null && [ -s "$path" ]; then
            file_size=$(stat -c%s "$path" 2>/dev/null || echo "0")
            echo "✅ 下载完成: $path ($file_size 字节)"
        else
            echo "⚠️  跳过可选文件: $(basename "$path")"
            rm -f "$path"
        fi
    else
        file_size=$(stat -c%s "$path" 2>/dev/null || echo "0")
        echo "✅ $(basename "$path") 已存在 ($file_size 字节)"
    fi
}

# 下载可选的地理数据
optional_geodata_check \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat" \
    "$CONFIG_DIR/GeoIP-lite.dat"

optional_geodata_check \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb" \
    "$CONFIG_DIR/Country-lite.mmdb"

optional_geodata_check \
    "https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb" \
    "$CONFIG_DIR/GeoASN.dat"

# 验证必要文件存在 - 使用兼容的语法
echo "🔍 验证必要文件..."
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "❌ 错误: 缺少必要文件: $file"
        exit 1
    fi
    echo "✅ 找到: $(basename "$file")"
}

check_file "$CONFIG_FILE"
check_file "/usr/local/bin/mihomo"
check_file "/srv/Caddyfile"

# 验证地理数据核心文件 - 使用兼容的语法
echo "🔍 验证核心地理数据文件..."
check_geo_file() {
    local geo_file=$1
    if [ ! -f "$geo_file" ]; then
        echo "❌ 错误: 缺少核心地理数据文件: $(basename "$geo_file")"
        exit 1
    fi
    echo "✅ 找到: $(basename "$geo_file")"
}

check_geo_file "$CONFIG_DIR/GeoSite.dat"
check_geo_file "$CONFIG_DIR/GeoIP.dat"
check_geo_file "$CONFIG_DIR/Country.mmdb"

echo "✅ 所有必要文件验证通过"

# 切换到工作目录
cd /srv

# 启动服务
echo "🚀 启动服务..."

# 启动 Caddy web server
echo "🌐 启动 Caddy web 服务器..."
echo "📄 Caddy 配置内容:"
cat ./Caddyfile
echo ""

# 验证 Caddyfile 语法
if caddy validate --config ./Caddyfile --adapter caddyfile; then
    echo "✅ Caddyfile 语法验证通过"
else
    echo "❌ Caddyfile 语法错误"
    exit 1
fi

# 后台启动 Caddy
caddy run --config ./Caddyfile --adapter caddyfile &

# 等待 Caddy 启动
echo "⏳ 等待 Caddy 启动..."
sleep 5

# 检查 Caddy 是否正常运行
if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
    echo "✅ Caddy 已成功启动在端口 8080"
else
    echo "❌ Caddy 启动失败，检查日志..."
    exit 1
fi

# 启动 Mihomo 核心
echo "🔧 启动 Mihomo 核心..."
echo "📋 Mihomo 版本信息:"
mihomo -v || echo "⚠️  无法获取 Mihomo 版本信息"

# 验证配置文件语法
if mihomo -d "$CONFIG_DIR" -t; then
    echo "✅ Mihomo 配置文件验证通过"
else
    echo "❌ Mihomo 配置文件验证失败"
    exit 1
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

# 在前台启动 mihomo（主进程）
exec mihomo -d "$CONFIG_DIR"