# GitLab Runner 停止脚本 (Windows PowerShell)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "停止 GitLab Runner..."
docker-compose down

Write-Host "Runner 已停止"
Read-Host "按 Enter 键退出"
