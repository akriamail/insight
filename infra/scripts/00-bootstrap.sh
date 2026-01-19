#!/bin/bash
# ==========================================
# 00-bootstrap.sh: 基础环境安装
# ==========================================
set -e

# --- 辅助函数 ---

# 检查并安装软件包（幂等性）
install_package_if_not_exists() {
    PACKAGE_NAME=$1
    if ! dpkg -s "$PACKAGE_NAME" >/dev/null 2>&1; then
        echo "➕ 正在安装 $PACKAGE_NAME..."
        sudo apt-get install -y "$PACKAGE_NAME"
    else
        echo "✅ $PACKAGE_NAME 已安装，跳过。"
    fi
}

# 检查并添加 sysctl 参数（幂等性）
check_and_add_sysctl_param() {
    PARAM=$1
    VALUE=$2
    if ! grep -q "^$PARAM=$VALUE" /etc/sysctl.conf; then
        echo "➕ 正在添加内核参数 $PARAM=$VALUE..."
        echo "$PARAM=$VALUE" | sudo tee -a /etc/sysctl.conf > /dev/null
    else
        echo "✅ 内核参数 $PARAM=$VALUE 已存在，跳过。"
    fi
}

# 概念性函数：选择最快的 APT 镜像源 (需要根据实际情况实现网络探测和用户选择逻辑)
select_apt_mirror() {
    echo "🌐 (概念性) 正在尝试选择最快的 APT 镜像源..."
    # 实际实现中，这里可以包含：
    # 1. ping 不同的镜像源，比较响应时间
    # 2. 根据地理位置或用户输入，提供源选择
    # 3. 替换 /etc/apt/sources.list
    echo "💡 提示: 本功能需要根据您的网络环境手动配置或进一步完善，目前使用默认源。"
}

# --- 辅助函数结束 ---

echo "🚀 开始安装基础依赖..."

# --- 概念性 APT 镜像选择 ---
select_apt_mirror
# --- APT 镜像选择结束 ---

# 1. 更新系统并安装必要工具
sudo apt-get update && sudo apt-get upgrade -y

install_package_if_not_exists curl
install_package_if_not_exists wget
install_package_if_not_exists git
install_package_if_not_exists vim
install_package_if_not_exists ca-certificates
install_package_if_not_exists gnupg
install_package_if_not_exists lsb-release
install_package_if_not_exists software-properties-common
install_package_if_not_exists ufw
install_package_if_not_exists htop

# 2. 自动化配置 4G Swap (解决 8G 内存压力)
echo "💾 配置 4G Swap 分区..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
fi

# 3. 安装 Docker Engine
echo "🐳 安装 Docker..."
if ! command -v docker &> /dev/null; then
    echo "➕ 正在安装 Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "✅ Docker 已安装，跳过。"
fi

# 4. 内核调优
echo "⚡ 优化网络连接与内核参数..."
check_and_add_sysctl_param net.core.default_qdisc fq
check_and_add_sysctl_param net.ipv4.tcp_congestion_control bbr
check_and_add_sysctl_param vm.max_map_count 262144
sudo sysctl -p

echo "✅ 基础依赖安装完成！"
