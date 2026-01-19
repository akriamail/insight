#!/bin/bash

# --- Project Team Node-A 一键停止脚本 (v1.0.0 完整版) ---

# 1. 自动定位路径
REPO_DIR=$(cd "$(dirname "$0")/.."; pwd)
COMPOSE_DIR="$REPO_DIR/compose"

echo "🛑 正在停止 Project Team Node-A 所有服务..."
echo "📂 配置文件位置: $COMPOSE_DIR"

# 2. 逆序停止（先停应用，后停数据库和网关）
echo "--- [1/3] 停止应用层 (Wiki, NocoDB, n8n) ---"
docker compose -f $COMPOSE_DIR/06-knowledge.yml down
docker compose -f $COMPOSE_DIR/05-data-viz.yml down
docker compose -f $COMPOSE_DIR/04-workflow.yml down

echo "--- [2/3] 停止数据层 (Postgres) ---"
docker compose -f $COMPOSE_DIR/03-databases.yml down

echo "--- [3/3] 停止接入层 (NPM Gateway) ---"
docker compose -f $COMPOSE_DIR/01-gateway.yml down

echo "✅ 所有容器已安全移除。"
echo "--------------------------------------"
docker ps -a
