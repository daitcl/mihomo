# Mihomo 代理服务容器化部署

## 项目概述
基于Mihomo核心的Docker化代理解决方案，提供：
- 多协议代理服务(HTTP/SOCKS5)
- 可视化规则管理界面
- 自动订阅更新机制
- TUN模式支持（需额外配置）

## 快速入门
```bash
# 创建环境配置文件
cp .env.example .env

# 启动容器（开发模式）
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 环境配置
在`.env`文件中设置：
```ini
# 基础配置
MI_VERSION=latest
TZ=Asia/Shanghai

# 安全配置（从安全渠道获取）
CLASH_SECRET=your_secure_secret
SUBSCRIBE_URL=your_subscription_endpoint
```

## 多环境部署
| 配置项       | 开发环境          | 生产环境          |
|--------------|-------------------|-------------------|
| 镜像版本     | latest            | v1.x.x            |
| 日志级别     | debug             | warning           |
| 健康检查间隔 | 30s               | 60s               |

## 端口说明
| 端口  | 协议    | 用途               |
|-------|---------|--------------------|
| 7890  | HTTP    | 网页代理           |
| 7891  | SOCKS5  |  socks5代理        |
| 9090  | HTTP    | 控制API            |
| 7888  | HTTP    | 规则管理界面       |

## 安全实践
1. 定期轮换CLASH_SECRET
2. 通过volume持久化配置
3. 使用网络隔离(clash-net)
4. 按需启用TUN模式

## 文档链接
- [Mihomo文档](https://github.com/MetaCubeX/mihomo)
- [Docker最佳实践](https://docs.docker.com/develop/)

## 直接使用镜像部署

```yaml
version: '3.8'

services:
  mihomo:
    container_name: mihomo
    image: daitcl/mihomo:v1.19.11  # 使用官方镜像
    restart: always
    environment:
      - TZ=Asia/Shanghai  # 时区设置
      - LOG_LEVEL=silent  # 日志级别: silent/info/debug
      - CLASH_SECRET=  # Web UI访问密钥
      - SUBSCRIBE_URL=your_subscribe_url  # 订阅链接
      - SUBSCRIBE_NAME=your_subscribe_name  # 订阅名称
    ports:
      - "7890:7890"  # HTTP代理
      - "7891:7891"  # SOCKS5代理
      - "7892:7892"  # 混合代理
      - "9090:9090"  # 控制API
      - "7888:80"    # Web UI
    volumes:
      - ./clash-config:/root/.config/mihomo  # 配置文件目录
      - ./metacubexd-config:/config/caddy     # Web UI配置目录
    networks:
      - clash-net

networks:
  clash-net:
    driver: bridge
```