# GitLab 云部署

基于阿里云 ECS + RDS PostgreSQL + OSS 的 GitLab 部署方案。

## 部署模式

支持两种模式（通过 `.env` 文件切换）：

| 模式 | DEPLOY_MODE | PostgreSQL | Redis | 说明 |
|------|-------------|------------|-------|------|
| **集成模式** | `integrated` | 内置 | 内置 | 开箱即用，无需外部依赖 |
| **外部模式** | `external` | 外部（阿里云 RDS） | 内置 | 数据持久化到云端 |

> **为什么 Redis 用内置？** 阿里云 Redis 版本 < 6.0，不兼容 GitLab 15.x。Redis 存储的是临时数据（会话、缓存），丢失不影响核心功能。

### 架构图

```
集成模式：                           外部模式：
┌─────────────────────┐             ┌─────────────────────┐
│  GitLab 容器         │             │  GitLab 容器         │
│  ├── Web (Puma)     │             │  ├── Web (Puma)     │
│  ├── Sidekiq        │             │  ├── Sidekiq        │
│  ├── PostgreSQL     │             │  └── Redis（内置）   │
│  └── Redis          │             └──────────┬──────────┘
└─────────────────────┘                        │
                                               ▼
                                    ┌─────────────────────┐
                                    │  阿里云 RDS PostgreSQL │
                                    └─────────────────────┘
```

> **为什么 Redis 用内置？** 阿里云 Redis 版本 < 6.0，不兼容 GitLab 15.x。Redis 存储的是临时数据（会话、缓存、任务队列），丢失不影响核心功能。

## 资源规划

| 资源 | 规格 | 参考价格 |
|------|------|----------|
| ECS | 2核4G | ￥80-100/月 |
| RDS PostgreSQL 12+ | 1核2G 基础版 | ￥50-80/月 |
| OSS | 按量付费 | ￥0.12/GB/月 |

**总成本**：约 ￥150-200/月

## 目录结构

```
deploy/cloud/
├── docker-compose.yml    # Docker Compose 配置
├── .env.example          # 环境变量示例
├── install.sh            # 环境安装脚本
├── start.sh              # 启动脚本
├── stop.sh               # 停止脚本
├── backup.sh             # OSS 备份脚本
├── restore.sh            # 数据恢复脚本
├── reset-password_root.sh     # 重置 root 密码
├── reset-database.sh     # 重置缓存数据
├── setup-cron.sh         # 配置定时备份
└── README.md             # 本文档
```

## 部署步骤

### 第一步：创建云资源

#### 1. 准备 RDS PostgreSQL

联系 DBA 创建数据库和用户，需要：
- 数据库名（如 `gitlabhq_production`）
- 用户名和密码
- 确保启用 `pg_trgm` 扩展

#### 2. 创建 OSS Bucket

1. 进入阿里云 OSS 控制台，创建 Bucket（与 ECS 同地域）
2. 权限设置为**私有**
3. 创建 RAM 用户并授予该 Bucket 读写权限

#### 3. 创建 ECS

1. 选择 2核4G 配置，Ubuntu 22.04 系统
2. 与 RDS/Redis 在同一 VPC
3. 分配公网 IP

### 第二步：安装环境

```bash
# 上传文件到 ECS
scp -r deploy/cloud/* root@your-ecs-ip:/opt/gitlab/

# SSH 登录 ECS
ssh root@your-ecs-ip
cd /opt/gitlab

# 运行安装脚本
chmod +x *.sh
./install.sh

# 配置 ossutil（替换为你的 AccessKey）
ossutil config -e oss-cn-hangzhou.aliyuncs.com -i YOUR_ACCESS_KEY_ID -k YOUR_ACCESS_KEY_SECRET
```

### 第三步：修改配置

```bash
# 编辑配置
vi .env
```

修改以下配置（docker-compose 会自动读取 `.env` 文件）：

```bash
DB_HOST=rm-xxxxx.pg.rds.aliyuncs.com  # RDS 内网地址
DB_PASSWORD=your_db_password           # 数据库密码
OSS_BUCKET=oss://your-bucket/gitlab-backups  # OSS 备份路径
```

### 第四步：启动 GitLab

```bash
./start.sh

# 查看启动日志
docker-compose logs -f gitlab

# 设置 root 密码
./reset-password_root.sh
```

### 第五步：配置定时备份

```bash
./setup-cron.sh
```

脚本会自动添加每天凌晨 3 点的备份任务。

## 常用命令

```bash
# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f gitlab

# 重启服务
docker-compose restart

# 手动备份
./backup.sh

# 升级 GitLab
docker-compose pull
docker-compose up -d
```

## 灾难恢复

```bash
# 1. 查看可用备份
ossutil ls oss://your-bucket/gitlab-backups/backups/

# 2. 恢复数据
./restore.sh 1234567890_2024_01_01_16.0.0_gitlab_backup.tar

# 3. 验证恢复
docker exec gitlab gitlab-rake gitlab:check SANITIZE=true
```

## 安全配置

### 安全组规则

| 端口 | 协议 | 来源 | 说明 |
|------|------|------|------|
| 80 | TCP | 0.0.0.0/0 | HTTP |
| 443 | TCP | 0.0.0.0/0 | HTTPS |
| 22 | TCP | 0.0.0.0/0 | SSH Git |

### 启用 HTTPS

修改 `.env` 后，编辑 `docker-compose.yml` 取消 Let's Encrypt 配置的注释。

## 故障排除

### 数据库连接失败

1. 检查 RDS 白名单是否包含 ECS IP
2. 检查账号密码是否正确
3. 确认数据库和用户已由 DBA 创建

### 恢复后无法登录

确保恢复了 `gitlab/config/` 目录下的 `gitlab-secrets.json`。
