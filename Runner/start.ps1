# GitLab Runner 启动脚本 (Windows PowerShell)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "========================================"
Write-Host "  启动 GitLab Runner"
Write-Host "========================================"
Write-Host ""

# 创建配置目录
if (!(Test-Path "config")) {
    New-Item -ItemType Directory -Path "config" | Out-Null
    Write-Host "已创建 config 目录"
}

# 启动容器
Write-Host "启动 Runner 容器..."
docker-compose up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Runner 已启动！" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步："
    Write-Host "  1. 配置 .env 文件（如未配置）"
    Write-Host "  2. 运行 .\register.ps1 注册 Runner"
    Write-Host ""
    Write-Host "查看日志："
    Write-Host "  docker-compose logs -f gitlab-runner"
} else {
    Write-Host "[错误] 启动失败" -ForegroundColor Red
}

Write-Host ""
Read-Host "按 Enter 键退出"
