# GitLab 本地部署停止脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  停止 GitLab 服务" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 停止所有可能的配置
Write-Host "正在停止服务..." -ForegroundColor Yellow

docker-compose down 2>&1 | Out-Null
docker-compose -f docker-compose.separated.yml down 2>&1 | Out-Null

Write-Host ""
Write-Host "GitLab 服务已停止" -ForegroundColor Green

Read-Host "按 Enter 键退出"
