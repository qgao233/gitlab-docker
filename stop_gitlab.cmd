@echo off
title GitLab Docker 停止脚本
echo.
echo ========================================
echo         GitLab Docker 停止脚本
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

:: 检查GitLab容器状态
echo [信息] 检查GitLab容器状态...
docker ps --filter "name=gitlab" --quiet >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] 未发现运行中的GitLab容器
    echo.
    docker ps -a --filter "name=gitlab" --quiet >nul 2>&1
    if %errorlevel% neq 0 (
        echo [信息] 没有找到GitLab容器
    ) else (
        echo [信息] 发现已停止的GitLab容器:
        docker ps -a --filter "name=gitlab"
    )
    echo.
    set /p continue=容器可能已经停止，是否继续执行清理操作？(Y/N)
    if /i not "%continue%"=="Y" (
        echo [信息] 操作已取消
        echo.
        pause
        exit /b 0
    )
) else (
    echo [信息] 发现运行中的GitLab容器
    docker ps --filter "name=gitlab"
)
echo.

:: 确认停止操作
echo ========================================
echo            确认停止操作
echo ========================================
echo.
echo 即将执行以下操作:
echo 1. 停止GitLab容器
echo 2. 移除容器（保留数据）
echo 3. 清理未使用的网络
echo.
echo 注意: 数据不会丢失，数据保存在 ./gitlab/ 目录中
echo.
set /p confirm=确认要停止GitLab服务吗？(Y/N)
if /i not "%confirm%"=="Y" (
    echo [信息] 操作已取消
    echo.
    pause
    exit /b 0
)
echo.

:: 停止服务
echo [信息] 正在停止GitLab服务...
docker-compose down
if %errorlevel% neq 0 (
    echo [错误] 停止服务失败，尝试强制停止...
    docker stop gitlab 2>nul
    docker rm gitlab 2>nul
    echo [警告] 已尝试强制停止容器
) else (
    echo [成功] GitLab服务已成功停止
)
echo.

:: 显示当前状态
echo [信息] 当前容器状态:
docker ps -a --filter "name=gitlab" 2>nul
if %errorlevel% neq 0 (
    echo [信息] 没有GitLab相关容器
)
echo.

:: 可选清理操作
echo ========================================
echo            可选清理操作
echo ========================================
echo.
set /p cleanup=是否要清理未使用的Docker资源？(Y/N)
if /i "%cleanup%"=="Y" (
    echo.
    echo [信息] 清理未使用的网络...
    docker network prune -f
    echo.
    echo [信息] 清理未使用的卷（不包括GitLab数据卷）...
    docker volume prune -f
    echo.
    echo [成功] 清理完成
)
echo.

:: 显示数据保存信息
echo ========================================
echo            数据保存信息
echo ========================================
echo.
echo GitLab数据已保存在以下目录:
echo - 配置文件: ./gitlab/config/
echo - 日志文件: ./gitlab/logs/
echo - 数据文件: ./gitlab/data/
echo.
echo 重新启动GitLab请运行: start_gitlab.cmd
echo.
echo ========================================

echo.
echo [成功] GitLab停止脚本执行完成！
pause
