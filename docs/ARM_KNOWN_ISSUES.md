# 📌 ARM 主机已知问题 & 快速排障清单（不影响 x86 基线）

本项目在 **x86_64** 环境下验证更充分；**ARM64**（如部分云厂商 ARM 主机）更容易遇到“环境/网络类”问题。该文档用于 **ARM 主机冒烟测试**与快速排障，不作为发布结论依据。

---

## ✅ 推荐测试策略（小团队省心版）

- **以 x86 为发布基线**：生产/开发环境稳定性主要看 x86。
- **ARM 只做冒烟**：确认脚本能跑通、容器能起、域名能访问、关键链路可用即可。
- **遇到 ARM 环境问题**：优先按本文排障，不要急着改业务脚本逻辑。

---

## 1) APT 更新 404（ARM64 常见）

### 现象
- `apt-get update` 出现类似：
  - `.../binary-arm64/Packages  404  Not Found`

### 原因
部分镜像源对 ARM64 支持不完整，或 ARM64 需要走 `ubuntu-ports` 源。

### 快速处理
- **优先使用官方 ports 源**（ARM64 通用）：
  - `http://ports.ubuntu.com/ubuntu-ports/`
- 若你在国内网络，选择 **明确支持 ARM64** 的镜像源再做测速/切换。

---

## 2) Docker 网络创建失败：address pools 用尽

### 现象
- 创建网络时报：
  - `Error response from daemon: all predefined address pools have been fully subnetted`
- 或 compose 报：
  - `network insight-net declared as external, but could not be found`

### 原因
Docker 默认地址池被大量历史网络耗尽/冲突，或 `insight-net` 没成功创建导致 external 网络找不到。

### 快速处理（安全优先）

1. **清理未使用网络**（不会删容器，但会删“未使用”的网络）：

```bash
docker network prune -f
```

2. **确认 `insight-net` 是否存在**：

```bash
docker network ls | grep insight-net
```

3. 若仍失败，建议 **删除并重建 `insight-net`**（会影响依赖该网络的容器，先停服务）：

```bash
docker compose -f /opt/insight/infra/compose/06-knowledge.yml down
docker compose -f /opt/insight/infra/compose/05-data-viz.yml down
docker compose -f /opt/insight/infra/compose/04-workflow.yml down
docker compose -f /opt/insight/infra/compose/01-gateway.yml down
docker compose -f /opt/insight/infra/compose/03-databases.yml down

docker network rm insight-net 2>/dev/null || true
docker network prune -f

# 选择一个你环境里不冲突的子网（示例）
docker network create --subnet=172.20.0.0/16 insight-net
```

---

## 3) 拉取 DockerHub 镜像失败（connection reset / timeout）

### 现象
- `failed to resolve reference ... read: connection reset by peer`
- `timeout` / `TLS handshake timeout`

### 原因
多数是 **网络出口/运营商/地区限制**，与业务脚本无关。

### 快速处理
- **保持镜像加速开启**（如果你的环境需要）。
- **先手动 pull 一遍镜像**，观察是否能成功：

```bash
docker pull postgres:16-alpine
docker pull jc21/nginx-proxy-manager:latest
docker pull n8nio/n8n:latest
docker pull nocodb/nocodb:latest
docker pull requarks/wiki:2
```

- 如果你们 x86 环境一直稳定：**把 ARM 当作网络条件差的测试机**即可，不建议为了 ARM 改变 x86 的生产默认策略。

---

## 4) ARM 上的“预期差异”（建议接受）

- **拉镜像速度**：ARM 镜像可能更慢、可用源更少。
- **生态与可用性**：某些第三方镜像/插件在 ARM 上支持度不如 x86。

---

## 5) 收集信息（排障时发给技术同学）

```bash
uname -a
dpkg --print-architecture
lsb_release -a || cat /etc/os-release
docker version
docker info | sed -n '1,80p'
docker network ls
docker ps -a
```

