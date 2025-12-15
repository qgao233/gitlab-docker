参考：https://www.cnblogs.com/chenhy-wj/p/10483078.html

GitLab是由GitLabInc.开发，使用MIT许可证的基于网络的Git仓库管理工具，且具有wiki和issue跟踪功能。使用Git作为代码管理工具，并在此基础上搭建起来的web服务。

 

一、Gitlab镜像文件下载：

可参考此处下载运行：https://docs.gitlab.com/omnibus/docker/

我的运行方式：

docker run -dit --hostname gitlab.chen.com --publish 1443:443  --publish 18080:80  --name gitlab --restart always --volume /data/gitlab/etc:/etc/gitlab --volume /data/gitlab/logs:/var/log/gitlab --volume /data/gitlab/data:/var/opt/gitlab -v /data/gitlab/databases:/data/gitlab/databases  8be4d926d44e

 

二、安装postgresql:

#yum install postgresql94-server.x86_64 postgresql94-contrib.x86_64 –y

#userdel postgres

#groupadd postgres

#useradd –g postgres postgres

修改启动配置文件：

#vim /usr/lib/systemd/system/postgresql-9.4.service

Environment=PGDATA=/data/pgsql/data/ 数据库文件存放目录

#mkdir –p /data/pgsql/data

#chown postgres:postgres –R /data/pgsql/data/

初始化数据库（必须以postgres用户初始化）

#/usr/pgsql-9.4/bin/initdb -E UNICODE -D /data/pgsql/data/

编辑postgresql.conf配置文件，修改数据库默认监听地址和端口：

listen_addresses = 'localhost'  改成 listen_addresses = '*'

port = 5432 默认5432，根据自己需求来改，我这使用默认端口

编辑pg_hba.conf配置文件，告诉数据库服务允许哪些客户端连接自己：

以下是我的配置：



备注：md5表示需要密码验证，可以设置为trust（本地可以直接psql -U postgres 登陆）

 

设置开机自启：

#systemctl enable postgresql-9.4.service

启动数据库服务：

#systemctl start postgresql-9.4.service

 

登陆数据库：

#su – postgres

#psql -U postgres



 

三、Redis安装

 

#mkdir –p /data/redis/{etc,logs,databases}

#tar xf redis-4.0.9.tar.gz

#cd redis-4.0.9

#make && make install

#cp redis.conf /data/redis/etc

修改redis配置文件：

dir /data/redis/databases

requirepass *****

logfile "/data/redis/logs/redis-slow.log"

 

启动redis:

#redis-server /data/redis/etc/redis.conf &

 

 

修改gitlab配置文件：

 

vim /data/gitlab/etc/gitlab.rb

 

修改数据库配置（docker镜像使用内置postgresql，建议分离出来，后期方便升级gitlab）：

postgresql['enable'] = false  #默认为true,设置为false

gitlab_rails['db_adapter'] = "postgresql"

gitlab_rails['db_encoding'] = "utf8"

gitlab_rails['db_host'] = "postgresql数据库服务端ip"

gitlab_rails['db_port'] = 5432

gitlab_rails['db_username'] = "postgres"

gitlab_rails['db_password'] = "chen1234"

gitlab_rails['db_database'] = "postgres"

 

修改gitlab redis配置（我使用的也是外置redis）:

redis['enable'] = false  #和postgresql同理

gitlab_rails['redis_host'] = "x.x.x.x"

gitlab_rails['redis_port'] = 6379

gitlab_rails['redis_password'] = "****"

 

配置发送邮件服务：

gitlab_rails['smtp_enable'] = true

gitlab_rails['smtp_address'] = "smtp.exmail.qq.com"

gitlab_rails['smtp_port'] = 465

gitlab_rails['smtp_user_name'] = "xxx"

gitlab_rails['smtp_password'] = "****"

gitlab_rails['smtp_domain'] = "smtp.qq.com"

gitlab_rails['smtp_authentication'] = "login"

gitlab_rails['smtp_enable_starttls_auto'] = true

gitlab_rails['smtp_tls'] = true

user['git_user_email'] = "xxx"

gitlab_rails['gitlab_email_from'] = 'xxx'

 

设置数据存储目录：

git_data_dirs({

  "default" => {

    "path" => "/data/gitlab/databases"

   }

})

 

 

刷新gitlab配置:

1.       进入容器：docker exec -it 49fd5e4ff215 /bin/bash

2.       刷新配置文件：gitlab-ctl reconfigure

3.       重启gitlab服务: gitlab-ctl  restart