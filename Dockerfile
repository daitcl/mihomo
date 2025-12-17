# ========== 第一阶段：构建 Metacubexd 前端 ==========
FROM node:20-alpine AS frontend-builder

ARG METACUBEXD_VERSION
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV HUSKY="0"
ENV NODE_OPTIONS="--max_old_space_size=4096"

WORKDIR /build

# 安装系统依赖和 pnpm
RUN apk update && apk add --no-cache git curl python3 make g++ \
    && npm install -g pnpm@latest \
    && corepack enable && corepack prepare pnpm@latest --activate

# 克隆指定版本的 Metacubexd 源码
RUN echo "正在克隆 MetaCubeX/metacubexd 版本: ${METACUBEXD_VERSION}" \
    && git clone -b ${METACUBEXD_VERSION} --depth 1 https://github.com/MetaCubeX/metacubexd.git . \
    || (echo "克隆失败，尝试使用 main 分支..." && git clone --depth 1 https://github.com/MetaCubeX/metacubexd.git .)

# 安装依赖并构建静态资源
RUN echo "安装依赖..." \
    && pnpm install --frozen-lockfile --ignore-scripts \
    && echo "构建静态资源..." \
    && pnpm generate \
    && echo "构建完成。"

# ========== 第二阶段：构建最终应用镜像 ==========
FROM caddy:alpine

ARG MI_VERSION
ARG METACUBEXD_VERSION
# 将构建参数设置为环境变量，供运行时使用
ENV MI_VERSION=${MI_VERSION}
ENV METACUBEXD_VERSION=${METACUBEXD_VERSION}
ENV LOG_LEVEL="info"
ENV CLASH_SECRET=""
ENV SUBSCRIBE_NAME="default"
ENV SUBSCRIBE_URL=""

# 安装运行依赖
RUN apk update && apk add --no-cache libcap curl bash gettext coreutils tzdata \
    && rm -rf /var/cache/apk/*

# 下载并安装 Mihomo 核心
RUN mkdir -p /root/.config/mihomo \
    && curl -fL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/mihomo-linux-amd64-compatible-${MI_VERSION}.gz" -o /tmp/mihomo.gz \
    && gunzip /tmp/mihomo.gz && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 复制前端构建产物
WORKDIR /srv
COPY --from=frontend-builder /build/dist ./

# 复制应用配置文件
COPY Caddyfile .
COPY config.yaml.template /app/config.yaml.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
    && caddy fmt --overwrite /srv/Caddyfile

# 暴露端口
EXPOSE 7890 7891 7892 7893 7894 9090 8080

# 健康检查（检查Web服务）
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# 使用自定义入口点脚本
ENTRYPOINT ["/docker-entrypoint.sh"]