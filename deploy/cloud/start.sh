#!/bin/bash
set -e

# 参数说明
show_help() {
    echo "用法: ./start.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -r, --rebuild    重新构建容器（删除旧容器后重建）"
    echo "  -f, --force      强制重建（删除容器和数据卷后重建）"
    echo "  -h, --help       显示帮助信息"
    echo ""
    echo "示例:"
    echo "  ./start.sh           # 正常启动"
    echo "  ./start.sh -r        # 重新构建容器"
    echo "  ./start.sh -f        # 强制重建（会丢失数据！）"
}

# 解析参数
REBUILD=0
FORCE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rebuild)
            REBUILD=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "[错误] 未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

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
    
    if [[ -z "$GITLAB_HOST" ]] || [[ "$GITLAB_HOST" == *"example.com"* ]]; then
        echo "  - GITLAB_HOST 未配置（你的域名或公网 IP）"
        has_error=1
    fi
    
    if [[ -z "$DB_HOST" ]] || [[ "$DB_HOST" == *"xxxxx"* ]]; then
        echo "  - DB_HOST 未配置（RDS 内网地址）"
        has_error=1
    fi
    
    if [[ "$DB_PASSWORD" == *"your_db_password"* ]] || [[ -z "$DB_PASSWORD" ]]; then
        echo "  - DB_PASSWORD 未配置"
        has_error=1
    fi
    
    if [[ "$OSS_BUCKET" == *"your-bucket-name"* ]]; then
        echo "  [提示] OSS_BUCKET 未配置（备份功能将不可用）"
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

# 处理重建逻辑
if [[ $FORCE -eq 1 ]]; then
    echo "[3/5] 强制重建（删除容器和数据）..."
    echo ""
    echo "  ⚠️  警告：这将删除所有 GitLab 数据！"
    read -p "  确定要继续吗？输入 'YES' 确认: " CONFIRM
    if [[ "$CONFIRM" != "YES" ]]; then
        echo "操作已取消"
        exit 0
    fi
    docker-compose down -v 2>/dev/null || true
    rm -rf gitlab/{config,logs,data}/*
    mkdir -p gitlab/{config,logs,data}
elif [[ $REBUILD -eq 1 ]]; then
    echo "[3/5] 重新构建容器..."
    docker-compose down 2>/dev/null || true
fi

# 拉取镜像
echo "[4/5] 拉取 GitLab 镜像..."
docker-compose pull

# 启动服务
echo "[5/5] 启动 GitLab 服务..."
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
echo "  查看启动服务："
echo "  docker exec gitlab gitlab-ctl status"
echo
echo "  设置 root 密码："
echo "  ./reset-password_root.sh"
echo
echo "========================================"
