#!/bin/sh
# GitLab Runner 注册脚本 (Linux/macOS)
#
# 【功能】
#   - 注册 GitLab Runner 到 GitLab 服务器
#
# 【使用方法】
#   chmod +x register.sh
#   ./register.sh

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 加载环境变量
if [ -f ".env" ]; then
    set -a
    . ./.env
    set +a
else
    echo "[错误] 未找到 .env 文件"
    echo "请先执行: cp .env.example .env 并配置"
    exit 1
fi

# 设置默认值
RUNNER_NAME="${RUNNER_NAME:-docker-runner}"
RUNNER_TAGS="${RUNNER_TAGS:-docker,linux}"
RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-docker}"
DOCKER_IMAGE="${DOCKER_IMAGE:-docker.1ms.run/library/alpine:latest}"

echo "========================================"
echo "  GitLab Runner 注册"
echo "========================================"
echo ""
echo "GitLab URL: $GITLAB_URL"
echo "Runner 名称: $RUNNER_NAME"
echo "Runner 标签: $RUNNER_TAGS"
echo "执行器类型: $RUNNER_EXECUTOR"
if [ "$RUNNER_EXECUTOR" = "docker" ]; then
    echo "默认镜像: $DOCKER_IMAGE"
fi
echo ""

# 检查必需配置
if [ -z "$GITLAB_URL" ] || [ -z "$REGISTRATION_TOKEN" ]; then
    echo "[错误] 请在 .env 中配置 GITLAB_URL 和 REGISTRATION_TOKEN"
    exit 1
fi

# 检查容器是否运行
if ! docker ps --filter "name=gitlab-runner" --format "{{.Names}}" | grep -q "gitlab-runner"; then
    echo "Runner 容器未运行，正在启动..."
    docker-compose up -d
    sleep 5
fi

# 注册 Runner
echo "正在注册 Runner..."

if [ "$RUNNER_EXECUTOR" = "docker" ]; then
    docker exec gitlab-runner gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --name "$RUNNER_NAME" \
        --tag-list "$RUNNER_TAGS" \
        --executor "$RUNNER_EXECUTOR" \
        --docker-image "$DOCKER_IMAGE" \
        --docker-privileged \
        --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"
else
    docker exec gitlab-runner gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --name "$RUNNER_NAME" \
        --tag-list "$RUNNER_TAGS" \
        --executor "$RUNNER_EXECUTOR"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "  注册成功！"
    echo "========================================"
    echo ""
    echo "查看 Runner 状态："
    echo "  docker exec gitlab-runner gitlab-runner list"
    echo ""
    echo "在 GitLab 中查看："
    echo "  Admin -> CI/CD -> Runners"
else
    echo ""
    echo "[错误] 注册失败"
    echo "请检查："
    echo "  1. GitLab URL 是否正确且可访问"
    echo "  2. Registration Token 是否正确"
    echo "  3. 网络连接是否正常"
fi
