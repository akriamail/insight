#!/bin/bash
# --- 修复 Docker 网络地址池问题 ---

echo "🔧 正在修复 Docker 网络问题..."

# 1. 清理未使用的网络
echo "📋 清理未使用的 Docker 网络..."
docker network prune -f

# 2. 检查并删除旧的 insight-net（如果存在且有问题）
if docker network ls | grep -q "insight-net"; then
    echo "🔍 检测到现有 insight-net 网络"
    read -p "是否删除并重建? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        # 停止使用该网络的所有容器
        echo "🛑 停止使用 insight-net 的容器..."
        docker ps --filter network=insight-net --format "{{.Names}}" | xargs -r docker stop 2>/dev/null || true
        
        # 删除网络
        docker network rm insight-net 2>/dev/null || {
            echo "⚠️  无法删除网络（可能有容器仍在使用），尝试强制清理..."
            docker network prune -f
        }
    fi
fi

# 3. 创建新网络（使用自定义子网避免冲突）
echo "🌐 创建新的 insight-net 网络..."
if docker network ls | grep -q "insight-net"; then
    echo "✅ insight-net 网络已存在"
else
    # 尝试多个子网段
    SUBNETS=("172.20.0.0/16" "172.21.0.0/16" "172.22.0.0/16" "10.20.0.0/16")
    CREATED=false
    
    for SUBNET in "${SUBNETS[@]}"; do
        if docker network create --subnet="$SUBNET" insight-net 2>/dev/null; then
            echo "✅ 使用子网 $SUBNET 创建网络成功"
            CREATED=true
            break
        fi
    done
    
    if [ "$CREATED" = false ]; then
        echo "❌ 所有子网都不可用，尝试使用默认配置..."
        if docker network create insight-net; then
            echo "✅ 使用默认配置创建网络成功"
        else
            echo "❌ 网络创建失败，请手动检查 Docker 网络配置"
            echo "   建议运行: docker network ls 查看现有网络"
            exit 1
        fi
    fi
fi

echo ""
echo "✅ Docker 网络修复完成！"
echo "📋 当前网络列表："
docker network ls | grep -E "NETWORK|insight"
