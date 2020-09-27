# MySQL_Group_Replication_FullAutoInstall
Full-automatic deployment of Local MGR is realized
## 支持的操作系统和数据库版本

操作系统：LINUX 6/7
数据库版本：MYSQL5.7.17以上

## 使用说明

### 前期准备工作

 1.上传脚本，并赋予脚本执行权限

 2.建议提供3个数据库实例，必须分别开启log-bin特性

 3.配置并生效mysql客户端环境变量

### 脚本参数说明

| 参数    | 注释       | 说明                                                         |
| ------- | ---------- | ------------------------------------------------------------ |
| f       | 配置文件   | 请填写数据库实例对应的配置文件，用逗号隔开。如果使用单个配置文件来实现多实例，则只需要填写一个选项文件，不过后面必须用-s参数标明对应实例。 |
| p       | 密码       | 密码。请填写数据库实例对应的密码，用逗号隔开。如果所有实例的密码全都相同，则可只填写一次密码。 |
| P       | 端口号     | 请填写数据库实例对应的端口号，用逗号隔开。                   |
| s       | 选项后缀   | 如果使用单个配置文件来实现多实例，则需要用-s标明数据库实例在配置文件中对应的[mysqld] |
| t       | 备份后缀名 | 自定义后缀名                                                 |
| McDeBuG | 调试模式   |                                                              |

### 脚本使用demo

 1.使用单个配置文件来实现多实例，密码相同

```
./MGRlocalAutoInstallGA.sh -f/etc/my.cnf -pAbcd321# -P33071,33072,33073 -s571,572,573 -tmcbak
```

 2.使用多个配置文件，密码不同

```
./MGRlocalAutoInstallGA.sh -f/etc/my33071.cnf,/etc/my33072.cnf,/etc/my33073.cnf -pAbcd321#,Abcd321#,Abcd321# -P33071,33072,33073 -tmcbak
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
| D    | deinstall             | 自动卸载MGR/回滚。部署失败后也要先回滚来恢复。               |
| P    | precheck              | 预检查。部署前先预检查一遍是否成功。                         |
| T    | test                  | 测试数据库实例的MGR状态。可在部署或回滚后测试状态判断是否成功。 |
| S    | switch multi primarys | 切换多主模式.                                                |
