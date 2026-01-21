# 🎯 Portainer 独立安装指南

## 📋 概述

Portainer 可以**完全独立安装**，不依赖任何项目。你可以在任何有 Docker 的服务器上安装它，用来管理该服务器上的所有 Docker 容器。

---

## 🚀 快速安装

### 方式一：使用独立安装脚本（推荐）

```bash
# 下载并运行独立安装脚本
curl -fsSL https://raw.githubusercontent.com/你的仓库/insight/main/infra/scripts/09-install-portainer-standalone.sh | bash

# 或者如果脚本已经在本地
bash /opt/insight/infra/scripts/09-install-portainer-standalone.sh
```

### 方式二：手动安装（最灵活）

```bash
# 1. 创建数据目录
sudo mkdir -p /opt/portainer/data

# 2. 启动 Portainer
docker run -d \
    --name portainer \
    --restart=always \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/portainer/data:/data \
    portainer/portainer-ce:latest
```

### 方式三：使用 Docker Compose（适合已有 compose 环境）

创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
```

然后运行：
```bash
docker compose up -d
```

---

## 🔧 配置选项

### 自定义端口

```bash
# 使用环境变量
export PORTAINER_PORT=8080
bash 09-install-portainer-standalone.sh

# 或手动修改 docker run 命令
docker run -d \
    --name portainer \
    -p 8080:9000 \  # 改为 8080
    ...
```

### 自定义数据目录

```bash
# 使用环境变量
export PORTAINER_DATA_DIR=/data/portainer
bash 09-install-portainer-standalone.sh

# 或手动修改
docker run -d \
    --name portainer \
    -v /data/portainer:/data \
    ...
```

---

## 📍 安装位置说明

### 独立安装 vs 集成安装

| 特性 | 独立安装 | 集成安装（insight 项目） |
|------|---------|----------------------|
| **位置** | 任意服务器 | `/opt/insight` 项目内 |
| **数据目录** | `/opt/portainer/data` | `/opt/insight/data/00-portainer` |
| **网络** | 默认 bridge | `insight-net` |
| **依赖** | 仅需 Docker | 需要 insight 项目 |
| **适用场景** | 管理任意服务器 | 管理 insight 项目服务 |

### 推荐场景

- **独立安装**：当你只想管理一台服务器的 Docker，或者管理多个不相关的项目
- **集成安装**：当你已经在使用 insight 项目，想把 Portainer 作为项目的一部分

---

## 🎯 使用场景

### 场景1：管理单台服务器

```bash
# 在任何服务器上安装
bash 09-install-portainer-standalone.sh

# 访问 http://服务器IP:9000
# 可以管理这台服务器上的所有 Docker 容器
```

### 场景2：管理多台服务器（需要 Portainer Agent）

1. **主服务器**：安装 Portainer（使用上面的脚本）
2. **其他服务器**：安装 Portainer Agent

```bash
# 在其他服务器上安装 Agent
docker run -d \
    --name portainer_agent \
    --restart=always \
    -p 9001:9001 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker/volumes:/var/lib/docker/volumes \
    portainer/agent:latest
```

3. **在主服务器 Portainer 中添加环境**：
   - 进入 Portainer → `Environments` → `Add environment`
   - 选择 `Docker Standalone`
   - 输入 Agent 服务器的 IP 和端口（9001）

---

## 🔒 安全建议

### 1. 使用 HTTPS（推荐）

通过 Nginx Proxy Manager 或其他反向代理配置 HTTPS：

```nginx
# Nginx 配置示例
server {
    listen 443 ssl;
    server_name portainer.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. 限制访问 IP

使用防火墙只允许特定 IP 访问：

```bash
# UFW 示例
sudo ufw allow from 你的IP to any port 9000
sudo ufw deny 9000
```

### 3. 设置强密码

首次登录时设置强密码（至少12位，包含大小写字母、数字、特殊字符）

---

## 🛠️ 管理命令

### 启动/停止/重启

```bash
# 启动
docker start portainer

# 停止
docker stop portainer

# 重启
docker restart portainer
```

### 查看日志

```bash
docker logs -f portainer
```

### 更新 Portainer

```bash
# 停止旧容器
docker stop portainer
docker rm portainer

# 拉取最新镜像
docker pull portainer/portainer-ce:latest

# 重新运行（使用相同命令）
docker run -d \
    --name portainer \
    --restart=always \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/portainer/data:/data \
    portainer/portainer-ce:latest
```

### 卸载 Portainer

```bash
# 停止并删除容器
docker stop portainer
docker rm portainer

# 删除数据（可选，会丢失所有配置）
sudo rm -rf /opt/portainer/data

# 删除镜像（可选）
docker rmi portainer/portainer-ce:latest
```

---

## ❓ 常见问题

### Q: 独立安装和集成安装可以共存吗？

A: **可以**，但通常不需要。如果你已经在 insight 项目中安装了 Portainer，就不需要再独立安装。两者功能相同，只是数据存储位置不同。

### Q: 可以同时管理多台服务器吗？

A: **可以**。需要：
1. 在主服务器安装 Portainer
2. 在其他服务器安装 Portainer Agent
3. 在 Portainer 中添加这些环境

### Q: 独立安装会影响现有容器吗？

A: **不会**。Portainer 只是管理工具，不会影响任何现有容器。它只是读取 Docker 的状态并提供 Web 界面。

### Q: 数据会丢失吗？

A: Portainer 的配置存储在 `/opt/portainer/data`（或你指定的目录）。只要这个目录存在，即使删除容器重新安装，配置也不会丢失。

---

## 📚 更多资源

- Portainer 官方文档：https://docs.portainer.io/
- Portainer CE GitHub：https://github.com/portainer/portainer
- Portainer 社区论坛：https://github.com/portainer/portainer/discussions

---

**总结：Portainer 完全可以独立安装，适合管理任意服务器的 Docker 环境！** 🎉
