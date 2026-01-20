#!/bin/bash
# --- Project Team 交互式全量恢复脚本 ---

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.."; pwd)
DATA_DIR="$ROOT_DIR/data"
BACKUP_ROOT="$ROOT_DIR/backups"
EXPORT_DIR="$ROOT_DIR/exports"
ENV_FILE="$ROOT_DIR/.env"

# 1. 加载环境变量
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "\033[0;31m❌ 错误: 未找到 .env 文件，无法获取配置！\033[0m"
    exit 1
fi

echo -e "\033[1;33m⚠️  进入全量恢复程序...\033[0m"

# 2. 列出并选择备份包
echo -e "\n🔍 正在扫描可用备份包 ($EXPORT_DIR):"
# 获取备份文件列表，按时间排序
IFS=$'\n' BACKUP_FILES=($(ls -t $EXPORT_DIR/Project_Team_Full_Backup_*.tar.gz 2>/dev/null))

if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
    echo -e "\033[0;31m❌ 未找到任何全量备份包！\033[0m"
    exit 1
fi

echo -e "------------------------------------------------------------"
for i in "${!BACKUP_FILES[@]}"; do
    # 获取文件时间戳，兼容 Linux 和 macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        FILE_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${BACKUP_FILES[$i]}")
    else
        FILE_TIME=$(stat -c %y "${BACKUP_FILES[$i]}" | cut -d'.' -f1)
    fi
    FILE_NAME=$(basename "${BACKUP_FILES[$i]}")
    printf "\033[0;32m%2d)\033[0m %-45s [%s]\n" $((i+1)) "$FILE_NAME" "$FILE_TIME"
done
echo -e "------------------------------------------------------------"

read -p "请输入要恢复的备份编号 [1-${#BACKUP_FILES[@]}] (取消请输入 q): " choice

if [[ "$choice" == "q" ]]; then
    echo "操作已取消。"
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#BACKUP_FILES[@]}" ]; then
    echo -e "\033[0;31m❌ 无效选择！\033[0m"
    exit 1
fi

SELECTED_BACKUP="${BACKUP_FILES[$((choice-1))]}"
echo -e "\n✅ 已选择: \033[1;32m$(basename "$SELECTED_BACKUP")\033[0m"

# 确认操作
read -p "⚠️  警告：恢复将彻底覆盖当前所有数据！确认继续？(y/n): " final_confirm
if [[ $final_confirm != [yY] ]]; then
    echo "操作已取消。"
    exit 0
fi

# 3. 开始执行恢复流程
echo -e "\n📦 正在解压备份包..."
mkdir -p "$BACKUP_ROOT"
tar -xzf "$SELECTED_BACKUP" -C "$BACKUP_ROOT"

# 停止应用服务
echo "🛑 正在暂停应用服务..."
bash "$SCRIPT_DIR/06-shutdown.sh"

echo "--- [1/3] 还原网关配置 ---"
GATAWAY_BACKUP=$(ls -t $BACKUP_ROOT/gateway/npm_*.tar.gz 2>/dev/null | head -1)
if [ -n "$GATAWAY_BACKUP" ]; then
    rm -rf "$DATA_DIR/01-gateway"/*
    mkdir -p "$DATA_DIR/01-gateway"
    tar -xzf "$GATAWAY_BACKUP" -C "$DATA_DIR/01-gateway"
    echo "✅ 网关配置已还原。"
fi

echo "--- [2/3] 启动数据库并准备环境 ---"
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/infra/compose/03-databases.yml" up -d
echo "⏳ 等待数据库就绪..."
RETRIES=15
until docker exec insight-db pg_isready -U insight_admin || [ $RETRIES -eq 0 ]; do
  sleep 2
  RETRIES=$((RETRIES - 1))
done

echo "--- [3/3] 导入数据库数据 ---"
export PGPASSWORD="$DB_PASSWORD"
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")

for DB_NAME in "${DB_LIST[@]}"; do
    FILE=$(ls -t $BACKUP_ROOT/postgres/${DB_NAME}_*.sql.gz 2>/dev/null | head -1)
    if [ -f "$FILE" ]; then
        echo "📂 正在恢复数据库: $DB_NAME ..."
        # 断开连接并重建数据库
        docker exec -i insight-db psql -U insight_admin -d postgres -c "REVOKE CONNECT ON DATABASE $DB_NAME FROM public;" 2>/dev/null || true
        docker exec -i insight-db psql -U insight_admin -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME';" 2>/dev/null || true
        docker exec -i insight-db psql -U insight_admin -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
        docker exec -i insight-db psql -U insight_admin -d postgres -c "CREATE DATABASE $DB_NAME;"
        # 导入数据
        zcat "$FILE" | docker exec -i insight-db psql -U insight_admin -d "$DB_NAME" > /dev/null
        echo "   ✅ $DB_NAME 恢复成功。"
    fi
done

echo "🚀 正在重新启动所有服务..."
bash "$SCRIPT_DIR/02-startup.sh"

echo -e "\n\033[1;32m✨ 恢复程序全部执行完毕！\033[0m"
