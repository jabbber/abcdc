#!/usr/bin/perl -w
#Auth: skybility
#Date: 2012-07-31
#Version: 2.3.6
#Last modify: 2013-05-08
#
#change log
#2013-05-08 执行other操作时输出命令的屏幕打印
#2013-04-25 把输出日志字符集编码设定为utf-8而不是通过环境变量判断
#2013-04-18 支持在任何目录下运行脚本，不需要切换到脚本所在目录
#2013-04-11 
#   对ssh登录时Net::OpenSSH模块可能抛出的致命错误做了防范
#   添加了ssh登录超时时间，设定为30秒
#   捕获未找到pool mamber的错误到结果列表，而不是执行错误列表
#2013-04-01 修改打印信息，操作结果和失败记录格式化输出
#2013-03-29 
#   取消所有远程命令结尾的错误重定向(2>&1),用Capture2方法取得错误输出
#   对操作前和操作后pool状态进行对比，生成操作失败记录到日志，并且在屏幕打印失败列表
#2013-03-28 程序健壮性调优，对获取f5版本和执行f5渐入渐出命令出现的异常做了处理，反馈到屏幕打印和日志
#2013-03-25 梳理优化脚本打开文件异常报错信息
#2013-03-24 
#   修改打印信息，ssh连接和远程执行命令出错都会在屏幕打印错误信息
#   other操作如果远程命令有屏幕打印，会汇总到日志的Standard list部分
#2013-03-22 处理了字符集和locale不一致导致的打印乱码问题
#2013-02-22 修复了日志文件名中日期字段月份和日期位置颠倒的问题
#2012-08-21
#   修改为多线程，并将host.cfg通过参数传递
#   多进程细化 (2012-08-18)- zhang
#   修改打印信息，并作变更前和变更后的状态对比，复核操作结果
#2012-08-22 修改日志打印方式，添加了第四个参数，允许屏幕打印结果
#2012-07-31   modify std print and cancel can't login ssh server exit


use strict;
use warnings;
use Net::OpenSSH;
use POSIX ":sys_wait_h";

#charset
#use POSIX;
#use Encode;
use utf8;
my $charset = "utf8";
my $local_charset = "utf8";
binmode(STDIN, ":encoding($charset)");
binmode(STDOUT, ":encoding($local_charset)");
binmode(STDERR, ":encoding($local_charset)");

use FindBin qw($Bin);
my $log_dir = "$Bin/result";
my $port_pro_file = "$Bin/protocol";

#check or create result dir
if(!-d $log_dir){
    mkdir("$log_dir", 0755);
}

#get log time
my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
my $log_time = sprintf("%4d%02d%02d%02d%02d%02d",$year+1900, $mon+1, $mday, $hour, $min,$sec);

our @re_check;
our $zombies = 0;
#$SIG{CHLD} = sub { $zombies++ };
$SIG{CHLD} = \&REAPER;
sub REAPER
{
    my $zpid;
    while (($zpid = waitpid(-1, WNOHANG)) > 0)
    {
        $zombies--;
        print "子进程".$zpid."处理完成!\n";
    }
}
my @outfilename;
my ($f5_version, @err_list, @std_out, @cmd_list, @fl_list);
my ($host_ip, $user, $pass);
#my ($pool_n, $ip_addr, $port, $protocol);
#add env to here for F5
$ENV{'PATH'} = "/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin$ENV{'PATH'}";

my %port_hash = (
    # "80" => "http",
    # "21" => "ftp",
);
if( -e $port_pro_file){
    open PRD, $port_pro_file or die ('error: ', "$port_pro_file: $!\n");
    while(<PRD>){
        my @arry = split(/\s+/, $_);
        $port_hash{$arry[1]} = $arry[0];

    }
    close FD;
}

#&ssh_login;
my $argc = scalar(@ARGV);
if($argc < 3){
    &usage;;
    exit;
}
#print "xxxxxx\n";
my $f = $ARGV[0];
my $host_file = $ARGV[1];
my $cfg_file = $ARGV[2];
my $prt_opt = 0;
if($ARGV[3]){
    $prt_opt = $ARGV[3];
}
if($f eq "in"){
    &ssh_login("in");


} elsif($f eq "out"){
    &ssh_login("out");


} elsif($f eq "other"){
    &ssh_login("other");


}else{
    &usage;
    exit;
}
while($zombies > 0)
{
    sleep(1);
}
print "所有子进程全部完成!\n\n";

#合并输出结果到屏幕：输出文件名：
my $report_filename = sprintf("$log_dir/changeF5-%s-%s.txt",$f, $log_time);
#open (FH, ">>$report_filename")||"Canot open the file!\n";
open (FH, ">>$report_filename")|| die ('error: ', "$report_filename: $!\n");
binmode(FH, "encoding($charset)");

if($f eq 'in' or $f eq 'out'){
    print "开始检查操作结果...\n";

    print (FH  "处理结果列表:\n");
    #合并结果文件到
    my $result_format = "%-16s %-20s %-16s %-5s %-5s %-5s %s";
    my @result_title = ("host ip","poolname","member ip","port","操作前状态","操作后状态","操作结果\n");
    printf FH $result_format,@result_title;
    my @miss_host;
    foreach my $fnn (@outfilename){

        #my $fnn = $_;
        open (FOUT, "$fnn.result.txt")||die ('error: ', "$fnn.result.txt: $!\n");
        binmode(FOUT, "encoding($charset)");
        my $len = 0;
        while(<FOUT>){
            printf FH $result_format, split(/\t+/, $_);
            $len += 1;
    #        print (FH  "$_");

        }
        close FOUT;
        unlink($fnn.".result.txt");
        if($len == 0){
            push @miss_host, $fnn;
        }
    }


    print (FH  "\n处理失败列表:\n");
    printf FH $result_format,@result_title;
    #合并结果文件到
    my @fail_list;
    foreach my $fnn (@outfilename){
        #my $fnn = $_;
        open (FOUT, "$fnn.fail.txt")||die ('error: ', "$fnn.fail.txt: $!\n");
        binmode(FOUT, "encoding($charset)");
        while(<FOUT>){
            push @fail_list, $_;
            printf FH $result_format, split(/\t+/, $_);
    #        print (FH  "$_");
        }
        close FOUT;
        unlink($fnn.".fail.txt");
    }
    if(@fail_list > 0 or @miss_host > 0){
        if (@fail_list >0){
            print "发现处理失败记录，请注意！\n处理失败列表：\n";
            printf $result_format,@result_title;
            foreach(@fail_list){
                printf $result_format, split(/\t+/, $_);
                #        print $_;
            }
        }
        if(@miss_host > 0){
            print "发现错误记录，请注意！\n出错主机列表：\n";
            foreach(@miss_host){
                my @file_path = split(/\//, $_);
                my $file_name = pop(@file_path);
                my @host_ip = split(/-/, $file_name);
                print @host_ip[0]."\n";
            }
        }
    }else{
        print "所有操作成功完成!\n";

    }

}elsif($f eq 'other'){

    print (FH  "\n处理日志:\n\n");

    foreach (@outfilename){
        my $fn = $_;
        open (FOUT, "$fn.txt")||die ('error: ', "$fn.txt: $!\n");
        binmode(FOUT, "encoding($charset)");
        my @file_path = split(/\//, $fn);
        my $file_name = pop(@file_path);
        print (FH "[HOST]".$file_name." 输出结果如下:\n");
        print (FH "======================================================================================\n");
        while(<FOUT>){
            print (FH  "$_");

        }
        close FOUT;
        unlink($fn.".txt");
    }

}

close(FH);

if($prt_opt eq 'print' or $f eq 'other'){
    open PRTFD, $report_filename or die ('error: ', "$report_filename: $!\n");
    binmode(PRTFD, "encoding($charset)");
    while(<PRTFD>){
        print $_;
    }
    close(PRTFD);
}


print "\n执行结果文件:".$report_filename."请查看!\n";
exit 0;





sub ssh_login(){
    #my @argx = @_;
    my $argx = shift; 
    #print @argx;
    #my $host_file = "./host.cfg";
    open HST, $host_file or die ('error: ', "$host_file: $!\n");


    my $count = 0;
    while(<HST>){
        if(/^#/){ next; }
        my @hs_info = split(/\s+/, $_);
        my $pid = fork(); 
        if (!defined($pid)) { 
            print "Error in fork: $!"; 
            exit 1; 
        }
        $count++;
        my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
        my $report_filename = sprintf("%s/%s-%s-%s-%s", $log_dir, $hs_info[0], $argx, $count, $log_time);
        if ($pid == 0){ 
            my @hs_info = split(/\s+/, $_);
            &Process($argx,$hs_info[0],$hs_info[1],$hs_info[2],$report_filename );
            exit 0;
        }
        else
        {
            $zombies++;
            print "第".$count."个子进程".$pid;
            print "开始对F5执行".$argx."操作。目的IP地址是:".$hs_info[0]."\n";
            push(@outfilename,$report_filename);
        }
    }
    close(HST);

}

sub Process()
{
    my @cs = @_;
    my $pt =  $cs[0];
    $host_ip = $cs[1];
    $user = $cs[2];
    $pass = $cs[3];
    my $report_ts = $cs[4];
    my $ssh = eval{ Net::OpenSSH -> new($host_ip, user => "$user", passwd => "$pass", timeout => "30") };
    if ($@){
        push(@err_list, "error[connect to host $host_ip faild]: ".$@);
    }
    elsif($ssh->error){
        push(@err_list, "error[connect to host $host_ip faild]: ".$ssh->error);
#        next;
    }
    else{
#        $f5_version = $ssh -> capture("b version |head -n 4|tail -n 1 2>&1");  #or die "remote command failed: " . $ssh->error;
        if($pt eq "in"){
            &into_opt($pt,$ssh);
            #&std_print;

        }elsif($pt eq "out"){
            &into_opt($pt,$ssh);
            #&std_print;

        }elsif($pt eq "other"){
            &other_opt($ssh);
            #&std_print;

        }
    }

    &error_print($host_ip);
    &std_print($report_ts);
}
#F5 insert server
sub into_opt(){
    my @cs = @_;
    my $argsx = $cs[0];
    my $ssh = $cs[1];
    open FD, $cfg_file or die ('error: ', "$cfg_file: $!\n");
    my @config_file = <FD>;
    close FD;

    my ($ssh_out,$ssh_err) =  $ssh -> capture2("b version");  #or die "remote command failed: " . $ssh->error;
    if ($ssh -> error){
        push(@err_list, "error[check f5 version failure]: ".$ssh_out.$ssh_err);
        return;
    }
    else{
        my @tmp = split(/\n/, $ssh_out);
        $f5_version = $tmp[3];
    }

    foreach(@config_file){
        my @pool_list;
        if(/^#|^$/){next;}
        my @v_define = split(/\s+/, $_);
        my $pool_n = $v_define[0];
        my $ip_addr = $v_define[1];
        my $port = $v_define[2];
        my $protocol;
        if(exists $port_hash{$port}){
            $protocol = $port_hash{$port};
        }else{
            $protocol = $port;
        }

        @pool_list = &do_check($ssh, $ip_addr, $protocol, $pool_n);
        if(!@pool_list){
#            push @err_list, "error: Not found $ip_addr:$protocol in pool name $pool_n ";
            my $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."不存在"."\t"."不存在"."\t跳过";
            push @re_check, $ss_y;
            push @fl_list, $ss_y;
        }
        foreach(@pool_list){
            if(/session\s+(\w+\s?\S?)/){
                my $status = $1;
#print "session status : $status\n\n";
                my $aft_sts;
                if($argsx eq "in"){
                    if($status =~ /enabled/){
                        #push @std_out, "$ip_addr in $pool_n is already enabled, Do nothing!";
                        #push @re_check, "$host_ip  $pool_n  $ip_addr  $port  $status  $status";
                        my $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐入"."\t"."已渐入"."\t跳过";
                        push @re_check,$ss_y;
                    }else{
                        my @act_ex = &version_judge("$pool_n", "$ip_addr", "$port");
                        push @cmd_list, $act_ex[0];

                        #last;

                        ($ssh_out,$ssh_err) = $ssh->capture2($act_ex[0]); #or die "remote command failed: " . $ssh->error;
                        if ($ssh -> error){
                            push(@err_list, "error[$act_ex[0]]: ".$ssh_out.$ssh_err);
                        }

                        my @after_check = &do_check($ssh, $ip_addr, $protocol, $pool_n);
                        foreach(@after_check){
                            if(/session\s+(\w+\s?\S?)/){
                                $aft_sts = $1;
                            }
                        }
                        my $ss_y;
                        if($aft_sts !~ /enabled/){
                            $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐出"."\t"."已渐出"."\t失败";
                            push @fl_list, $ss_y;
                        }else{
                            $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐出"."\t"."已渐入"."\t成功";
                        }
                        push @re_check, $ss_y;

                    }
                }elsif($argsx eq "out"){
                    if($status !~ /enabled/){
                        #push @std_out, "$ip_addr in $pool_n is already disabled, Do nothing!";
                        my $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐出"."\t"."已渐出"."\t跳过";
                        push @re_check,$ss_y;
                    }else{
                        my @act_ex = &version_judge("$pool_n", "$ip_addr", "$port");
                        push @cmd_list, $act_ex[1];
                        #last;

                        ($ssh_out,$ssh_err)  = $ssh->capture2($act_ex[1]); # or die "remote command failed: " . $ssh->error;
                        if ($ssh -> error){
                            push(@err_list, "error[$act_ex[1]]: ".$ssh_out.$ssh_err);
                        }
                        my @after_check = &do_check($ssh, $ip_addr, $protocol, $pool_n);
                        foreach(@after_check){
                            if(/session\s+(\w+\s?\S?)/){
                                $aft_sts = $1;
                            }
                        }
                        my $ss_y;    
                        if($aft_sts =~ /enabled/){
                            $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐入"."\t"."已渐入"."\t失败";
                            push @fl_list, $ss_y;
                        }else{
                            $ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t"."已渐入"."\t"."已渐出"."\t成功";
                        }
                        push @re_check, $ss_y;
                    }
                }
            }
        }
    }
}

#状态查询
sub do_check(){
    my @lst = @_;
    my $ssh = $lst[0];
    my $ip = $lst[1];
    my $prc = $lst[2];
    my $pool_name_s = $lst[3];
    my (@p_list, $get);
    my ($ssh_out,$ssh_err) = $ssh -> capture2("b pool $pool_name_s show");
    if ($ssh -> error){
        push(@err_list, "error[check pool status failure]: $ssh_out$ssh_err");
    }
    my @d_content = split(/\n/, $ssh_out);
#    my @d_content = $ssh -> capture("b pool $pool_name_s show");
    foreach(@d_content){
        if(/($ip):$prc/){
            $get = 1;
            push @p_list, $_;
            next;
        }

        if($get){
            if($_ !~ /POOL\s+MEMBER/){
                push @p_list, $_;
            }else{
                last;
            }
        }
    }
    return @p_list;

}



sub other_opt(){
    #my $cfg_file = "./f5.cfg";
    my $ssh = shift;
    my $other_cmd;
    open FD, "$cfg_file" or die ('error: ', "$cfg_file: $!\n");
    while(<FD>){
        chomp;
        if(/^#/){ next; }
        $other_cmd = $_;
        print "Command: $_  in $host_ip\n";
        my($out,$err) = $ssh -> capture2($other_cmd); #or die "remote command failed: " . $ssh->error;
        if ($ssh -> error){
            push(@err_list, "error[$other_cmd]:".$out.$err);
        }
        else{
            push(@std_out, "[$other_cmd]:\n".$out);
        }
        #print "\n\n";
        push @cmd_list, $_;
    }
    close FD;
}


#F5 version judge and excute
sub version_judge(){
    my ($p_n, $ip, $p_t) = @_;
    #my $version = `b version |head -n 4|tail -n 1 2>&1`;
    #chomp $version;
    my ($in_ex, $out_ex);
    if($f5_version =~ /10.2.4/){
        #print "$f5_version\n";
        $in_ex = "b pool $p_n members $ip:$p_t up session user enabled";
        $out_ex = "b pool $p_n members $ip:$p_t down session user disabled";
    }elsif($f5_version =~ /10.1.0/){
        #print "$f5_version\n";
        $in_ex = "b pool $p_n members $ip:$p_t up session enable";
        $out_ex = "b pool $p_n members $ip:$p_t down session disable";
    }
    else{
        push(@err_list, "error[unsupport f5 version]: $f5_version");
    }
    return ($in_ex, $out_ex);

}

sub usage{
    print "Usage: $0 [OPTION]...[HOST FILE]...[F5 FILE]...[print]...\n";
    print "options: {in|out|other}\n";
}

sub error_print(){
    my $host_ip = shift;
    if (@err_list != 0){
        print $host_ip." 操作出错,请特别留意:\n";
        foreach(@err_list){
            print "$_\n";
        }
    }
}

sub std_print(){
    my $argd = shift;
    open WRD, ">>$argd.txt" or die ('error: ', "$argd.txt: $!\n");
    binmode(WRD, "encoding($charset)");

    if(@err_list){
        print (WRD "错误列表:\n");
        foreach (@err_list){
            print (WRD "$_\n");
        }
        print WRD "\n";
    }

    print (WRD "已执行命令列表:\n");
    foreach (@cmd_list){
        print (WRD "$_\n");
    }
    print WRD "\n";

    print (WRD "命令输出列表:\n");
    foreach (@std_out){
        print (WRD "$_\n");
    }
    print WRD "\n";
    close WRD;

    open FTOOH, ">>$argd.result.txt" or die ('error: ', "$argd.result.txt: $!\n");
    binmode(FTOOH, "encoding($charset)");
    foreach(@re_check){
        print FTOOH "$_\n";
    }
    close FTOOH;

    open FTOOH, ">>$argd.fail.txt" or die ('error: ', "$argd.fail.txt: $!\n");
    binmode(FTOOH, "encoding($charset)");
    foreach(@fl_list){
        print FTOOH "$_\n";
    }
    close FTOOH;
}

