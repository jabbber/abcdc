tcp��ؽű�����˵��
====================================

ͨ��
-----------------------

1������Ŀ¼/openimis/SysChk/bin log etc ��tcp_monitor.pl��check_tcp_monitor.sh��restart_tcp_monitor.sh����binĿ¼��tcp_monitor.conf����etcĿ¼��

2�����ͱ�����������Ϣ��ip��port��tcp_monitor.pl�ļ���ͷ����ָ����$alarm_switch/$report_switch��ֵ��Ϊ0�Ļ���ʾ�����ͣ�

3�������ļ�tcp_monitor.conf�������ø�״̬��������ֵ�������������ļ����������ļ��в����ڵ��������tcp_monitor.pl�ļ���ͷ��$cfg_file����ָ�������ļ�·����

4��tcp_monitor.pl�ļ���ͷ��$debug����Ϊ1���Կ���debug��־��$debuglog����ָ��debug��־·����

5��tcp_monitor.pl�ļ���ͷ��$_refresh_rate�������÷��ͼ������λΪ�룻


linux/unix
------------------------

corntab ���沿��ÿ����������������ÿ��5���Ӽ��
*/5 * * * * check_tcp_monitor.sh  #�������Ƿ����
2 12 * * * restart_tcp_monitor.sh #ÿ��������һ��


windows
------------------------

�üƻ�����ķ�ʽ���У�ÿ�����з���3�Σ�����Ϊ perl /openimis/SysChk/bin/tcp_monitor.pl -c 3