#!/bin/bash
set -e

echo "========================================"
echo "  GitLab 云部署启动脚本"
echo "========================================"
echo

# 检查配置
check_config() {
    if [ ! -f ".env" ]; then
        echo "[错误] 未找到 .env 文件"
        echo "请先执行: cp .env.example .env"
        echo "然后编辑 .env 文件修改配置"
        exit 1
    fi
    
    # 使用 set -a 导出变量
    set -a
    . ./.env
    set +a
    
    # 检查必要配置
    local has_error=0
    
    if [[ "$DEPLOY_MODE" == "external" ]]; then
        if [[ -z "$DB_HOST" ]]; then
            echo "  - DB_HOST 未配置"
            has_error=1
        fi
        if [[ "$DB_PASSWORD" == *"your_db_password"* ]] || [[ -z "$DB_PASSWORD" ]]; then
            echo "  - DB_PASSWORD 未配置"
            has_error=1
        fi
    fi
    
    if [[ "$OSS_BUCKET" == *"your-bucket-name"* ]]; then
        echo "  - OSS_BUCKET 未配置（备份功能将不可用）"
    fi
    
    if [[ $has_error -eq 1 ]]; then
        echo ""
        echo "[错误] 请先修改 .env 文件中的配置"
        exit 1
    fi
}

# 检查 Docker
if ! docker info > /dev/null 2>&1; then
    echo "[错误] Docker 未运行，请先启动 Docker"
    exit 1
fi

# 检查配置
echo "[1/4] 检查配置..."
check_config
echo "配置检查通过"

# 创建数据目录
echo "[2/4] 创建数据目录..."
mkdir -p gitlab/{config,logs,data}

# 拉取镜像
echo "[3/4] 拉取 GitLab 镜像..."
docker-compose pull

# 启动服务
echo "[4/4] 启动 GitLab 服务..."
docker-compose up -d

echo
echo "========================================"
echo "  GitLab 正在启动..."
echo "========================================"
echo
echo "  启动需要 3-5 分钟，请稍候"
echo
echo "  查看启动日志："
echo "  docker-compose logs -f gitlab"
echo
echo "  设置 root 密码："
echo "  ./reset-password_root.sh"
echo
echo "========================================"
