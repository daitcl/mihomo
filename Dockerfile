# syntax=docker/dockerfile:1.7

# ========== 第一阶段：构建 Metacubexd 前端（修复 Node.js 版本） ==========
FROM --platform=$BUILDPLATFORM node:22-alpine AS frontend-builder

ARG METACUBEXD_VERSION
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV HUSKY="0"
ENV NODE_OPTIONS="--max_old_space_size=4096"

WORKDIR /build

# 安装构建工具和 pnpm（使用 corepack 固定版本，避免 latest 漂移）
RUN apk update && apk add --no-cache git curl python3 make g++ \
    && corepack enable \
    && corepack prepare pnpm@latest --activate

# 只克隆指定版本的源码
RUN echo "正在克隆 MetaCubeX/metacubexd 版本: ${METACUBEXD_VERSION}" \
    && git clone -b ${METACUBEXD_VERSION} --depth 1 https://github.com/MetaCubeX/metacubexd.git . \
    || (echo "克隆失败，尝试使用 main 分支..." && git clone --depth 1 https://github.com/MetaCubeX/metacubexd.git .)

# 先复制依赖清单，利用 Docker 层缓存：依赖未变时跳过重复安装
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml* ./
# 如果仓库使用 monorepo 布局，也需要复制各子包的清单：
# COPY packages/ ./packages/
# COPY apps/ ./apps/

RUN echo "安装依赖..." \
    && pnpm install --frozen-lockfile --ignore-scripts

# 再复制完整源码并构建
COPY . .
RUN echo "构建静态资源..." \
    && pnpm --filter @metacubexd/ui generate \
    && echo "构建完成。"

# 直接使用 Nuxt 标准输出目录，去掉动态探测逻辑
RUN test -f /build/packages/ui/.output/public/index.html \
    && echo "✅ 前端产物验证通过" \
    && mkdir -p /build/final \
    && cp -r /build/packages/ui/.output/public/* /build/final/

# ========== 第二阶段：获取目标架构的 Mihomo 内核 ==========
FROM alpine:3.20 AS kernel

ARG TARGETARCH
ARG MI_VERSION

RUN apk add --no-cache curl ca-certificates gzip

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) ASSET="mihomo-linux-amd64-compatible-${MI_VERSION}.gz" ;; \
      arm64) ASSET="mihomo-linux-arm64-${MI_VERSION}.gz" ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/${ASSET}" -o /tmp/mihomo.gz; \
    gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo; \
    chmod +x /usr/local/bin/mihomo; \
    /usr/local/bin/mihomo -v

# ========== 第三阶段：运行时镜像（Caddy + Mihomo） ==========
FROM caddy:2-alpine

ARG MI_VERSION
ARG METACUBEXD_VERSION

# 运行时环境变量（敏感数据仍建议通过 secrets 注入，CLASH_SECRET 保持为空占位）
ENV MI_VERSION=${MI_VERSION} \
    METACUBEXD_VERSION=${METACUBEXD_VERSION} \
    LOG_LEVEL="info" \
    CLASH_SECRET="" \
    SUBSCRIBE_NAME="default" \
    SUBSCRIBE_URL=""

LABEL org.opencontainers.image.title="mihomo" \
      org.opencontainers.image.version="${MI_VERSION}" \
      org.opencontainers.image.description="Mihomo with Metacubexd dashboard, powered by Caddy" \
      com.daitcl.mihomo.version="${MI_VERSION}" \
      com.daitcl.metacubexd.version="${METACUBEXD_VERSION}"

# 安装必要的运行时工具
RUN apk add --no-cache curl bash gettext coreutils tzdata libcap \
    && rm -rf /var/cache/apk/*

# 从 kernel 阶段复制 Mihomo 内核（而非在目标镜像中下载）
COPY --from=kernel /usr/local/bin/mihomo /usr/local/bin/mihomo
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 复制前端产物
WORKDIR /srv
COPY --from=frontend-builder /build/final/ ./

# 复制配置文件与入口脚本
COPY Caddyfile .
COPY config.yaml.template /app/config.yaml.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
    && caddy fmt --overwrite /srv/Caddyfile

# 确保 caddy 用户对必要目录有权限（caddy:alpine 镜像已内置 caddy 用户）
RUN mkdir -p /data /config \
    && chown -R caddy:caddy /data /config /srv

EXPOSE 7890 7891 7892 7893 7894 9090 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]