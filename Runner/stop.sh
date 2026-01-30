#!/bin/sh
# GitLab Runner 停止脚本 (Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "停止 GitLab Runner..."
docker-compose down

echo "Runner 已停止"
