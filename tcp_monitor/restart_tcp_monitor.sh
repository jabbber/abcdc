WORKDIR=/openimis/SysChk
today=$(perl -e "use POSIX qw(strftime); print strftime '%Y%m%d' , localtime( time()-3600*24) ")
LOGFILE=$WORKDIR/log/tcp_monitor_check.log.$today

find $WORKDIR/log -mtime +10 -name "tcp_monitor_*.log.*" -exec rm -f {} \;

cd $WORKDIR/bin

  date >> $LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE
  echo "kill tcp_monitor" >>$LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep |awk '{print $2}' |xargs kill -9
  echo "restart tcp_monitor begin" >>$LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE
  /usr/bin/perl $WORKDIR/bin/tcp_monitor.pl -d >>$LOGFILE
 
  echo "restart tcp_monitor end" >>$LOGFILE
  ps -ef|grep perl|grep tcp_monitor.pl|grep root|grep -v grep >>$LOGFILE

