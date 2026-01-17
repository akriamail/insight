#!/bin/bash
# --- Project Team 超级管理入口 (2026 监控增强版) ---

case "$1" in
    init)
        bash infra/scripts/setup_env.sh
        ;;
    up)
        bash infra/scripts/startup.sh
        bash infra/scripts/03-init-db.sh
        ;;
    down)
        bash infra/scripts/shutdown.sh
        ;;
    backup)
        bash infra/scripts/backup.sh
        ;;
    restore)
        bash infra/scripts/restore.sh
        ;;
    status)
        echo "📊 容器运行状态:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    monitor)
        echo "🌡️  Project Team 服务器健康报告 - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "------------------------------------------------"
        echo "📈 [CPU 负载]: $(uptime | awk -F'load average:' '{ print $2 }')"
        echo "🧠 [内存使用]: $(free -h | awk '/^Mem:/ {print $3 \" / \" $2}')"
        echo "💾 [磁盘空间]: $(df -h / | awk '/\// {print $3 \" / \" $2 \" (使用率: \" $5 \")\"}')"
        echo "📦 [容器监控]:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        echo "------------------------------------------------"
        ;;
    *)
        echo "用法: ./manage.sh {init|up|down|backup|restore|status|monitor}"
        exit 1
esac
