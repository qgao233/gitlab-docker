#!/bin/bash

echo "========================================"
echo "  停止 GitLab 服务"
echo "========================================"
echo

docker-compose down

echo
echo "GitLab 服务已停止"
