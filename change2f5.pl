#!/usr/bin/perl -w
#Auth: skybility
#Date: 2012-07-31
#Version: 2.1.2
#Last modify: 2013-02-22
#
#change log
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
my $port_pro_file = "/home/perl_work/protocol";
if( -e $port_pro_file){
	open PRD, $port_pro_file or die "can't open the file $!";
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
my $prt_opt;
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
      print "所有子进程全部完成!\n";

#合并输出结果到屏幕：输出文件名：
my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
my $log_dir = "result";
if(!-d $log_dir){
	mkdir("$log_dir", 0755);

}
my $report_filename = sprintf("./$log_dir/changeF5-%s-%4d%02d%02d%02d%02d%02d.txt",$f, $year+1900, $mon+1, $mday, $hour, $min,$sec);

print "执行结果文件:".$report_filename."请查看!\n";
#open (FH, ">>$report_filename")||"Canot open the file!\n";
open (FH, ">>$report_filename")|| Die (1, "open(FH): $!\n");
 

print (FH  "处理结果列表:\n");
#合并结果文件到
foreach my $fnn (@outfilename){

    #my $fnn = $_;
    open (FOUT, $fnn."result")||die "Cannot open the file!\n";
    while(<FOUT>){
         print (FH  "$_");

    }
    close FOUT;
    unlink($fnn."result");


}

print (FH  "\n处理日志:\n");

foreach (@outfilename){
    my $fn = $_;
    open (FOUT, "$fn")||die "Cannot open the file!\n";
    print (FH $fn."输出结果如下:\n");
    while(<FOUT>){
         print (FH  "$_");

    }
    close FOUT;
    unlink($fn);

}





close(FH);

if($prt_opt){
	if($prt_opt eq "print"){
		open PRTFD, $report_filename or die "can't open the file $!\n";
		while(<PRTFD>){
			print $_;
		}
	}

}
exit 0;





sub ssh_login(){
	#my @argx = @_;
	my $argx = shift; 
	#print @argx;
	#my $host_file = "./host.cfg";
	open HST, $host_file or die "can't open the file $!";
	
      
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
                my $report_filename = sprintf($count."-%4d%02d%02d%02d%02d%02d.txt", $year+1900, $mon+1, $mday, $hour, $min,$sec);
		if ($pid == 0){ 
			my @hs_info = split(/\s+/, $_);
			&Process($argx,$hs_info[0],$hs_info[1],$hs_info[2],$report_filename );
                        exit 0;
		}
             else
             {
                   $zombies++;
                   print "第".$count."个子进程".$pid;
                   print "开始对F5执行".$argx."操作目的IP地址是:".$hs_info[0]."\n";
                   push(@outfilename,$hs_info[0]."-".$argx."-".$report_filename);
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
		    my $ssh = Net::OpenSSH -> new($host_ip, user => "$user", passwd => "$pass");
			if($ssh->error){
				push @err_list, "error: connect to host $host_ip faild";
				next;
			}
			$f5_version = $ssh -> capture("b version |head -n 4|tail -n 1 2>&1");  #or die "remote command failed: " . $ssh->error;
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
			 
            
            &std_print($host_ip."-".$pt."-".$report_ts);
}
#F5 insert server
sub into_opt(){
        my @cs = @_;
	my $argsx = $cs[0];
        my $ssh = $cs[1];;
	my ($p_f);
	#my ($p_f, @d_content);
	my @f5_ip_status;
	open FD, $cfg_file or die "can't open the file $!";
	my @config_file = <FD>;
	#while(<FD>){
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
		#下面获取pool列表注释，修改为子例程方式
		# @d_content = $ssh -> capture("b pool $pool_n show 2>&1");  #or die "remote command failed: " . $ssh->error;
		# my $get = 0;
		# foreach(@d_content){
			# if(/($ip_addr):$protocol/){
				# $get = 1;
				# push @pool_list, $_;
				# next;
			# }
			
			# if($get){
				# if($_ !~ /POOL\s+MEMBER/){
					# push @pool_list, $_;
				# }else{
					# last;
				# }
			# }
		# }
		@pool_list = &do_check($ssh, $ip_addr, $protocol, $pool_n);
#print "$_\n" foreach @pool_list;
#print "xxoo\n";	
		if(!@pool_list){
			push @err_list, "Not found $ip_addr in pool name $pool_n ";
		}
		foreach(@pool_list){
			if(/session\s+(\w+\s?\S?)/){
				#@f5_ip_status = $_;
				my $status = $1;
#print "session status : $status\n\n";
				my $aft_sts;
				if($argsx eq "in"){
					if($status =~ /enabled/){
						#push @std_out, "$ip_addr in $pool_n is already enabled, Do nothing!";
						#push @re_check, "$host_ip  $pool_n  $ip_addr  $port  $status  $status";
						my @ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t".$status."\t".$status;
						push @re_check,@ss_y;
					}else{
								my @act_ex = &version_judge("$pool_n", "$ip_addr", "$port");
						
						
						#last;

					$ssh->system("$act_ex[0]"); #or die "remote command failed: " . $ssh->error;
					my @after_check = &do_check($ssh, $ip_addr, $protocol, $pool_n);
					foreach(@after_check){
						if(/session\s+(\w+\s?\S?)/){
							$aft_sts = $1;
						}
					
					
					}
					push @re_check, "$host_ip  $pool_n  $ip_addr  $port  $status  $aft_sts";

                                        #请在此查询一次状态，判断是否已经是要去的状态!!!! 

					push @cmd_list, $act_ex[0];
					#print "Excute: $act_ex[0] in Host: $host_ip\n";
					
					}
				}elsif($argsx eq "out"){
					if($status !~ /enabled/){
						#push @std_out, "$ip_addr in $pool_n is already disabled, Do nothing!";
						my @ss_y = $host_ip."\t".$pool_n."\t".$ip_addr."\t".$port."\t".$status."\t".$status;
						push @re_check,@ss_y;
					}else{
								my @act_ex = &version_judge("$pool_n", "$ip_addr", "$port");
						push @cmd_list, $act_ex[1];
						#last;

					$ssh->system("$act_ex[1]")  or die "remote command failed: " . $ssh->error;
					my @after_check = &do_check($ssh, $ip_addr, $protocol, $pool_n);
					foreach(@after_check){
						if(/session\s+(\w+\s?\S?)/){
							$aft_sts = $1;
						}
					
					
					}
					push @re_check, "$host_ip  $pool_n  $ip_addr  $port  $status  $aft_sts";
					
					
					#print "Excute: $act_ex[1] in $host_ip\n";
                                        #请在此查询一次状态，判断是否已经是要去的状态!!!! 
					}
				}
			}

		}
	
	}
	close FD;

}

#状态查询
sub do_check(){
	my @lst = @_;
	my $ssh = $lst[0];
	my $ip = $lst[1];
	my $prc = $lst[2];
	my $pool_name_s = $lst[3];
	my (@p_list, $get);
	my @d_content = $ssh -> capture("b pool $pool_name_s show 2>&1");
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
	open FD, "$cfg_file" or die "can't open the configure file $!";
	while(<FD>){
		chomp;
		if(/^#/){ next; }
		$other_cmd = $_;
		print "Command: $_  in $host_ip\n";
		$ssh -> system($other_cmd); #or die "remote command failed: " . $ssh->error;
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

	return ($in_ex, $out_ex);

}

sub usage{
	print "Usage: $0 [OPTION]...[HOST FILE]...[F5 FILE]...[print]...\n";
	print "options: {in|out|other}\n";
}

sub std_print(){
	my $argd = shift;
	open WRD, ">>./$argd" or die "can't $!";
	print (WRD "Command list is:\n");
	foreach (@cmd_list){
		print (WRD "$_\n");
	}

	print (WRD "Error list is:\n");
	foreach (@err_list){
		print (WRD "$_\n");
	}

	print (WRD "Standard list is:\n");
	foreach (@std_out){
		print (WRD "$_\n");
	}
	close WRD;


        my $fn = $argd."result";

	open FTOOH, ">>./$fn" or die "Canot open the file!\n";
	foreach(@re_check){
		print FTOOH "$_\n";
	}
	close FTOOH;
}

