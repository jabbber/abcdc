#!/usr/bin/env perl
#author:        zwj@skybility.com
#version:       0.3
#last modfiy:   2013-12-06
#This script is tcp status from netstat and alarm when it is over threshold.

use strict;
use warnings;

use FindBin qw($Bin);
my $cfg_file = "$Bin/tcp_check.conf";
 
my $_refresh_rate = 5; #Refresh rate of the netstat data

sub netstat { 
    #Array positions for the connection type and state data 
    # acquired from the netstat output. 
    my $tcp_at = 0;
    my $tcp_state_at = 5;
    
    my %tempconns;
    
    #Call the netstat utility and split the output into separate lines 
    my @lines = `netstat -atn`;
    #Iterate through the netstat output looking for the 'tcp' keyword in the tcp_at 
    # position and the state information in the tcp_state_at position. Count each 
    # occurance of each state. 
    foreach my $tcp (@lines){
        # skip empty lines 
        if ($tcp eq ''){
            next;
        }
        my @line = split /\s+/, $tcp;
        if ($line[$tcp_at] eq 'tcp'){
            if (exists $tempconns{$line[$tcp_state_at]}){
                $tempconns{$line[$tcp_state_at]} += 1;
            }else{
                $tempconns{$line[$tcp_state_at]} = 1;
            }
        }
    }
    return %tempconns;
}

#read conf
my %threshold;
open FD, "$cfg_file" or die "can't open the configure file $!";
while(<FD>){
    chomp;
    if (/^\s*#/ or /^\s*$/){next;}
    my @arry = split(/\s+/,$_);
    $threshold{$arry[0]} = {
        'warning' => $arry[1],
        'alarm' => $arry[2]
    }
}
close FD;

sub level {
    my ($name, $value) = @_;
    my $level = 'Normal';
    if (exists $threshold{$name}){
        if ($value >= $threshold{$name}{'alarm'}){
            $level = 'Alarm';
        }elsif ($value >= $threshold{$name}{'warning'}){
            $level = 'Warning';
        }
    }
    return $level;
}

#check cycle
while (1) {
    my %conns = &netstat;
    foreach my $name (keys %conns) {
        my $level = &level($name,$conns{$name});
        print "value for $name is $conns{$name}, $level\n";
    }
    print "\n";
    sleep $_refresh_rate;
}
