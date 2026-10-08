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

---

## 🚀 快速上手（30 秒）

1. **准备订阅链接**：从机场/订阅服务商获取订阅 URL（形如 `https://example.com/sub?token=xxx`）。免费订阅可网上自行搜索。
2. **创建网络并运行容器**：

```bash
docker network create clash-net
docker run -d --name mihomo --restart always --network clash-net \
  -p 7890:7890 -p 7891:7891 -p 7892:7892 -p 7893:7893 -p 7894:7894 \
  -p 9090:9090 -p 8080:8080 \
  -e SUBSCRIBE_URL="你的订阅链接" \
  -e TZ=Asia/Shanghai \
  daitcl/mihomo:latest
```

3. **访问面板**：浏览器打开 `http://<服务器IP>:8080`，登录后即可切换节点、查看流量。

> 提示：你将 v 换成上一步拿到的实际版本号，避免使用 `latest` 时可固定版本，例如 `docker pull daitcl/mihomo:v1.19.25`。

---

## 🔌 环境变量说明

| 变量 | 默认值 | 说明 |
|---|---|---|
| `SUBSCRIBE_URL` | （必填） | 订阅链接，格式 `https://...`，容器会用它生成 `proxy-providers` 配置 |
| `SUBSCRIBE_NAME` | `default` | 订阅在配置中的名称，建议使用英文字母/数字（不能有空格或特殊字符） |
| `CLASH_SECRET` | 空 | 外部控制器（9090 端口）的访问密钥；**设置后访问面板也需要输入** |
| `LOG_LEVEL` | `info` | mihomo 日志级别，可设为 `silent` 关闭大部分日志 |
| `TZ`（非脚本） | `Asia/Shanghai` | 时区，供容器内 `tzdata` 使用 |

---

## 🐳 拉取镜像

```bash
# Docker Hub
docker pull daitcl/mihomo:latest
# GitHub Container Registry
docker pull ghcr.io/daitcl/mihomo:latest
```

> 建议固定版本（如 `docker pull daitcl/mihomo:vX.Y.Z`）以保证行为可预期，`latest` 跟随最新构建。

---

## 📦 单容器运行方式（详细）

```bash
# 创建容器网络
docker network create clash-net

# 启动容器
docker run -d \
  --name mihomo \
  --restart always \
  --network clash-net \
  -p 7890:7890 \
  -p 7891:7891 \
  -p 7892:7892 \
  -p 7893:7893 \
  -p 7894:7894 \
  -p 9090:9090 \
  -p 8080:8080 \
  -e TZ=Asia/Shanghai \
  -e LOG_LEVEL=silent \
  -e CLASH_SECRET="" \
  -e SUBSCRIBE_URL="your_subscribe_url" \
  -e SUBSCRIBE_NAME="your_subscribe_name" \
  -v "$(pwd)/clash-config:/root/.config/mihomo" \
  -v "$(pwd)/metacubexd-config:/config/caddy" \
  --health-cmd "curl -f http://localhost:9090" \
  --health-interval 30s \
  --health-timeout 10s \
  --health-retries 3 \
  daitcl/mihomo:latest
```

**参数说明：**

- `-p 7890:7890` — HTTP 代理端口
- `-p 7891:7891` — SOCKS5 代理端口
- `-p 7892:7892` — 混合端口（HTTP+SOCKS5）
- `-p 7893:7893` — REDIR 端口
- `-p 7894:7894` — TPROXY 端口
- `-p 9090:9090` — Clash 外部控制 API
- `-p 8080:8080` — Metacubexd Web UI
- `-v $(pwd)/clash-config:/root/.config/mihomo` — **持久化** mihomo 配置/订阅（首次为空目录时自动生成 config.yaml）
- `-v $(pwd)/metacubexd-config:/config/caddy` — **持久化**面板数据（Caddy 数据目录）

---

## 🧩 docker-compose.yml 使用方式

### 方式一：直接用仓库自带的 compose 文件

```bash
# 克隆并进入目录
git clone https://github.com/daitcl/mihomo.git
cd mihomo

# 修改 docker-compose.yml 中的 SUBSCRIBE_URL
# （或复制一份另用）
sed -i 's|your_subscribe_url|你的订阅链接|' docker-compose.yml

# 启动
docker-compose up -d
```

### 方式二：创建你自己的 compose 文件

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

> 若容器网络 `clash-net` 不存在，`docker-compose up -d` 会自动创建（compose 会管理声明的网络）。单独使用 `docker network create` 仅用于 `docker run` 场景。

---

## 🛠 使用技巧

- **切换订阅**：更新容器挂载目录内的 `config.yaml`，或修改 `SUBSCRIBE_URL` 后重建容器。
- **修改自定义规则**：编辑挂载目录 `/root/.config/mihomo` 下的 `config.yaml`（首次由模板生成的）。注意：模板只在配置不存在时生效。
- **重启生效**：配置文件改动后 `docker restart mihomo`。

## ⚠️ 常见问题

- **面板打不开**：检查 `8080` 端口是否映射，`docker logs mihomo` 查看 Caddy 日志。
- **订阅配置无效**：确认 `SUBSCRIBE_URL` 格式（以 `https://` 开头），若订阅含特殊字符请 URL 编码。
- **节点不显示**：节点来自订阅，URL 错误或墙外时 `proxy-providers` 拉取会失败，查看 mihomo 日志确认。
- **TUN 模式**：启用 TUN 后，宿主机需 `NET_ADMIN` 权限并挂载 `/dev/net/tun` 设备，取消 compose 中注释即可。

---

>
> 仓库地址：https://github.com/daitcl/mihomo
>
> 作者：[daitcl](https://blog.daitcc.top)
>
> 项目源码：[mihomo](https://github.com/MetaCubeX/mihomo) | [Metacubexd](https://github.com/MetaCubeX/metacubexd)
>
> 协议：[MIT](License)
> 

### 📄 许可证

>
>协议：[MIT](License) — 允许任何人自由使用、复制、修改、合并、发布、分发、再授权和/或销售软件的副本，前提是保留原始版权声明和许可声明。
>
>免责声明：软件按“原样”提供，不附带任何明示或暗示的保证，包括但不限于适销性、特定用途适用性和非侵权的保证。在任何情况下，作者或版权持有人均不对任何索赔、损害或其他责任负责，无论是在合同诉讼、侵权诉讼或其他诉讼中，由于软件或软件的使用或其他交易引起的。
>

### 🔗 来找我

- **CSDN**：[daitcl的博客](https://blog.csdn.net/qq_39538318) — csdn、技术文章和教程
- **GitHub**：[@daitcl](https://github.com/daitcl) —  个人代码仓库（**gitee/gitcode**同名同步）
- **爱发电**：[爱发电主页](https://ifdian.net/a/daitcc) — 欢迎支持、分享或合作
- **个人主页**：[daitcc.top](https://www.daitcc.top) — 个人主页、技术文章和教程
- **邮箱**：daitcctop@163.com — 欢迎交流、指正或闲聊
- **微信公众号**：扫一扫下方二维码，关注公众号获取更新推送  
  <img src="https://raw.gitcode.com/daitcl/picgo/raw/main/wechat_qrcode.jpg" alt="微信公众号二维码" width="150" />

### ☕ 支持与鼓励

>
> 如果代码对你有所启发，或者单纯想请我喝杯咖啡，可以通过下方的 **爱发电** 或者 **支付宝/微信赞赏码** 来支持我创作。每一份鼓励都是我持续创作的动力。
>

- **爱发电**：[赞助作者](https://ifdian.net/a/daitcc) — 点击链接即可支持  
  <img src="https://raw.gitcode.com/daitcl/picgo/raw/main/ifdian.png" alt="爱发电" width="150" />
  
- **支付宝赞赏**：扫一扫下方二维码  
  <img src="https://raw.gitcode.com/daitcl/picgo/raw/main/alipay.png" alt="支付宝收款码" width="150" />      

- **微信赞赏**：扫一扫下方二维码  
  <img src="https://raw.gitcode.com/daitcl/picgo/raw/main/wechatpay.png" alt="微信赞赏码" width="150" />

>“独行快，众行远。” 感谢你的每一次阅读、点赞和分享。  
>期待在技术道路上，与你并肩前行。
