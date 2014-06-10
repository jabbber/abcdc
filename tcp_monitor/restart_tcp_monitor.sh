WORKDIR=/openimis/SysChk
LOGFILE=$WORKDIR/log/check_tcp_monitor.log
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

#let "oldd=$(date +%s) - 10 * 24 * 3600"
#oldday=$(date --date="@$oldd" +"%a %b %e")
oldday=$(perl -e "use POSIX qw(strftime); print strftime '%a %b %e' , localtime( time()-3600*24*10) ")
let "linenum=$(grep -n -e "$oldday" $LOGFILE|head -1|cut -d: -f1) -1"
if [[ $linenum > 0 ]];then
    sed -e "1,${linenum}d" -i $LOGFILE
fi
