#!/bin/bash
echo "🗄️ 正在初始化数据库环境..."
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    docker exec -i insight-db psql -U insight_admin -d postgres -c "SELECT 'CREATE DATABASE $DB_NAME' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec"
done
echo "✅ 数据库就绪。"
