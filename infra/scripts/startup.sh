#!/bin/bash
# --- Project Team 一键启动脚本 ---
COMPOSE_DIR=$(cd "$(dirname "$0")/../compose"; pwd)

echo "🚀 正在按序拉起服务..."
docker compose -f $COMPOSE_DIR/03-databases.yml up -d
sleep 5
docker compose -f $COMPOSE_DIR/01-gateway.yml up -d
docker compose -f $COMPOSE_DIR/04-workflow.yml up -d
docker compose -f $COMPOSE_DIR/05-data-viz.yml up -d
docker compose -f $COMPOSE_DIR/06-knowledge.yml up -d

echo "✅ 所有服务已尝试启动。请运行 docker ps 检查状态。"
