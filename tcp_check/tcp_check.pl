#!/usr/bin/env perl
#author:        zwj@skybility.com
#version:       0.3
#last modfiy:   2013-12-06
#This script is tcp status from netstat and alarm when it is over threshold.

#注：生产区的脚本，请把下面的$IP值设为"10.235.128.195"
#    办公区则设为"10.237.128.171"
#
#需要携带9个参数，分别为：服务器名称，服务名称，报警源，报警值，报警id，报警级别，报警注释，报警短消息，报警详细信息
#
#
#CUSTOM^机构代码^报警日期(8位)^报警时间(6位)^流水号^HostID(不超过32个半角字符)^ServerID(不超过100个半角字符)^所在项目(不超过80个半角字符)^报警源(不超过9个半角,如BMC,MYAME,SCOM,OPMS等)^报警值^报警类型编号(4位数字)^报警级别(4位,如0001)^报警级别说明(不超>过32个半角字符,如一般报警!)^报警短信(不超过640个半角字符)^报警详细信息^关联类型（查>询用，可填空）^关联ID（查询用，可填空）^关联说明（查询用，可填空）
#

use strict;
use warnings;
use IO::Socket;

use FindBin qw($Bin);
my $cfg_file = "$Bin/tcp_check.conf";
 
my $_refresh_rate = 5; #Refresh rate of the netstat data

sub netstat
{ 
    #Array positions for the connection type and state data 
    # acquired from the netstat output. 
    my $tcp_at = 0;
    my $tcp_state_at = 5;
    my $local_address_at = 3;
    my $foreign_address_at = 3;
    
    my %tempconns;
    
    #Call the netstat utility and split the output into separate lines 
    my @lines = `netstat -atn`;
    #Iterate through the netstat output looking for the 'tcp' keyword in the tcp_at 
    # position and the state information in the tcp_state_at position. Count each 
    # occurance of each state. 
    foreach my $tcp (@lines)
    {
        # skip empty lines 
        if ($tcp eq '')
        {
            next;
        }
        my @line = split /\s+/, $tcp;
        if ($line[$tcp_at] eq 'tcp')
        {
            if (! exists $tempconns{$line[$tcp_state_at]})
            {
                $tempconns{$line[$tcp_state_at]} = {"total" => 0,
                                                    "local" => {},
                                                    "foreign" => {} 
                                                    };
            }
            if (! exists $tempconns{$line[$tcp_state_at]}{"local"}{$line[$local_address_at]})
            {
                $tempconns{$line[$tcp_state_at]}{"local"}{$line[$local_address_at]} = 0;
                $tempconns{$line[$tcp_state_at]}{"foreign"}{$line[$foreign_address_at]} = 0;
            }
            $tempconns{$line[$tcp_state_at]}{"total"} += 1;
            $tempconns{$line[$tcp_state_at]}{"local"}{$line[$local_address_at]} += 1;
            $tempconns{$line[$tcp_state_at]}{"foreign"}{$line[$foreign_address_at]} += 1;
        }
    }
    return %tempconns;
}

#read conf
my %threshold;
open FD, "$cfg_file" or die "$cfg_file $!";
while(<FD>)
{
    chomp;
    if (/^\s*#/ or /^\s*$/){next;}
    my @arry = split(/\s+/,$_);
    $threshold{$arry[0]} = {
        'warning' => $arry[1],
        'alarm' => $arry[2]
    };
}
close FD;

sub level
{
    my ($name, $value) = @_;
    my $level = 'Normal';
    if (exists $threshold{$name})
    {
        if ($value >= $threshold{$name}{'alarm'})
        {
            $level = 'Alarm';
        }
        elsif ($value >= $threshold{$name}{'warning'})
        {
            $level = 'Warning';
        }
    }
    return $level;
}

sub sort_sum
{
    my %hash = @_;
    my @result;
    foreach my $address (keys %hash)
    {
        my $n = 0;
        foreach (@result)
        {
            if ($hash{$address} >= $hash{$_})
            {
                splice @result, $n, 0, ($address);
                last;
            }
            $n += 1;
        }
        if (@result == 0)
        {
            push @result, $address;
        }
    }
    return @result;
}

sub do_check
{
    my %conns = &netstat;
    my $detail = "";
    foreach my $name (keys %conns)
    {
        my $level = &level($name,$conns{$name}{'total'});
        $detail .= "value for $name is $conns{$name}{'total'}, $level\n";
        my @local_sort = &sort_sum(%{$conns{$name}{"local"}});
        my @foreign_sort = &sort_sum(%{$conns{$name}{"foreign"}});
        foreach (@local_sort)
        {
            $detail .= "$_ $conns{$name}{'local'}{$_}\n";
        }
        foreach (@foreign_sort)
        {
            $detail .= "$_ $conns{$name}{'foreign'}{$_}\n";
        }
    }
    return $detail;
}

our $warnip = "10.237.128.195";
sub sendUDP  #发送报警
{
    my $str = shift;
    my $s = IO::Socket::INET->new(PeerPort =>'31820',
                     Proto =>'udp',
                     PeerAddr =>$warnip) || die "socket error!\n";

    print $str."\n";
    $s->send("$str");
    close $s;
}

#check cycle
my $count = 0;
while (1)
{
    my $detail = &do_check;
    print $detail;
    print "\n";
    sleep $_refresh_rate;
}

