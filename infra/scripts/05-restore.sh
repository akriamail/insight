#!/bin/bash
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"

echo "⚠️  启动全量恢复程序..."
LATEST_FULL=$(ls -t $EXPORT_DIR/Project_Team_Full_Backup_*.tar.gz 2>/dev/null | head -1)
if [ -z "$LATEST_FULL" ]; then echo "❌ 未找到备份包"; exit 1; fi

tar -xzf $LATEST_FULL -C $BACKUP_ROOT
echo "--- [1/3] 还原网关 ---"
tar -xzf $(ls -t $BACKUP_ROOT/gateway/npm_*.tar.gz | head -1) -C $DATA_DIR/01-gateway

echo "--- [2/3] 重启服务与初始化 ---"
docker compose -f $ROOT_DIR/infra/compose/03-databases.yml up -d
sleep 10
bash $SCRIPT_DIR/03-init-db.sh

echo "--- [3/3] 导入数据 ---"
export PGPASSWORD='z1a2q3W4!@#'
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    FILE=$(ls -t $BACKUP_ROOT/postgres/${DB_NAME}_*.sql.gz | head -1)
    zcat $FILE | docker exec -i insight-db psql -U insight_admin -d $DB_NAME
done
echo "✨ 恢复完成。"
