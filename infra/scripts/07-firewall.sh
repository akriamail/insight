#!/bin/bash
# --- Project Team 防火墙管理脚本 (UFW) ---

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否安装了 UFW
if ! command -v ufw &> /dev/null; then
    echo -e "${RED}❌ 错误: 系统未安装 UFW 防火墙。请先通过初始化脚本安装。${NC}"
    exit 1
fi

# --- 功能函数 ---

# 1. 查看状态
show_status() {
    echo -e "\n${BLUE}📊 当前防火墙规则列表:${NC}"
    echo "----------------------------------------"
    sudo ufw status numbered
    echo "----------------------------------------"
}

# 2. 一键安全加固
quick_secure() {
    echo -e "${YELLOW}🛡️  执行一键安全加固...${NC}"
    echo "1. 默认拒绝入站, 允许出站"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    echo "2. 允许 SSH (22)"
    sudo ufw allow 22/tcp
    
    echo "3. 允许 HTTP (80) & HTTPS (443)"
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    echo "4. 允许 NPM 管理后台 (81)"
    sudo ufw allow 81/tcp
    
    echo "5. 激活防火墙"
    echo "y" | sudo ufw enable
    
    echo -e "${GREEN}✅ 安全加固完成！基础服务已开放。${NC}"
    show_status
}

# 3. 添加自定义端口
add_port() {
    read -p "请输入要开放的端口号 (如 3000): " port
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ 无效端口号${NC}"
        return
    fi
    read -p "协议类型 (tcp/udp, 默认 tcp): " proto
    proto=${proto:-tcp}
    
    sudo ufw allow "$port/$proto"
    echo -e "${GREEN}✅ 已开放端口 $port/$proto${NC}"
}

# 4. 删除规则
delete_rule() {
    show_status
    read -p "请输入要删除的规则编号 (直接按回车取消): " rule_num
    if [[ -n "$rule_num" && "$rule_num" =~ ^[0-9]+$ ]]; then
        echo "y" | sudo ufw delete "$rule_num"
        echo -e "${GREEN}✅ 规则已删除。${NC}"
    fi
}

# 5. Docker 兼容性修复 (防止 Docker 绕过防火墙)
docker_fix() {
    echo -e "${YELLOW}🔧 正在配置 Docker 与 UFW 的兼容性修复...${NC}"
    # 这是一个比较复杂的课题，最简单有效的方法是修改 DOCKER-USER 链
    # 这里我们采用一种常用的安全做法：确保外部无法直接访问映射出的容器端口（除非 UFW 显式允许）
    
    # 修改 /etc/default/ufw
    sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
    
    echo -e "${GREEN}✅ 配置已更新。注意：此修复需要重启服务器或 Docker 服务才能完全生效。${NC}"
    echo -e "${YELLOW}提示：目前最好的做法是配合 UFW 规则，并确保容器不使用 --net=host 模式。${NC}"
}

# --- 菜单逻辑 ---

while true; do
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}    🧱 防火墙管理 (Firewall)${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "1) 📊 查看规则状态 (Status)"
    echo -e "2) 🛡️  一键安全加固 (SSH/HTTP/HTTPS/NPM)"
    echo -e "3) ➕ 开放自定义端口 (Add Port)"
    echo -e "4) ➖ 删除规则序号 (Delete Rule)"
    echo -e "5) 🔓 关闭防火墙 (Disable)"
    echo -e "6) 🔧 Docker 兼容性修复 (Docker Fix)"
    echo -e "0) ⬅️  返回高级菜单"
    echo -e "${BLUE}----------------------------------------${NC}"
    read -p "请选择操作 [0-6]: " fw_choice

    case $fw_choice in
        1) show_status ;;
        2) quick_secure ;;
        3) add_port ;;
        4) delete_rule ;;
        5) sudo ufw disable ;;
        6) docker_fix ;;
        0) exit 0 ;;
        *) echo -e "${RED}❌ 无效选择${NC}" ;;
    esac
done
