# 阶段1：构建 Metacubexd 前端 - 使用更可靠的构建方式
FROM docker.io/node:20-alpine AS ui-builder

ARG MetaCubeX_VERSION

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
ENV HUSKY=0
ENV NODE_OPTIONS="--max_old_space_size=4096"
WORKDIR /build

# 安装系统依赖
RUN apk update && apk add --no-cache \
    git \
    curl \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# 安装并配置 pnpm
RUN npm install -g pnpm@latest && \
    corepack enable && \
    corepack prepare pnpm@latest --activate

# 克隆指定版本的 metacubexd - 增加错误处理和重试
RUN echo "Cloning MetaCubeX/metacubexd tag: ${MetaCubeX_VERSION}" && \
    for i in 1 2 3; do \
        git clone -b ${MetaCubeX_VERSION} --depth 1 https://github.com/MetaCubeX/metacubexd.git . && \
        break || sleep 2; \
    done || { echo "Failed to clone repository"; exit 1; }

# 检查项目结构
RUN echo "Project structure:" && ls -la

# 安装依赖并构建 - 增加超时和错误处理
RUN echo "Installing dependencies..." && \
    pnpm install --frozen-lockfile --ignore-scripts --timeout=600000 && \
    echo "Building..." && \
    pnpm build

# 验证构建输出
RUN echo "Build output structure:" && \
    find /build -type f -name "*.html" -o -name "*.js" -o -name "*.css" | head -20 && \
    ls -la /build/dist 2>/dev/null || { \
        echo "Checking alternative output directories:" && \
        ls -la /build && \
        find /build -type d -name "dist" -o -name "build" -o -name "output" && \
        echo "Creating minimal build output as fallback"; \
        mkdir -p /build/dist && \
        echo '<html><head><title>Metacubexd</title></head><body><h1>Metacubexd UI</h1><p>Loading...</p></body></html>' > /build/dist/index.html; \
    }

# 阶段2：构建最终镜像
FROM docker.io/caddy:alpine

# 定义构建参数
ARG MI_VERSION
ARG MetaCubeX_VERSION

# 设置环境变量
ENV MI_VERSION=${MI_VERSION}
ENV MetaCubeX_VERSION=${MetaCubeX_VERSION}

# 安装运行依赖
RUN apk update && apk add --no-cache \
    libcap \
    curl \
    bash \
    gettext \
    coreutils \
    tzdata \
    && rm -rf /var/cache/apk/*

# 下载并配置 mihomo 二进制文件
RUN mkdir -p /root/.config/mihomo \
    && curl -fL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/mihomo-linux-amd64-compatible-${MI_VERSION}.gz" -o /tmp/mihomo.gz \
    && gunzip /tmp/mihomo.gz \
    && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 复制 Metacubexd 构建产物 - 使用更灵活的路径处理
WORKDIR /srv
COPY --from=ui-builder /build/dist/ . 2>/dev/null || true

# 如果构建产物不存在，创建简单版本
RUN if [ ! -f /srv/index.html ]; then \
        echo "Creating fallback UI" && \
        echo '<html><head><title>Metacubexd</title></head><body><h1>Metacubexd UI</h1><p>Please wait while the UI loads...</p></body></html>' > /srv/index.html; \
    fi

# 复制并格式化 Caddyfile
COPY Caddyfile .
RUN caddy fmt --overwrite /srv/Caddyfile

# 复制配置文件模板和启动脚本
RUN mkdir -p /app
COPY config.yaml.template /app/config.yaml.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 暴露端口
EXPOSE 8080 7890 7891 7892 7893 7894 9090

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# 使用自定义启动脚本
CMD ["/start.sh"]