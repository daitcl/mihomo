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

### 🔗 来找我

- **CSDN**：[daitcl的博客](https://blog.csdn.net/qq_39538318)
- **GitHub**：[@daitcl](https://github.com/daitcl) — 个人代码仓库（**gitee/gitcode**同名同步）
- **爱发电**：[爱发电主页](https://ifdian.net/a/daitcc) — 欢迎支持、分享或合作
- **个人网站**：[daitcc.top](https://www.daitcc.top) — （**你正在这里**）
- **邮箱**：daitcctop@163.com — 欢迎交流、指正或闲聊
- **微信公众号**：扫一扫下方二维码，获取更新推送  
  <img src="./img/wechat_qrcode.jpg" alt="微信公众号二维码" width="150" />

### ☕ 支持与鼓励

如果代码/容器对你有所启发，或者单纯想请我喝杯咖啡，  
可以通过下方的 **爱发电** 或者 **支付宝/微信赞赏码** 来支持我创作。  
每一份鼓励都是我持续创作的动力。

- **爱发电**：[赞助作者](https://ifdian.net/a/daitcc) — 点击链接即可支持  
  <img src="./img/ifdian.png" alt="爱发电" width="150" />
  
- **支付宝赞赏**：扫一扫下方二维码  
  <img src="./img/alipay.png" alt="支付宝收款码" width="150" />      

- **微信赞赏**：扫一扫下方二维码  
  <img src="./img/wechatpay.png" alt="微信赞赏码" width="150" />
