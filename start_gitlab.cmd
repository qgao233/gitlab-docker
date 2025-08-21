@echo off
title GitLab Docker 部署脚本
echo.
echo ========================================
echo         GitLab Docker 部署脚本
echo ========================================
echo.

:: 检查Docker是否运行
echo [信息] 检查Docker服务状态...
docker version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker服务未运行或未安装！
    echo        请先启动Docker Desktop或安装Docker
    echo.
    pause
    exit /b 1
)
echo [成功] Docker服务正常运行
echo.

:: 检查docker-compose是否可用
echo [信息] 检查Docker Compose...
docker-compose version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker Compose不可用！
    echo        请确保Docker Compose已正确安装
    echo.
    pause
    exit /b 1
)
echo [成功] Docker Compose可用
echo.

:: 创建必要的目录
echo [信息] 创建数据目录...
if not exist "gitlab\config" mkdir gitlab\config
if not exist "gitlab\logs" mkdir gitlab\logs
if not exist "gitlab\data" mkdir gitlab\data
echo [成功] 数据目录创建完成
echo.

:: 拉取最新镜像
echo [信息] 拉取GitLab最新镜像...
docker-compose pull
if %errorlevel% neq 0 (
    echo [错误] 镜像拉取失败！
    echo.
    pause
    exit /b 1
)
echo [成功] GitLab镜像拉取完成
echo.

:: 启动GitLab服务
echo [信息] 启动GitLab服务...
docker-compose up -d
if %errorlevel% neq 0 (
    echo [错误] GitLab启动失败！
    echo.
    pause
    exit /b 1
)
echo.
echo [成功] GitLab服务启动成功！
echo.

:: 显示服务状态
echo [信息] 服务状态:
docker-compose ps
echo.

:: 显示访问信息
echo ========================================
echo            部署完成信息
echo ========================================
echo.
echo GitLab正在初始化，请等待几分钟时间
echo.
echo 访问地址: http://localhost:9980
echo SSH克隆端口: 9922
echo.
echo 初始账号: root
echo 初始密码位置: gitlab/config/initial_root_password
echo.
echo 查看启动日志: docker-compose logs -f gitlab
echo 停止服务: docker-compose down
echo 重启服务: docker-compose restart
echo.
echo ========================================

echo.
set /p choice=是否要查看启动日志？(Y/N)
if /i "%choice%"=="Y" (
    echo.
    echo [信息] 显示GitLab启动日志 ^(按Ctrl+C退出^)
    docker-compose logs -f gitlab
)

echo.
echo 脚本执行完成！
pause