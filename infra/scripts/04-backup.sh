#!/bin/bash
# --- Project Team 全量备份脚本 (v1.1 - 支持应用文件归档) ---

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
ENV_FILE="$ROOT_DIR/.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 1. 加载环境变量
if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
else
    echo "❌ 错误: 未找到 .env 文件！"
    exit 1
fi

echo "🚀 开始执行全量深度备份..."

# 2. 准备临时目录
mkdir -p "$BACKUP_ROOT/postgres" "$BACKUP_ROOT/gateway" "$BACKUP_ROOT/apps" "$EXPORT_DIR"

# 3. 备份数据库
echo "📂 [1/4] 备份数据库数据..."
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    echo "   - 正在导出: $DB_NAME ..."
    docker exec insight-db pg_dump -U insight_admin "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_ROOT/postgres/${DB_NAME}_$TIMESTAMP.sql.gz"
done

# 4. 备份网关配置
echo "📂 [2/4] 备份网关配置 (Nginx Proxy Manager)..."
tar -czf "$BACKUP_ROOT/gateway/npm_$TIMESTAMP.tar.gz" -C "$DATA_DIR/01-gateway" .

# 5. 备份应用本地持久化文件 (关键：包含 NocoDB 管理员状态、n8n 密钥等)
echo "📂 [3/4] 备份应用本地文件 (n8n, NocoDB, Wiki.js)..."
# 我们只备份非数据库的持久化目录
tar -czf "$BACKUP_ROOT/apps/app_data_$TIMESTAMP.tar.gz" \
    -C "$DATA_DIR" 04-workflow 05-data-viz 06-knowledge 2>/dev/null

# 6. 打包全量导出包
echo "📦 [4/4] 创建最终全量归档压缩包..."
# 清理 5 分钟前的临时文件
find "$BACKUP_ROOT/postgres" -name "*.sql.gz" -mmin +5 -delete
find "$BACKUP_ROOT/gateway" -name "*.tar.gz" -mmin +5 -delete
find "$BACKUP_ROOT/apps" -name "*.tar.gz" -mmin +5 -delete

tar -czf "$EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz" -C "$BACKUP_ROOT" .
echo -e "\033[1;32m✨ 全量深度备份完成！\033[0m"
echo "📄 备份文件: $EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz"
