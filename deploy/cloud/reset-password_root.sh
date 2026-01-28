#!/bin/bash
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

set -e

echo "========================================"
echo "  GitLab Root 密码重置脚本"
echo "========================================"
echo ""

# 检查容器是否运行
if ! docker ps --filter "name=gitlab" --format "{{.Names}}" | grep -q "gitlab"; then
    echo "[错误] GitLab 容器未运行"
    echo "请先启动容器: ./start.sh"
    exit 1
fi

# 检查 root 用户是否存在
echo "正在检查 root 用户..."
CHECK_SCRIPT="user = User.find_by(username: 'root'); puts user ? 'EXISTS' : 'NOT_EXISTS'"
USER_EXISTS=$(docker exec gitlab gitlab-rails runner "$CHECK_SCRIPT" 2>/dev/null || echo "ERROR")

if [[ "$USER_EXISTS" == *"NOT_EXISTS"* ]]; then
    echo ""
    echo "[提示] root 用户不存在，正在运行种子数据创建用户..."
    echo "这可能需要 1-2 分钟，请耐心等待..."
    echo ""
    
    # 运行种子数据
    docker exec gitlab gitlab-rake db:seed_fu RAILS_ENV=production
    
    # 再次检查用户是否创建成功
    sleep 5
    USER_EXISTS=$(docker exec gitlab gitlab-rails runner "$CHECK_SCRIPT" 2>/dev/null || echo "ERROR")
    
    if [[ "$USER_EXISTS" == *"NOT_EXISTS"* ]]; then
        echo "[错误] 种子数据执行后仍未创建 root 用户"
        echo "请检查数据库连接和日志"
        echo ""
        echo "查看日志命令: docker-compose logs gitlab"
        exit 1
    fi
    
    echo "[成功] root 用户已创建"
    echo ""
else
    echo "[成功] root 用户已存在"
    echo ""
fi

# 生成随机密码（12位）
generate_password() {
    # 使用 /dev/urandom 生成随机密码
    local password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 11 | head -n 1)
    # 添加特殊字符
    local special_chars='#@$%&*!'
    local special_char=${special_chars:$((RANDOM % ${#special_chars})):1}
    echo "${password}${special_char}"
}

DEFAULT_PASSWORD=$(generate_password)

# 提示密码要求
echo "密码要求："
echo "  - 至少 8 个字符"
echo "  - 不能包含常见词（password、gitlab、admin 等）"
echo ""
echo "默认密码: $DEFAULT_PASSWORD （直接回车使用默认密码）"
echo ""

# 输入新密码
read -p "请输入新密码（回车使用默认密码）: " NEW_PASSWORD

# 如果为空，使用默认密码
if [[ -z "$NEW_PASSWORD" ]]; then
    NEW_PASSWORD="$DEFAULT_PASSWORD"
    echo "使用默认密码: $DEFAULT_PASSWORD"
    echo ""
else
    if [[ ${#NEW_PASSWORD} -lt 8 ]]; then
        echo "[错误] 密码长度至少 8 个字符"
        exit 1
    fi
    
    # 确认密码
    read -p "请再次输入密码确认: " CONFIRM_PASSWORD
    
    if [[ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
        echo "[错误] 两次输入的密码不一致"
        exit 1
    fi
fi

echo ""
echo "正在修改密码..."

# 执行密码修改
SCRIPT="user = User.find_by(username: 'root'); if user; user.password = '$NEW_PASSWORD'; user.password_confirmation = '$NEW_PASSWORD'; if user.save; puts 'SUCCESS'; else; puts 'ERROR:' + user.errors.full_messages.join(', '); end; else; puts 'ERROR:User root not found'; end"

RESULT=$(docker exec gitlab gitlab-rails runner "$SCRIPT" 2>&1)

if [[ "$RESULT" == *"SUCCESS"* ]]; then
    echo ""
    echo "========================================"
    echo "  密码修改成功！"
    echo "========================================"
    echo ""
    echo "登录信息："
    echo "  用户名: root"
    echo "  密码: $NEW_PASSWORD"
elif [[ "$RESULT" == *"ERROR:"* ]]; then
    echo ""
    echo "[错误] 密码修改失败"
    echo "原因: ${RESULT#*ERROR:}"
    echo ""
    echo "常见原因："
    echo "  - 密码包含常见词组合"
    echo "  - 密码强度不足"
    echo ""
    echo "建议使用随机密码，如: Kx9#mPz2vL5n"
    exit 1
else
    echo ""
    echo "[错误] 执行失败"
    echo "$RESULT"
    exit 1
fi
