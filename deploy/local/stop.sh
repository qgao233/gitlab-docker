#!/bin/bash

echo "========================================"
echo "  停止 GitLab 服务"
echo "========================================"
echo

# 停止所有可能的配置
docker-compose down 2>/dev/null
docker-compose -f docker-compose.separated.yml down 2>/dev/null

echo
echo "GitLab 服务已停止"
