#!/bin/bash
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "📂 [1/3] 备份数据库..."
export PGPASSWORD='z1a2q3W4!@#'
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
mkdir -p $BACKUP_ROOT/postgres $BACKUP_ROOT/gateway
for DB_NAME in "${DB_LIST[@]}"; do
    docker exec insight-db pg_dump -U insight_admin $DB_NAME | gzip > $BACKUP_ROOT/postgres/${DB_NAME}_$TIMESTAMP.sql.gz
done

echo "📂 [2/3] 备份网关配置..."
tar -czf $BACKUP_ROOT/gateway/npm_full_config_$TIMESTAMP.tar.gz -C $DATA_DIR/01-gateway .

echo "📦 [3/3] 打包全量导出包..."
tar -czf $EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz -C $BACKUP_ROOT .
echo "✅ 备份完成: $EXPORT_DIR"
