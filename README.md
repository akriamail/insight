#🚀 Project Team - Insight Infrastructure
这是 Project Team 的核心基础设施管理仓库。采用扁平化架构设计，实现“配置与数据分离”，支持一键部署、交互式管理与全量备份。

## 目录结构

```
.
├── manage.sh              # 🚀 唯一交互式入口 (按数字键操作)
├── README.md              # 本项目操作说明
├── .gitignore             # Git 忽略配置
├── data/                  # [生产数据] 实际业务数据挂载点
│   ├── 01-gateway/        # Nginx Proxy Manager 配置文件
│   └── 03-databases/      # Postgres 数据库原始文件
├── infra/                 # [核心配置]
│   ├── compose/           # Docker Compose 蓝图文件 (.yml)
│   └── scripts/           # 自动化运维脚本 (backup/restore/setup)
└── exports/               # [备份产出] 存放生成的全量备份压缩包
```
## 快速操作指南
1. 新服务器初始化 (开荒)

```bash
git clone https://github.com/akriamail/insight.git /opt/insight
cd /opt/insight
./manage.sh    # 选择菜单中的 7 (Init) 进行环境安装
```

2. 交互式管理入口
只需运行根目录下的脚本，即可进入图形化数字菜单：

```bash
./manage.sh
```
### 菜单功能一览：

*   启动服务: 拉起所有容器并自动初始化数据库。
*   停止服务: (需确认) 安全移除容器。
*   容器状态: 快速查看当前业务运行详情。
*   系统监控: 实时查看 CPU、内存、磁盘占用。
*   执行备份: 生成全量数据包至 exports/。
*   全量恢复: (需确认) 从备份包一键还原。

## 维护规范
安全第一: 涉及删除、停止的操作均设有 (y/n) 二次确认。

Git 同步: 仅提交 infra/ 变更，严禁手动修改 data/ 结构。