#!/bin/bash
# --- Project Team 一键启动脚本 ---
COMPOSE_DIR=$(cd "$(dirname "$0")/../compose"; pwd)

PROJECT_ROOT=$(cd "$(dirname "$0")/../.."; pwd)
ENV_FILE_PATH="$PROJECT_ROOT/.env"
ENV_EXAMPLE_FILE_PATH="$PROJECT_ROOT/.env.example"

# 加载 .env 文件中的环境变量
if [ -f "$ENV_FILE_PATH" ]; then
    echo "✅ 发现 .env 文件，正在加载环境变量..."
    set -a
    source "$ENV_FILE_PATH"
    set +a
else
    echo "⚠️ 未发现 .env 文件，将使用 .env.example 作为默认配置..."
    if [ -f "$ENV_EXAMPLE_FILE_PATH" ]; then
        cp "$ENV_EXAMPLE_FILE_PATH" "$ENV_FILE_PATH"
        set -a
        source "$ENV_FILE_PATH"
        set +a
    else
        echo "❌ 警告：.env.example 文件也不存在，部分服务可能无法正常启动！"
    fi
fi

echo "🚀 正在按序拉起服务..."

# 确保 insight-net 网络存在
if ! docker network ls | grep -q "insight-net"; then
    echo "🌐 创建 Docker 网络 insight-net..."
    # 尝试创建网络，如果地址池已满，尝试清理旧网络或使用不同子网
    if ! docker network create ${DOCKER_NETWORK_NAME:-insight-net} 2>/dev/null; then
        echo "⚠️  网络创建失败（可能是地址池已满），尝试清理未使用的网络..."
        docker network prune -f
        # 尝试使用自定义子网
        if ! docker network create --subnet=172.20.0.0/16 ${DOCKER_NETWORK_NAME:-insight-net} 2>/dev/null; then
            echo "❌ 无法创建 Docker 网络，请手动清理：docker network prune -f"
            exit 1
        else
            echo "✅ 使用自定义子网创建网络成功"
        fi
    fi
fi

# 启动服务并检查镜像拉取结果
start_service() {
    local COMPOSE_FILE=$1
    local SERVICE_NAME=$2
    
    echo "🚀 启动 $SERVICE_NAME..."
    if docker compose --env-file "$ENV_FILE_PATH" -f "$COMPOSE_FILE" up -d 2>&1 | tee /tmp/docker-compose-output.log; then
        # 检查是否有镜像拉取错误
        if grep -q "failed to resolve reference\|connection reset\|timeout" /tmp/docker-compose-output.log; then
            echo "❌ $SERVICE_NAME 镜像拉取失败！"
            echo "💡 建议："
            echo "   1. 检查网络连接"
            echo "   2. 如果是生产环境且无法访问 docker.io，请切换到开发环境部署（使用镜像加速）"
            echo "   3. 运行: ./manage.sh -> 5 -> 3 (开发环境部署)"
            return 1
        fi
        return 0
    else
        echo "❌ $SERVICE_NAME 启动失败"
        return 1
    fi
}

# 启动数据库（必须先启动）
if start_service "$COMPOSE_DIR/03-databases.yml" "数据库服务"; then
    echo "⏳ 等待数据库启动..."
    sleep 5
else
    echo "❌ 数据库启动失败，停止后续服务启动"
    exit 1
fi

# 启动其他服务
start_service "$COMPOSE_DIR/01-gateway.yml" "网关服务"
start_service "$COMPOSE_DIR/04-workflow.yml" "工作流服务 (n8n)"
start_service "$COMPOSE_DIR/05-data-viz.yml" "数据可视化服务 (NocoDB)"
start_service "$COMPOSE_DIR/06-knowledge.yml" "知识库服务 (Wiki)"

# 修复权限
if [ -d "$PROJECT_ROOT/data/04-workflow" ]; then
    chown -R 1000:1000 "$PROJECT_ROOT/data/04-workflow" 2>/dev/null || true
fi

# 清理临时文件
rm -f /tmp/docker-compose-output.log

echo ""
echo "✅ 所有服务已尝试启动。"
echo "📋 请运行以下命令检查状态："
echo "   docker ps"
echo "   docker ps -a  # 查看所有容器（包括停止的）"