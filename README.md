<h3><div align="center">mihomo 镜像</div>

---

<div align="center">
  <img src="https://img.shields.io/github/last-commit/daitcl/mihomo" alt="最后提交">
  <img src="https://img.shields.io/github/actions/workflow/status/daitcl/mihomo/docker-build.yml" alt="构建状态">
  <a href="https://github.com/daitcl/mihomo/blob/main/License">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT许可证">
  </a>
 <a href="https://hub.docker.com/r/daitcl/mihomo">
   <img src="https://img.shields.io/docker/pulls/daitcl/mihomo" alt="Docker Hub Pulls">
 </a>
  <a href="https://github.com/daitcl/mihomo/pkgs/container/mihomo">
    <img src="https://img.shields.io/badge/GHCR.io-Package-blue?logo=github" alt="GHCR Package">
  </a>
</div>

mihomo 是一个基于 Clash 核心的代理工具镜像，集成了 Metacubexd 管理面板，提供强大的代理功能和直观的 Web 管理界面。

### 拉取镜像
```bash
# Docker Hub
docker pull daitcl/mihomo:latest
# GitHub Container Registry
docker pull ghcr.io/daitcl/mihomo:latest
# 启动容器
docker run -d --name mihomo -p 7890:7890 -p 8080:8080 daitcl/mihomo:latest
```

### docker-compose.yml配置文件

```yaml
version: '3.8'

services:
  mihomo:
    container_name: mihomo
    image: daitcl/mihomo:latest
    restart: always
    environment:
      # 核心配置
      - TZ=Asia/Shanghai
      - LOG_LEVEL=silent
      - CLASH_SECRET=  
      - SUBSCRIBE_URL=your_subscribe_url
      - SUBSCRIBE_NAME=your_subscribe_name
    ports:
      - "7890:7890"  # HTTP代理
      - "7891:7891"  # SOCKS5代理
      - "7892:7892"  # 混合代理
      - "7893:7893"  # TPROXY
      - "7894:7894"  # REDIR
      - "9090:9090"  # Clash控制API
      - "8080:8080"  # Metacubexd Web UI
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090"]
      interval: 30s
      timeout: 10s
      retries: 3
    volumes:
      - ./clash-config:/root/.config/mihomo  # Clash配置文件目录
      - ./metacubexd-config:/config/caddy    # Metacubexd配置目录
      # - /etc/timezone:/etc/timezone:ro       # 共享主机时区
      # - /etc/localtime:/etc/localtime:ro
    # 如需启用TUN模式，取消以下注释
    # cap_add:
    #   - NET_ADMIN
    # devices:
    #   - /dev/net/tun:/dev/net/tun
    networks:
      - clash-net

networks:
  clash-net:
    driver: bridge
```

>
> 仓库地址：https://github.com/daitcl/mihomo
>
> 作者：[daitcl](https://blog.daitcc.top)
>
> 项目源码：[mihomo](https://github.com/MetaCubeX/mihomo) | [Metacubexd](https://github.com/MetaCubeX/metacubexd)
>
> 协议：[MIT](License)
> 

###  微信公众号
![微信公众号](./img/gzh.jpg)

---

### 赞赏

请我一杯咖啡吧！

![赞赏码](./img/skm.jpg)
