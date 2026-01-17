#!/bin/bash
# ==========================================
# 01-manage.sh: 生产目录结构与网络初始化
# ==========================================
BASE_DIR="/opt/insight-ai"
NET_NAME="insight-net"

echo "📂 正在初始化 insight.ai 分层目录结构..."

# 1. 定义需要创建的模块路径
declare -a modules=(
    "01-gateway/conf" "01-gateway/data"
    "02-security/conf" "02-security/data"
    "03-databases/conf" "03-databases/data"
    "04-workflow/data"
    "05-registry/conf" "05-registry/storage"
    "06-knowledge/conf" "06-knowledge/data"
)

# 2. 循环创建目录
for dir in "${modules[@]}"; do
    mkdir -p "$BASE_DIR/$dir"
    echo "  - 已创建 $BASE_DIR/$dir"
done

# 3. 创建 Docker 跨容器网络
if [ ! "$(docker network ls | grep $NET_NAME)" ]; then
    echo "🌐 创建 Docker 网络: $NET_NAME"
    docker network create $NET_NAME
else
    echo "✅ 网络 $NET_NAME 已存在"
fi

# 4. 权限修正
# PostgreSQL 容器通常需要特定的权限
sudo chown -R 999:999 "$BASE_DIR/03-databases/data"
# 将整个生产目录的所有权给到你当前用户，方便后续用 Git 或 SFTP 管理
sudo chown -R $USER:$USER $BASE_DIR

echo "✨ 目录结构与网络初始化完成！"
