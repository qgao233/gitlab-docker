#!/bin/sh
# GitLab Runner 启动脚本 (Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  启动 GitLab Runner"
echo "========================================"
echo ""

# 创建配置目录
if [ ! -d "config" ]; then
    mkdir -p config
    echo "已创建 config 目录"
fi

# 启动容器
echo "启动 Runner 容器..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "Runner 已启动！"
    echo ""
    echo "下一步："
    echo "  1. 配置 .env 文件（如未配置）"
    echo "  2. 运行 ./register.sh 注册 Runner"
    echo ""
    echo "查看日志："
    echo "  docker-compose logs -f gitlab-runner"
else
    echo "[错误] 启动失败"
fi
