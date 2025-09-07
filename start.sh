#!/bin/sh
set -e

# 从模板生成配置文件
if [ ! -f "/root/.config/mihomo/config.yaml" ]; then
    echo "生成配置文件..."
    envsubst '${LOG_LEVEL} ${CLASH_SECRET} ${SUBSCRIBE_NAME} ${SUBSCRIBE_URL}' < /app/config.yaml.template > /root/.config/mihomo/config.yaml
else
    echo "/root/.config/mihomo/config.yaml 已存在，跳过生成"
fi
# 地理数据检查函数
geodata_check() {
  local url=$1
  local path=$2
  local retries=3
  local attempt=1
  local delay=2

  if [ -f "$path" ]; then
    echo "$path 已存在，跳过下载"
    return 0
  fi

  while [ $attempt -le $retries ]; do
    echo "正在下载 $url (尝试 $attempt/$retries)..."
    if curl -fL "$url" -o "$path"; then
      echo "下载完成: $path"
      return 0
    fi

    sleep $delay
    delay=$((delay * 2))
    echo "下载失败，${delay}秒后重试..."
    attempt=$((attempt + 1))
  done

  echo "错误: 无法下载 $path（共尝试 $retries 次）"
  return 1
}

# 检查并下载地理数据文件
geodata_check \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
  "/root/.config/mihomo/GeoSite.dat"

geodata_check \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat" \
  "/root/.config/mihomo/GeoIP.dat"

geodata_check \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb" \
  "/root/.config/mihomo/Country.mmdb"

geodata_check \
  "https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb" \
  "/root/.config/mihomo/GeoASN.dat"

# 添加注释说明

# 启动 Clash
echo "Starting mihomo version: $(mihomo -v | head -1)"
mihomo -d /root/.config/mihomo &

# 启动 Caddy
echo "Starting Caddy with config:"
cat ./Caddyfile
caddy run --config ./Caddyfile &

# 监控进程状态
wait -n
exit $?