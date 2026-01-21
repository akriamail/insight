# 🎯 Portainer 使用指南 - 积木式服务管理

## 📋 概述

Portainer 是一个**完全免费开源**的 Docker Web 管理界面，让你像"堆积木"一样管理所有服务。

**适合场景：**
- ✅ 4人小团队，技术维护水平一般
- ✅ 不想记命令行，想要可视化界面
- ✅ 需要勾选式启动/停止服务
- ✅ 需要查看容器状态、日志、资源使用

---

## 🚀 快速开始

### 1. 安装 Portainer

```bash
cd /opt/insight
bash infra/scripts/08-install-portainer.sh
```

安装完成后，访问：`http://你的服务器IP:9000`

### 2. 首次登录设置

1. 打开浏览器访问 Portainer
2. 设置管理员密码（至少8位）
3. 选择 **"Docker"** 环境（本地 Docker）

---

## 🧩 积木式服务管理

### 方式一：在 Portainer 中导入现有服务（推荐）

你现有的每个 `compose` 文件都可以作为一个 **Stack（堆栈）** 导入：

#### 步骤：

1. **进入 Stacks 页面**
   - 左侧菜单 → `Stacks` → `Add stack`

2. **导入服务模块**
   
   每个服务单独导入，命名建议：
   - `gateway` - Nginx Proxy Manager
   - `databases` - PostgreSQL
   - `workflow` - n8n
   - `data-viz` - NocoDB
   - `knowledge` - Wiki.js
   - `portainer` - Portainer 自己

3. **导入方式选择 "Web editor"**
   - 复制对应 compose 文件内容
   - 粘贴到编辑器
   - 点击 `Deploy the stack`

4. **环境变量处理**
   - Portainer 会自动读取 `.env` 文件
   - 或者在 Stack 编辑页面手动添加环境变量

#### 示例：导入 Gateway 服务

```yaml
# 复制 infra/compose/01-gateway.yml 的内容
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: insight-gateway
    # ... 其他配置
```

---

### 方式二：通过命令行创建，在 Portainer 中管理

如果你已经用 `manage.sh` 启动了服务，Portainer 会自动识别这些容器，你可以：

1. 在 `Containers` 页面看到所有运行中的容器
2. 点击容器名称，可以：
   - 查看日志
   - 重启/停止/删除
   - 查看资源使用（CPU/内存）
   - 进入容器终端

---

## 🎨 积木式组合使用

### 场景1：只启动部分服务

**需求：** 只想启动数据库和 Wiki，不启动 n8n

**操作：**
1. 进入 `Stacks` 页面
2. 找到 `workflow` (n8n) 和 `data-viz` (NocoDB)
3. 点击 `Stop` 停止这些服务
4. 只保留 `databases` 和 `knowledge` 运行

### 场景2：迁移服务到另一台机器

**需求：** 把 n8n 迁移到独立服务器

**操作：**
1. **在原机器：**
   - Portainer → `Stacks` → `workflow` → `Editor`
   - 导出 compose 配置（复制 YAML）

2. **在新机器：**
   - 安装 Portainer（如果还没有）
   - 创建新 Stack，粘贴配置
   - 修改环境变量（数据库地址等）
   - 部署 Stack

3. **数据迁移：**
   - 使用现有的 `04-backup.sh` 备份 n8n 数据
   - 在新机器用 `05-restore.sh` 恢复

### 场景3：一台机器装多个应用

**需求：** 在服务器A上同时运行 Wiki 和 Ghost CMS

**操作：**
1. 在 Portainer 中创建两个 Stack：
   - `knowledge` (Wiki)
   - `ghost-cms` (Ghost)
2. 两个 Stack 共享同一个数据库 Stack (`databases`)
3. 在 Nginx Proxy Manager 中配置两个域名分别指向这两个服务

---

## 📊 监控与状态

### 基础监控（Portainer 自带）

1. **容器状态**
   - `Containers` 页面：绿色=运行中，红色=停止
   - 点击容器查看详细信息

2. **资源使用**
   - `Containers` → 点击容器 → `Stats` 标签
   - 实时显示 CPU、内存、网络使用

3. **日志查看**
   - `Containers` → 点击容器 → `Logs` 标签
   - 可以搜索、过滤日志

### 如果需要更详细的监控（可选）

后续可以添加 **Grafana + Prometheus**，但 Portainer 的基础监控对4人小团队通常够用了。

---

## 🔧 备份与恢复

### 在 Portainer 中触发备份

虽然 Portainer 没有内置备份功能，但你可以：

1. **通过 Portainer 执行脚本**
   - `Containers` → 找到任意容器 → `Console`
   - 或者创建临时容器执行备份脚本

2. **更好的方式：包装成 API 调用**
   - 后续可以在 Portainer 中添加"自定义脚本"按钮
   - 或者通过 Webhook 触发备份

**目前建议：** 继续使用 `manage.sh` 的备份功能，Portainer 主要用于日常管理。

---

## 🎯 1.2 版本规划建议

### 短期（1.2.0）

1. ✅ 集成 Portainer（已完成）
2. ✅ 每个服务独立 Stack（可勾选启动）
3. 🔄 优化备份脚本，支持按服务备份

### 中期（1.2.1）

1. 添加服务依赖关系（例如：apps 依赖 databases）
2. 一键迁移向导（在 Portainer 中点击按钮完成迁移）
3. 简单的 Dashboard（显示所有服务健康状态）

### 长期（1.3.0）

1. 多机器管理（Portainer Agent）
2. 自动备份调度（定时任务）
3. 告警通知（服务异常时发邮件/微信）

---

## ❓ 常见问题

### Q: Portainer 安全吗？

A: Portainer CE 是开源免费的，代码公开可审计。建议：
- 使用 HTTPS（通过 Nginx Proxy Manager）
- 设置强密码
- 限制访问 IP（防火墙规则）

### Q: 会影响现有脚本吗？

A: **不会**。Portainer 只是 Docker 的 Web 界面，你的 `manage.sh` 和所有脚本都可以继续使用。两者可以共存。

### Q: 可以同时用命令行和 Portainer 吗？

A: **可以**。Portainer 和命令行操作的是同一个 Docker 环境，两者完全兼容。

### Q: 如果 Portainer 容器挂了怎么办？

A: Portainer 只是管理工具，不影响你的业务服务。可以：
- 用命令行重启：`docker restart insight-portainer`
- 或者直接用 `manage.sh` 管理

---

## 📚 更多资源

- Portainer 官方文档：https://docs.portainer.io/
- Portainer CE GitHub：https://github.com/portainer/portainer

---

**总结：Portainer 让你用 Web 界面"堆积木"管理服务，简单直观，完全免费，适合小团队！** 🎉
