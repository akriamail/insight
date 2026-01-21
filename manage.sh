#!/bin/bash
# --- Project Team 基础设施交互式指挥中心 ---

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 导入外部脚本
source infra/scripts/01-configure-docker-mirrors.sh

# --- 辅助函数 ---

confirm_action() {
    read -p "⚠️  危险操作！你确定要继续吗? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        return 1
    fi
    return 0
}

# 修改数据库内部密码并同步 .env
change_db_password() {
    echo -e "\n${BLUE}🔐 正在执行数据库密码变更同步...${NC}"
    
    # 1. 获取旧密码（尝试从当前 .env 获取，如果连不上则需要用户输入）
    source .env
    OLD_PW="$DB_PASSWORD"
    
    read -p "请输入新的数据库密码: " NEW_PW
    if [ -z "$NEW_PW" ]; then echo "❌ 密码不能为空"; return; fi

    echo -e "${YELLOW}正在尝试连接数据库并更新内部密码...${NC}"
    
    # 直接穿透容器，使用超级用户权限修改 insight_admin 的密码
    # 注意：这里不需要知道旧密码也可以改，因为是通过 docker exec 以容器内 root 权限运行的
    docker exec -i insight-db psql -U postgres -c "ALTER USER $DB_USER WITH PASSWORD '$NEW_PW';"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 数据库内部密码修改成功！${NC}"
        echo -e "${YELLOW}正在同步更新 .env 文件...${NC}"
        # 使用 sed 替换 .env 中的旧密码
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$NEW_PW/g" .env
        echo -e "${GREEN}✅ .env 文件同步完成。${NC}"
        echo -e "${RED}⚠️  重要：为了使所有应用（n8n, Wiki, NocoDB）识别新密码，系统将自动重启所有服务。${NC}"
        confirm_action && (bash infra/scripts/02-startup.sh)
    else
        echo -e "${RED}❌ 数据库修改失败。请确保 insight-db 容器正在运行！${NC}"
    fi
}

# 强行创建 n8n 管理员用户
create_n8n_user() {
    echo -e "\n${BLUE}👤 正在准备强行创建 n8n 管理员用户...${NC}"
    read -p "请输入邮箱: " email
    read -p "请输入密码 (至少8位): " password
    read -p "请输入名 (FirstName): " fname
    read -p "请输入姓 (LastName): " lname
    echo -e "${YELLOW}正在容器中执行创建命令...${NC}"
    docker exec -it insight-n8n n8n user:create --email "$email" --password "$password" --firstName "$fname" --lastName "$lname" --role admin
    [ $? -eq 0 ] && echo -e "${GREEN}✅ 用户创建成功！${NC}" || echo -e "${RED}❌ 创建失败。${NC}"
}

# 检查 .env 是否已配置
check_env_configured() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}📝 正在生成 .env 配置文件...${NC}"
        cp .env.example .env
        edit_env_file
        return 1
    fi
    if grep -q "change_me_please_2026" .env; then
        echo -e "${RED}❌ 警告：你还在使用默认密码！${NC}"
        read -p "是否现在修改? (y/n): " fix_now
        [[ $fix_now == [yY] ]] && (edit_env_file; return 1)
    fi
    return 0
}

# 编辑 .env 文件
edit_env_file() {
    echo -e "${BLUE}正在修改 .env 配置文件...${NC}"
    if command -v nano &> /dev/null; then nano .env; elif command -v vim &> /dev/null; then vim .env; else vi .env; fi
    echo -e "${GREEN}✅ 已保存。${NC}"
}

# 状态与监控报告
show_status_report() {
    echo -e "\n${GREEN}📊 容器状态:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    echo -e "\n${GREEN}🌡️  服务器健康报告:${NC}"
    echo "📈 [CPU]: $(uptime | awk -F'load average:' '{print $2}')  🧠 [内存]: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# 重置系统
reset_system() {
    echo -e "${RED}⚠️  警告：即将执行彻底重置！${NC}"
    if confirm_action; then
        docker stop $(docker ps -aq) 2>/dev/null; docker rm $(docker ps -aq) 2>/dev/null
        docker network ls --format "{{.Name}}" | grep "insight-net" | xargs -r docker network rm 2>/dev/null
        rm -rf /opt/insight/data
        echo -e "${GREEN}✅ 系统已重置。${NC}"
    fi
}

# --- 菜单逻辑 ---

advanced_menu() {
    while true; do
        echo -e "\n${BLUE}⚙️  高级维护与部署 (Advanced)${NC}"
        echo -e "1) 🛠️  新主机部署基础环境"
        echo -e "2) ✨ 一键生产环境部署"
        echo -e "3) 🧪 一键开发环境部署"
        echo -e "4) 🧱 防火墙管理 (UFW)"
        echo -e "5) 📝 编辑环境变量 (.env)"
        echo -e "6) 👤 强行创建 n8n 管理员"
        echo -e "7) 🔐 修改数据库密码 (Change DB PW)"
        echo -e "8) 🌐 Docker 镜像源配置"
        echo -e "9) ⚠️  全量数据恢复"
        echo -e "10) 🗑️  重置系统 (危险)"
        echo -e "11) 🎯 安装 Portainer (Web 管理界面)"
        echo -e "12) 🔧 修复 Docker 网络问题"
        echo -e "0) ⬅️  返回主菜单"
        read -p "选择 [0-12]: " adv_choice
        case $adv_choice in
            1) bash infra/scripts/00-bootstrap.sh ;;
            2) if check_env_configured; then 
                   echo -e "${YELLOW}⚠️  生产环境部署：将禁用 Docker 镜像加速器${NC}"
                   echo -e "${YELLOW}   如果无法访问 docker.io，镜像拉取可能失败${NC}"
                   echo -e "${YELLOW}   建议：如果网络受限，请使用开发环境部署（选项 3）${NC}"
                   read -p "是否继续? (y/n): " confirm
                   if [[ $confirm == [yY] ]]; then
                       sed -i 's/USE_DOCKER_MIRRORS=true/USE_DOCKER_MIRRORS=false/g' .env
                       bash infra/scripts/00-bootstrap.sh && bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh
                   else
                       echo -e "${YELLOW}操作已取消。${NC}"
                   fi
               fi ;;
            3) if check_env_configured; then sed -i 's/USE_DOCKER_MIRRORS=false/USE_DOCKER_MIRRORS=true/g' .env; bash infra/scripts/00-bootstrap.sh && bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh; fi ;;
            4) bash infra/scripts/07-firewall.sh ;;
            5) edit_env_file ;;
            6) create_n8n_user ;;
            7) change_db_password ;;
            8) configure_docker_mirrors ;;
            9) bash infra/scripts/05-restore.sh ;;
            10) reset_system ;;
            11) bash infra/scripts/08-install-portainer.sh ;;
            12) bash infra/scripts/10-fix-docker-network.sh ;;
            0) return ;;
            *) echo "❌ 无效选择" ;;
        esac
    done
}

main_menu() {
    while true; do
        echo -e "\n${BLUE}Project Team 基础设施管理系统${NC}"
        echo -e "1) 🚀 启动服务 (Up)"
        echo -e "2) 🛑 停止服务 (Down)"
        echo -e "3) 📊 状态与监控 (Status)"
        echo -e "4) 📂 数据备份 (Backup)"
        echo -e "5) ⚙️  高级维护与部署 (Advanced)..."
        echo -e "0) 🚪 退出"
        read -p "选择 [0-5]: " choice
        case $choice in
            1) bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh ;;
            2) if confirm_action; then bash infra/scripts/06-shutdown.sh; fi ;;
            3) show_status_report ;;
            4) bash infra/scripts/04-backup.sh ;;
            5) advanced_menu ;;
            0) exit 0 ;;
            *) echo "❌ 无效选择" ;;
        esac
    done
}

main_menu
