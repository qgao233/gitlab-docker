# GitLab 本地部署

通过 Docker Compose 在本地部署 GitLab 社区版。

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

## 快速开始

### 方式一：使用启动脚本（推荐）

**Windows (PowerShell):**
```powershell
.\start.ps1
```

**Linux/macOS:**
```bash
chmod +x start.sh stop.sh
./start.sh
```

### 方式二：手动启动

```bash
# 1. 复制配置模板
cp .env.example .env

# 2. 编辑配置（选择模式、设置数据库信息）
vi .env

# 3. 创建目录并启动
mkdir -p gitlab/{config,logs,data}
docker-compose up -d
```

## 配置说明

通过 `.env` 文件配置（docker-compose 会自动读取）：

```bash
# 部署模式：integrated（集成）或 external（外部）
DEPLOY_MODE=external

# 外部模式需要配置数据库信息
DB_HOST=hq-mii-db.pg.rds.aliyuncs.com
DB_PORT=5432
DB_NAME=github-yfpo
DB_USER=github_user
DB_PASSWORD=your_password
```

> 集成模式下数据库配置会被忽略。

## 访问信息

| 项目 | 值 |
|------|------|
| Web 地址 | http://localhost:9980 |
| SSH 端口 | 9922 |
| 初始用户名 | root |

### 设置 root 密码

```powershell
.\reset-password_root.ps1
```

## 目录结构

```
deploy/local/
├── docker-compose.yml           # 主配置文件（支持集成/外部模式）
├── docker-compose.separated.yml # 分离模式（本地PG/Redis容器）
├── .env.example                 # 环境变量模板
├── start.ps1 / start.sh         # 启动脚本
├── stop.ps1 / stop.sh           # 停止脚本
├── reset-password_root.ps1           # 重置 root 密码
├── reset-database.ps1           # 重置数据库
├── README.md                    # 本文档
└── gitlab/                      # GitLab 数据（启动后创建）
    ├── config/
    ├── logs/
    └── data/
```

## 常用命令

```bash
# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f gitlab

# 重启服务
docker-compose restart

# 创建备份
docker exec gitlab gitlab-backup create

# 进入容器
docker exec -it gitlab bash
```

## 故障排除

### 无法连接 RDS PostgreSQL

1. 检查 RDS 白名单是否包含本机公网 IP
2. 检查账号密码是否正确
3. 确认数据库和用户已创建

### 重置 root 密码

```powershell
.\reset-password_root.ps1
```

### 重置数据库（清空重来）

```powershell
.\reset-database.ps1
```

> ⚠️ 重置数据库会丢失所有 GitLab 数据，但保留 Git 仓库文件。
