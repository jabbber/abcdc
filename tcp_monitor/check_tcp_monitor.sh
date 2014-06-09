WORKDIR=/openimis/SysChk
LOGFILE=$WORKDIR/log/check_tcp_monitor.log
cd $WORKDIR/bin

procNum=`ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep|wc -l`
if [ $procNum -ge 1 ]
  then
  date >> $LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE
  echo "tcp_monitor OK" >>$LOGFILE
else
  date >> $LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE
  echo "tcp_monitor Error" >>$LOGFILE
  /usr/bin/perl $WORKDIR/bin/tcp_monitor.pl -d >>$LOGFILE
   
   ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE
fi 
