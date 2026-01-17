#!/bin/bash

# --- Project Team Node-A 一键启动脚本 (v1.0.0 完整版) ---

# 1. 自动定位路径（核心逻辑）
# 获取脚本所在目录的上一级，即仓库根目录
REPO_DIR=$(cd "$(dirname "$0")/.."; pwd)
COMPOSE_DIR="$REPO_DIR/compose"
ENV_FILE="$REPO_DIR/.env"

echo "🚀 Project Team Node-A 正在从以下路径启动:"
echo "📂 根目录: $REPO_DIR"

# 2. 依次拉起服务
echo "--- [1/4] 启动流量网关 ---"
docker compose -f $COMPOSE_DIR/01-gateway.yml --env-file $ENV_FILE up -d

echo "--- [2/4] 启动数据底座 ---"
docker compose -f $COMPOSE_DIR/03-databases.yml --env-file $ENV_FILE up -d

echo "--- [3/4] 启动业务应用 (n8n & NocoDB) ---"
docker compose -f $COMPOSE_DIR/04-workflow.yml --env-file $ENV_FILE up -d
docker compose -f $COMPOSE_DIR/05-data-viz.yml --env-file $ENV_FILE up -d

echo "--- [4/4] 启动团队知识库 ---"
docker compose -f $COMPOSE_DIR/06-knowledge.yml --env-file $ENV_FILE up -d

echo "✅ 所有服务已拉起！"
echo "--------------------------------------"
docker ps
