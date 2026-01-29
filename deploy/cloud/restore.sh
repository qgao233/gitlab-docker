#!/bin/sh
set -e

# 加载 PATH
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    . "$SCRIPT_DIR/.env"
    set +a
else
    echo "[错误] 未找到 .env 文件"
    echo "请先执行: cp .env.example .env"
    exit 1
fi

# ============ 配置 ============
OSS_BUCKET="${OSS_BUCKET:-oss://your-bucket-name/gitlab-backups}"
GITLAB_DIR="$SCRIPT_DIR"

echo "========================================"
echo "  GitLab 数据恢复脚本"
echo "========================================"
echo

# 检查参数
if [ -z "$1" ]; then
    echo "用法: sh $0 <备份文件名>"
    echo
    echo "查看可用备份:"
    echo "  ossutil ls ${OSS_BUCKET}/backups/"
    echo
    echo "示例:"
    echo "  sh $0 1234567890_2024_01_01_15.11.13_gitlab_backup.tar"
    exit 1
fi

BACKUP_FILE=$1
# 从文件名提取备份 ID（移除 _gitlab_backup.tar 后缀）
# 例如：1769650886_2026_01_29_15.11.13_gitlab_backup.tar -> 1769650886_2026_01_29_15.11.13
BACKUP_NAME=${BACKUP_FILE%_gitlab_backup.tar}

echo "[1/8] 从 OSS 下载配置文件..."
mkdir -p ${GITLAB_DIR}/gitlab/config
ossutil cp -r ${OSS_BUCKET}/config/ ${GITLAB_DIR}/gitlab/config/

echo "[2/8] 修复配置文件权限..."
# 修复 secrets 文件权限（必须是 600）
if [ -f "${GITLAB_DIR}/gitlab/config/gitlab-secrets.json" ]; then
    chmod 600 ${GITLAB_DIR}/gitlab/config/gitlab-secrets.json
    echo "  - gitlab-secrets.json 权限已修复"
fi
# 修复 SSH 密钥权限
chmod 600 ${GITLAB_DIR}/gitlab/config/ssh_host_*_key 2>/dev/null || true
chmod 644 ${GITLAB_DIR}/gitlab/config/ssh_host_*_key.pub 2>/dev/null || true
echo "  - SSH 密钥权限已修复"

echo "[3/8] 从 OSS 下载备份文件..."
mkdir -p ${GITLAB_DIR}/gitlab/data/backups
ossutil cp ${OSS_BUCKET}/backups/${BACKUP_FILE} ${GITLAB_DIR}/gitlab/data/backups/

echo "[4/8] 启动 GitLab..."
docker-compose up -d

echo "[5/8] 等待 GitLab 启动（约需 3-5 分钟）..."
echo "  可以在另一个终端查看日志: docker-compose logs -f gitlab"
sleep 180

echo "[6/8] 停止相关服务..."
docker exec gitlab gitlab-ctl stop puma
docker exec gitlab gitlab-ctl stop sidekiq
sleep 10

echo "[7/8] 恢复数据..."
docker exec gitlab gitlab-backup restore BACKUP=${BACKUP_NAME} force=yes

echo "[8/8] 修复容器内权限并重启..."
# 修复容器内的 SSH 密钥权限
docker exec gitlab chmod 600 /etc/gitlab/ssh_host_*_key 2>/dev/null || true
docker exec gitlab chmod 644 /etc/gitlab/ssh_host_*_key.pub 2>/dev/null || true
# 重新配置并重启
docker exec gitlab gitlab-ctl reconfigure
docker-compose restart

echo
echo "========================================"
echo "  恢复完成！"
echo "========================================"
echo
echo "验证恢复结果："
echo "  docker exec gitlab gitlab-rake gitlab:check SANITIZE=true"
echo
echo "如果出现加密错误，运行："
echo "  docker exec gitlab gitlab-rake gitlab:doctor:secrets"
echo
