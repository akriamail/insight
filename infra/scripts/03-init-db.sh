#!/bin/bash
# --- Project Team 数据库自动初始化脚本 ---

echo "🧐 正在检测数据库容器状态..."

# 0. 首先检查容器是否存在
if ! docker ps -a | grep -q "insight-db"; then
    echo "❌ 错误: 数据库容器 'insight-db' 不存在！"
    echo "💡 可能原因："
    echo "   1. 镜像拉取失败（网络问题）"
    echo "   2. 容器启动失败"
    echo ""
    echo "🔍 请检查："
    echo "   docker ps -a | grep insight-db"
    echo "   docker logs insight-db  # 如果容器存在"
    echo ""
    echo "💡 建议："
    echo "   1. 如果是生产环境且无法访问 docker.io，请切换到开发环境部署"
    echo "   2. 运行: ./manage.sh -> 5 -> 3 (开发环境部署，使用镜像加速)"
    echo "   3. 或者手动拉取镜像: docker pull postgres:16-alpine"
    exit 1
fi

# 检查容器是否在运行
if ! docker ps | grep -q "insight-db"; then
    echo "⚠️  数据库容器存在但未运行，尝试启动..."
    docker start insight-db
    sleep 3
fi

# 1. 循环检测 Postgres 端口，确保容器已完全启动
RETRIES=10
until docker exec insight-db pg_isready -U insight_admin 2>/dev/null || [ $RETRIES -eq 0 ]; do
  echo "⏳ 等待 Postgres 核心启动中... (剩余重试: $RETRIES)"
  sleep 3
  RETRIES=$((RETRIES - 1))
done

if [ $RETRIES -eq 0 ]; then
    echo "❌ 错误: 数据库容器在指定时间内未就绪"
    echo "🔍 请检查日志: docker logs insight-db"
    echo "💡 可能原因：数据库初始化失败或配置错误"
    exit 1
fi

# --- 辅助函数：创建数据库（幂等性）---
create_db_if_not_exists() {
    DB_NAME=$1
    DB_USER="insight_admin" # 所有数据库都使用同一个管理员用户

    echo "⚙️  检查并创建数据库: $DB_NAME"
    CHECK_DB=$(docker exec -i insight-db psql -U $DB_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

    if [ "$CHECK_DB" != "1" ]; then
        echo "➕ 正在创建新数据库: $DB_NAME"
        docker exec -i insight-db psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"
        echo "✅ 数据库 $DB_NAME 创建成功。"
    else
        echo "🆗 数据库 $DB_NAME 已存在，跳过。"
    fi
}

# --- 2. 为各个服务创建数据库 ---
echo "🛠️  开始为各个服务初始化数据库..."

# n8n 数据库
create_db_if_not_exists "n8n_db"

# NocoDB 数据库
create_db_if_not_exists "nocodb_db"

# Wiki.js 数据库
create_db_if_not_exists "wikijs_db"

# Teleport 数据库 (如果需要)
create_db_if_not_exists "teleport_db"

echo "✨ 所有服务数据库环境检查完毕。"
