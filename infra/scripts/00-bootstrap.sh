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

# 智能选择 APT 镜像源
select_apt_mirror() {
    echo "🌐 正在评估 APT 镜像源速度..."

    # 定义常用镜像源 (国内 & 国外)
    declare -A MIRRORS
    MIRRORS["官方源"]="http://archive.ubuntu.com/ubuntu/"
    MIRRORS["阿里云"]="http://mirrors.aliyun.com/ubuntu/"
    MIRRORS["清华大学"]="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
    MIRRORS["腾讯云"]="http://mirrors.tencent.com/ubuntu/"
    # ... 可以根据需要添加更多

    FASTEST_MIRROR=""
    FASTEST_TIME=99999

    echo "--- 测试镜像源速度 ---"
    for NAME in "${!MIRRORS[@]}"; do
        URL="${MIRRORS[$NAME]}"
        echo -n "   测试 $NAME ($URL)... "
        # 使用 curl 测试连接速度，并提取时间
        # -o /dev/null: 不输出文件
        # -s: 静默模式
        # -w "%{time_total}": 仅输出总时间
        # --max-time 5: 最长等待 5 秒
        TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 5 "$URL" || echo "timeout")

        if [[ "$TIME" != "timeout" && -n "$TIME" ]]; then
            echo "耗时: ${TIME}s"
            # 比较时间，找到最快源
            if (( $(echo "$TIME < $FASTEST_TIME" | bc -l) )); then
                FASTEST_TIME="$TIME"
                FASTEST_MIRROR="$URL"
            fi
        else
            echo "超时或失败"
        fi
    done
    echo "----------------------"

    if [ -n "$FASTEST_MIRROR" ]; then
        echo -e "${GREEN}✨ 检测到最快镜像源: $FASTEST_MIRROR (耗时: ${FASTEST_TIME}s)${NC}"
        read -p "是否替换为最快的镜像源？(y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            echo "备份原有 sources.list..."
            sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
            echo "正在替换 sources.list 为 $FASTEST_MIRROR..."
            CODE_NAME=$(lsb_release -sc)
            NEW_SOURCES_LIST="deb ${FASTEST_MIRROR} ${CODE_NAME} main restricted universe multiverse\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-updates main restricted universe multiverse\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-backports main restricted universe multiverse\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-security main restricted universe multiverse\n"
            echo -e "$NEW_SOURCES_LIST" | sudo tee /etc/apt/sources.list > /dev/null
            echo -e "${GREEN}✅ APT 镜像源已更新。${NC}"
        else
            echo -e "${YELLOW} APT 镜像源未更改，继续使用默认源。${NC}"
        fi
    else
        echo -e "${RED}❌ 未能检测到可用的快速镜像源，请检查网络或手动配置。${NC}"
    fi
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

    # 尝试下载 Docker GPG 密钥
    echo "🌐 正在下载 Docker GPG 密钥..."
    sudo install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        echo -e "${RED}❌ Docker GPG 密钥下载失败！请检查网络连接或尝试手动下载。${NC}"
        echo "💡 尝试使用国内镜像站的 GPG 密钥下载地址，例如阿里云、腾讯云等。"
        # 可以考虑在这里添加用户交互，引导用户替换源
        exit 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 尝试添加 Docker APT 源
    echo "🌐 正在添加 Docker APT 源..."
    if ! echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        echo -e "${RED}❌ Docker APT 源添加失败！请检查网络连接或尝试手动添加。${NC}"
        echo "💡 尝试使用国内 Docker 镜像源，例如阿里云、腾讯云等。"
        exit 1
    fi

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
