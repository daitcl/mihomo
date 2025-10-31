#!/bin/sh
set -e

echo "=== 启动 Mihomo 代理服务 ==="

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
        echo "✅ $path 已存在，跳过下载"
        return 0
    fi

    echo "📥 正在下载地理数据: $(basename "$path")"

    while [ $attempt -le $retries ]; do
        echo "   尝试 $attempt/$retries: $url"
        if curl -fL --connect-timeout 30 --retry 2 "$url" -o "$path"; then
            if [ -s "$path" ]; then
                echo "✅ 下载完成: $path ($(stat -c%s "$path") 字节)"
                return 0
            else
                echo "⚠️  文件为空，删除并重试..."
                rm -f "$path"
            fi
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
        if curl -fL --connect-timeout 20 "$url" -o "$path" 2>/dev/null && [ -s "$path" ]; then
            echo "✅ 下载完成: $path"
        else
            echo "⚠️  跳过可选文件: $(basename "$path")"
            rm -f "$path"
        fi
    else
        echo "✅ $(basename "$path") 已存在"
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

# 验证必要文件存在
echo "🔍 验证必要文件..."
required_files=(
    "$CONFIG_FILE"
    "/usr/local/bin/mihomo"
    "/srv/Caddyfile"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 错误: 缺少必要文件: $file"
        exit 1
    fi
    echo "✅ 找到: $(basename "$file")"
done

# 验证地理数据核心文件
core_geo_files=(
    "$CONFIG_DIR/GeoSite.dat"
    "$CONFIG_DIR/GeoIP.dat" 
    "$CONFIG_DIR/Country.mmdb"
)

for geo_file in "${core_geo_files[@]}"; do
    if [ ! -f "$geo_file" ]; then
        echo "❌ 错误: 缺少核心地理数据文件: $(basename "$geo_file")"
        exit 1
    fi
done

# 切换到工作目录
cd /srv

# 启动服务
echo "🚀 启动服务..."

# 启动 Caddy web server
echo "🌐 启动 Caddy web 服务器..."
echo "Caddy 配置:"
cat ./Caddyfile
caddy run --config ./Caddyfile --adapter caddyfile &

# 等待 Caddy 启动
echo "⏳ 等待 Caddy 启动..."
sleep 3

# 检查 Caddy 是否正常运行
if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
    echo "✅ Caddy 已成功启动在端口 8080"
else
    echo "⚠️  Caddy 启动检查失败，但继续启动进程..."
fi

# 启动 Mihomo 核心
echo "🔧 启动 Mihomo 核心..."
echo "Mihomo 版本: $(mihomo -v | head -1)"

# 在前台启动 mihomo（主进程）
exec mihomo -d "$CONFIG_DIR"