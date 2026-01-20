#!/bin/bash
# --- Project Team 交互式全量深度恢复脚本 (v1.1) ---

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
ENV_FILE="$ROOT_DIR/.env"

# 1. 加载环境变量
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; } || { echo "❌ 未找到 .env"; exit 1; }

echo -e "\033[1;33m⚠️  进入全量深度恢复程序...\033[0m"

# 2. 选择备份包
IFS=$'\n' BACKUP_FILES=($(ls -t $EXPORT_DIR/Project_Team_Full_Backup_*.tar.gz 2>/dev/null))
[ ${#BACKUP_FILES[@]} -eq 0 ] && { echo "❌ 未找到备份"; exit 1; }

echo "------------------------------------------------------------"
for i in "${!BACKUP_FILES[@]}"; do
    FILE_TIME=$(stat -c %y "${BACKUP_FILES[$i]}" 2>/dev/null | cut -d'.' -f1 || echo "Unknown")
    printf "\033[0;32m%2d)\033[0m %-45s [%s]\n" $((i+1)) "$(basename "${BACKUP_FILES[$i]}")" "$FILE_TIME"
done
echo "------------------------------------------------------------"
read -p "选择编号 (q取消): " choice
[[ "$choice" == "q" ]] && exit 0
SELECTED_BACKUP="${BACKUP_FILES[$((choice-1))]}"

# 3. 开始恢复
echo -e "\n📦 正在准备数据..."
mkdir -p "$BACKUP_ROOT"
tar -xzf "$SELECTED_BACKUP" -C "$BACKUP_ROOT"

# 停止应用服务
echo "🛑 停止当前服务..."
bash "$SCRIPT_DIR/06-shutdown.sh"

echo "--- [1/4] 还原网关配置 ---"
G_BACKUP=$(ls -t $BACKUP_ROOT/gateway/npm_*.tar.gz 2>/dev/null | head -1)
if [ -n "$G_BACKUP" ]; then
    mkdir -p "$DATA_DIR/01-gateway" && rm -rf "$DATA_DIR/01-gateway"/*
    tar -xzf "$G_BACKUP" -C "$DATA_DIR/01-gateway"
    echo "✅ 网关还原完成。"
fi

echo "--- [2/4] 还原应用本地文件 (关键点) ---"
A_BACKUP=$(ls -t $BACKUP_ROOT/apps/app_data_*.tar.gz 2>/dev/null | head -1)
if [ -n "$A_BACKUP" ]; then
    # 还原 n8n, nocodb, wikijs 的本地卷文件
    tar -xzf "$A_BACKUP" -C "$DATA_DIR"
    echo "✅ 应用配置文件已同步还原。"
else
    echo "⚠️  未发现应用文件备份，仅恢复数据库。"
fi

echo "--- [3/4] 重启数据库 ---"
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/infra/compose/03-databases.yml" up -d
echo "⏳ 等待就绪..."
until docker exec insight-db pg_isready -U insight_admin >/dev/null 2>&1; do sleep 2; done

echo "--- [4/4] 导入数据库数据 ---"
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    FILE=$(ls -t $BACKUP_ROOT/postgres/${DB_NAME}_*.sql.gz 2>/dev/null | head -1)
    if [ -f "$FILE" ]; then
        echo "📂 恢复 $DB_NAME ..."
        docker exec -i insight-db psql -U insight_admin -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME';" >/dev/null 2>&1
        docker exec -i insight-db psql -U insight_admin -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" >/dev/null
        docker exec -i insight-db psql -U insight_admin -d postgres -c "CREATE DATABASE $DB_NAME;" >/dev/null
        zcat "$FILE" | docker exec -i insight-db psql -U insight_admin -d "$DB_NAME" > /tmp/restore_err.log 2>&1
        if [ $? -eq 0 ]; then echo "   ✅ 成功"; else echo "   ❌ 失败 (见 /tmp/restore_err.log)"; fi
    fi
done

echo "🚀 重新拉起所有应用..."
bash "$SCRIPT_DIR/02-startup.sh"
echo -e "\n\033[1;32m✨ 深度恢复已完成！NocoDB 状态应已恢复。\033[0m"
