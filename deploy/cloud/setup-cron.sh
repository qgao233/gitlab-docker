#!/bin/sh
# 配置 GitLab 定时备份任务
#
# 【功能】
#   - 添加每天凌晨 3 点自动备份的 cron 任务
#   - 备份会同步到阿里云 OSS
#
# 【使用方法】
#   sh setup-cron.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
LOG_FILE="/var/log/gitlab-backup.log"

echo "========================================"
echo "  配置 GitLab 定时备份"
echo "========================================"
echo ""

# 检查 backup.sh 是否存在
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "[错误] 备份脚本不存在: $BACKUP_SCRIPT"
    exit 1
fi

# 确保备份脚本有执行权限
chmod +x "$BACKUP_SCRIPT"

# 创建 cron 任务
# 测试模式：每分钟执行一次（测试完成后改回 "0 3 * * *" 每天凌晨3点）
# CRON_JOB="* * * * * cd $SCRIPT_DIR && sh ./backup.sh >> $LOG_FILE 2>&1"
CRON_JOB="0 3 * * * cd $SCRIPT_DIR && sh ./backup.sh >> $LOG_FILE 2>&1"

# 检查是否已存在相同的 cron 任务
if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    echo "[提示] 定时任务已存在，是否要更新？"
    printf "输入 'YES' 确认更新: "
    read CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "操作已取消"
        exit 0
    fi
    # 删除旧的任务
    crontab -l 2>/dev/null | grep -v "backup.sh" | crontab -
fi

# 添加新的 cron 任务
(crontab -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -

echo ""
echo "[成功] 定时备份已配置"
echo ""
echo "当前 cron 任务："
crontab -l 2>/dev/null | grep "backup.sh" || echo "  (无)"
echo ""
echo "备份计划："
echo "  - 脚本: $BACKUP_SCRIPT"
echo "  - 日志: $LOG_FILE"
echo ""
echo "查看日志: tail -f $LOG_FILE"
echo "========================================"
