# 🚀 Project Team - Insight Infrastructure

## 项目概述
Project Team Insight Infrastructure 是一个基于 Docker Compose 部署的集成基础设施管理系统。它采用扁平化架构设计，旨在实现“配置与数据分离”，提供一键部署、交互式管理与全量备份功能，为团队提供一套高效、稳定的运营支撑环境。

## 功能特性
*   **统一网关管理:** 基于 Nginx Proxy Manager，实现 HTTP/HTTPS 流量的统一代理、负载均衡和自动化 SSL 证书管理。
*   **核心数据库服务:** 使用 PostgreSQL 作为所有应用的基础数据存储，确保数据可靠性和一致性。
*   **灵活的工作流自动化:** 集成 n8n，支持可视化地构建和自动化复杂的业务流程与集成任务。
*   **数据可视化与低代码:** 利用 NocoDB 提供强大的数据表格界面和低代码开发能力，简化数据管理和应用构建。
*   **团队知识管理:** 搭建 Wiki.js 知识库平台，促进团队知识沉淀、共享与协作。
*   **全面的系统管理:**
    *   **一键初始化:** 自动化安装 Docker 等运行环境。
    *   **服务生命周期:** 方便地启动、停止所有容器化服务。
    *   **实时监控:** 提供 CPU、内存、磁盘占用及 Docker 容器资源的实时监控报告。
    *   **全量备份与恢复:** 实现 Nginx Proxy Manager 配置和所有 PostgreSQL 数据库的全量备份，并支持一键恢复到最新状态。
    *   **一键清空数据:** 快速停止所有容器、移除网络并删除持久化数据，方便重新部署和测试。
*   **配置与数据分离:** 通过清晰的目录结构和 Docker 卷挂载，确保业务数据与应用配置独立管理，方便升级和迁移。

## 技术栈
*   **容器化:** Docker, Docker Compose
*   **网关:** Nginx Proxy Manager
*   **数据库:** PostgreSQL
*   **工作流:** n8n
*   **数据管理:** NocoDB
*   **知识库:** Wiki.js
*   **脚本语言:** Bash

## 目录结构
```
.
├── manage.sh              # 🚀 唯一交互式入口 (按数字键操作)
├── README.md              # 本项目操作说明
├── .gitignore             # Git 忽略配置
├── .env.example           # 环境变量配置示例文件
├── data/                  # [生产数据] 实际业务数据挂载点
│   ├── 01-gateway/        # Nginx Proxy Manager 配置文件持久化
│   ├── 02-security/       # (预留) 安全服务数据
│   ├── 03-databases/      # Postgres 数据库原始文件持久化
│   ├── 04-workflow/       # n8n 工作流数据持久化
│   ├── 05-data-viz/       # NocoDB 数据持久化
│   ├── 05-registry/       # (预留) 容器镜像仓库数据
│   ├── 06-knowledge/      # Wiki.js 知识库数据持久化
│   └── ...                # 其他服务数据
├── infra/                 # [核心配置] 基础设施相关配置与脚本
│   ├── compose/           # Docker Compose 蓝图文件 (.yml)
│   └── scripts/           # 自动化运维脚本 (backup/restore/setup/startup/shutdown/init-db)
├── exports/               # [备份产出] 存放生成的全量备份压缩包
└── backups/               # [临时备份区] 存放细粒度备份文件 (网关、数据库)
```

## 快速入门

### 1. 全新服务器部署 (推荐)
对于一台全新的服务器，推荐使用此选项一键完成所有基础环境搭建、服务启动和数据库初始化。

```bash
git clone https://github.com/akriamail/insight.git /opt/insight
cd /opt/insight
# 选择菜单中的 8 (全新服务器部署)
./manage.sh
```

### 2. 交互式管理入口
只需运行根目录下的 `manage.sh` 脚本，即可进入图形化数字菜单，进行各种操作：

```bash
./manage.sh
```

**菜单功能一览：**
*   **1) 🚀 启动服务 (Up):** 拉起所有容器并自动初始化数据库。
*   **2) 🛑 停止服务 (Down):** (需确认) 安全移除所有容器。
*   **3) 📊 容器状态 (Status):** 快速查看当前业务运行详情，包含镜像名称、状态和端口信息。要查看更详细的容器资源使用情况 (CPU/内存/网络)，请选择选项 4) 🌡️  系统监控 (Monitor)。
*   **4) 🌡️ 系统监控 (Monitor):** 实时查看 CPU、内存、磁盘占用及容器资源使用。
*   **5) 📂 执行备份 (Backup):** 生成全量数据包至 `exports/`。
*   **6) ⚠️ 全量恢复 (Restore):** (需确认) 从备份包一键还原所有数据。
*   **7) 🛠️ 初始化基础环境 (Init Base Env):** (需确认) 仅安装 Docker 等基础环境并进行内核优化。
*   **8) ✨ 全新服务器部署 (Full Setup):** (需确认) 整合选项 7、选项 1 和数据库初始化，一键完成所有部署。
*   **9) 🗑️ 清空所有数据 (Clear All Data):** (需确认) 快速停止所有容器、移除网络并删除持久化数据 (保留 Docker 镜像)。
*   **0) 🚪 退出 (Exit):** 退出管理系统。

## 环境变量配置
为了方便管理和适应不同部署环境，本项目支持通过 `.env` 文件来配置各项参数。
**请在项目根目录 `/opt/insight/` 下创建 `.env` 文件。**

你可以复制 `.env.example` 中的内容作为起点，并根据你的需求进行修改。
**示例 `.env` 文件内容 (`/opt/insight/.env.example`):
```
# .env.example - Insight 基础设施的环境变量配置示例

# 数据库配置
DB_PASSWORD=insight_password_2024

# Docker 网络配置
DOCKER_NETWORK_NAME=insight-net

# 服务端口配置 (示例 - 根据需要调整)
# NGINX_PROXY_MANAGER_HTTP_PORT=80  # Nginx Proxy Manager HTTP 端口
# NGINX_PROXY_MANAGER_HTTPS_PORT=443 # Nginx Proxy Manager HTTPS 端口
# NGINX_PROXY_MANAGER_ADMIN_PORT=81 # Nginx Proxy Manager 后台管理端口
# N8N_PORT=5678 # n8n 服务端口
# NOCODB_PORT=8080 # NocoDB 服务端口
# WIKIJS_PORT=3000 # Wiki.js 服务端口

# 服务域名配置 (示例 - 根据需要调整)
# N8N_HOST=n8n.yourdomain.com # n8n 服务域名
# NOCODB_HOST=nocodb.yourdomain.com # NocoDB 服务域名
# WIKIJS_HOST=wiki.yourdomain.com # Wiki.js 服务域名

# Docker 镜像加速器配置
# Set to 'false' to disable Docker registry mirrors (e.g., for overseas hosts)
USE_DOCKER_MIRRORS=true
```
**配置生效：** 更改 `.env` 文件后，通常需要重启相关的 Docker Compose 服务才能使新配置生效。你可以使用 `manage.sh` 中的 `9) 🗑️ 清空所有数据 (Clear All Data)` 然后 `8) ✨ 全新服务器部署 (Full Setup)` 来快速应用新的配置。

## 维护规范

*   **安全第一:** 涉及删除、停止和恢复等危险操作均设有 `(y/n)` 二次确认，请谨慎操作。
*   **Git 同步:** 仅提交 `infra/` 目录下的变更，严禁手动修改 `data/` 目录结构，以确保配置与数据分离的原则。
*   **环境凭证:** 敏感凭证（如数据库密码）通过环境变量管理，请勿硬编码到配置文件中。
*   **定期备份:** 建议定期执行全量备份，并将备份包存储在安全位置。
*   **版本控制:** 遵循 Git 最佳实践，提交前检查代码，编写清晰的提交信息。
