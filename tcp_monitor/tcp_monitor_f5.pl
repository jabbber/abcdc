#!/usr/bin/env perl
#author:        zwj@skybility.com
#version:       1.1.2
#last modfiy:   2014-05-01
#This script send tcp connect from f5.
#changelog:
#1.0.1  支持F5 v10版本通过对比floating IP和vs IP的网段找到floating IP
#1.1.0  引入Net::OpenSSH远程执行命令获取输出
#1.1.1  去掉所有带any的链接信息，修复主机名问题，修复f5tocustom和client对方端口没有置空的问题
#1.1.2  强制先检测版本,不支持的版本將报错并跳过

use strict;
use warnings;
use IO::Socket;
use Time::Local;
use Net::OpenSSH;
use POSIX 'setsid';

my $report_ip = "10.235.128.195";
my $report_port = 31830;

my $refresh_rate = 300;

use FindBin qw($Bin);
my $host_file = "$Bin/host.cfg";
my $debug = 1;

#### 将十进制数转换成8为二进制
sub dectobin {
    substr(unpack("B32",pack("N",shift)) , -8);
}

#### 将32位二进制转换成十进制
sub bintodec {
    unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

#### 将二进制表示的 IP/子网掩码转换成十进制形式
sub ipmask_bin2dec {
    my $prefix = "";
    my $result;
    map { $result .= $prefix . &bintodec($_); $prefix = ".";
    } split (/\./,shift);
    return $result;
}

#### 将十进制表示的 IP/子网掩码转换成二进制形式
sub ipmask_dec2bin {
    my $prefix = "";
    my $result;
    map { $result .= $prefix . &dectobin($_); $prefix = ".";
    } split (/\./,shift);
    return $result;
}

sub get_time()
{
    my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
    my $report_ts = sprintf("%4d%02s%02s%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    return $report_ts;
}

my @err_list;
sub ssh_cmd()
{
    my $ssh = shift;
    my $cmd = shift;
    my ($out, $error) = $ssh->capture2($cmd);
    if ($ssh->error){ push @err_list, "[$cmd] $error";}
    return $out;
}

sub sendUDP 
{
    my $str = shift;
    my $s = IO::Socket::INET->new(PeerPort =>$report_port,
        Proto =>'udp',
        PeerAddr =>$report_ip) || print "socket error!\n";

    if ($debug){
        print $str."\n";}
    $s->send("$str") || print "udp send fail!\n";
    close $s;
}

sub filter
{
    my @input = @_;
    my @output;

    my $oneconnect_1;
    foreach my $line (@input)
    {
        if ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            if ($1 eq $3 and $2 eq $4){next;}
            push @output, "$1 $2 $3 $4";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            push @output, "$1 $2 *:* $3";
        }
    }
    return @output;
}

my %vlans;
sub vlans_init
{
    my $selfip_out = shift;
    my @floats = split /\n(?=[^\|])/, $selfip_out;
    foreach my $line (@floats)
    {
        if ($line =~ /^SELF\s+(\d+\.\d+\.\d+\.\d+)/)
        {
            my $ip = $1;
            $line =~ /mask\s+(\d+\.\d+\.\d+\.\d+)/;
            my $mask = $1;
            $line =~ /VLAN\s+(\w+)/;
            my $vlan = $1;
            my $floating;
            if ($line =~ /floating enable/)
            {
                $floating=1;
            }else{
                $floating=0;
            }
            if (!exists $vlans{$vlan})
            {
                $vlans{$vlan} = {'ip' => $ip, 'mask' => $mask, 'floating' => $floating};
            }elsif($floating == 1 and $vlans{$vlan}{'floating'} == 0){
                $vlans{$vlan} = {'ip' => $ip, 'mask' => $mask, 'floating' => $floating};
            }
        }
    }
}

my %vfmap;
sub float_match
{
    my $v_ip = shift;
    if (exists $vfmap{$v_ip}){
        return $vfmap{$v_ip};
    }else{
        foreach my $vlan (keys %vlans)
        {
            if ((&ipmask_dec2bin($vlans{$vlan}{'ip'}) & &ipmask_dec2bin($vlans{$vlan}{'mask'})) eq (&ipmask_dec2bin($v_ip) & &ipmask_dec2bin($vlans{$vlan}{'mask'})))
            {
                $vfmap{$v_ip} = $vlans{$vlan}{'ip'};
                return $vfmap{$v_ip};
            }
        }
    }
    return '*';
}

sub get_conns
{
    my $conn_out = shift;
    # get connect status
    my @connects = split /\n/, $conn_out;
    @connects = &filter(@connects);

    my %conns;
    foreach my $connect (@connects)
    {
        my @line = split /\s+/, $connect;
        my($c_ip,$c_port) = split /:/, $line[0];
        my($v_ip,$v_port) = split /:/, $line[1];
        my($f_ip,$f_port) = split /:/, $line[2];
        my($p_ip,$p_port) = split /:/, $line[3];
        if ($f_ip eq '*')
        {
            $f_ip = &float_match($v_ip);
        }
        $conns{"server^F:$f_ip,V:$v_ip^$v_port^$c_ip^"} = 1;
        $conns{"client^F:$f_ip,V:$v_ip^$v_port^$p_ip^$p_port"} = 1;
    }
    return %conns;
}


sub main{
    open HST, $host_file or die "can't open the file $!";
    while (<HST>)
    {
        %vlans = ();
        %vfmap = ();
        if(/^\s*#/){ next; }
        my @hs_info = split(/\s+/, $_);
        my $h_ip = $hs_info[0];
        my $h_user = $hs_info[1];
        my $h_pass = $hs_info[2];
        my $report_ts = &get_time;
        my $ssh = Net::OpenSSH -> new($h_ip, user => $h_user, passwd => $h_pass);
        if($ssh->error)
        {
            print "$report_ts host $h_ip Couldn't establish SSH connection: ". $ssh->error . "\n";
            next;
        }
        @err_list = ();
        #my $hostID = &ssh_cmd($ssh, "~/f5name.sh");
        my $hostID = &ssh_cmd($ssh, "bigpipe system hostname");
        $hostID =~ /Local Host Name:\s+([\w\-\_]+)\.?.*$/;
        $hostID = $1;

        # get version
        #my $version_out = &ssh_cmd($ssh, '~/f5version.sh');
        my $version_out = &ssh_cmd($ssh, 'tmsh show sys version');
        my $version = '';
        if ($version_out =~ /Version\s+([\d\.]+)/)
        {
            $version = $1;
        }
        if (! $version)
        {
            print "$report_ts host $h_ip :This OS isn't F5.\n";
            next;
        }
        my @versions = split /\./, $version;

        my $conn_out = '';
        if ($versions[0] == 10)
        {
            #$conn_out = &ssh_cmd($ssh,'~/f5.sh');
            $conn_out = &ssh_cmd($ssh,'b conn show -n');
            #my $selfip_out = &ssh_cmd($ssh,'~/f5ip.sh');
            my $selfip_out = &ssh_cmd($ssh,'b self');
            &vlans_init($selfip_out);
        }
        elsif ($versions[0] == 11)
        {
            $conn_out = &ssh_cmd($ssh,'tmsh show sys connection');
        }
        else
        {
            print "$report_ts host $h_ip :F5 Version $version do not support.\n";
            next;
        }

        my $msghead = "SYSTEMLOG|TCPNETSTAT|$hostID|";
        my $report = '';
        my %conns = &get_conns($conn_out);
        foreach my $connect (keys %conns)
        {
            if (length $report > 0)
            {
                if (length $report > 3500)
                {
                    &sendUDP($msghead.$report);
                    $report = '';
                }else{
                    $report .= '#^#';
                }
            }
            my $app_name = "f5tocustom";
            if ($connect =~ /server/)
            {
                $app_name = "customtof5";
            }
            my $msgbody = "$report_ts^tcp^$connect^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^F5^$app_name^^^";
            $report .= $msgbody;
        }
        if (length $report > 0)
        {
            &sendUDP($msghead.$report);
        }

        foreach (@err_list)
        {
            print "$report_ts host $h_ip remote command failed: $_";
        }

    }
}

if (!exists $ARGV[0])
{
    &main;
}
elsif ($ARGV[0] eq '-d')
{
    print "start as daemon...\n\n";
    #------------------------------
    # create daemon process
    exit if fork;

    &setsid();

    # fork() again so the parent (session group leader) can exit.
    exit if fork;

    # chdir('/') to ensure our daemon doesn't keep any directory in use.
    chdir '/';

    # ignore SIGCHLD signal to avoid zombie processes
    $SIG{CHLD} = 'IGNORE';
    $SIG{'INT'}  = 'IGNORE';
    $SIG{'QUIT'} = 'IGNORE';
    $SIG{'ALRM'} = 'IGNORE';
    $SIG{'ILL'}  = 'IGNORE';
    $SIG{'ABRT'} = 'IGNORE';
    $SIG{'FPE'}  = 'IGNORE';
    $SIG{'SEGV'} = 'IGNORE';
    $SIG{'TERM'} = 'IGNORE';
    $SIG{'BUS'}  = 'IGNORE';
    $SIG{'SYS'}  = 'IGNORE';
    $SIG{'XCPU'} = 'IGNORE';
    $SIG{'XFSZ'} = 'IGNORE';
    $SIG{'IOT'}  = 'IGNORE';
    $SIG{'PIPE'} = 'IGNORE';
    $SIG{'HUP'}  = 'IGNORE';

    # start main loop.
    my $pid = fork;
    if ($pid == 0)
    {
        exit;
    }
    else
    {
        while(1) {
            &main;
            sleep $refresh_rate;
        }
    }
}
else
{
    print "usage:\n";
    print "    -d          start as daemon\n";
    exit;
}
