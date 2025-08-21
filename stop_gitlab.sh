#!/bin/bash

# GitLab Docker 停止脚本
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
echo "        GitLab Docker 停止脚本"
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

# 检查GitLab容器状态
print_info "检查GitLab容器状态..."
if docker ps --filter "name=gitlab" --format "{{.Names}}" | grep -q gitlab; then
    print_info "发现运行中的GitLab容器:"
    docker ps --filter "name=gitlab" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    GITLAB_RUNNING=true
elif docker ps -a --filter "name=gitlab" --format "{{.Names}}" | grep -q gitlab; then
    print_warning "发现已停止的GitLab容器:"
    docker ps -a --filter "name=gitlab" --format "table {{.Names}}\t{{.Status}}"
    GITLAB_RUNNING=false
    echo
    read -p "容器可能已经停止，是否继续执行清理操作？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi
else
    print_info "没有找到GitLab容器"
    GITLAB_RUNNING=false
fi
echo

# 确认停止操作
echo "========================================"
echo "           确认停止操作"
echo "========================================"
echo
echo "即将执行以下操作:"
echo "1. 停止GitLab容器"
echo "2. 移除容器（保留数据）"
echo "3. 清理未使用的网络"
echo
echo "注意: 数据不会丢失，数据保存在 ./gitlab/ 目录中"
echo

if [ "$GITLAB_RUNNING" = true ]; then
    read -p "确认要停止GitLab服务吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi
fi
echo

# 停止服务
print_info "正在停止GitLab服务..."
if $COMPOSE_CMD down; then
    print_success "GitLab服务已成功停止"
else
    print_error "停止服务失败，尝试强制停止..."
    docker stop gitlab 2>/dev/null || true
    docker rm gitlab 2>/dev/null || true
    print_warning "已尝试强制停止容器"
fi
echo

# 显示当前状态
print_info "当前容器状态:"
if docker ps -a --filter "name=gitlab" --format "{{.Names}}" | grep -q gitlab; then
    docker ps -a --filter "name=gitlab" --format "table {{.Names}}\t{{.Status}}"
else
    echo "没有GitLab相关容器"
fi
echo

# 可选清理操作
echo "========================================"
echo "           可选清理操作"
echo "========================================"
echo
read -p "是否要清理未使用的Docker资源？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    print_info "清理未使用的网络..."
    docker network prune -f
    
    echo
    print_info "清理未使用的卷（不包括GitLab数据卷）..."
    docker volume prune -f
    
    echo
    print_success "清理完成"
fi
echo

# 显示数据保存信息
echo "========================================"
echo "           数据保存信息"
echo "========================================"
echo
echo "GitLab数据已保存在以下目录:"
echo "- 配置文件: ./gitlab/config/"
echo "- 日志文件: ./gitlab/logs/"
echo "- 数据文件: ./gitlab/data/"
echo
echo "重新启动GitLab请运行: ./start_gitlab.sh"
echo
echo "========================================"

echo
print_success "GitLab停止脚本执行完成！"
