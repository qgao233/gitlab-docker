# GitLab Runner 注册脚本 (Windows PowerShell)
#
# 【功能】
#   - 注册 GitLab Runner 到 GitLab 服务器
#
# 【使用方法】
#   .\register.ps1

$ErrorActionPreference = "Stop"

# 获取脚本目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 加载环境变量
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*"?([^"]*)"?\s*$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
} else {
    Write-Host "[错误] 未找到 .env 文件" -ForegroundColor Red
    Write-Host "请先执行: cp .env.example .env 并配置"
    Read-Host "按 Enter 键退出"
    exit 1
}

# 读取配置
$GitLabUrl = [Environment]::GetEnvironmentVariable("GITLAB_URL", "Process")
$RegistrationToken = [Environment]::GetEnvironmentVariable("REGISTRATION_TOKEN", "Process")
$RunnerName = [Environment]::GetEnvironmentVariable("RUNNER_NAME", "Process")
$RunnerTags = [Environment]::GetEnvironmentVariable("RUNNER_TAGS", "Process")
$RunnerExecutor = [Environment]::GetEnvironmentVariable("RUNNER_EXECUTOR", "Process")
$DockerImage = [Environment]::GetEnvironmentVariable("DOCKER_IMAGE", "Process")

# 设置默认值
if (-not $RunnerName) { $RunnerName = "docker-runner" }
if (-not $RunnerTags) { $RunnerTags = "docker,linux" }
if (-not $RunnerExecutor) { $RunnerExecutor = "docker" }
if (-not $DockerImage) { $DockerImage = "docker.1ms.run/library/alpine:latest" }

Write-Host "========================================"
Write-Host "  GitLab Runner 注册"
Write-Host "========================================"
Write-Host ""
Write-Host "GitLab URL: $GitLabUrl"
Write-Host "Runner 名称: $RunnerName"
Write-Host "Runner 标签: $RunnerTags"
Write-Host "执行器类型: $RunnerExecutor"
if ($RunnerExecutor -eq "docker") {
    Write-Host "默认镜像: $DockerImage"
}
Write-Host ""

# 检查必需配置
if (-not $GitLabUrl -or -not $RegistrationToken) {
    Write-Host "[错误] 请在 .env 中配置 GITLAB_URL 和 REGISTRATION_TOKEN" -ForegroundColor Red
    Read-Host "按 Enter 键退出"
    exit 1
}

# 检查容器是否运行
$containerRunning = docker ps --filter "name=gitlab-runner" --format "{{.Names}}" 2>$null
if ($containerRunning -ne "gitlab-runner") {
    Write-Host "Runner 容器未运行，正在启动..."
    docker-compose up -d
    Start-Sleep -Seconds 5
}

# 注册 Runner
Write-Host "正在注册 Runner..."

if ($RunnerExecutor -eq "docker") {
    docker exec gitlab-runner gitlab-runner register `
        --non-interactive `
        --url "$GitLabUrl" `
        --registration-token "$RegistrationToken" `
        --name "$RunnerName" `
        --tag-list "$RunnerTags" `
        --executor "$RunnerExecutor" `
        --docker-image "$DockerImage" `
        --docker-privileged `
        --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"
} else {
    docker exec gitlab-runner gitlab-runner register `
        --non-interactive `
        --url "$GitLabUrl" `
        --registration-token "$RegistrationToken" `
        --name "$RunnerName" `
        --tag-list "$RunnerTags" `
        --executor "$RunnerExecutor"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  注册成功！" -ForegroundColor Green
    Write-Host "========================================"
    Write-Host ""
    Write-Host "查看 Runner 状态："
    Write-Host "  docker exec gitlab-runner gitlab-runner list"
    Write-Host ""
    Write-Host "在 GitLab 中查看："
    Write-Host "  Admin -> CI/CD -> Runners"
} else {
    Write-Host ""
    Write-Host "[错误] 注册失败" -ForegroundColor Red
    Write-Host "请检查："
    Write-Host "  1. GitLab URL 是否正确且可访问"
    Write-Host "  2. Registration Token 是否正确"
    Write-Host "  3. 网络连接是否正常"
}

Write-Host ""
Read-Host "按 Enter 键退出"
