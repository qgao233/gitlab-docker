#!/bin/bash

echo "========================================"
echo "  GitLab 本地部署启动脚本"
echo "========================================"
echo

# 检查 Docker
if ! docker info > /dev/null 2>&1; then
    echo "[错误] Docker 未运行，请先启动 Docker"
    exit 1
fi

# 创建数据目录
echo "[1/3] 创建数据目录..."
mkdir -p gitlab/{config,logs,data}

# 选择部署模式
echo
echo "请选择部署模式："
echo "  1. 集成模式（内置 PostgreSQL/Redis，推荐新手）"
echo "  2. 分离模式（独立 PostgreSQL/Redis 容器）"
echo
read -p "请输入选项 [1/2] (默认 1): " mode

if [ "$mode" = "2" ]; then
    echo
    echo "[2/3] 使用分离模式启动..."
    
    # 创建分离模式数据目录
    mkdir -p postgresql/data redis/data
    
    docker-compose -f docker-compose.separated.yml up -d
else
    echo
    echo "[2/3] 使用集成模式启动..."
    docker-compose up -d
fi

echo
echo "[3/3] GitLab 正在启动（约需 3-5 分钟）..."
echo
echo "========================================"
echo "  启动命令已执行"
echo "========================================"
echo
echo "  访问地址: http://localhost:9980"
echo "  SSH 端口: 9922"
echo "  用户名: root"
echo
echo "  查看启动日志:"
echo "  docker-compose logs -f gitlab"
echo
echo "  获取初始密码:"
echo "  docker exec gitlab cat /etc/gitlab/initial_root_password"
echo
echo "========================================"
