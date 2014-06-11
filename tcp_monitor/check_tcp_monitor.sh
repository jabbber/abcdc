WORKDIR=/openimis/SysChk
today=$(perl -e "use POSIX qw(strftime); print strftime '%Y%m%d' , localtime( time()-3600*24) ")
LOGFILE=$WORKDIR/log/tcp_monitor_check.log.$today
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
