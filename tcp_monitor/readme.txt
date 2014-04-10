tcp监控脚本部署说明
====================================

通用
-----------------------

1、程序目录/openimis/SysChk/bin log etc ，tcp_monitor.pl、check_tcp_monitor.sh、restart_tcp_monitor.sh放在bin目录，tcp_monitor.conf放在etc目录；

2、发送报警和连接信息的ip和port在tcp_monitor.pl文件开头部分指定，$alarm_switch/$report_switch的值设为0的话表示不发送；

3、配置文件tcp_monitor.conf用来配置各状态报警的阈值，不存在配置文件或者配置文件中不存在的项不报警，tcp_monitor.pl文件开头的$cfg_file用于指定配置文件路径；

4、tcp_monitor.pl文件开头的$debug设置为1可以开启debug日志，$debuglog用于指定debug日志路径；

5、tcp_monitor.pl文件开头的$_refresh_rate用于设置发送间隔，单位为秒；


linux/unix
------------------------

corntab 里面部署，每天中午重新启动，每隔5分钟检查
*/5 * * * * check_tcp_monitor.sh  #检查进程是否存在
2 12 * * * restart_tcp_monitor.sh #每天中午起动一次


windows
------------------------

用计划任务的方式运行，每次运行发送3次，命令为 perl /openimis/SysChk/bin/tcp_monitor.pl -c 3