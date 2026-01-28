# GitLab 数据库重置脚本
# 用于清理 PostgreSQL 和 Redis 数据，重新初始化 GitLab
# 
# 【警告】此操作会删除以下数据：
#   - PostgreSQL 数据库（用户、项目配置等）
#   - Redis 缓存
#   - GitLab Rails 缓存
# 
# 【保留】Git 仓库数据（gitlab/data/git-data/）会保留
#
# 【使用场景】
#   - 切换集成模式/分离模式后需要重新初始化
#   - 数据库配置错误需要重置
#   - 数据库损坏需要重建

Write-Host "========================================" -ForegroundColor Red
Write-Host "  GitLab 数据库重置脚本" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "此操作将删除以下数据：" -ForegroundColor Yellow
Write-Host "  - PostgreSQL 数据库" -ForegroundColor Yellow
Write-Host "  - Redis 缓存" -ForegroundColor Yellow
Write-Host "  - GitLab Rails 缓存" -ForegroundColor Yellow
Write-Host ""
Write-Host "Git 仓库数据（git-data）会保留" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "确定要继续吗？输入 'YES' 确认"

if ($confirm -ne "YES") {
    Write-Host ""
    Write-Host "操作已取消" -ForegroundColor Cyan
    exit 0
}

Write-Host ""
Write-Host "[1/4] 停止 GitLab 容器..." -ForegroundColor Yellow
docker-compose down

if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 停止容器失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/4] 删除数据库相关目录..." -ForegroundColor Yellow

$dataPath = "..\..\gitlab\data"

# 删除 PostgreSQL 数据
if (Test-Path "$dataPath\postgresql") {
    Remove-Item -Recurse -Force "$dataPath\postgresql"
    Write-Host "  - 已删除 postgresql/" -ForegroundColor Gray
}

# 删除 Redis 数据
if (Test-Path "$dataPath\redis") {
    Remove-Item -Recurse -Force "$dataPath\redis"
    Write-Host "  - 已删除 redis/" -ForegroundColor Gray
}

# 删除 GitLab Rails 缓存
if (Test-Path "$dataPath\gitlab-rails") {
    Remove-Item -Recurse -Force "$dataPath\gitlab-rails"
    Write-Host "  - 已删除 gitlab-rails/" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[3/4] 启动 GitLab 容器..." -ForegroundColor Yellow
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 启动容器失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[4/4] 等待 GitLab 初始化（约需 3-5 分钟）..." -ForegroundColor Yellow
Write-Host ""
Write-Host "你可以在另一个终端中运行以下命令查看进度：" -ForegroundColor Gray
Write-Host "  docker-compose logs -f gitlab" -ForegroundColor Cyan
Write-Host ""
Write-Host "检查服务状态：" -ForegroundColor Gray
Write-Host "  docker exec gitlab gitlab-ctl status" -ForegroundColor Cyan
Write-Host ""
Write-Host "获取初始密码：" -ForegroundColor Gray
Write-Host "  docker exec gitlab cat /etc/gitlab/initial_root_password" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  重置完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "访问地址: http://localhost:9980" -ForegroundColor Cyan
Write-Host ""

Read-Host "按 Enter 键退出"
