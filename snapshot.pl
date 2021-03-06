#!/usr/local/bin/perl
use strict;

my $replicate = 0;
my $to = 'patton';
my @excludes = (
    'Storage/Plex',
    'Storage/Plex/Library',
    'Storage/Plex/Transcoding',
    'Storage/powers'
);

die if ( -d '/Storage/Crypt' );
open(my $LOG, '>>', '/var/log/snapshot.log');
select $LOG;

chomp(my $pool = `zpool list -o name -H`);
my $now = localtime();
my $nowepoch = time();
my ( $day, $month, $date, $time, $year ) = split(/\s+/, $now);
print "[*] Starting run on $now\n";
chomp(my @filesystems = `zfs list -o name -H`);
my $fail = 0;
foreach my $fs (@filesystems) {
	system("zfs snapshot $fs\@$day-$month-$date-$time-$year-$nowepoch");
    next if ( grep(/^$fs$/, @excludes) );
	next unless ( $replicate );
    chomp(my @remote = `ssh $to "zfs list -t snapshot -o name -H -r $fs 2>/dev/null"`);
    my ( undef, $last ) = split(/\@/, pop(@remote));
    if ( $last ) {
    	system("zfs send -v -i $fs\@$last $fs\@$day-$month-$date-$time-$year-$nowepoch | ssh $to \"zfs recv -F $fs\"");
    } else {
        system("zfs send -v $fs\@$day-$month-$date-$time-$year-$nowepoch | ssh $to \"zfs recv -F $fs\"");
#        system("ssh $to \"zfs inherit readonly $fs\"");
    }
	if ( $? ) {
		$fail = 1;
	}
}
#system("ssh $to \"zfs set readonly=on Storage\"") if ( $replicate );
open(my $DAT, '-|', 'zfs list -o name -t snapshot -H');
	while(<$DAT>) {
		chomp();
		if ( /^($pool(\/[a-zA-Z0-9\-\/\_]+)?)\@([a-zA-Z]+)\-([a-zA-Z]+)\-([0-9]+)\-([0-9]{2}:[0-9]{2}:[0-9]{2})\-([0-9]{4})\-([0-9]{10})/ ) {
			my ( $fs, $day, $month, $date, $time, $year, $epoch ) = ( $1, $3, $4, $5, $6, $7, $8 );
			my ( $hour, $minute, $second ) = split(/:/, $time);
			
			# if older than a month
			if (( $nowepoch - $epoch ) >= 2629740 ) {
				# if not the first of the month
#				if ( $date != 1 ) { 
					print "[*] Deleting $_ for being older than a month.\n";
					system("zfs destroy $fs\@$day-$month-$date-$time-$year-$epoch");
#				}
				next;
			}
			# if older than a week
			if (( $nowepoch - $epoch ) >= 604800 ) {
				# if not a saturday
				if ( $day ne 'Sat' ) {
					print "[*] Deleting $_ for being older than a week.\n";
					system("zfs destroy $fs\@$day-$month-$date-$time-$year-$epoch");
				}
				next;
			}
			# if older than 24 hours
			if (( $nowepoch - $epoch ) >= 86400 ) {
				# if not the midnight snapshot
				if ( $hour != 00 ) {
					print "[*] Deleting $_ for being older than a day.\n";
					system("zfs destroy $fs\@$day-$month-$date-$time-$year-$epoch");
				}
				next;
			}
		}
	}
close($DAT);
print "[*] -------------------------------------------------------------------------------------------\n";
close($LOG);
