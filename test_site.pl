#!/usr/bin/perl 
use strict;
use warnings;
use Net::Ping;
use JSON;
use Getopt::Std;

my $to = 'webmaster@domain.nl';

my $sendmail = "/usr/bin/msmtp -t";
my $statusfile = "/home/vincent/.site_status.json";

our $opt_a = "";
our $opt_d = "";
our $opt_c = 0;

getopts("cd:a:");

if($opt_a ne "") {
    add_site($opt_a);
} elsif($opt_d ne "") {
    del_site($opt_d);
} elsif($opt_c) {
    check_status()
}

sub del_site {
    my $host = $_[0];
    my @hosts = @{read_file()};

    # Check if the new host is already in the file
    for(my $count = 0; $count < @hosts; $count++) {
        my $site = $hosts[$count];
        if($site->{"host"} eq $host) {
            delete $hosts[$count];
            print "deleted $count\n";
        }

    }

    write_file(\@hosts);
}

sub add_site {
    my $p = Net::Ping->new();
    my $host = $_[0];
    my $hosts = read_file();

    # Check if the new host is already in the file
    foreach(@$hosts) {
        if($_->{"host"} eq $host) {
            return;
        }

    }

    my $site = {};
    $site->{'host'} = $host;

    if($p->ping($site->{'host'})) {
        $site->{'status'} = 'up';
    } else {
        $site->{'status'} = 'down';
    }

    $site->{'since'} = time();

    push(@$hosts, $site);

    write_file($hosts);
}

sub check_status {
    my $p = Net::Ping->new();

    my $hosts = read_file();

    foreach(@$hosts) {
        my $status = $_->{"status"};
        my $host = $_->{"host"};
        my $since = int($_->{"since"});

        if($status eq "up") {
            if(!$p->ping($host)) {
                my %time = from_unix(time() - $since);

                email("$host is down", 
                    "Hi,\n\nI would like to inform you $host is down after being up for $time{'days'} days, $time{'hours'} hours, $time{'minutes'} minutes and $time{'seconds'} seconds");

                $_->{"status"} = "down";
                $_->{"since"} = time();

            }
        } elsif ($status eq "down") {
            if($p->ping($host)) {
                my %time = from_unix(time() - $since);

                email("$host is up", 
                    "Hi,\n\nI would like to inform you $host is back up after being down for $time{'days'} days, $time{'hours'} hours, $time{'minutes'} minutes and $time{'seconds'} seconds");

                $_->{"status"} = "up";
                $_->{"since"} = time();
            }
        }
    }
    write_file($hosts);

}

sub read_file {
    my $hosts;
    if(-r $statusfile) {
        my $json;
        {
            local $/; #enable slurp
            open my $fh, "<", "$statusfile";
            $json = <$fh>;
        } 
        $hosts = decode_json($json);
    } else {
        $hosts = [];
    }
        
    return $hosts;
}

sub write_file {
    my $json = to_json($_[0], {pretty => 1});

    open (SITES, ">", $statusfile);
    print SITES $json;
    close (SITES);
}

sub email {
    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!"; 
    print SENDMAIL "From: $from\n";
    print SENDMAIL "To: $to\n";
    print SENDMAIL "Subject: $_[0]\n"; 
    print SENDMAIL "Content-type: text/plain\n\n"; 
    print SENDMAIL "$_[1]"; 
    close(SENDMAIL);
}

sub from_unix {
    my %time = ();
    my $uptime = $_[0];

    $time{"days"} = int($uptime / (60 * 60 * 24));
    $uptime = int($uptime % (60 * 60 * 24));

    $time{"hours"} = int($uptime / (60 * 60));
    $uptime = int($uptime % (60 * 60));

    $time{"minutes"} = int($uptime / 60);
    $time{"seconds"} = int($uptime % 60);

    return %time;
}
