#!/bin/bash
set -e

# 加载环境变量
if [ -f ".env" ]; then
    source .env
fi

# ============ 配置 ============
OSS_BUCKET="${OSS_BUCKET:-oss://your-bucket-name/gitlab-backups}"
GITLAB_DIR="$(pwd)"

echo "========================================"
echo "  GitLab 数据恢复脚本"
echo "========================================"
echo

# 检查参数
if [ -z "$1" ]; then
    echo "用法: $0 <备份文件名>"
    echo
    echo "查看可用备份:"
    echo "  ossutil ls ${OSS_BUCKET}/backups/"
    echo
    echo "示例:"
    echo "  $0 1234567890_2024_01_01_16.0.0_gitlab_backup.tar"
    exit 1
fi

BACKUP_FILE=$1
BACKUP_NAME=${BACKUP_FILE%.tar}  # 移除 .tar 后缀

echo "[1/6] 从 OSS 下载配置文件..."
mkdir -p ${GITLAB_DIR}/gitlab/config
ossutil cp -r ${OSS_BUCKET}/config/ ${GITLAB_DIR}/gitlab/config/

echo "[2/6] 从 OSS 下载备份文件..."
mkdir -p ${GITLAB_DIR}/gitlab/data/backups
ossutil cp ${OSS_BUCKET}/backups/${BACKUP_FILE} ${GITLAB_DIR}/gitlab/data/backups/

echo "[3/6] 启动 GitLab..."
docker-compose up -d

echo "[4/6] 等待 GitLab 启动（约需 3-5 分钟）..."
sleep 180

echo "[5/6] 停止相关服务..."
docker exec gitlab gitlab-ctl stop puma
docker exec gitlab gitlab-ctl stop sidekiq
sleep 10

echo "[6/6] 恢复数据..."
docker exec gitlab gitlab-backup restore BACKUP=${BACKUP_NAME} force=yes

echo
echo "重启 GitLab..."
docker-compose restart

echo
echo "========================================"
echo "  恢复完成！"
echo "========================================"
echo
echo "验证恢复结果："
echo "  docker exec gitlab gitlab-rake gitlab:check SANITIZE=true"
echo
