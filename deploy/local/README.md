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
DB_PASSWORD="your_password"

# OSS 备份配置（可选）
OSSUTIL_PATH="D:\ossutil-2.2.0-windows-amd64\ossutil.exe"
OSS_BUCKET=oss://your-bucket-name/gitlab-backups
```

> 集成模式下数据库配置会被忽略。密码包含特殊字符时需用双引号包裹。

## 访问信息

| 项目 | 值 |
|------|------|
| Web 地址 | http://localhost:9980 |
| SSH 端口 | 9922 |
| 初始用户名 | root |

### 设置 root 密码

```powershell
.\reset-password.ps1
```

## 目录结构

```
deploy/local/
├── docker-compose.yml           # 主配置文件（支持集成/外部模式）
├── docker-compose.separated.yml # 分离模式（本地PG/Redis容器）
├── .env.example                 # 环境变量模板
├── start.ps1 / start.sh         # 启动脚本
├── stop.ps1 / stop.sh           # 停止脚本
├── backup.ps1                   # 备份脚本（支持 OSS 上传）
├── restore.ps1                  # 恢复脚本（支持 OSS 下载）
├── reset-password.ps1           # 重置 root 密码
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

# 进入容器
docker exec -it gitlab bash
```

## 备份与恢复

### 备份

```powershell
.\backup.ps1
```

功能：
- 创建 GitLab 数据备份
- 本地备份配置文件到 `config-backup/`
- **可选**：自动上传到阿里云 OSS（需在 `.env` 配置）

### 恢复

```powershell
# 从本地备份恢复
.\restore.ps1 <备份文件名>

# 从 OSS 下载并恢复
.\restore.ps1 -FromOss <备份文件名>

# 列出 OSS 上的备份
.\restore.ps1 -ListOss
```

示例：
```powershell
.\restore.ps1 1769650886_2026_01_29_15.11.13_gitlab_backup.tar
```

### OSS 配置（可选）

如需将备份上传到阿里云 OSS，需要安装和配置 ossutil。

#### 1. 下载 ossutil-2

下载地址：https://gosspublic.alicdn.com/ossutil/v2/2.2.0/ossutil-2.2.0-windows-amd64.zip?spm=a2c63.p38356.0.0.5401c0eaxffczu&file=ossutil-2.2.0-windows-amd64.zip

下载后解压到任意目录，如 `D:\ossutil-2.2.0-windows-amd64\`

#### 2. 配置 ossutil

创建配置文件 `C:\Users\<用户名>\.ossutilconfig`：

```ini
[Credentials]
language = CH
endpoint = oss-cn-shanghai.aliyuncs.com
accessKeyID = <你的 AccessKey ID>
accessKeySecret = <你的 AccessKey Secret>
region = cn-shanghai
```

> 注意：本地使用**公网地址** `oss-cn-shanghai.aliyuncs.com`，ECS 内网使用 `oss-cn-shanghai-internal.aliyuncs.com`

#### 3. 验证配置

```powershell
D:\ossutil-2.2.0-windows-amd64\ossutil.exe ls
```

应该能看到你的 bucket 列表。

#### 4. 配置 .env

在 `.env` 中添加：
```bash
OSSUTIL_PATH="D:\ossutil-2.2.0-windows-amd64\ossutil.exe"
OSS_BUCKET=oss://gitlab-oss/gitlab-backups
```


## 故障排除

### 无法连接 RDS PostgreSQL

1. 检查 RDS 白名单是否包含本机公网 IP
2. 检查账号密码是否正确
3. 确认数据库和用户已创建

### 重置 root 密码

```powershell
.\reset-password.ps1
```

### 重置数据库（清空重来）

```powershell
.\reset-database.ps1
```

> ⚠️ 重置数据库会丢失所有 GitLab 数据，但保留 Git 仓库文件。
