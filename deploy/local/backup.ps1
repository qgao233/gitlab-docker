# GitLab 备份脚本 (Windows PowerShell)
#
# 【功能】
#   - 创建 GitLab 备份
#   - 备份配置文件
#   - 上传到阿里云 OSS（可选，需配置 .env）
#
# 【使用方法】
#   .\backup.ps1

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
}

# 配置
$GitLabDir = $ScriptDir
$BackupDir = "$GitLabDir\gitlab\data\backups"
$ConfigDir = "$GitLabDir\gitlab\config"
$LogFile = "$GitLabDir\backup.log"

# OSS 配置（从环境变量读取）
$OssutilPath = [Environment]::GetEnvironmentVariable("OSSUTIL_PATH", "Process")
$OssBucket = [Environment]::GetEnvironmentVariable("OSS_BUCKET", "Process")

# 检查 OSS 是否配置
$OssEnabled = $false
if ($OssutilPath -and $OssBucket) {
    if (Test-Path $OssutilPath) {
        $OssEnabled = $true
    } else {
        Write-Host "[警告] ossutil 路径无效: $OssutilPath" -ForegroundColor Yellow
    }
}

# 日志函数
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Host "========================================"
Write-Host "  GitLab 备份脚本"
Write-Host "========================================"
Write-Host ""
Write-Host "OSS 上传: $(if ($OssEnabled) { '已启用' } else { '未启用（仅本地备份）' })"
Write-Host ""

# 检查容器是否运行
$containerRunning = docker ps --filter "name=gitlab" --format "{{.Names}}" 2>$null
if ($containerRunning -ne "gitlab") {
    Write-Host "[错误] GitLab 容器未运行" -ForegroundColor Red
    Write-Host "请先启动容器: .\start.ps1"
    Read-Host "按 Enter 键退出"
    exit 1
}

# 记录备份前的文件
$beforeFiles = @()
if (Test-Path $BackupDir) {
    $beforeFiles = Get-ChildItem -Path $BackupDir -Filter "*.tar" | Select-Object -ExpandProperty Name
}

Write-Log "========== 开始 GitLab 备份 =========="

# 1. 创建 GitLab 备份
Write-Log "创建 GitLab 备份..."
docker exec -e TZ=Asia/Shanghai gitlab gitlab-backup create CRON=1

if ($LASTEXITCODE -eq 0) {
    Write-Log "GitLab 备份创建成功"
} else {
    Write-Log "[错误] GitLab 备份创建失败"
    Read-Host "按 Enter 键退出"
    exit 1
}

# 找出新生成的备份文件
$afterFiles = @()
if (Test-Path $BackupDir) {
    $afterFiles = Get-ChildItem -Path $BackupDir -Filter "*.tar" | Select-Object -ExpandProperty Name
}

$newBackup = $afterFiles | Where-Object { $_ -notin $beforeFiles } | Select-Object -First 1

if ($newBackup) {
    Write-Log "新备份文件: $newBackup"
} else {
    Write-Log "[警告] 未找到新生成的备份文件"
}

# 2. 备份配置文件（本地复制）
Write-Log "备份配置文件..."
$configBackupDir = "$GitLabDir\config-backup"
if (!(Test-Path $configBackupDir)) {
    New-Item -ItemType Directory -Path $configBackupDir | Out-Null
}
Copy-Item -Path "$ConfigDir\*" -Destination $configBackupDir -Recurse -Force
Write-Log "配置文件已备份到: $configBackupDir"

# 3. 上传到 OSS（如果已配置）
if ($OssEnabled -and $newBackup) {
    Write-Log "上传备份到 OSS..."
    
    # 上传数据备份到 OSS_BUCKET/backups/
    $backupFilePath = "$BackupDir\$newBackup"
    Write-Log "上传数据备份: $newBackup"
    & $OssutilPath cp "$backupFilePath" "$OssBucket/backups/" --update
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "数据备份上传成功"
    } else {
        Write-Log "[警告] 数据备份上传失败"
    }
    
    # 上传配置文件到 OSS_BUCKET/config/
    Write-Log "上传配置文件..."
    & $OssutilPath sync "$ConfigDir\" "$OssBucket/config/" --update
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "配置文件上传成功"
    } else {
        Write-Log "[警告] 配置文件上传失败"
    }
} elseif (-not $OssEnabled) {
    Write-Log "OSS 未配置，跳过云端备份"
}

Write-Log "========== 备份完成 =========="

Write-Host ""
Write-Host "========================================"
Write-Host "  备份完成！" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "备份文件位置："
Write-Host "  - 数据备份: $BackupDir\$newBackup"
Write-Host "  - 配置备份: $configBackupDir"
if ($OssEnabled) {
    Write-Host "  - OSS 位置: $OssBucket/backups/"
}
Write-Host ""
Write-Host "查看备份日志: $LogFile"
Write-Host ""

Read-Host "按 Enter 键退出"
