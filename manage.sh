#!/bin/bash
# --- Project Team 超级管理入口 (2026 全能版) ---

case "$1" in
    init)
        echo "🛠️ 开始环境初始化..."
        bash infra/scripts/setup_env.sh
        ;;
    up)
        echo "🚀 启动所有服务..."
        bash infra/scripts/startup.sh
        # 启动后自动检查并创建必要的数据库
        bash infra/scripts/03-init-db.sh
        ;;
    down)
        echo "🛑 停止所有服务..."
        bash infra/scripts/shutdown.sh
        ;;
    backup)
        echo "📂 执行全量备份..."
        bash infra/scripts/backup.sh
        ;;
    restore)
        echo "⚠️ 启动全量恢复程序..."
        bash infra/scripts/restore.sh
        ;;
    status)
        echo "📊 当前容器运行状态:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "❌ 错误: 无效参数"
        echo "用法: ./manage.sh {init|up|down|backup|restore|status}"
        echo "  - init:    安装 Docker/Compose 环境"
        echo "  - up:      启动服务并初始化数据库"
        echo "  - down:    停止所有容器"
        echo "  - backup:  生成全量备份包到 exports/"
        echo "  - restore: 从 exports/ 最新的包恢复"
        echo "  - status:  查看运行详情"
        exit 1
esac
