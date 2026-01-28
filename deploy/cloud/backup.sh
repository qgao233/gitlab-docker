#!/bin/bash
set -e

# 加载环境变量
if [ -f ".env" ]; then
    source .env
fi

# ============ 配置 ============
OSS_BUCKET="${OSS_BUCKET:-oss://your-bucket-name/gitlab-backups}"
GITLAB_DIR="$(pwd)"
LOG_FILE="/var/log/gitlab-backup.log"

# ============ 日志函数 ============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# ============ 主流程 ============
log "========== 开始 GitLab 备份 =========="

# 1. 创建 GitLab 备份
log "创建 GitLab 备份..."
docker exec gitlab gitlab-backup create CRON=1
if [ $? -eq 0 ]; then
    log "GitLab 备份创建成功"
else
    log "[错误] GitLab 备份创建失败"
    exit 1
fi

# 2. 同步备份文件到 OSS
log "同步备份文件到 OSS..."
ossutil sync ${GITLAB_DIR}/gitlab/data/backups/ ${OSS_BUCKET}/backups/ --update
if [ $? -eq 0 ]; then
    log "备份文件同步成功"
else
    log "[错误] 备份文件同步失败"
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
find ${GITLAB_DIR}/gitlab/data/backups -name "*.tar" -mtime +30 -delete 2>/dev/null || true

log "========== 备份完成 =========="
