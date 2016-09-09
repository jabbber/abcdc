#!/usr/bin/perl
#This script is use to get all ip address of a Suse Linux Server.
#author: zwj
#version: 0.1

use warnings;

my $hostname = `hostname`;
chomp $hostname;

my ($MIP,$SIP,$IP,$AIP) = ('') x 4;

my $HA = -f '/opt/ha/conf/cluster.xml';
my $DB2 = 1;
if ($hostname =~ /\-/){
    $DB2 = 0;
}

my $ipshow = `ip -o addr show`;

if ($DB2){
}

if ($HA){
    if ($ipshow =~ /inet\s(.+?)\/\d+\s[\w\s.]+global\ssecondary/){
        $SIP = $1;
    }
}

if ($ipshow =~ /bond0\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
    $IP = $1;
}
if ($ipshow =~ /bond1\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
    $MIP = $1;
}


my @iplines = split(/\n/, $ipshow);
foreach my $line (@iplines) {
    if ($line =~ /^\d+\:\slo/){next;}
    if ($line =~ /inet\s(.+?)\/\d+\s[\w\s.]+/){
        my $ip = $1;
        if (not $MIP){$MIP = $ip;next;}
        if (not $SIP and not $HA){$SIP = $ip;next;}
        if (not $IP ){$IP = $ip;next;}
        if ($ip eq $MIP or $ip eq $SIP or $ip eq $IP){next;}
        $AIP = $AIP.",$ip";
    }
}

print "$hostname,$MIP,$SIP,$IP$AIP\n";
