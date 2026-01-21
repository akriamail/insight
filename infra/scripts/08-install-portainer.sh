#!/bin/bash
# --- 安装 Portainer CE (Web Docker 管理界面) ---

COMPOSE_DIR=$(cd "$(dirname "$0")/../compose"; pwd)
PROJECT_ROOT=$(cd "$(dirname "$0")/../.."; pwd)
ENV_FILE_PATH="$PROJECT_ROOT/.env"

# 加载环境变量
if [ -f "$ENV_FILE_PATH" ]; then
    set -a
    source "$ENV_FILE_PATH"
    set +a
fi

echo "🚀 正在安装 Portainer CE..."
echo "📝 Portainer 是一个开源的 Docker 管理界面，让你通过 Web 页面管理所有容器"

# 确保网络存在
if ! docker network ls | grep -q "insight-net"; then
    echo "🌐 创建 Docker 网络 insight-net..."
    docker network create ${DOCKER_NETWORK_NAME:-insight-net}
fi

# 创建数据目录
mkdir -p "$PROJECT_ROOT/data/00-portainer"

# 启动 Portainer
docker compose --env-file "$ENV_FILE_PATH" -f $COMPOSE_DIR/00-portainer.yml up -d

if [ $? -eq 0 ]; then
    PORTAINER_PORT=${PORTAINER_PORT:-9000}
    echo ""
    echo "✅ Portainer 安装成功！"
    echo ""
    echo "📌 访问地址: http://$(hostname -I | awk '{print $1}'):${PORTAINER_PORT}"
    echo "   (或 http://localhost:${PORTAINER_PORT})"
    echo ""
    echo "🔐 首次访问需要设置管理员密码（至少8位）"
    echo ""
    echo "💡 使用提示："
    echo "   1. 首次登录后，选择 'Docker' 环境"
    echo "   2. 在 'Stacks' 页面可以导入你现有的 compose 文件"
    echo "   3. 每个服务（gateway/databases/workflow等）可以单独管理"
    echo ""
    echo "📖 详细使用指南请查看: docs/PORTAINER_GUIDE.md"
else
    echo "❌ Portainer 安装失败，请检查错误信息"
    exit 1
fi
