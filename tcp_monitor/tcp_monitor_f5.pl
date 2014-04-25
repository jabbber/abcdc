#!/usr/bin/env perl
#author:        zwj@skybility.com
#version:       1.0.1
#last modfiy:   2014-04-25
#This script send tcp connect from f5.
#changelog:

use strict;
use warnings;
use IO::Socket;
use Time::Local;
use Sys::Hostname;

my $hostID = hostname;

my $report_ip = "10.235.128.195";
my $report_port = 31830;

# get version
#my $version_out = `tmsh show sys version`;
#my $version_out = `~/f5version.sh`;
#my $version = '11.2.1';
#if ($version_out =~ /Version\s+([\d\.]+)/)
#{
#    $version = $1;
#}

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

sub sendUDP 
{
    my $str = shift;
    my $s = IO::Socket::INET->new(PeerPort =>$report_port,
        Proto =>'udp',
        PeerAddr =>$report_ip) || print "socket error!\n";

    print $str."\n";
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
            push @output, "$1 $2 $3 $4";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            my ($v_ip,$v_port) = split /:/, $2;
            my $f_ip = &float_match($v_ip);
            push @output, "$1 $2 $f_ip:* $3";
        }elsif ($line =~ /any6\.any\s+any6\.any\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            $oneconnect_1 = "$1 $2";
        }elsif ($line =~ /any6[\s\<\-\>]+\d+\.\d+\.\d+\.\d+\:\w+[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            $oneconnect_1 = "$1";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+any6\.any\s+any6\.any/){
            push @output, "$1 $2 $oneconnect_1";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+any6/){
            my ($v_ip,$v_port) = split /:/, $2;
            my $f_ip = &float_match($v_ip);
            push @output, "$1 $2 $f_ip:* $oneconnect_1";
        }
    }
    return @output;
}

my %vlans;
my %vfmap;
sub float_match
{
    my $v_ip = shift;
    if (exists $vfmap{$v_ip}){
        return $vfmap{$v_ip};
    }else{
        if(%vlans == 0){
            #my @float_out = `b self`;
            my $float_out = `~/f5ip.sh`;
            my @floats = split /\n(?=[^\|])/, $float_out;
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
    # get connect status
    my @status_out = `~/f5.sh`;
    #my @status_out = `tmsh show sys connection`;

    @status_out = &filter(@status_out);
    my %conns;
    foreach my $connect (@status_out)
    {
        my @line = split /\s+/, $connect;
        my($c_ip,$c_port) = split /:/, $line[0];
        my($v_ip,$v_port) = split /:/, $line[1];
        my($f_ip,$f_port) = split /:/, $line[2];
        my($p_ip,$p_port) = split /:/, $line[3];
        $conns{"server^F:$f_ip,V:$v_ip^$v_port^$c_ip^$c_port"} = 1;
        $conns{"client^F:$f_ip,V:$v_ip^$v_port^$p_ip^$p_port"} = 1;
    }
    return %conns;
}

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $date = sprintf("%04d%02d%02d",$year+1900,$mon+1,$mday);
my $time = sprintf("%02d%02d%02d",$hour,$min,$sec);

my $msghead = "SYSTEMLOG|TCPNETSTAT|$hostID|";
my $report = '';
my %conns = &get_conns;
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
    my $msgbody = "$date$time^tcp^$connect^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^F5^customtof5^^^";
    $report .= $msgbody;
}
if (length $report > 0)
{
    &sendUDP($msghead.$report);
}

print "\n";
