#!/bin/sh
# 移除 GitLab 定时备份任务
#
# 【使用方法】
#   sh remove-cron.sh

echo "========================================"
echo "  移除 GitLab 定时备份"
echo "========================================"
echo ""

# 检查是否存在备份任务
if ! crontab -l 2>/dev/null | grep -q "backup.sh"; then
    echo "[提示] 未找到 GitLab 备份定时任务"
    exit 0
fi

# 显示当前任务
echo "当前备份任务："
crontab -l 2>/dev/null | grep "backup.sh"
echo ""

printf "确定要移除吗？[y/N]: "
read CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "操作已取消"
    exit 0
fi

# 移除备份任务
crontab -l 2>/dev/null | grep -v "backup.sh" | crontab -

echo ""
echo "[成功] 定时备份已移除"
echo ""
echo "如需重新启用，运行："
echo "  sh setup-cron.sh"
