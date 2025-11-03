# 阶段1：构建 Metacubexd 前端
FROM docker.io/node:20-alpine AS ui-builder

ARG MetaCubeX_VERSION

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
ENV HUSKY=0
ENV NODE_OPTIONS="--max_old_space_size=4096"
WORKDIR /build

# 安装系统依赖（修复版本）
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

# 安装依赖并构建（使用更稳定的配置）
RUN pnpm install --frozen-lockfile --ignore-scripts && \
    pnpm build

# 阶段2：构建最终镜像
FROM docker.io/caddy:alpine

ARG MI_VERSION

# 安装运行依赖
RUN apk update && apk add --no-cache \
    libcap \
    curl \
    bash \
    gettext \
    && rm -rf /var/cache/apk/*

# 下载并配置 mihomo 二进制文件
RUN mkdir -p /root/.config/mihomo \
    && curl -fL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/mihomo-linux-amd64-compatible-${MI_VERSION}.gz" -o /tmp/mihomo.gz \
    && gunzip /tmp/mihomo.gz \
    && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 下载地理数据文件
RUN curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" -o /root/.config/mihomo/GeoSite.dat \
    && curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" -o /root/.config/mihomo/GeoIP.dat \
    && curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" -o /root/.config/mihomo/Country.mmdb

# 复制 Metacubexd 构建产物
WORKDIR /srv
COPY --from=ui-builder /build/dist .

# 复制并格式化 Caddyfile
COPY Caddyfile .
RUN caddy fmt --overwrite /srv/Caddyfile

# 复制配置文件模板和启动脚本
RUN mkdir -p /app
COPY config.yaml.template /app/config.yaml.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 清理缓存以减小镜像大小
RUN rm -rf /var/cache/apk/* /tmp/* /var/tmp/* ~/.cache

# 暴露端口
EXPOSE 8080 7890 7891 7892 7893 7894 9090

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# 使用自定义启动脚本
CMD ["/start.sh"]
