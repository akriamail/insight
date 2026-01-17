#!/bin/bash
# --- Project Team 数据库初始化逻辑 ---

echo "🗄️ 正在检查并初始化数据库..."

# 等待数据库容器完全启动
until docker exec insight-db pg_isready -U insight_admin; do
  echo "⏳ 等待 Postgres 启动中..."
  sleep 2
done

DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")

for DB_NAME in "${DB_LIST[@]}"; do
    # 检查数据库是否存在，不存在则创建
    MATCH=$(docker exec -i insight-db psql -U insight_admin -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
    if [ "$MATCH" != "1" ]; then
        echo "➕ 正在创建数据库: $DB_NAME"
        docker exec -i insight-db psql -U insight_admin -d postgres -c "CREATE DATABASE $DB_NAME;"
    else
        echo "✅ 数据库 $DB_NAME 已存在"
    fi
done
