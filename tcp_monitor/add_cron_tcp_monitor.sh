#!/bin/bash

cron_file=/var/spool/cron/tabs/root
if [ -w $cron_file ]; then
    os='linux'
    echo "OS is linux"
    echo "modify $cron_file"
else
    cron_file=/var/spool/cron/crontabs/root
    if [ -w $cron_file ]; then
        os='aix'
        echo "OS is aix"
        echo "modify $cron_file"
    else
        echo "Error: no found crontab config file!"
        exit 1
    fi
fi

cronjob=`grep -e "/openimis/SysChk/bin/check_tcp_monitor.sh" $cron_file`
if [[ $? != 0 ]]; then
    if [[ $os == 'linux' ]]; then
        echo "add */5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh to cron"
        echo "*/5 * * * * /openimis/SysChk/bin/check_tcp_monitor.sh" >> $cron_file
    elif [[ $os == 'aix' ]]; then
        echo "add 0,5,10,15,20,25,30,35,40,45,50,55 /openimis/SysChk/bin/check_tcp_monitor.sh to cron"
        echo "0,5,10,15,20,25,30,35,40,45,50,55 /openimis/SysChk/bin/check_tcp_monitor.sh" >> $cron_file
    fi
else
    echo "$cronjob exist"
fi
cronjob=`grep -e "/openimis/SysChk/bin/restart_tcp_monitor.sh" $cron_file`
if [[ $? != 0 ]]; then
    echo "add 2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh to cron"
    echo "2 12 * * * /openimis/SysChk/bin/restart_tcp_monitor.sh" >> $cron_file
else
    echo "$cronjob exist"
fi
