#!/bin/bash

# GitLab Docker 部署脚本
# 适用于Linux和macOS系统

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 命令不存在，请先安装 $1"
        exit 1
    fi
}

# 脚本开始
echo
echo "========================================"
echo "        GitLab Docker 部署脚本"
echo "========================================"
echo

# 检查Docker是否安装和运行
print_info "检查Docker服务状态..."
check_command "docker"

if ! docker info &> /dev/null; then
    print_error "Docker服务未运行！请先启动Docker服务"
    exit 1
fi
print_success "Docker服务正常运行"
echo

# 检查docker-compose是否可用
print_info "检查Docker Compose..."
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    print_error "Docker Compose不可用！请先安装Docker Compose"
    exit 1
fi
print_success "Docker Compose可用 ($COMPOSE_CMD)"
echo

# 创建必要的目录
print_info "创建数据目录..."
mkdir -p gitlab/{config,logs,data}
print_success "数据目录创建完成"
echo

# 设置目录权限（Linux特有）
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_info "设置目录权限..."
    sudo chown -R 998:998 gitlab/
    print_success "目录权限设置完成"
    echo
fi

# 拉取最新镜像
print_info "拉取GitLab最新镜像..."
if ! $COMPOSE_CMD pull; then
    print_error "镜像拉取失败！"
    exit 1
fi
print_success "GitLab镜像拉取完成"
echo

# 启动GitLab服务
print_info "启动GitLab服务..."
if ! $COMPOSE_CMD up -d; then
    print_error "GitLab启动失败！"
    exit 1
fi
print_success "GitLab服务启动成功！"
echo

# 显示服务状态
print_info "服务状态:"
$COMPOSE_CMD ps
echo

# 等待GitLab启动
print_info "等待GitLab初始化..."
echo "这可能需要几分钟时间，请耐心等待..."

# 检查GitLab是否就绪
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec gitlab curl -f http://localhost/health &> /dev/null; then
        print_success "GitLab已就绪！"
        break
    fi
    echo -n "."
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    print_warning "GitLab可能仍在初始化中，请稍后手动检查"
fi
echo

# 显示访问信息
echo "========================================"
echo "           部署完成信息"
echo "========================================"
echo
echo "访问地址: http://localhost:9980"
echo "SSH克隆端口: 9922"
echo
echo "初始账号: root"
echo "初始密码获取: docker exec gitlab cat /etc/gitlab/initial_root_password"
echo
echo "常用命令:"
echo "  查看日志: $COMPOSE_CMD logs -f gitlab"
echo "  停止服务: $COMPOSE_CMD down"
echo "  重启服务: $COMPOSE_CMD restart"
echo "  进入容器: docker exec -it gitlab /bin/bash"
echo
echo "========================================"
echo

# 询问是否查看日志
read -p "是否要查看启动日志？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    print_info "显示GitLab启动日志 (按Ctrl+C退出)..."
    $COMPOSE_CMD logs -f gitlab
fi

echo
print_success "脚本执行完成！"