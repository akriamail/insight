#!/bin/bash
# --- Project Team 全量备份脚本 (增强版：含数据库与文件) ---

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
ENV_FILE="$ROOT_DIR/.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 1. 加载环境变量
[ -f "$ENV_FILE" ] && source "$ENV_FILE" || { echo "❌ 未找到 .env"; exit 1; }

echo "🚀 开始执行全量备份 [$TIMESTAMP]..."
mkdir -p "$BACKUP_ROOT/postgres" "$BACKUP_ROOT/gateway" "$BACKUP_ROOT/apps" "$EXPORT_DIR"

# 2. 备份数据库 (SQL)
echo "📂 [1/4] 备份数据库..."
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    echo "   - 正在备份数据库: $DB_NAME"
    docker exec insight-db pg_dump -U insight_admin "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_ROOT/postgres/${DB_NAME}_$TIMESTAMP.sql.gz"
    [ $? -eq 0 ] && echo "     ✅ $DB_NAME 备份成功" || echo "     ❌ $DB_NAME 备份失败"
done

# 3. 备份网关配置
echo "📂 [2/4] 备份网关配置 (Nginx Proxy Manager)..."
if [ -d "$DATA_DIR/01-gateway" ]; then
    tar -czf "$BACKUP_ROOT/gateway/npm_$TIMESTAMP.tar.gz" -C "$DATA_DIR" "01-gateway"
    echo "   ✅ 网关配置备份成功"
fi

# 4. 备份应用持久化文件 (Volumes)
echo "📂 [3/4] 备份应用持久化文件 (Data Volumes)..."
# 包含：workflow (n8n), data-viz (nocodb), knowledge (wikijs)
APP_DIRS=("04-workflow" "05-data-viz" "06-knowledge")
for APP_DIR in "${APP_DIRS[@]}"; do
    if [ -d "$DATA_DIR/$APP_DIR" ]; then
        echo "   - 正在打包应用目录: $APP_DIR"
        tar -czf "$BACKUP_ROOT/apps/${APP_DIR}_$TIMESTAMP.tar.gz" -C "$DATA_DIR" "$APP_DIR"
        [ $? -eq 0 ] && echo "     ✅ $APP_DIR 备份成功" || echo "     ❌ $APP_DIR 备份失败"
    else
        echo "   ⚠️  目录不存在，跳过: $APP_DIR"
    fi
done

# 5. 打包全量导出包
echo "📦 [4/4] 创建全量归档压缩包..."
# 清理 5 分钟前的旧本地临时文件
find "$BACKUP_ROOT/postgres" -name "*.sql.gz" -mmin +5 -delete 2>/dev/null
find "$BACKUP_ROOT/gateway" -name "*.tar.gz" -mmin +5 -delete 2>/dev/null
find "$BACKUP_ROOT/apps" -name "*.tar.gz" -mmin +5 -delete 2>/dev/null

tar -czf "$EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz" -C "$BACKUP_ROOT" .
echo "✨ 全量备份完成！"
echo "📄 备份文件位置: $EXPORT_DIR/Project_Team_Full_Backup_$TIMESTAMP.tar.gz"
