# 阶段1：构建 Metacubexd 前端
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

# 克隆指定版本的 metacubexd
RUN git clone -b ${MetaCubeX_VERSION} --depth 1 https://github.com/MetaCubeX/metacubexd.git .

# 安装依赖并构建
RUN pnpm install --frozen-lockfile --ignore-scripts && \
    pnpm build

# 验证构建产物
RUN echo "=== Build output structure ===" && \
    find /build -name "index.html" -o -name "*.js" -o -name "*.css" | head -10 && \
    ls -la /build/dist 2>/dev/null || echo "No dist directory found" && \
    echo "=== Checking alternative build output locations ===" && \
    find /build -type f -name "*.html" | head -5

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

# 下载地理数据文件（基础文件）
RUN curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" -o /root/.config/mihomo/GeoSite.dat \
    && curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" -o /root/.config/mihomo/GeoIP.dat

# 复制 Metacubexd 构建产物 - 修复路径问题
WORKDIR /srv
COPY --from=ui-builder /build/dist/ .

# 验证复制的文件
RUN echo "=== Copied files in /srv ===" && \
    ls -la /srv 2>/dev/null || echo "No files in /srv" && \
    echo "=== Searching for index.html ===" && \
    find /srv -type f -name "index.html" 2>/dev/null | head -3

# 如果构建产物不存在，创建一个简单的占位文件
RUN if [ ! -f /srv/index.html ]; then \
        echo "Creating placeholder index.html" && \
        mkdir -p /srv && \
        echo "<html><body><h1>Metacubexd UI</h1><p>Build output not found. Check the build process.</p></body></html>" > /srv/index.html; \
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