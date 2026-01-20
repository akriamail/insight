#!/bin/bash
# --- Project Team 交互式全量深度恢复脚本 (v1.2 - 修复 NocoDB 数据丢失) ---

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

# 停止应用服务（关键：必须在恢复前停止，防止应用重新初始化）
echo "🛑 停止当前服务..."
bash "$SCRIPT_DIR/06-shutdown.sh"

echo "--- [1/5] 还原网关配置 ---"
G_BACKUP=$(ls -t $BACKUP_ROOT/gateway/npm_*.tar.gz 2>/dev/null | head -1)
if [ -n "$G_BACKUP" ]; then
    mkdir -p "$DATA_DIR/01-gateway"
    rm -rf "$DATA_DIR/01-gateway"/*
    tar -xzf "$G_BACKUP" -C "$DATA_DIR"
    echo "✅ 网关还原完成。"
else
    echo "⚠️  未发现网关备份，跳过。"
fi

echo "--- [2/5] 还原应用本地文件 (关键：NocoDB/Wiki/n8n 的持久化数据) ---"
# 逐个恢复每个应用目录的备份文件
APP_DIRS=("04-workflow" "05-data-viz" "06-knowledge")
for APP_DIR in "${APP_DIRS[@]}"; do
    # 查找该应用目录的最新备份文件（匹配备份脚本生成的文件名格式）
    APP_BACKUP=$(ls -t $BACKUP_ROOT/apps/${APP_DIR}_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$APP_BACKUP" ]; then
        echo "   - 正在恢复: $APP_DIR"
        mkdir -p "$DATA_DIR/$APP_DIR"
        rm -rf "$DATA_DIR/$APP_DIR"/*
        tar -xzf "$APP_BACKUP" -C "$DATA_DIR"
        [ $? -eq 0 ] && echo "     ✅ $APP_DIR 恢复成功" || echo "     ❌ $APP_DIR 恢复失败"
    else
        echo "   ⚠️  未发现 $APP_DIR 的备份文件，跳过。"
    fi
done

echo "--- [3/5] 重启数据库 ---"
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/infra/compose/03-databases.yml" up -d
echo "⏳ 等待数据库就绪..."
RETRIES=15
until docker exec insight-db pg_isready -U insight_admin >/dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    sleep 2
    RETRIES=$((RETRIES - 1))
done

echo "--- [4/5] 导入数据库数据 (强制清理重建) ---"
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "${DB_LIST[@]}"; do
    FILE=$(ls -t $BACKUP_ROOT/postgres/${DB_NAME}_*.sql.gz 2>/dev/null | head -1)
    if [ -f "$FILE" ]; then
        echo "📂 恢复数据库: $DB_NAME ..."
        # 强制断开所有连接
        docker exec -i insight-db psql -U insight_admin -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME';" >/dev/null 2>&1
        # 删除并重建数据库
        docker exec -i insight-db psql -U insight_admin -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" >/dev/null
        docker exec -i insight-db psql -U insight_admin -d postgres -c "CREATE DATABASE $DB_NAME;" >/dev/null
        # 导入数据
        zcat "$FILE" | docker exec -i insight-db psql -U insight_admin -d "$DB_NAME" > /tmp/restore_${DB_NAME}_err.log 2>&1
        if [ $? -eq 0 ]; then
            echo "   ✅ $DB_NAME 恢复成功"
        else
            echo "   ❌ $DB_NAME 恢复失败 (错误日志: /tmp/restore_${DB_NAME}_err.log)"
        fi
    else
        echo "   ⚠️  未发现 $DB_NAME 的备份文件，跳过。"
    fi
done

echo "--- [5/5] 重新拉起所有应用服务 ---"
bash "$SCRIPT_DIR/02-startup.sh"

echo -e "\n\033[1;32m✨ 深度恢复已完成！\033[0m"
echo -e "\033[1;33m提示：如果 NocoDB 仍要求重新注册，请检查：\033[0m"
echo "   1. 数据库 nocodb_db 是否已成功恢复"
echo "   2. 本地文件 /opt/insight/data/05-data-viz 是否已正确还原"
echo "   3. 查看 NocoDB 容器日志: docker logs insight-nocodb"
