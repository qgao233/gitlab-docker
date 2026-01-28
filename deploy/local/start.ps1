# GitLab 本地部署启动脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab 本地部署启动脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker 是否运行
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "[错误] Docker 未运行，请先启动 Docker Desktop" -ForegroundColor Red
    Read-Host "按 Enter 键退出"
    exit 1
}

# 创建数据目录
Write-Host "[1/3] 创建数据目录..." -ForegroundColor Yellow
$dirs = @("gitlab\config", "gitlab\logs", "gitlab\data")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# 选择部署模式
Write-Host ""
Write-Host "请选择部署模式：" -ForegroundColor White
Write-Host "  1. 集成模式（内置 PostgreSQL/Redis，推荐新手）"
Write-Host "  2. 分离模式（独立 PostgreSQL/Redis 容器）"
Write-Host ""
$mode = Read-Host "请输入选项 [1/2] (默认 1)"

if ($mode -eq "2") {
    Write-Host ""
    Write-Host "[2/3] 使用分离模式启动..." -ForegroundColor Yellow
    
    # 创建分离模式数据目录
    $separatedDirs = @("postgresql\data", "redis\data")
    foreach ($dir in $separatedDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    docker-compose -f docker-compose.separated.yml up -d
} else {
    Write-Host ""
    Write-Host "[2/3] 使用集成模式启动..." -ForegroundColor Yellow
    docker-compose up -d
}

Write-Host ""
Write-Host "[3/3] GitLab 正在启动（约需 3-5 分钟）..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  启动命令已执行" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  访问地址: " -NoNewline; Write-Host "http://localhost:9980" -ForegroundColor Cyan
Write-Host "  SSH 端口: " -NoNewline; Write-Host "9922" -ForegroundColor Cyan
Write-Host "  用户名: " -NoNewline; Write-Host "root" -ForegroundColor Cyan
Write-Host ""
Write-Host "  查看启动日志:"
Write-Host "  docker-compose logs -f gitlab" -ForegroundColor Gray
Write-Host ""
Write-Host "  获取初始密码:"
Write-Host "  docker exec gitlab cat /etc/gitlab/initial_root_password" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Green

Read-Host "按 Enter 键退出"
