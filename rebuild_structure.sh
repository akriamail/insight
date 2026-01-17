#!/bin/bash

# --- Project Team 架构重组自动化工具 ---
ROOT_DIR="/opt/insight"
cd $ROOT_DIR

echo "🏗️  正在构建扁平化目录结构..."

# 1. 创建所有目录
mkdir -p data/01-gateway data/02-security data/03-databases \
         data/04-workflow data/05-data-viz data/05-registry \
         data/06-knowledge infra/compose infra/scripts backups exports

# 2. 生成 .gitkeep 占位文件
find data backups exports -type d -exec touch {}/.gitkeep \;

# 3. 写入 .gitignore
cat <<EOF > .gitignore
# 忽略所有生产数据
data/**/*
backups/**/*
exports/**/*

# 但保留目录结构
!**/
!**/.gitkeep

# 系统冗余
*.log
.DS_Store
EOF

echo "📜  正在生成适配新路径的运维脚本..."

# --- 生成 03-init-db.sh ---
cat <<EOF > infra/scripts/03-init-db.sh
#!/bin/bash
echo "🗄️ 正在初始化数据库环境..."
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "\${DB_LIST[@]}"; do
    docker exec -i insight-db psql -U insight_admin -d postgres -c "SELECT 'CREATE DATABASE \$DB_NAME' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '\$DB_NAME')\gexec"
done
echo "✅ 数据库就绪。"
EOF

# --- 生成 backup.sh ---
cat <<EOF > infra/scripts/backup.sh
#!/bin/bash
SCRIPT_DIR=\$(cd "\$(dirname "\$0")"; pwd)
ROOT_DIR=\$(cd "\$SCRIPT_DIR/../.."; pwd)
DATA_DIR="\$ROOT_DIR/data"
BACKUP_ROOT="\$ROOT_DIR/backups"
EXPORT_DIR="\$ROOT_DIR/exports"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)

echo "📂 [1/3] 备份数据库..."
export PGPASSWORD='z1a2q3W4!@#'
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
mkdir -p \$BACKUP_ROOT/postgres \$BACKUP_ROOT/gateway
for DB_NAME in "\${DB_LIST[@]}"; do
    docker exec insight-db pg_dump -U insight_admin \$DB_NAME | gzip > \$BACKUP_ROOT/postgres/\${DB_NAME}_\$TIMESTAMP.sql.gz
done

echo "📂 [2/3] 备份网关配置..."
tar -czf \$BACKUP_ROOT/gateway/npm_full_config_\$TIMESTAMP.tar.gz -C \$DATA_DIR/01-gateway .

echo "📦 [3/3] 打包全量导出包..."
tar -czf \$EXPORT_DIR/Project_Team_Full_Backup_\$TIMESTAMP.tar.gz -C \$BACKUP_ROOT .
echo "✅ 备份完成: \$EXPORT_DIR"
EOF

# --- 生成 restore.sh ---
cat <<EOF > infra/scripts/restore.sh
#!/bin/bash
SCRIPT_DIR=\$(cd "\$(dirname "\$0")"; pwd)
ROOT_DIR=\$(cd "\$SCRIPT_DIR/../.."; pwd)
DATA_DIR="\$ROOT_DIR/data"
BACKUP_ROOT="\$ROOT_DIR/backups"
EXPORT_DIR="\$ROOT_DIR/exports"

echo "⚠️  启动全量恢复程序..."
LATEST_FULL=\$(ls -t \$EXPORT_DIR/Project_Team_Full_Backup_*.tar.gz 2>/dev/null | head -1)
if [ -z "\$LATEST_FULL" ]; then echo "❌ 未找到备份包"; exit 1; fi

tar -xzf \$LATEST_FULL -C \$BACKUP_ROOT
echo "--- [1/3] 还原网关 ---"
tar -xzf \$(ls -t \$BACKUP_ROOT/gateway/npm_*.tar.gz | head -1) -C \$DATA_DIR/01-gateway

echo "--- [2/3] 重启服务与初始化 ---"
docker compose -f \$ROOT_DIR/infra/compose/03-databases.yml up -d
sleep 10
bash \$SCRIPT_DIR/03-init-db.sh

echo "--- [3/3] 导入数据 ---"
export PGPASSWORD='z1a2q3W4!@#'
DB_LIST=("n8n_db" "nocodb_db" "wikijs_db" "teleport_db")
for DB_NAME in "\${DB_LIST[@]}"; do
    FILE=\$(ls -t \$BACKUP_ROOT/postgres/\${DB_NAME}_*.sql.gz | head -1)
    zcat \$FILE | docker exec -i insight-db psql -U insight_admin -d \$DB_NAME
done
echo "✨ 恢复完成。"
EOF

chmod +x infra/scripts/*.sh
echo "🚀 重组完成！请将 .yml 文件放入 /opt/insight/infra/compose/ 即可。"
