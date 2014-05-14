#!/usr/bin/env sh

os=`uname|tr -d '\n'`
user=`whoami|tr -d '\n'`
tmp_file=/tmp/add_cron_tcp_monitor.tmp

if [[ $user != 'root' ]];then
    echo "Warning: not run this script by root!"
fi

modify=0
crontab -l|sed '/^#/d' > $tmp_file
cronjob=`grep -e "/openimis/SysChk/bin/check_tcp_monitor.sh" $tmp_file`
if [[ $? != 0 ]]; then
    case "$os" in
        Linux)
            echo "add */5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh to crontab"
            echo "*/5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh" >> $tmp_file
        ;;
        AIX)
            echo "add 0,5,10,15,20,25,30,35,40,45,50,55 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh to cron"
            echo "0,5,10,15,20,25,30,35,40,45,50,55 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh" >> $tmp_file
        ;;
        *)
            echo "unknow os!"
            exit 1
        ;;
    esac
    modify=1
else
    echo "$cronjob exist"
fi

cronjob=`grep -e "/openimis/SysChk/bin/restart_tcp_monitor.sh" $tmp_file`
if [[ $? != 0 ]]; then
    echo "add 2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh to crontab"
    echo "2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh" >> $tmp_file
    modify=1
else
    echo "$cronjob exist"
fi

#import tmp to crontab
if [[ $modify == 1 ]];then
    echo "reload crontab"
    crontab $tmp_file
else
    echo "crontab have not change"
fi

rm $tmp_file
