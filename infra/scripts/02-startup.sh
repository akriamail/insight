#!/bin/bash
# --- Project Team 一键启动脚本 ---
COMPOSE_DIR=$(cd "$(dirname "$0")/../compose"; pwd)

# 加载 .env 文件中的环境变量
if [ -f ../../.env ]; then
    echo "✅ 发现 .env 文件，正在加载环境变量..."
    set -a
    source ../../.env
    set +a
else
    echo "⚠️ 未发现 .env 文件，将使用 .env.example 作为默认配置..."
    if [ -f ../../.env.example ]; then
        cp ../../.env.example ../../.env
        set -a
        source ../../.env
        set +a
    else
        echo "❌ 警告：.env.example 文件也不存在，部分服务可能无法正常启动！"
    fi
fi

echo "🚀 正在按序拉起服务..."

# 确保 insight-net 网络存在
if ! docker network ls | grep -q "insight-net"; then
    echo "🌐 创建 Docker 网络 insight-net..."
    docker network create ${DOCKER_NETWORK_NAME:-insight-net}
fi

docker compose -f $COMPOSE_DIR/03-databases.yml up -d
sleep 5
docker compose -f $COMPOSE_DIR/01-gateway.yml up -d
docker compose -f $COMPOSE_DIR/04-workflow.yml up -d
docker compose -f $COMPOSE_DIR/05-data-viz.yml up -d
docker compose -f $COMPOSE_DIR/06-knowledge.yml up -d

echo "✅ 所有服务已尝试启动。请运行 docker ps 检查状态。"