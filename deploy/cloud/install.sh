#!/bin/bash
set -e

echo "========================================"
echo "  GitLab 云部署 - 环境安装脚本"
echo "========================================"
echo

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "[警告] 建议使用 root 用户运行此脚本"
fi

# 安装 Docker
echo "[1/4] 安装 Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "Docker 安装完成"
else
    echo "Docker 已安装，跳过"
fi

# 安装 Docker Compose
echo "[2/4] 安装 Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose 安装完成"
else
    echo "Docker Compose 已安装，跳过"
fi

# 安装 ossutil
echo "[3/4] 安装 ossutil..."
if ! command -v ossutil &> /dev/null; then
    wget -q https://gosspublic.alicdn.com/ossutil/1.7.14/ossutil64
    chmod 755 ossutil64
    mv ossutil64 /usr/local/bin/ossutil
    echo "ossutil 安装完成"
    echo "[提示] 请运行 'ossutil config' 配置阿里云 OSS 访问凭证"
else
    echo "ossutil 已安装，跳过"
fi

# 创建目录
echo "[4/4] 创建目录结构..."
mkdir -p gitlab/{config,logs,data}

# 复制环境变量示例
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "[提示] 已创建 .env 文件，请修改其中的配置"
fi

echo
echo "========================================"
echo "  环境安装完成！"
echo "========================================"
echo
echo "后续步骤："
echo "1. 配置 ossutil: ossutil config"
echo "2. 修改 .env 文件中的数据库和 Redis 配置"
echo "3. 运行启动脚本: ./start.sh"
echo
