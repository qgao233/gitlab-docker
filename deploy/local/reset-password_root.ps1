# GitLab Root 用户密码重置脚本
#
# 【使用场景】
#   - 忘记 root 密码
#   - 数据库重置后需要设置新密码
#   - 初始密码文件已过期或丢失
#
# 【密码要求】
#   - 至少 8 个字符
#   - 不能包含常见词组合（如 password、gitlab、admin 等）
#   - 建议使用随机字符组合
#
# 【功能】
#   - 自动检测 root 用户是否存在
#   - 如不存在，自动运行种子数据创建用户
#   - 重置 root 用户密码

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitLab Root 密码重置脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查容器是否运行
$containerRunning = docker ps --filter "name=gitlab" --format "{{.Names}}" 2>$null
if ($containerRunning -ne "gitlab") {
    Write-Host "[错误] GitLab 容器未运行" -ForegroundColor Red
    Write-Host "请先启动容器: docker-compose up -d" -ForegroundColor Yellow
    Read-Host "按 Enter 键退出"
    exit 1
}

# 检查 root 用户是否存在
Write-Host "正在检查 root 用户..." -ForegroundColor Yellow
$checkUserScript = "user = User.find_by(username: 'root'); puts user ? 'EXISTS' : 'NOT_EXISTS'"
$userExists = docker exec gitlab gitlab-rails runner $checkUserScript 2>$null

if ($userExists -match "NOT_EXISTS") {
    Write-Host ""
    Write-Host "[提示] root 用户不存在，正在运行种子数据创建用户..." -ForegroundColor Yellow
    Write-Host "这可能需要 1-2 分钟，请耐心等待..." -ForegroundColor Gray
    Write-Host ""
    
    # 运行种子数据
    $seedOutput = docker exec gitlab gitlab-rake db:seed_fu RAILS_ENV=production 2>&1
    
    # 再次检查用户是否创建成功
    Start-Sleep -Seconds 5
    $userExists = docker exec gitlab gitlab-rails runner $checkUserScript 2>$null
    
    if ($userExists -match "NOT_EXISTS") {
        Write-Host "[错误] 种子数据执行后仍未创建 root 用户" -ForegroundColor Red
        Write-Host "请检查数据库连接和日志" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "查看日志命令: docker-compose logs gitlab" -ForegroundColor Gray
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    Write-Host "[成功] root 用户已创建" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "[成功] root 用户已存在" -ForegroundColor Green
    Write-Host ""
}

# 生成随机密码（12位：大小写字母+数字+特殊字符）
function Generate-RandomPassword {
    $length = 12
    $chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $specialChars = '#@$%&*!'
    
    # 生成基础密码
    $password = -join ((1..($length-1)) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    
    # 在随机位置插入一个特殊字符
    $specialChar = $specialChars[(Get-Random -Maximum $specialChars.Length)]
    $insertPos = Get-Random -Maximum $password.Length
    $password = $password.Insert($insertPos, $specialChar)
    
    return $password
}

# 生成默认密码
$defaultPassword = Generate-RandomPassword

# 提示密码要求
Write-Host "密码要求：" -ForegroundColor Yellow
Write-Host "  - 至少 8 个字符" -ForegroundColor Gray
Write-Host "  - 不能包含常见词（password、gitlab、admin 等）" -ForegroundColor Gray
Write-Host ""
Write-Host "默认密码: $defaultPassword （直接回车使用默认密码）" -ForegroundColor Cyan
Write-Host ""

# 输入新密码
$newPassword = Read-Host "请输入新密码（回车使用默认密码）"

# 如果为空，使用默认密码
if ([string]::IsNullOrWhiteSpace($newPassword)) {
    $newPassword = $defaultPassword
    Write-Host "使用默认密码: $defaultPassword" -ForegroundColor Gray
    Write-Host ""
} else {
    if ($newPassword.Length -lt 8) {
        Write-Host "[错误] 密码长度至少 8 个字符" -ForegroundColor Red
        Read-Host "按 Enter 键退出"
        exit 1
    }
    
    # 确认密码（仅在自定义密码时需要）
    $confirmPassword = Read-Host "请再次输入密码确认"
    
    if ($newPassword -ne $confirmPassword) {
        Write-Host "[错误] 两次输入的密码不一致" -ForegroundColor Red
        Read-Host "按 Enter 键退出"
        exit 1
    }
}

Write-Host ""
Write-Host "正在修改密码..." -ForegroundColor Yellow

# 执行密码修改
$script = @"
user = User.find_by(username: 'root')
if user
  user.password = '$newPassword'
  user.password_confirmation = '$newPassword'
  if user.save
    puts 'SUCCESS'
  else
    puts 'ERROR:' + user.errors.full_messages.join(', ')
  end
else
  puts 'ERROR:User root not found'
end
"@

$result = docker exec gitlab gitlab-rails runner $script 2>&1

if ($result -match "SUCCESS") {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  密码修改成功！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "登录信息：" -ForegroundColor White
    Write-Host "  地址: http://localhost:9980" -ForegroundColor Cyan
    Write-Host "  用户名: root" -ForegroundColor Cyan
    Write-Host "  密码: $newPassword" -ForegroundColor Cyan
} elseif ($result -match "ERROR:(.+)") {
    Write-Host ""
    Write-Host "[错误] 密码修改失败" -ForegroundColor Red
    Write-Host "原因: $($Matches[1])" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "常见原因：" -ForegroundColor Gray
    Write-Host "  - 密码包含常见词组合" -ForegroundColor Gray
    Write-Host "  - 密码强度不足" -ForegroundColor Gray
    Write-Host ""
    Write-Host "建议使用随机密码，如: Kx9#mPz2vL5n" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "[错误] 执行失败" -ForegroundColor Red
    Write-Host $result -ForegroundColor Yellow
}

Write-Host ""
Read-Host "按 Enter 键退出"
