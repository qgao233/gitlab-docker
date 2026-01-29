# GitLab 恢复脚本 (Windows PowerShell)
#
# 【功能】
#   - 从备份文件恢复 GitLab 数据
#   - 支持从 OSS 下载备份（可选）
#   - 自动修复容器内权限
#
# 【使用方法】
#   .\restore.ps1 <备份文件名>
#   .\restore.ps1 -FromOss <备份文件名>    # 从 OSS 下载
#   .\restore.ps1 -ListOss                  # 列出 OSS 上的备份
#
# 【示例】
#   .\restore.ps1 1769650886_2026_01_29_15.11.13_gitlab_backup.tar
#   .\restore.ps1 -FromOss 1769650886_2026_01_29_15.11.13_gitlab_backup.tar

param(
    [Parameter(Position=0)]
    [string]$BackupFile,
    [switch]$FromOss,
    [switch]$ListOss
)

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

# OSS 配置
$OssutilPath = [Environment]::GetEnvironmentVariable("OSSUTIL_PATH", "Process")
$OssBucket = [Environment]::GetEnvironmentVariable("OSS_BUCKET", "Process")
$OssEnabled = $false
if ($OssutilPath -and $OssBucket -and (Test-Path $OssutilPath)) {
    $OssEnabled = $true
}

$BackupDir = "$ScriptDir\gitlab\data\backups"
$ConfigDir = "$ScriptDir\gitlab\config"

Write-Host "========================================"
Write-Host "  GitLab 数据恢复脚本"
Write-Host "========================================"
Write-Host ""

# 列出 OSS 备份
if ($ListOss) {
    if (-not $OssEnabled) {
        Write-Host "[错误] OSS 未配置或 ossutil 路径无效" -ForegroundColor Red
        Write-Host "请检查 .env 文件中的 OSSUTIL_PATH 和 OSS_BUCKET"
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    Write-Host "OSS 上的备份文件："
    & $OssutilPath ls "$OssBucket/backups/" | Select-String "_gitlab_backup.tar"
    Write-Host ""
    Read-Host "按 Enter 键退出"
    exit 0
}

# 检查参数
if ([string]::IsNullOrEmpty($BackupFile)) {
    Write-Host "用法: .\restore.ps1 <备份文件名>" -ForegroundColor Yellow
    Write-Host "      .\restore.ps1 -FromOss <备份文件名>    # 从 OSS 下载"
    Write-Host "      .\restore.ps1 -ListOss                  # 列出 OSS 备份"
    Write-Host ""
    Write-Host "本地备份文件："
    
    if (Test-Path $BackupDir) {
        $backups = Get-ChildItem -Path $BackupDir -Filter "*_gitlab_backup.tar" | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt 0) {
            foreach ($backup in $backups) {
                Write-Host "  - $($backup.Name)"
            }
        } else {
            Write-Host "  (无备份文件)"
        }
    } else {
        Write-Host "  (备份目录不存在)"
    }
    
    if ($OssEnabled) {
        Write-Host ""
        Write-Host "提示: 使用 -ListOss 查看 OSS 上的备份"
    }
    
    Write-Host ""
    Write-Host "示例："
    Write-Host "  .\restore.ps1 1769650886_2026_01_29_15.11.13_gitlab_backup.tar"
    Write-Host ""
    Read-Host "按 Enter 键退出"
    exit 0
}

# 提取备份 ID（移除 _gitlab_backup.tar 后缀）
$BackupName = $BackupFile -replace "_gitlab_backup\.tar$", ""
$BackupPath = "$BackupDir\$BackupFile"

# 从 OSS 下载备份
if ($FromOss) {
    if (-not $OssEnabled) {
        Write-Host "[错误] OSS 未配置或 ossutil 路径无效" -ForegroundColor Red
        Write-Host "请检查 .env 文件中的 OSSUTIL_PATH 和 OSS_BUCKET"
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    Write-Host "[准备] 从 OSS 下载备份..." -ForegroundColor Yellow
    
    # 确保备份目录存在
    if (!(Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    # 下载备份文件（从 OSS_BUCKET/backups/ 下载）
    Write-Host "  下载数据备份: $BackupFile"
    & $OssutilPath cp "$OssBucket/backups/$BackupFile" "$BackupPath"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 下载备份文件失败" -ForegroundColor Red
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    # 下载配置文件
    Write-Host "  下载配置文件..."
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    & $OssutilPath sync "$OssBucket/config/" "$ConfigDir\" --update
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  配置文件下载成功"
    } else {
        Write-Host "[警告] 配置文件下载失败，将使用本地配置" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# 检查备份文件是否存在
if (!(Test-Path $BackupPath)) {
    Write-Host "[错误] 备份文件不存在: $BackupPath" -ForegroundColor Red
    if ($OssEnabled -and -not $FromOss) {
        Write-Host "提示: 使用 -FromOss 参数从 OSS 下载备份"
    }
    Read-Host "按 Enter 键退出"
    exit 1
}

Write-Host "备份文件: $BackupFile"
Write-Host "备份 ID: $BackupName"
Write-Host ""

# 确认操作
Write-Host "警告: 此操作将覆盖现有数据！" -ForegroundColor Yellow
$confirm = Read-Host "确定要继续吗？输入 'YES' 确认"
if ($confirm -ne "YES") {
    Write-Host "操作已取消"
    exit 0
}

Write-Host ""

# 步骤 1: 检查配置文件
Write-Host "[1/7] 检查配置文件..." -ForegroundColor Yellow
$secretsFile = "$ConfigDir\gitlab-secrets.json"

if (!(Test-Path $secretsFile)) {
    Write-Host "[警告] gitlab-secrets.json 不存在" -ForegroundColor Yellow
    Write-Host "如果有配置备份，请先恢复配置文件到 gitlab\config\ 目录"
    
    $configBackupDir = "$ScriptDir\config-backup"
    if (Test-Path $configBackupDir) {
        $restoreConfig = Read-Host "检测到本地配置备份，是否恢复？[y/N]"
        if ($restoreConfig -eq "y" -or $restoreConfig -eq "Y") {
            if (!(Test-Path $ConfigDir)) {
                New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
            }
            Copy-Item -Path "$configBackupDir\*" -Destination $ConfigDir -Recurse -Force
            Write-Host "配置文件已恢复"
        }
    } elseif ($OssEnabled) {
        $restoreFromOss = Read-Host "是否从 OSS 下载配置文件？[y/N]"
        if ($restoreFromOss -eq "y" -or $restoreFromOss -eq "Y") {
            if (!(Test-Path $ConfigDir)) {
                New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
            }
            & $OssutilPath sync "$OssBucket/config/" "$ConfigDir\" --update
            Write-Host "配置文件已从 OSS 下载"
        }
    }
} else {
    Write-Host "  gitlab-secrets.json 已存在"
}

# 步骤 2: 启动 GitLab
Write-Host "[2/7] 启动 GitLab..." -ForegroundColor Yellow
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 启动失败" -ForegroundColor Red
    Read-Host "按 Enter 键退出"
    exit 1
}

# 步骤 3: 等待启动
Write-Host "[3/7] 等待 GitLab 启动（约需 3-5 分钟）..." -ForegroundColor Yellow
Write-Host "  可以在另一个终端查看日志: docker-compose logs -f gitlab"

# 等待并检查健康状态
$maxWait = 300  # 最多等待 5 分钟
$waited = 0
$interval = 15

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds $interval
    $waited += $interval
    
    $health = docker exec gitlab gitlab-ctl status 2>$null
    if ($health -match "run: puma") {
        Write-Host "  GitLab 已启动 (等待了 $waited 秒)"
        break
    }
    Write-Host "  等待中... ($waited 秒)"
}

# 步骤 4: 停止相关服务
Write-Host "[4/7] 停止相关服务..." -ForegroundColor Yellow
docker exec gitlab gitlab-ctl stop puma
docker exec gitlab gitlab-ctl stop sidekiq
Start-Sleep -Seconds 10

# 步骤 5: 恢复数据
Write-Host "[5/7] 恢复数据..." -ForegroundColor Yellow
Write-Host "  备份 ID: $BackupName"

docker exec gitlab gitlab-backup restore BACKUP=$BackupName force=yes

if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 恢复失败" -ForegroundColor Red
    Write-Host "请检查备份文件是否完整"
    Read-Host "按 Enter 键退出"
    exit 1
}

# 步骤 6: 修复容器内权限
Write-Host "[6/7] 修复容器内权限..." -ForegroundColor Yellow
docker exec gitlab chmod 600 /etc/gitlab/ssh_host_ed25519_key 2>$null
docker exec gitlab chmod 600 /etc/gitlab/ssh_host_ecdsa_key 2>$null
docker exec gitlab chmod 600 /etc/gitlab/ssh_host_rsa_key 2>$null
docker exec gitlab chmod 644 /etc/gitlab/ssh_host_ed25519_key.pub 2>$null
docker exec gitlab chmod 644 /etc/gitlab/ssh_host_ecdsa_key.pub 2>$null
docker exec gitlab chmod 644 /etc/gitlab/ssh_host_rsa_key.pub 2>$null
Write-Host "  SSH 密钥权限已修复"

# 步骤 7: 重新配置并重启
Write-Host "[7/7] 重新配置并重启..." -ForegroundColor Yellow
docker exec gitlab gitlab-ctl reconfigure
docker-compose restart

Write-Host ""
Write-Host "========================================"
Write-Host "  恢复完成！" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "验证恢复结果："
Write-Host "  docker exec gitlab gitlab-rake gitlab:check SANITIZE=true"
Write-Host ""
Write-Host "如果出现加密错误，运行："
Write-Host "  docker exec gitlab gitlab-rake gitlab:doctor:secrets"
Write-Host ""

Read-Host "按 Enter 键退出"
