#!/bin/bash
# GitLab 数据库重置脚本
# 用于清理内置 Redis 数据，重新初始化 GitLab
# 
# 【警告】此操作会删除以下数据：
#   - 内置 Redis 缓存
#   - GitLab Rails 缓存
# 
# 【保留】
#   - PostgreSQL 数据（存储在阿里云 RDS，不受影响）
#   - Git 仓库数据（gitlab/data/git-data/）
#
# 【使用场景】
#   - Redis 缓存损坏需要重置
#   - GitLab 配置变更后需要清理缓存

set -e

echo "========================================"
echo "  GitLab 缓存重置脚本"
echo "========================================"
echo ""
echo "此操作将删除以下数据："
echo "  - 内置 Redis 缓存"
echo "  - GitLab Rails 缓存"
echo ""
echo "以下数据会保留："
echo "  - PostgreSQL 数据（阿里云 RDS）"
echo "  - Git 仓库数据（git-data）"
echo ""

read -p "确定要继续吗？输入 'YES' 确认: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
    echo ""
    echo "操作已取消"
    exit 0
fi

echo ""
echo "[1/4] 停止 GitLab 容器..."
docker-compose down

echo ""
echo "[2/4] 删除缓存目录..."

DATA_PATH="./gitlab/data"

# 删除 Redis 数据
if [[ -d "$DATA_PATH/redis" ]]; then
    rm -rf "$DATA_PATH/redis"
    echo "  - 已删除 redis/"
fi

# 删除 GitLab Rails 缓存
if [[ -d "$DATA_PATH/gitlab-rails" ]]; then
    rm -rf "$DATA_PATH/gitlab-rails"
    echo "  - 已删除 gitlab-rails/"
fi

echo ""
echo "[3/4] 启动 GitLab 容器..."
docker-compose up -d

echo ""
echo "[4/4] 等待 GitLab 初始化（约需 3-5 分钟）..."
echo ""
echo "查看启动日志："
echo "  docker-compose logs -f gitlab"
echo ""
echo "检查服务状态："
echo "  docker exec gitlab gitlab-ctl status"
echo ""
echo "========================================"
echo "  重置完成！"
echo "========================================"
