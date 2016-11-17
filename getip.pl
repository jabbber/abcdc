#!/usr/bin/perl
#This script is use to get all ip address of a Suse Linux Server.
#author: zwj
#version: 0.7
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
my $ORACLE = 0;
if ($hostname =~ /\-R\d{2}$/){
    $ORACLE = 1;
}

my $ipshow = `ip -o addr show`;

if ($DB2){
}

if($ORACLE){
    if ($ipshow =~ /bond0\s+inet\s(.+?)\/\d+\s[\w\s.]+global\ssecondary/){
        ($PIP, $SIP, $FIP) = ($ipshow =~ /bond0\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/g);
        if (not $FIP){ $FIP = '';}
    }
}elsif ($HA){
    my $haconf=`cat /opt/ha/conf/cluster.xml`;
    if ($haconf =~ /network.+ipaddress="(.+?)"/){
        $SIP = $1;
        if (not $ipshow =~ /$SIP/){
            $SIP = '';
        }
    }
    if ($haconf =~ /network.+netintf="(.+?)"/){
        my $SEth = $1;
        if ($ipshow =~ /$SEth\s+inet\s(.+?)\/\d+\s[\w\s.]+global\s/){
            $PIP = $1;
        }
    }
}else{
    if ($ipshow =~ /bond0\s+inet\s(10\.[(?:235)(?:227)]\..+?)\/\d+\s[\w\s.]+global\s/){
        $SIP = $1;
    }
    if ($ipshow =~ /bond1\s+inet\s(10\.[(?:235)(?:227)]\..+?)\/\d+\s[\w\s.]+global\s/){
        $PIP = $1;
    }
}


my @iplines = split(/\n/, $ipshow);
foreach my $line (@iplines) {
    if ($line =~ /^\d+\:\slo/){next;}
    if ($line =~ /inet\s(.+?)\/\d+\s[\w\s.]+/){
        my $ip = $1;
        if ($ip eq $PIP or $ip eq $SIP or $ip eq $FIP){next;}
        if (not $SIP and not $HA){
            if ($ip =~ /^10\.[(?:235)(?:227)]/){
                $SIP = $ip;
                next;
            }
        }
        if (not $PIP){
            if ($ip =~ /^10\.[(?:235)(?:227)]/){
                $PIP = $ip;
                next;
            }
        }
        if (not $MIP and $HA){
            if ($ip =~ /^10\.[(?:235)(?:227)]/){
                $MIP = $ip;
                next;
            }
        }
        $OIP = $OIP.",$ip";
    }
}
if (not $OIP){ $OIP = ',';}
if (not $PIP){ $PIP = $SIP;}

print "host,perm,srv,float,man,other\n";
print "$hostname,$PIP,$SIP,$FIP,$MIP$OIP\n";

