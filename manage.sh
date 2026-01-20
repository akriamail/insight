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

# 确认提示函数
confirm_action() {
    read -p "⚠️  危险操作！你确定要继续吗? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        return 1
    fi
    return 0
}

# 强行创建 n8n 管理员用户
create_n8n_user() {
    echo -e "\n${BLUE}👤 正在准备强行创建 n8n 管理员用户...${NC}"
    read -p "请输入邮箱: " email
    read -p "请输入密码 (至少8位): " password
    read -p "请输入名 (FirstName): " fname
    read -p "请输入姓 (LastName): " lname
    
    echo -e "${YELLOW}正在容器中执行创建命令...${NC}"
    # 尝试使用 n8n 官方 CLI
    docker exec -it insight-n8n n8n user:create --email "$email" --password "$password" --firstName "$fname" --lastName "$lname" --role admin
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 用户创建成功！请尝试登录。${NC}"
    else
        echo -e "${RED}❌ 创建失败。请确保 n8n 容器正在运行且数据库连接正常。${NC}"
    fi
}

# 检查 .env 是否已配置
check_env_configured() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}📝 检测到尚未创建 .env 配置文件。正在从模板生成...${NC}"
        cp .env.example .env
        echo -e "${RED}⚠️  请注意：已生成默认 .env，但其中的域名和密码均为占位符！${NC}"
        edit_env_file
        return 1
    fi
    
    if grep -q "change_me_please_2026" .env; then
        echo -e "${RED}❌ 警告：你还在使用默认的占位符密码！这非常不安全。${NC}"
        read -p "是否现在修改 .env 配置文件? (y/n): " fix_now
        if [[ $fix_now == [yY] ]]; then
            edit_env_file
            return 1
        fi
    fi
    return 0
}

# 编辑 .env 文件
edit_env_file() {
    echo -e "${BLUE}正在打开编辑器修改 .env 配置文件... (Ctrl+O 保存, Ctrl+X 退出)${NC}"
    if command -v nano &> /dev/null; then
        nano .env
    elif command -v vim &> /dev/null; then
        vim .env
    else
        vi .env
    fi
    echo -e "${GREEN}✅ .env 配置文件已保存。建议重启服务以应用配置。${NC}"
}

# 状态与监控报告
show_status_report() {
    echo -e "\n${GREEN}📊 [1/2] 容器运行状态:${NC}"
    echo -e "${BLUE}----------------------------------------------------------------------------------------------------${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    echo -e "${BLUE}----------------------------------------------------------------------------------------------------${NC}"

    echo -e "\n${GREEN}🌡️  [2/2] 服务器健康报告:${NC}"
    echo "📈 [CPU 负载]: $(uptime | awk -F'load average:' '{print $2}')"
    echo "🧠 [内存使用]: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
    echo "💾 [磁盘空间]: $(df -h / | tail -1 | awk '{print $3 " / " $2 " (使用率: " $5 ")"}')"
    
    echo -e "\n📦 [实时资源占用]:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# 重置系统（危险操作）
reset_system() {
    echo -e "${RED}⚠️  警告：即将执行重置！这将停止所有容器、移除网络并彻底删除所有持久化数据！${NC}"
    if confirm_action; then
        echo -e "${YELLOW}🛑 正在停止并移除容器...${NC}"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true

        echo -e "${YELLOW}🌐 正在移除网络...${NC}"
        docker network ls --format "{{.Name}}" | grep -E "insight-net" | xargs -r docker network rm 2>/dev/null || true

        echo -e "${YELLOW}🗑️  正在删除数据目录 (/opt/insight/data)...${NC}"
        rm -rf /opt/insight/data

        echo -e "${GREEN}✅ 系统已重置。您可以重新执行一键部署。${NC}"
    fi
}

# --- 菜单逻辑 ---

# 二级菜单：高级维护与部署
advanced_menu() {
    while true; do
        echo -e "\n${BLUE}========================================${NC}"
        echo -e "${BLUE}    ⚙️  高级维护与部署 (Advanced)${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "1) 🛠️  新主机部署基础环境 (Init Env)"
        echo -e "2) ✨ 一键生产环境部署 (Prod Setup)"
        echo -e "3) 🧪 一键开发环境部署 (Dev Setup)"
        echo -e "4) 🧱 防火墙管理 (Firewall Management)"
        echo -e "5) 📝 编辑环境变量 (Edit .env)"
        echo -e "6) 👤 强行创建 n8n 管理员 (Create n8n User)"
        echo -e "7) 🌐 Docker 镜像源配置 (Mirror Config)"
        echo -e "8) ⚠️  全量数据恢复 (Restore)"
        echo -e "9) 🗑️  重置系统 (危险 - Reset System)"
        echo -e "0) ⬅️  返回主菜单"
        echo -e "${BLUE}----------------------------------------${NC}"
        read -p "请选择操作 [0-9]: " adv_choice

        case $adv_choice in
            1) bash infra/scripts/00-bootstrap.sh ;;
            2) 
                if ! check_env_configured; then break; fi
                sed -i 's/USE_DOCKER_MIRRORS=true/USE_DOCKER_MIRRORS=false/g' .env 2>/dev/null || true
                echo -e "${GREEN}正在启动生产环境部署...${NC}"
                bash infra/scripts/00-bootstrap.sh && bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh
                ;;
            3) 
                if ! check_env_configured; then break; fi
                sed -i 's/USE_DOCKER_MIRRORS=false/USE_DOCKER_MIRRORS=true/g' .env 2>/dev/null || true
                echo -e "${GREEN}正在启动开发环境部署...${NC}"
                bash infra/scripts/00-bootstrap.sh && bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh
                ;;
            4) bash infra/scripts/07-firewall.sh ;;
            5) edit_env_file ;;
            6) create_n8n_user ;;
            7) configure_docker_mirrors ;;
            8) bash infra/scripts/05-restore.sh ;;
            9) reset_system ;;
            0) return ;;
            *) echo -e "${RED}❌ 无效选择${NC}" ;;
        esac
    done
}

# 主菜单：基础运维
main_menu() {
    while true; do
        echo -e "\n${BLUE}========================================${NC}"
        echo -e "${BLUE}    Project Team 基础设施管理系统${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "1) 🚀 启动服务 (Up)"
        echo -e "2) 🛑 停止服务 (Down)"
        echo -e "3) 📊 状态与监控 (Status)"
        echo -e "4) 📂 数据备份 (Backup)"
        echo -e "5) ⚙️  高级维护与部署 (Advanced)..."
        echo -e "0) 🚪 退出"
        echo -e "${BLUE}----------------------------------------${NC}"
        read -p "请选择操作 [0-5]: " choice

        case $choice in
            1) bash infra/scripts/02-startup.sh && bash infra/scripts/03-init-db.sh ;;
            2) if confirm_action; then bash infra/scripts/06-shutdown.sh; fi ;;
            3) show_status_report ;;
            4) bash infra/scripts/04-backup.sh ;;
            5) advanced_menu ;;
            0) echo "👋 再见！"; exit 0 ;;
            *) echo -e "${RED}❌ 无效选择${NC}" ;;
        esac
    done
}

# 启动入口
main_menu
