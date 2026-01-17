#!/bin/bash
# --- Project Team 超级管理入口 ---

case "$1" in
    up)
        bash infra/scripts/startup.sh
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
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Usage: ./manage.sh {up|down|backup|restore|status}"
        exit 1
esac
