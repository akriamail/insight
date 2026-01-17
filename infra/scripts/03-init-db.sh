#!/bin/bash
# --- Project Team 数据库自动初始化脚本 ---

echo "🧐 正在检测数据库容器状态..."

# 1. 循环检测 Postgres 端口，确保容器已完全启动
RETRIES=10
until docker exec insight-db pg_isready -U insight_admin || [ $RETRIES -eq 0 ]; do
  echo "⏳ 等待 Postgres 核心启动中... (剩余重试: $RETRIES)"
  sleep 3
  RETRIES=$((RETRIES - 1))
done

if [ $RETRIES -eq 0 ]; then
    echo "❌ 错误: 数据库容器在指定时间内未就绪，请检查日志: docker logs insight-db"
    exit 1
fi

# 2. 定义需要创建的数据库清单
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")

echo "🛠️  开始扫描数据库清单..."

for DB_NAME in "${DB_LIST[@]}"; do
    # 检查数据库是否已存在
    CHECK_DB=$(docker exec -i insight-db psql -U insight_admin -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
    
    if [ "$CHECK_DB" != "1" ]; then
        echo "➕ 正在创建新数据库: $DB_NAME"
        docker exec -i insight-db psql -U insight_admin -d postgres -c "CREATE DATABASE $DB_NAME;"
        echo "✅ $DB_NAME 创建成功。"
    else
        echo "🆗 数据库 $DB_NAME 已存在，跳过。"
    fi
done

echo "✨ 数据库环境检查完毕。"
