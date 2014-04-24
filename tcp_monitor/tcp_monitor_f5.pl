#!/usr/bin/env perl
#author:        zwj@skybility.com
#version:       1.0
#last modfiy:   2014-04-24
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
my $version_out = `~/f5version.sh`;
my $version = '11.2.1';
if ($version_out =~ /Version\s+([\d\.]+)/)
{
    $version = $1;
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
        if ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+\d+\.\d+\.\d+\.\d+\:\w+\s+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            push @output, "$1 $2 $3";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            push @output, "$1 $2 $3";
        }elsif ($line =~ /any6\.any\s+any6\.any\s+\d+\.\d+\.\d+\.\d+\:\w+\s+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            $oneconnect_1 = "$1";
        }elsif ($line =~ /any6[\s\<\-\>]+\d+\.\d+\.\d+\.\d+\:\w+[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)/){
            $oneconnect_1 = "$1";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)\s+(\d+\.\d+\.\d+\.\d+\:\w+)\s+any6\.any\s+any6\.any/){
            push @output, "$1 $2 $oneconnect_1";
        }elsif ($line =~ /(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+(\d+\.\d+\.\d+\.\d+\:\w+)[\s\<\-\>]+any6/){
            push @output, "$1 $2 $oneconnect_1";
        }
    }
    return @output;
}

sub get_conns
{
    # get connect status
    #my $status = `tmsh show sys connection`;
    my @status_out = `~/f5.sh`;
    @status_out = &filter(@status_out);
    my %conns;
    foreach my $connect (@status_out)
    {
        my @line = split /\s+/, $connect;
        my($c_ip,$c_port) = split /:/, $line[0];
        my($v_ip,$v_port) = split /:/, $line[1];
        my($p_ip,$p_port) = split /:/, $line[2];
        $conns{"server^$c_ip^$c_port^$v_ip^$v_port"} = 1;
        $conns{"client^$v_ip^$v_port^$p_ip^$p_port"} = 1;
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
    my $msgbody = "$date$time^tcp^$connect^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^-1^unknow^unknow^^^";
    $report .= $msgbody;
}
if (length $report > 0)
{
    &sendUDP($msghead.$report);
}

