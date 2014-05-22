#!/usr/bin/env sh

os=`uname|tr -d '\n'`
user=`whoami|tr -d '\n'`

if [[ $user != 'root' ]];then
    echo "Error: not run this script by root!"
    exit 1
fi

case "$os" in
    Linux)
	cron_file=/var/spool/cron/tabs/root
    ;;
    AIX)
	cron_file=/var/spool/cron/crontabs/root
    ;;
    *)
        echo "Error: unknow os!"
        exit 1
    ;;
esac

if [[ -f $cron_file && -w $cron_file && -r $cron_file ]]; then
    touch $cron_file
else
    echo "Error: can not read and write $cron_file ."
    exit 1
fi

modify=0
cronjob=`grep -e "/openimis/SysChk/bin/check_tcp_monitor.sh" $cron_file`
if [[ $? != 0 ]]; then
    case "$os" in
        Linux)
            echo "add */5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh to crontab"
            echo "*/5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh" >> $cron_file
        ;;
        AIX)
            echo "add 0,5,10,15,20,25,30,35,40,45,50,55 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh to cron"
            echo "0,5,10,15,20,25,30,35,40,45,50,55 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh" >> $cron_file
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

cronjob=`grep -e "/openimis/SysChk/bin/restart_tcp_monitor.sh" $cron_file`
if [[ $? != 0 ]]; then
    echo "add 2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh to crontab"
    echo "2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh" >> $cron_file
    modify=1
else
    echo "$cronjob exist"
fi

#import tmp to crontab
if [[ $modify == 1 ]];then
    echo "reload crontab"
    case "$os" in
        Linux)
            crontab -u root $cron_file
        ;;
        AIX)
            crontab -e root<<!
:x
!
        ;;
        *)
            echo "Error: unknow os!"
            exit 1
        ;;
    esac
else
    echo "crontab have not change"
fi


