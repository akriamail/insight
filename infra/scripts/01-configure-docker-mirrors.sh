#!/bin/bash

# 配置 Docker 镜像源
configure_docker_mirrors() {
    echo -e "${YELLOW}🌐 正在配置 Docker 镜像源...${NC}"

    # 加载 .env 文件中的环境变量
    # 这里的 PROJECT_ROOT 需要在脚本被 source 的环境中定义
    # 或者我们可以重新计算它，但由于这里会被manage.sh和00-bootstrap.sh source，
    # 所以 PROJECT_ROOT 会在它们内部定义并传递过来
    # 为了本脚本独立运行时的健壮性，这里也重新定义
    local CURRENT_SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
    local PROJECT_ROOT=$(cd "$CURRENT_SCRIPT_DIR/../.."; pwd) # 从 infra/scripts 到 project root
    local ENV_FILE_PATH="$PROJECT_ROOT/.env"
    local ENV_EXAMPLE_FILE_PATH="$PROJECT_ROOT/.env.example"

    if [ -f "$ENV_FILE_PATH" ]; then
        set -a
        source "$ENV_FILE_PATH"
        set +a
    elif [ -f "$ENV_EXAMPLE_FILE_PATH" ]; then
        cp "$ENV_EXAMPLE_FILE_PATH" "$ENV_FILE_PATH"
        set -a
        source "$ENV_FILE_PATH"
        set +a
    else
        echo -e "${RED}❌ 错误：未找到 .env 或 .env.example 文件，无法配置 Docker 镜像源！${NC}"
        return 1
    fi

    DOCKER_CONFIG_FILE="/etc/docker/daemon.json"
    EXCLUSIVE_MIRROR="https://0b2a66d0e26e387f101ab5b89e160772.d.1ms.run" # 用户提供的专属镜像

    if [ "$USE_DOCKER_MIRRORS" = "true" ]; then
        echo -e "${GREEN}✅ 启用 Docker 镜像加速器: $EXCLUSIVE_MIRROR${NC}"
        if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
            echo "{}" | sudo tee "$DOCKER_CONFIG_FILE" > /dev/null
        fi
        TEMP_JSON=$(mktemp)
        sudo cat "$DOCKER_CONFIG_FILE" | jq --arg mirror "$EXCLUSIVE_MIRROR" \
            '. + { "registry-mirrors": [ $mirror ] }' > "$TEMP_JSON" \
            || { echo -e "${RED}❌ 更新 daemon.json 失败！请检查 jq 是否安装或 JSON 格式。${NC}"; rm -f "$TEMP_JSON"; return 1; }
        sudo mv "$TEMP_JSON" "$DOCKER_CONFIG_FILE"
        echo -e "${YELLOW}🔄 正在重启 Docker 服务以应用更改...${NC}"
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        echo -e "${GREEN}✨ Docker 镜像源配置完成！${NC}"
    else
        echo -e "${YELLOW}❌ 禁用 Docker 镜像加速器。${NC}"
        if [ -f "$DOCKER_CONFIG_FILE" ]; then
            TEMP_JSON=$(mktemp)
            sudo cat "$DOCKER_CONFIG_FILE" | jq 'del(."registry-mirrors")' > "$TEMP_JSON" \
                || { echo -e "${RED}❌ 更新 daemon.json 失败！请检查 jq 是否安装或 JSON 格式。${NC}"; rm -f "$TEMP_JSON"; return 1; }
            sudo mv "$TEMP_JSON" "$DOCKER_CONFIG_FILE"
            echo -e "${YELLOW}🔄 正在重启 Docker 服务以应用更改...${NC}"
            sudo systemctl daemon-reload
            sudo systemctl restart docker
            echo -e "${GREEN}✨ Docker 镜像源已禁用。${NC}"
        else
            echo -e "${YELLOW}提示：daemon.json 文件不存在，无需禁用。${NC}"
        fi
    fi
}
