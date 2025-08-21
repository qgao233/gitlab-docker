Docker部署GitLab
1
2
3
通过Docker部署GitLab可以快速搭建一个高效的代码托管平台。以下是详细的步骤：

1. 拉取GitLab镜像

首先，下载最新的GitLab社区版镜像：

docker pull gitlab/gitlab-ce:latest
2. 启动GitLab容器

运行以下命令启动GitLab容器，并映射端口和挂载数据目录：

docker run -d \
-p 9980:80 \
-p 9922:22 \
--name gitlab \
--restart always \
-v /home/gitlab/config:/etc/gitlab \
-v /home/gitlab/logs:/var/log/gitlab \
-v /home/gitlab/data:/var/opt/gitlab \
gitlab/gitlab-ce:latest
-p 9980:80：将容器的HTTP服务映射到宿主机的9980端口。

-p 9922:22：将容器的SSH服务映射到宿主机的9922端口。

--restart always：确保容器在重启后自动启动。

3. 配置GitLab

进入容器并修改配置文件：

docker exec -it gitlab /bin/bash
vi /etc/gitlab/gitlab.rb
修改以下内容：

external_url 'http://<宿主机IP>:9980'
gitlab_rails['gitlab_shell_ssh_port'] = 9922
保存后使配置生效：

gitlab-ctl reconfigure
4. 重启并访问

重启GitLab服务：

gitlab-ctl restart
在浏览器中访问 http://<宿主机IP>:9980，首次登录时会提示设置root密码。

5. 修改默认密码

如果需要手动修改root密码，执行以下命令：

docker exec -it gitlab bash
gitlab-rails console -e production

# 修改密码
user = User.where(id: 1).first
user.password = '新密码'
user.save!
exit
6. 注意事项

宿主机需至少分配 4GB内存，否则可能无法正常启动。

如果使用云服务器，请确保开放对应端口（如9980和9922）。

完成以上步骤后，您即可通过Docker成功部署GitLab！