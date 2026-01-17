#!/bin/bash
# ==========================================
# 00-bootstrap.sh: 基础环境安装
# ==========================================
set -e

echo "🚀 开始安装基础依赖..."

# 1. 更新系统并安装必要工具
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget git vim ca-certificates gnupg lsb-release software-properties-common ufw htop

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
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. 内核调优
echo "⚡ 优化网络连接与内核参数..."
cat <<EOF | sudo tee -a /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
vm.max_map_count=262144
EOF
sudo sysctl -p

echo "✅ 基础依赖安装完成！"
