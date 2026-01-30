# GitLab Runner 部署

通过 Docker 部署 GitLab Runner，用于执行 CI/CD 作业。

## 快速开始

### 1. 启动 Runner 容器

**Windows:**
```powershell
.\start.ps1
```

**Linux/macOS:**
```bash
chmod +x *.sh
./start.sh
```

### 2. 获取注册令牌

在 GitLab 中获取 Runner 注册令牌：

1. 以管理员登录 GitLab
2. 进入 **Admin Area** → **CI/CD** → **Runners**
3. 点击 **Register an instance runner**
4. 复制 **Registration token**

或者在项目级别注册：
1. 进入项目 → **Settings** → **CI/CD** → **Runners**
2. 展开 **Runners** 部分
3. 复制 **Registration token**

### 3. 配置 .env 文件

```bash
cp .env.example .env
```

编辑 `.env`：
```bash
# GitLab 服务器地址
GITLAB_URL=http://localhost:9980

# 注册令牌
REGISTRATION_TOKEN=your_token_here

# Runner 配置
RUNNER_NAME=docker-runner
RUNNER_TAGS=docker,linux
RUNNER_EXECUTOR=docker
DOCKER_IMAGE=docker.1ms.run/library/alpine:latest
```

### 4. 注册 Runner

**Windows:**
```powershell
.\register.ps1
```

**Linux/macOS:**
```bash
./register.sh
```

## 目录结构

```
Runner/
├── docker-compose.yml   # Docker Compose 配置
├── .env.example         # 环境变量模板
├── start.ps1 / start.sh # 启动脚本
├── stop.ps1 / stop.sh   # 停止脚本
├── register.ps1 / register.sh  # 注册脚本
├── README.md            # 本文档
└── config/              # Runner 配置（启动后创建）
    └── config.toml      # Runner 配置文件
```

## 执行器类型

| 执行器 | 说明 | 适用场景 |
|--------|------|----------|
| `docker` | 每个作业在独立容器中运行 | 推荐，隔离性好 |
| `shell` | 直接在 Runner 主机上运行 | 需要访问主机资源 |
| `docker+machine` | 自动扩展 Docker 主机 | 大规模 CI/CD |

## 常用命令

```bash
# 查看 Runner 状态
docker exec gitlab-runner gitlab-runner list

# 查看运行中的作业
docker exec gitlab-runner gitlab-runner list --all

# 验证 Runner 配置
docker exec gitlab-runner gitlab-runner verify

# 取消注册 Runner
docker exec gitlab-runner gitlab-runner unregister --name "docker-runner"

# 取消注册所有 Runner
docker exec gitlab-runner gitlab-runner unregister --all-runners

# 查看日志
docker-compose logs -f gitlab-runner
```

## 配置说明

### config.toml

注册后会自动生成 `config/config.toml`，可手动编辑：

```toml
concurrent = 4                    # 并发作业数
check_interval = 0                # 检查间隔

[[runners]]
  name = "docker-runner"
  url = "http://gitlab:80"
  token = "xxxxx"
  executor = "docker"
  
  [runners.docker]
    image = "alpine:latest"
    privileged = true             # 允许特权模式（docker-in-docker）
    volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
    pull_policy = "if-not-present"
```

### 增加并发数

编辑 `config/config.toml`：
```toml
concurrent = 8
```

然后重启：
```bash
docker-compose restart
```

## 网络配置

### Runner 访问 GitLab

如果 GitLab 和 Runner 在同一 Docker 网络：
```bash
GITLAB_URL=http://gitlab:80
```

如果通过主机网络访问：
```bash
# Windows/Mac Docker Desktop
GITLAB_URL=http://host.docker.internal:9980

# Linux
GITLAB_URL=http://172.17.0.1:9980
```

### Runner 访问外部服务

Runner 容器默认可访问外部网络。如需访问内网服务，确保 Docker 网络配置正确。

## 故障排除

### Runner 无法连接 GitLab

1. 检查 `GITLAB_URL` 是否正确
2. 确认 Runner 容器能访问 GitLab：
   ```bash
   docker exec gitlab-runner curl -s http://gitlab:80/api/v4/version
   ```

### 作业卡在 Pending

1. 检查 Runner 是否在线：GitLab → Admin → Runners
2. 检查作业标签是否匹配 Runner 标签
3. 查看 Runner 日志：`docker-compose logs -f`

### Docker executor 无法拉取镜像

1. 检查镜像地址是否正确
2. 如使用私有仓库，配置认证：
   ```toml
   [runners.docker]
     image = "your-registry/image:tag"
     
   [[runners.docker.registry_auth]]
     username = "user"
     password = "pass"
     host = "your-registry"
   ```

### 权限问题

如果遇到 Docker socket 权限问题：
```bash
# Linux 需要确保 docker.sock 可访问
sudo chmod 666 /var/run/docker.sock
```
