# 🐛 Bug 修复记录 (Bug Fix Log)

本文档记录所有已修复的 Bug 及其解决方案，按版本号倒序排列。

---

## v1.03.1 (2026-01-20)

### 🐛 Bug #001: NocoDB 数据丢失问题
**问题描述：**
- 在 NocoDB 中创建管理员并初始化后，重新部署并恢复备份时，NPM 配置恢复成功，但 NocoDB 的数据（包括管理员账号）丢失，需要重新注册。

**根本原因：**
1. **文件名不匹配**：备份脚本生成的文件名为 `apps/05-data-viz_TIMESTAMP.tar.gz`，但恢复脚本查找的是 `apps/app_data_*.tar.gz`，导致 NocoDB 的本地文件卷从未被恢复。
2. **恢复顺序不当**：原脚本先恢复文件，再恢复数据库，最后启动服务。如果 NocoDB 容器启动时发现本地文件与数据库不一致，可能触发重新初始化。

**修复方案：**
- 修复 `infra/scripts/05-restore.sh`：逐个查找并恢复每个应用目录的备份文件（`04-workflow_*.tar.gz`, `05-data-viz_*.tar.gz`, `06-knowledge_*.tar.gz`）。
- 优化恢复顺序：先停止所有服务 → 恢复网关配置 → 恢复应用本地文件 → 启动数据库 → 恢复数据库数据 → 最后启动所有应用服务。
- 增强错误处理：添加详细的日志输出和成功/失败提示。

**影响范围：**
- 备份/恢复功能
- NocoDB 数据持久化

**修复文件：**
- `infra/scripts/04-backup.sh`
- `infra/scripts/05-restore.sh`

---

## v1.03 (2026-01-20)

### 🐛 Bug #002: 数据库密码修改后无法生效
**问题描述：**
- 修改 `.env` 中的数据库密码后，已运行的数据库容器内部密码未同步更新，导致应用无法连接。

**修复方案：**
- 新增 `manage.sh` 菜单选项 `7) 🔐 修改数据库密码`，支持热修改数据库内部密码并同步更新 `.env` 文件。

**修复文件：**
- `manage.sh`

---

### 🐛 Bug #003: n8n 注册邀请链接 404 错误
**问题描述：**
- 通过外部域名访问 n8n 注册页面时出现 404 错误，无法完成注册流程。

**根本原因：**
- n8n 的 `WEBHOOK_URL` 环境变量未正确指向外部访问地址，导致邀请链接校验失败。

**修复方案：**
- 优化 `infra/compose/04-workflow.yml`，确保 `WEBHOOK_URL` 动态组合协议和域名。
- 新增 `manage.sh` 菜单选项 `6) 👤 强行创建 n8n 管理员`，支持绕过注册流程直接创建账号。

**修复文件：**
- `infra/compose/04-workflow.yml`
- `manage.sh`

---

### 🐛 Bug #004: 全量恢复时数据库冲突错误
**问题描述：**
- 执行全量恢复时出现大量 `ERROR: relation already exists` 和 `duplicate key value violates unique constraint` 错误。

**根本原因：**
- 恢复脚本直接向已存在的数据库导入数据，未先清理旧数据。

**修复方案：**
- 修复 `infra/scripts/05-restore.sh`：在恢复每个数据库前，强制断开所有连接、删除旧数据库并重建，确保导入环境干净。

**修复文件：**
- `infra/scripts/05-restore.sh`

---

## v1.02 (2026-01-20)

### 🐛 Bug #005: Wiki.js 数据库连接失败
**问题描述：**
- Wiki.js 容器启动后无法连接到数据库，日志显示 `password authentication failed`。

**根本原因：**
- `infra/compose/06-knowledge.yml` 中使用了不存在的数据库用户 `wikijs` 和数据库名 `wikijs`。

**修复方案：**
- 统一使用 `.env` 中定义的 `insight_admin` 用户和 `wikijs_db` 数据库。

**修复文件：**
- `infra/compose/06-knowledge.yml`

---

### 🐛 Bug #006: 环境变量未正确加载
**问题描述：**
- Docker Compose 启动时提示 `WARN: The "DB_PASSWORD" variable is not set`。

**根本原因：**
- 启动脚本未正确加载 `.env` 文件，或路径解析错误。

**修复方案：**
- 修复 `infra/scripts/02-startup.sh`：使用绝对路径加载 `.env` 文件，并在所有 `docker compose` 命令中显式指定 `--env-file`。

**修复文件：**
- `infra/scripts/02-startup.sh`
- `infra/compose/*.yml`

---

## 修复记录格式说明

每个 Bug 记录包含以下信息：
- **版本号**：修复所在的版本
- **Bug 编号**：唯一标识符
- **问题描述**：详细说明问题现象
- **根本原因**：问题产生的技术原因（如适用）
- **修复方案**：具体的修复措施
- **影响范围**：受影响的模块或功能
- **修复文件**：被修改的文件列表
