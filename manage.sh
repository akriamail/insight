#!/bin/bash
# --- Project Team 交互式指挥中心 ---

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 确认提示函数
confirm_action() {
    read -p "⚠️  危险操作！你确定要继续吗? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        return 1
    fi
    return 0
}

# 清空所有数据（不删除镜像）
clear_all_data() {
    echo -e "${RED}⚠️  危险操作！即将停止所有容器，移除所有网络，并删除所有持久化数据！${NC}"
    if confirm_action; then
        echo -e "${YELLOW}🛑 正在停止并移除所有 Docker 容器...${NC}"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true

        echo -e "${YELLOW}🌐 正在移除所有 Docker 网络...${NC}"
        # 考虑到 insight-net 是外部网络，这里可以尝试移除所有自定义网络
        docker network ls --format "{{.Name}}" | grep -E "insight-net" | xargs -r docker network rm 2>/dev/null || true

        echo -e "${YELLOW}🗑️  正在删除所有持久化数据目录 (/opt/insight/data)...${NC}"
        rm -rf /opt/insight/data # 由于你目前是root用户，不再需要sudo

        echo -e "${GREEN}✅ 所有数据已清空 (Docker 镜像保留)。${NC}"
    fi
}

while true; do
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}    Project Team 基础设施管理系统${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "1) 🚀 启动服务 (Up)"
    echo -e "2) 🛑 停止服务 (Down)"
    echo -e "3) 📊 容器状态 (Status)"
    echo -e "4) 🌡️  系统监控 (Monitor)"
    echo -e "5) 📂 执行备份 (Backup)"
    echo -e "6) ⚠️  全量恢复 (Restore)"
    echo -e "7) 🛠️  初始化基础环境 (Init Base Env)"
    echo -e "8) ✨ 全新服务器部署 (Full Setup)"
    echo -e "9) 🗑️  清空所有数据 (Clear All Data)"
    echo -e "0) 🚪 退出 (Exit)"
    echo -e "${BLUE}----------------------------------------${NC}"
    read -p "请选择操作 [0-9]: " choice

    case $choice in
        1)
            bash infra/scripts/02-startup.sh
            bash infra/scripts/03-init-db.sh
            ;;
        2)
            if confirm_action; then
                bash infra/scripts/06-shutdown.sh
            fi
            ;;
        3)
            echo -e "\n${GREEN}📊 当前容器状态:${NC}"
            echo -e "${BLUE}----------------------------------------------------------------------------------------------------${NC}"
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            echo -e "${BLUE}----------------------------------------------------------------------------------------------------${NC}"
            echo -e "${YELLOW}提示：要查看更详细的容器资源使用情况 (CPU/内存/网络)，请选择选项 4) 🌡️  系统监控 (Monitor)。${NC}"
            ;;
        4)
            echo -e "\n${GREEN}🌡️  服务器健康报告:${NC}"
            echo "📈 [CPU 负载]: $(uptime | awk -F'load average:' '{print $2}')"
            echo "🧠 [内存使用]: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
            echo "💾 [磁盘空间]: $(df -h / | tail -1 | awk '{print $3 " / " $2 " (使用率: " $5 ")"}')"
            echo -e "\n📦 [容器详情]:"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
            ;;
        5)
            bash infra/scripts/04-backup.sh
            ;;
        6)
            echo -e "${RED}警告：恢复操作将覆盖当前所有数据！${NC}"
            if confirm_action; then
                bash infra/scripts/05-restore.sh
            fi
            ;;
        7) # 初始化基础环境
            echo -e "${YELLOW}提示：仅初始化基础依赖，如 Docker 等。${NC}"
            if confirm_action; then
                bash infra/scripts/00-bootstrap.sh
            fi
            ;;
        8) # 全新服务器部署
            echo -e "${YELLOW}提示：这将执行：1) 初始化基础环境 -> 2) 启动所有服务 -> 3) 初始化数据库。${NC}"
            if confirm_action; then
                echo -e "${GREEN}1/3: 正在初始化基础环境...${NC}"
                bash infra/scripts/00-bootstrap.sh || { echo -e "${RED}❌ 基础环境初始化失败！${NC}"; break; }

                echo -e "${GREEN}2/3: 正在启动所有服务...${NC}"
                bash infra/scripts/02-startup.sh || { echo -e "${RED}❌ 服务启动失败！${NC}"; break; }

                echo -e "${GREEN}3/3: 正在初始化数据库...${NC}"
                bash infra/scripts/03-init-db.sh || { echo -e "${RED}❌ 数据库初始化失败！${NC}"; break; }

                echo -e "${GREEN}✨ 全新服务器部署完成！${NC}"
            fi
            ;;
        9) # 清空所有数据
            clear_all_data
            ;;
        0) # 退出
            echo "👋 祝 Project Team 运行愉快，再见！"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效选择，请重新输入。${NC}"
            ;;
    esac
done
