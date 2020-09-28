# MySQL_Group_Replication_FullAutoInstall
Full-automatic deployment of Remote MGR is realized
## 支持的操作系统和数据库版本

操作系统：LINUX 6/7
数据库版本：MYSQL5.7.17以上

## 使用说明

### 前期准备工作

 1.上传脚本，并赋予脚本执行权限

 2.建议提供(2N+1)个数据库实例，必须分别开启log-bin特性

 3.配置并生效mysql客户端环境变量

 4.安装sshpass

```
shell> yum install -y epel-release
shell> yum repolist
shell> yum install -y sshpass
```

 5.使用sshpass连接要部署的异机

```
shell> ssh root@192.168.106.128
shell> ssh root@192.168.106.130
shell> ssh root@192.168.106.131
```

 保证能够成功连接到所有你要部署的异机

```
shell> sshpass -phzmcdba ssh root@192.168.106.128
shell> sshpass -phzmcdba ssh root@192.168.106.130
shell> sshpass -phzmcdba ssh root@192.168.106.131
```

 检测完成，所有异机都能成功连接

 6.配置域名解析

```
shell> vi /etc/hosts
192.168.106.128 mysql
192.168.106.130 mysql2
192.168.106.131 mysql3
```

 在所有主机上配置对应所有域名解析

### 脚本参数说明

| 参数    | 注释             | 说明                                         |
| ------- | ---------------- | -------------------------------------------- |
| d       | db password             | 指定MySQL选项文件。若指定多个，请用逗号隔开。     |
| f       | option file         | 指定MySQL数据库系统账户密码。若指定多个，请用逗号隔开。 |
| i       | ipaddress     | 必须指定MGR所有MySQL主机IP地址，用逗号隔开。         |
| o       | os password | 指定MySQL主机系统账户密码，若指定多个，请用逗号隔开。 |
| P       | db port           | 指定MySQL实例端口，若指定多个，请用逗号隔开。   |
| t       | tag       | 指定MySQL选项文件备份标签。                               |
| McDeBuG | debug         |	用于此脚本调试                                              |

注意：如果密码，选项文件，主机root账户密码，端口号都相同，可以只写一个。但是只要一个不同，则需要全部都写完整。

### 脚本使用demo

 1.密码，选项文件，主机root账户密码，端口号都相同

```
shell> ./MGRremoteAutoInstallGA.sh -dAbcd321# -f/etc/my.cnf -i192.168.239.57,192.168.239.58,192.168.239.59 -ohzmcdba -P3306 -tmcbak
```

 2.密码，选项文件，主机root账户密码，端口号其中一个不同

```
shell> ./MGRremoteAutoInstallGA.sh -dAbcd321#,Abcd321#,Abcd321# -f/etc/my.cnf,/etc/my.cnf,/etc/my.cnf -i192.168.239.57,192.168.239.58,192.168.239.59 -ohzmcdba,hzmcdba,hzmcdba -P3306,3306,3306 -tmcbak
```

### 脚本运行后参数(不区分大小写)

1.是否运行脚本

```
Welcome to the MySQL group replication Install or Deinstall , please check? [Y/N]
```

2.选择运行模式

```
Welcome to Local install, deinstall, precheck, test, or switch multi primarys, please check? [I/D/P/T/S]
```

| 选择 | 注释                  | 功能                                                         |
| ---- | --------------------- | ------------------------------------------------------------ |
| I    | install               | 自动部署MGR。                                                |
| D    | deinstall             | 自动卸载MGR。如果首次部署失败，必须先卸载再重新部署。               |
| P    | precheck              | 预检查。部署之前先执行预检并确保通过。                   |
| T    | test                  | 检查MGR组复制各成员状态。 |
| S    | switch multi primarys | 将单主模式切换为多主。                                           |
