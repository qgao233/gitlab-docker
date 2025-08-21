# GitLab Docker 部署

通过Docker Compose快速部署GitLab社区版的完整解决方案。

## 文件说明

- `docker-compose.yml` - Docker Compose配置文件
- `start_gitlab.cmd` - Windows启动脚本
- `start_gitlab.sh` - Linux/Mac启动脚本
- `stop_gitlab.cmd` - Windows停止脚本
- `stop_gitlab.sh` - Linux/Mac停止脚本
- `sketch.md` - 部署参考文档

## 快速开始

### Windows系统

**启动GitLab:**
1. 确保Docker Desktop已安装并运行
2. 双击运行 `start_gitlab.cmd` 或在命令提示符中执行：
   ```cmd
   start_gitlab.cmd
   ```

**停止GitLab:**
```cmd
stop_gitlab.cmd
```

### Linux/Mac系统

**启动GitLab:**
1. 确保Docker和Docker Compose已安装
2. 给脚本添加执行权限并运行：
   ```bash
   chmod +x start_gitlab.sh
   ./start_gitlab.sh
   ```

**停止GitLab:**
```bash
chmod +x stop_gitlab.sh
./stop_gitlab.sh
```

### 手动部署

如果不想使用脚本，也可以手动执行：

```bash
# 创建数据目录
mkdir -p gitlab/{config,logs,data}

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps
```

## 宿主机访问信息

- **Web访问地址**: http://localhost:9980
- **SSH端口**: 9922
- **初始用户名**: root
- **初始密码获取**:
  ```bash
  # Linux/Mac
  docker exec gitlab cat /etc/gitlab/initial_root_password
  
  # Windows
  docker exec gitlab type /etc/gitlab/initial_root_password
  ```

## 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f gitlab

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 进入容器
docker exec -it gitlab /bin/bash

# 更新GitLab
docker-compose pull
docker-compose up -d
```

## 配置说明

### 端口映射

- `9980:80` - HTTP访问端口
- `9922:22` - SSH Git克隆端口
- `9443:443` - HTTPS端口（可选）

### 数据持久化

所有GitLab数据存储在 `./gitlab/` 目录下：

- `gitlab/config/` - 配置文件
- `gitlab/logs/` - 日志文件
- `gitlab/data/` - 数据文件

### 性能优化

配置文件已包含以下优化：

- 禁用了监控组件以节省内存
- 优化了数据库连接数
- 设置了合适的worker进程数
- 限制了内存使用

## 系统要求

- **最小内存**: 4GB RAM
- **推荐内存**: 8GB+ RAM
- **存储空间**: 至少10GB可用空间
- **操作系统**: Windows 10+, Linux, macOS

## 故障排除

### GitLab无法启动

1. 检查内存是否足够（至少4GB）
2. 确保端口9980和9922未被占用
3. 查看详细日志：`docker-compose logs gitlab`

### 忘记root密码

```bash
# 进入容器
docker exec -it gitlab bash

# 进入Rails控制台
gitlab-rails console -e production

# 重置密码
user = User.where(id: 1).first
user.password = '新密码'
user.password_confirmation = '新密码'
user.save!
exit
```

### 国际化切换

登录进去后，可以从preference中找到语言进行更改，之后刷新。

### 修改访问地址（可选）

编辑 `docker-compose.yml` 文件，修改 `external_url` 配置：

```yaml
# 更改gitlab的默认访问地址，不改则是默认80端口（这里是容器内运行，所以不需要更改，会在下面映射宿主机的9980到容器的80端口）
GITLAB_OMNIBUS_CONFIG: |
  external_url 'http://your-domain.com:9980'
```

然后重新启动服务：

```bash
docker-compose down
docker-compose up -d
```

## 安全建议

1. 首次登录后立即修改root密码
2. 创建普通用户账号，避免使用root进行日常操作
3. 定期备份 `gitlab/` 目录
4. 如果在生产环境使用，建议配置HTTPS
5. 考虑使用反向代理（如Nginx）

## 备份与恢复

### 备份

```bash
# 创建备份
docker exec -t gitlab gitlab-backup create

# 备份位置
# 备份文件位于: gitlab/data/backups/
```

### 恢复

```bash
# 停止服务
docker-compose down

# 将备份文件放到 gitlab/data/backups/ 目录

# 启动服务
docker-compose up -d

# 恢复数据
docker exec -it gitlab gitlab-backup restore BACKUP=备份文件名
```


# 仓库连接

## 连接前的操作

任意目录生成ssh证书(取名`id_rsa_gitlab`，避免覆盖其他已生成密钥)
```bash
ssh-keygen -t rsa -C "邮箱"
```
把生成的密钥对放入`~/.ssh/`目录后，再更改`~/.ssh/`目录的`config`文件：
```config
Host localhost
    User git
    Port 9922
    IdentityFile ~/.ssh/id_rsa_gitlab
```
测试：
```bash
ssh -T git@localhost -p 9922
```

## 绑定远程仓库与本地仓库

![](./gitlab仓库的远程与本地绑定.png)


# 额外提醒

## 容器之间互相通信

如果要容器之间互相通信，建议创建自定义网络，比如：

```bash
docker network create gitlab_network
```

并在docker-compose.yml中进行更改：

```config
services:
  serviceA:
    image: nginx
    networks:
      - gitlab_network

networks:
  gitlab_network:
    external: true
    name: gitlab_network
```

```config
services:
  serviceB:
    image: nginx
    networks:
      - gitlab_network

networks:
  gitlab_network:
    external: true
    name: gitlab_network
```

容器 A 可以通过服务名称 serviceB 访问容器 B。例如，如果容器 B 是一个 Web 服务，容器 A 可以通过以下方式访问容器 B：
```bash
curl http://serviceB
```

## 配置webhook报错

### Urlis blocked: Requests to the local network are not allowed

进入 Admin area => Settings => Network ，然后点击 Outbound requests 右边 的“expand”按钮，勾选允许对本地的请求，并点击 Save changes按钮即可