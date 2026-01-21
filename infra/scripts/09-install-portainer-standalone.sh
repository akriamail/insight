#!/bin/bash
# --- Portainer CE 独立安装脚本 ---
# 这个脚本可以在任何服务器上独立安装 Portainer，不依赖 insight 项目

set -e

echo "🚀 Portainer CE 独立安装脚本"
echo "================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 错误：未检测到 Docker，请先安装 Docker"
    echo "   安装命令：curl -fsSL https://get.docker.com | bash"
    exit 1
fi

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    echo "❌ 错误：Docker 未运行，请先启动 Docker"
    echo "   启动命令：sudo systemctl start docker"
    exit 1
fi

# 配置参数（可通过环境变量覆盖）
PORTAINER_PORT=${PORTAINER_PORT:-9000}
PORTAINER_DATA_DIR=${PORTAINER_DATA_DIR:-/opt/portainer/data}

echo "📝 安装配置："
echo "   - Portainer 端口: ${PORTAINER_PORT}"
echo "   - 数据目录: ${PORTAINER_DATA_DIR}"
echo ""

# 创建数据目录
echo "📂 创建数据目录..."
sudo mkdir -p "$PORTAINER_DATA_DIR"
sudo chown -R $(id -u):$(id -g) "$PORTAINER_DATA_DIR" 2>/dev/null || true

# 停止并删除旧容器（如果存在）
if docker ps -a | grep -q portainer; then
    echo "🔄 检测到旧版本 Portainer，正在清理..."
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
fi

# 拉取最新镜像
echo "📥 拉取 Portainer CE 最新镜像..."
docker pull portainer/portainer-ce:latest

# 启动 Portainer
echo "🚀 启动 Portainer..."
docker run -d \
    --name portainer \
    --restart=always \
    -p ${PORTAINER_PORT}:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${PORTAINER_DATA_DIR}:/data \
    portainer/portainer-ce:latest

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Portainer 安装成功！"
    echo ""
    echo "📌 访问信息："
    
    # 尝试获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "   - 本地访问: http://localhost:${PORTAINER_PORT}"
    echo "   - 远程访问: http://${SERVER_IP}:${PORTAINER_PORT}"
    echo ""
    echo "🔐 首次访问需要设置管理员密码（至少8位）"
    echo ""
    echo "💡 使用提示："
    echo "   1. 首次登录后，选择 'Docker' 环境（本地 Docker）"
    echo "   2. 现在你可以管理这台服务器上的所有 Docker 容器"
    echo "   3. 可以导入 docker-compose.yml 文件创建 Stack"
    echo ""
    echo "🔒 安全建议："
    echo "   - 建议通过 Nginx Proxy Manager 配置 HTTPS"
    echo "   - 或者使用防火墙限制访问 IP"
    echo ""
    echo "📖 更多信息：https://docs.portainer.io/"
else
    echo "❌ Portainer 安装失败，请检查错误信息"
    exit 1
fi
