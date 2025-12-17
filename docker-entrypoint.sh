#!/bin/sh
set -e

echo "=========================================="
echo "启动 Mihomo + Metacubexd 集成容器"
echo "=========================================="
echo "Mihomo 版本:      ${MI_VERSION}"
echo "Metacubexd 版本:  ${METACUBEXD_VERSION}"
echo "日志级别:         ${LOG_LEVEL:-info}"
echo "订阅名称:         ${SUBSCRIBE_NAME:-未设置}"
echo "=========================================="

# 配置路径
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
TEMPLATE_FILE="/app/config.yaml.template"

# 1. 生成 Mihomo 配置文件
mkdir -p "${CONFIG_DIR}"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "生成 Mihomo 配置文件..."
    if [ -f "${TEMPLATE_FILE}" ]; then
        envsubst '${LOG_LEVEL} ${CLASH_SECRET} ${SUBSCRIBE_NAME} ${SUBSCRIBE_URL}' < "${TEMPLATE_FILE}" > "${CONFIG_FILE}"
        echo "✅ 配置文件已生成: ${CONFIG_FILE}"
    else
        echo "❌ 错误: 未找到配置模板"
        exit 1
    fi
else
    echo "📁 使用现有配置文件: ${CONFIG_FILE}"
fi

# 2. 验证配置
echo "验证 Mihomo 配置..."
if mihomo -d "${CONFIG_DIR}" -t 2>/dev/null; then
    echo "✅ Mihomo 配置文件验证通过"
else
    echo "⚠️  Mihomo 配置文件验证失败，但继续启动..."
fi

# 3. 启动 Caddy Web 服务器
echo "启动 Caddy Web 服务器..."
caddy run --config /srv/Caddyfile --adapter caddyfile &

# 等待 Caddy 启动
sleep 2

# 4. 在前台启动 Mihomo
echo "启动 Mihomo 核心..."
exec mihomo -d "${CONFIG_DIR}"