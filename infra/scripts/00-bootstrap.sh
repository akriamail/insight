#!/bin/bash
# ==========================================
# 00-bootstrap.sh: Base environment installation
# ==========================================
set -e

# --- Helper functions ---

# Check and install package (idempotent)
install_package_if_not_exists() {
    PACKAGE_NAME=$1
    if ! dpkg -s "$PACKAGE_NAME" >/dev/null 2>&1; then
        echo "Installing $PACKAGE_NAME..."
        sudo apt-get install -y "$PACKAGE_NAME"
    else
        echo "$PACKAGE_NAME is already installed, skipping."
    fi
}

# Check and add sysctl parameter (idempotent)
check_and_add_sysctl_param() {
    PARAM=$1
    VALUE=$2
    if ! grep -q "^$PARAM=$VALUE" /etc/sysctl.conf; then
        echo "Adding kernel parameter $PARAM=$VALUE..."
        echo "$PARAM=$VALUE" | sudo tee -a /etc/sysctl.conf > /dev/null
    else
        echo "Kernel parameter $PARAM=$VALUE already exists, skipping."
    fi
}

# Smartly select APT mirror source
select_apt_mirror() {
    echo "Evaluating APT mirror source speed..."
    
    # Detect architecture
    ARCH=$(dpkg --print-architecture)
    echo "Detected architecture: $ARCH"

    # Define common mirror sources (domestic & international)
    declare -A MIRRORS
    MIRRORS["Official"]="http://archive.ubuntu.com/ubuntu/"
    MIRRORS["Tsinghua"]="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
    MIRRORS["Tencent"]="http://mirrors.tencent.com/ubuntu/"
    
    # For ARM64, avoid Aliyun (incomplete support) and prefer official or well-supported mirrors
    if [ "$ARCH" = "arm64" ]; then
        echo "⚠️  ARM64 架构检测：优先使用官方源或支持 ARM64 的镜像源"
        # For ARM64, use ports.ubuntu.com as fallback
        MIRRORS["Official-Ports"]="http://ports.ubuntu.com/ubuntu-ports/"
    else
        MIRRORS["Aliyun"]="http://mirrors.aliyun.com/ubuntu/"
    fi

    FASTEST_MIRROR=""
    FASTEST_TIME=99999
    VALID_MIRRORS=()

    echo "--- Testing mirror source speed ---"
    for NAME in "${!MIRRORS[@]}"; do
        URL="${MIRRORS[$NAME]}"
        echo -n "   Testing $NAME ($URL)... "
        TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 5 "$URL" 2>&1 | grep -Eo '^[0-9]+\.?[0-9]*' || echo "timeout")

        if [[ "$TIME" != "timeout" && -n "$TIME" ]]; then
            echo "Time: ${TIME}s"
            VALID_MIRRORS+=("$NAME|$URL|$TIME")
            if (( $(echo "$TIME < $FASTEST_TIME" | bc -l) )); then
                FASTEST_TIME="$TIME"
                FASTEST_MIRROR="$URL"
            fi
        else
            echo "Timeout or failed"
        fi
    done
    echo "----------------------"

    # For ARM64, verify the selected mirror actually supports ARM64 before using it
    if [ "$ARCH" = "arm64" ] && [ -n "$FASTEST_MIRROR" ]; then
        # Test if the mirror has ARM64 packages
        CODE_NAME=$(lsb_release -sc)
        TEST_URL="${FASTEST_MIRROR}dists/${CODE_NAME}/main/binary-arm64/"
        if ! curl -s --head "$TEST_URL" | grep -q "200 OK"; then
            echo "⚠️  检测到所选镜像源可能不支持 ARM64，切换到官方源..."
            # Use official ports source for ARM64
            if [ -n "${MIRRORS[Official-Ports]}" ]; then
                FASTEST_MIRROR="${MIRRORS[Official-Ports]}"
                FASTEST_TIME=99999
            else
                FASTEST_MIRROR="http://ports.ubuntu.com/ubuntu-ports/"
            fi
        fi
    fi

    if [ -n "$FASTEST_MIRROR" ]; then
        echo "Detected fastest mirror source: $FASTEST_MIRROR (Time: ${FASTEST_TIME}s)"
        echo "Backing up original sources.list..."
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        CODE_NAME=$(lsb_release -sc)
        
        # For ARM64, use ports.ubuntu.com format
        if [ "$ARCH" = "arm64" ] && [[ "$FASTEST_MIRROR" == *"ports.ubuntu.com"* ]]; then
            echo "Replacing sources.list with $FASTEST_MIRROR (ARM64 ports format)..."
            NEW_SOURCES_LIST="deb ${FASTEST_MIRROR} ${CODE_NAME} main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-updates main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-backports main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-security main restricted universe multiverse\\n"
        else
            echo "Replacing sources.list with $FASTEST_MIRROR..."
            NEW_SOURCES_LIST="deb ${FASTEST_MIRROR} ${CODE_NAME} main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-updates main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-backports main restricted universe multiverse\\n"
            NEW_SOURCES_LIST+="deb ${FASTEST_MIRROR} ${CODE_NAME}-security main restricted universe multiverse\\n"
        fi
        
        echo -e "$NEW_SOURCES_LIST" | sudo tee /etc/apt/sources.list > /dev/null
        echo "APT mirror source updated."
    else
        echo "Failed to detect a usable fast mirror source, please check network or configure manually."
        if [ "$ARCH" = "arm64" ]; then
            echo "⚠️  建议：ARM64 架构请使用官方源 http://ports.ubuntu.com/ubuntu-ports/"
        fi
    fi
}

# --- End Helper functions ---

source infra/scripts/01-configure-docker-mirrors.sh

echo "Starting base dependency installation..."

# --- Conceptual APT mirror selection ---
select_apt_mirror
# --- End APT mirror selection ---

# 1. Update system and install necessary tools
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
install_package_if_not_exists jq

# 2. Automatically configure 4G Swap (to alleviate 8G memory pressure)
echo "Configuring 4G Swap partition..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
fi

# 3. Install Docker Engine
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."

    # Attempt to download Docker GPG key
    echo "Downloading Docker GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        echo "Docker GPG key download failed! Please check network connection or try manual download."
        echo "Try using a domestic mirror site for GPG key download, e.g., Aliyun, Tencent Cloud, etc."
        exit 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Attempt to add Docker APT source
    echo "Adding Docker APT source..."
    if ! echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        echo "Docker APT source addition failed! Please check network connection or try manual addition."
        echo "Try using a domestic Docker mirror source, e.g., Aliyun, Tencent Cloud, etc."
        exit 1
    fi

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "Docker is already installed, skipping."
fi

configure_docker_mirrors # Call the function to set up Docker mirrors

# 4. Kernel tuning
echo "Optimizing network connection and kernel parameters..."
check_and_add_sysctl_param net.core.default_qdisc fq
check_and_add_sysctl_param net.ipv4.tcp_congestion_control bbr
check_and_add_sysctl_param vm.max_map_count 262144
sudo sysctl -p

echo "Base dependencies installation complete!"