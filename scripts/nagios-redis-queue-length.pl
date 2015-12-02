#!/usr/bin/perl 
#
# Script to be used by Nagios to check queue length
#
# typical usage:
#    nagios-redis-queue-length.pl -H 127.0.0.1 -q mytest_main -w 200 -c 5000
#    nagios-redis-queue-length.pl -H 127.0.0.1 -q mytest_busy -w 50 -c 150
#    nagios-redis-queue-length.pl -H 127.0.0.1 -q mytest_failed -w 30 -c 100
#
use strict;

use Redis;
use Getopt::Std;

use constant {
    OK       => 0,
    WARNING  => 1,
    CRITICAL => 2,
    UNKNOWN  => 3
};

my %opts;
getopts('P:H:p:q:w:c:?hv', \%opts);

usage() if ( exists $opts{h} || exists $opts{'?'}
    || !exists $opts{H}) || !exists $opts{q};

my $VERBOSE = exists $opts{v};

# Defaults
$opts{p} ||= '6379';
$opts{w} ||= '100';
$opts{c} ||= '500';
$opts{P} ||= '';

for (qw(p w c)) {
    if ($opts{$_} =~ m/^[^0-9]+$/) {
        warn "Invalid value for option $_\n";
        exit UNKNOWN;
    }
}


if ($opts{w} > $opts{c}) {
    warn "warn level ($opts{w}) should be lower than"
    . " critical level ($opts{c})\n";
    usage();
}

my $service = "$opts{H}:$opts{p}";
my $password = $opts{P};

my $conn = Redis->new( server => $service, reconnect => 3);
$conn->auth($password) if $password;
    
if (!$conn) {
    warn "can't connect to $service\n";
    exit CRITICAL;
}

my $len = $conn->llen($opts{q});

print "$opts{q} has length $len\n" if $VERBOSE;

my $ev = OK;
if ($len < $opts{w}) {
    print "$opts{q} length $len is OK";
}
elsif ($len < $opts{c}) {
    printf "%s: queue length of %s is %d (threshold: %d)",
        'Warning', $opts{q}, $len, $opts{w};
    $ev = WARNING;
}
else {
    printf "%s: queue length of %s is %d (threshold: %d)",
        'Critical', $opts{q}, $len, $opts{c};
    $ev = CRITICAL;
}

#perfdata!
printf " | %s=%d;%d;%d;\n", $opts{q}, $len, $opts{w}, $opts{c};
exit $ev;

sub usage {
    print "usage $0 -H host -q queue_name [-P password] [-p port] [-w len] [-c len] [-v]\n";
    exit;
}
