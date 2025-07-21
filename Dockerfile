FROM docker.io/node:alpine AS ui-builder 
# 阶段1：构建 Metacubexd 前端
ARG MetaCubeX_VERSION

ENV HUSKY=0
WORKDIR /build

# 克隆指定版本仓库并安装构建依赖
RUN apk add --no-cache git gettext \
    && git clone -b ${MetaCubeX_VERSION} https://github.com/MetaCubeX/metacubexd.git . \
    && corepack enable \
    && corepack prepare pnpm@latest --activate \
    && pnpm install \
    && pnpm build

# 阶段2：构建最终镜像
FROM docker.io/caddy:alpine

ARG MI_VERSION

# 安装依赖并配置运行环境
RUN apk add --no-cache libcap curl gettext

# 下载并配置mihomo二进制文件
RUN mkdir -p /root/.config/mihomo \
    && curl -fL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/mihomo-linux-amd64-compatible-${MI_VERSION}.gz" -o /tmp/mihomo.gz \
    && gunzip /tmp/mihomo.gz \
    && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 下载地理数据文件
RUN curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" -o /root/.config/mihomo/GeoSite.dat \
    && curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat" -o /root/.config/mihomo/GeoIP.dat \
    && curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb" -o /root/.config/mihomo/Country.mmdb \
    && curl -fL "https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb" -o /root/.config/mihomo/GeoASN.dat

# 复制 Metacubexd 构建产物
WORKDIR /srv
COPY --from=ui-builder /build/dist/. .

# 复制并格式化 Caddyfile
COPY Caddyfile .
RUN caddy fmt --overwrite

# 复制配置文件模板
RUN mkdir -p /app
COPY config.yaml.template /app/config.yaml.template

# 添加启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 暴露端口
EXPOSE 8080 7890 7891 7892 7893 7894 9090

# 使用自定义启动脚本
CMD ["/start.sh"]