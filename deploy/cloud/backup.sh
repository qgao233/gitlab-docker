#!/bin/sh
set -e

# 加载 PATH（cron 环境可能没有）
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# 设置时区为 UTC+8
export TZ='Asia/Shanghai'

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
BACKUP_DIR="${GITLAB_DIR}/gitlab/data/backups"
LOG_FILE="/var/log/gitlab-backup.log"

# ============ 日志函数 ============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# ============ 主流程 ============
log "========== 开始 GitLab 备份 =========="

# 记录备份前的文件列表
BEFORE_FILES=$(ls -1 ${BACKUP_DIR}/*.tar 2>/dev/null || true)

# 1. 创建 GitLab 备份
log "创建 GitLab 备份..."
docker exec -e TZ=Asia/Shanghai gitlab gitlab-backup create CRON=1
if [ $? -eq 0 ]; then
    log "GitLab 备份创建成功"
else
    log "[错误] GitLab 备份创建失败"
    exit 1
fi

# 找出新生成的备份文件
AFTER_FILES=$(ls -1 ${BACKUP_DIR}/*.tar 2>/dev/null || true)
NEW_BACKUP=""
for file in $AFTER_FILES; do
    if ! echo "$BEFORE_FILES" | grep -q "$(basename $file)"; then
        NEW_BACKUP="$file"
        break
    fi
done

if [ -z "$NEW_BACKUP" ]; then
    log "[错误] 未找到新生成的备份文件"
    exit 1
fi

NEW_BACKUP_NAME=$(basename "$NEW_BACKUP")
log "新备份文件: $NEW_BACKUP_NAME"

# 2. 上传新备份文件到 OSS（只上传本次生成的文件）
log "上传备份文件到 OSS..."
ossutil cp "${NEW_BACKUP}" "${OSS_BUCKET}/backups/${NEW_BACKUP_NAME}"
if [ $? -eq 0 ]; then
    log "备份文件上传成功"
else
    log "[错误] 备份文件上传失败"
    exit 1
fi

# 3. 同步配置文件到 OSS（重要！包含 secrets）
log "同步配置文件到 OSS..."
ossutil sync ${GITLAB_DIR}/gitlab/config/ ${OSS_BUCKET}/config/ --update
if [ $? -eq 0 ]; then
    log "配置文件同步成功"
else
    log "[错误] 配置文件同步失败"
    exit 1
fi

# 4. 清理 30 天前的本地备份
log "清理旧备份..."
find ${BACKUP_DIR} -name "*.tar" -mtime +30 -delete 2>/dev/null || true

log "========== 备份完成 =========="
