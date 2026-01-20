#!/bin/bash
# --- Project Team 全量备份脚本 ---

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
ENV_FILE="$ROOT_DIR/.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 1. 加载环境变量
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "❌ 错误: 未找到 .env 文件，无法获取数据库密码！"
    exit 1
fi

echo "🚀 开始执行全量备份..."

# 2. 备份数据库
echo "📂 [1/3] 备份数据库数据..."
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
mkdir -p "$BACKUP_ROOT/postgres" "$BACKUP_ROOT/gateway" "$EXPORT_DIR"

for DB_NAME in "${DB_LIST[@]}"; do
    echo "   - 正在备份: $DB_NAME ..."
    docker exec insight-db pg_dump -U insight_admin "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_ROOT/postgres/${DB_NAME}_$TIMESTAMP.sql.gz"
    if [ $? -eq 0 ]; then
        echo "     ✅ $DB_NAME 备份成功。"
    else
        echo "     ❌ $DB_NAME 备份失败！"
    fi
done

# 3. 备份网关配置
echo "📂 [2/3] 备份网关配置 (Nginx Proxy Manager)..."
tar -czf "$BACKUP_ROOT/gateway/npm_$TIMESTAMP.tar.gz" -C "$DATA_DIR/01-gateway" .
echo "   ✅ 网关配置备份成功。"

# 4. 打包全量导出包
echo "📦 [3/3] 创建全量归档压缩包..."
# 清理旧的本地备份，只保留本次的，避免全量包越来越大
find "$BACKUP_ROOT/postgres" -name "*.sql.gz" -mmin +5 -delete
find "$BACKUP_ROOT/gateway" -name "*.tar.gz" -mmin +5 -delete

tar -czf "$EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz" -C "$BACKUP_ROOT" .
echo "✨ 全量备份完成！"
echo "📄 备份文件位置: $EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz"
