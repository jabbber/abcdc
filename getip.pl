#!/usr/bin/perl
#This script is use to get all ip address of a Suse Linux Server.
#author: zwj
#version: 0.4
#Oupput Format:
#    host,perm,srv,float,man,other

use warnings;

my $hostname = `hostname`;
chomp $hostname;

my ($PIP,$SIP,$FIP,$MIP,$OIP) = ('') x 5;

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
        $FIP = $1;
    }
    if ($ipshow =~ /\d+\:\s(\w+)\s+inet\s.+?\/\d+\s[\w\s.]+global\ssecondary/){
        my $SEth = $1;
        if ($ipshow =~ /$SEth\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
            $SIP = $1;
        }
    }
}else{
    if ($ipshow =~ /bond0\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
        $SIP = $1;
    }
    if ($ipshow =~ /bond1\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
        $PIP = $1;
    }
}


my @iplines = split(/\n/, $ipshow);
foreach my $line (@iplines) {
    if ($line =~ /^\d+\:\slo/){next;}
    if ($line =~ /inet\s(.+?)\/\d+\s[\w\s.]+/){
        my $ip = $1;
        if ($ip eq $PIP or $ip eq $SIP or $ip eq $FIP){next;}
        if (not $SIP){
            if ($ip =~ /^10\./){
                $SIP = $ip;
                next;
            }
        }
        if (not $PIP){
            if ($ip =~ /^10\./){
                $PIP = $ip;
                next;
            }
        }
        $OIP = $OIP.",$ip";
    }
}
if (not $OIP){ $OIP = ',';}

print "host,perm,srv,float,man,other\n";
print "$hostname,$PIP,$SIP,$FIP,$MIP$OIP\n";

