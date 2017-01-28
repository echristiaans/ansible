#!/bin/env perl
# check_bacula.pl
# Author -  Michael van den Berg
# Copyright - Sentia B.V. 2016

use DBI;
use Getopt::Long;
use DateTime;
use Time::Piece;
use Math::Round;

# Help message etc
(my $script_name = $0) =~ s/.\///;

my $bacula_server = "localhost";
my $db = "bacula";
my $warn = 32;
my $crit = 56;

# Command line options
GetOptions (	"H|host=s"  	=> \$bacula_server,
	    	"j|jobpool=s"	=> \my $pool,
	  	"u|username=s" 	=> \my $username,
		"p|password=s"	=> \my $password, 
	    	"w|warnhours=i"	=> \$warn,
	    	"c|crithours=i"	=> \$crit,
	    	"help|?" 		=> \my $help);

my $help_info = <<END;
\n$script_name - v1.0

Nagios script to check status of Bacual ll jobs within a specific backup pool

This check will do a MySQL/MariaDB lookup and query the backup history of all 
backup jobs for clients within a backup pool. If a backups last result is not
successful or a backup job is too old as specified, then a nagios alert will
be generated.

Usage:
-H|host		The host where the bacula SQL database resides
-u|username	Username that can query the bacula database (Only SELECT rights are required)
-p|password	Password
-j|jobpool	The name of the backup job pool to check
-w|warnhours	Warning threshold in hours since the last successful backup job as run (default 32 hours)
-c|crithours 	Critical threshold in hours since the last successful backup job as run (default 56 hours)

Example: $script_name -H bacuala.server.com -u nagios -p mysecret -j POOL

END

# Nagios exit codes
my $OK		= { "status" => "OK:", "exitcode" => 0 };
my $WARNING 	= { "status" => "WARNING:", "exitcode" => 1 };
my $CRITICAL	= { "status" => "CRITICAL:", "exitcode" => 2 };
my $UNKNOWN	= { "status" => "UNKNOWN:", "exitcode" => 3 };

my $nagiosResult = $UNKNOWN;	# Default

# If the needed command line arguments or help was called, exit with UNKNOWN.
if((!defined $bacula_server) || (!defined $pool) || (!defined $username) || (!defined $password) || (defined $help)){
	print $help_info;
	exit $UNKNOWN->{status};
}

$sqlquery = "SELECT Client.Name as Client, Status.JobStatusLong as Status, Job1.EndTime, Pool.Name AS Pool FROM Status, Pool, Client JOIN Job Job1 ON (Client.ClientId=Job1.ClientId) LEFT OUTER JOIN Job Job2 ON Client.ClientId=Job2.ClientId AND Job1.EndTime < Job2.EndTime WHERE Job2.EndTime IS NULL AND Job1.JobStatus = Status.JobStatus AND Pool.Poolid=Job1.PoolId AND Pool.Name = '$pool'";

$dbh = DBI->connect("DBI:mysql:$db;host=$bacula_server", $username, $password
	           ) || die "CRITICAL: Could not connect to database: $DBI::errstr";

$sth = $dbh->prepare($sqlquery);
$sth->execute();
my @failed_backups = ();
my @old_backups = ();
my $result_count = 0;

while ($result = $sth->fetchrow_hashref){
	$result_count++;
	my $endtime_dt = Time::Piece->strptime($result->{EndTime},"%Y-%m-%d %H:%M:%S");
	my $now = localtime->epoch;
	my $last_backup_hrs = round(($now - ($endtime_dt->epoch)) / 3600);;
	
	if ( not $result->{Status} eq "Completed successfully" ){
		$nagiosResult = $CRITICAL;
		push @failed_backups, ($result->{Client}. " ($result->{Status})");
	}else{
		if ( $last_backup_hrs > $crit ){
			$nagiosResult = $CRITICAL;
 			push @old_backups, $result->{Client}."(".$last_backup_hrs." hrs)";
		}elsif($last_backup_hrs > $warn){
			$nagiosResult = $WARNING if ( not $nagiosResult eq $CRITICAL);
			push @old_backups, $result->{Client}."(".$last_backup_hrs." hrs)" if (not $nagiosResult eq $CRITICAL);
		}else{
			$nagiosResult = $OK if (( not $nagiosResult eq $CRITICAL && not $nagiosResult eq $WARNING));
			$success_count++;
		}
	}
}

if($result_count < 1){
	print $CRITICAL->{status}." No backup jobs for pool '$pool' found\n";
	exit $CRITICAL->{exitcode};
}
if($nagiosResult eq $CRITICAL || $nagiosResult eq $WARNING){
	$message =  " ".(join ", ", @failed_backups) if(scalar(@failed_backups));
	$message .= " BACKUPS TOO OLD - ". (join ", ", @old_backups) if(scalar(@old_backups));
	print $nagiosResult->{status}."$message\n";
	exit $nagiosResult->{exitcode};
}elsif($nagiosResult eq $OK){
	print $nagiosResult->{status}." All backups for $pool successful ($success_count jobs) within the last $warn hours\n";
        exit $nagiosResult->{exitcode};
}

# We shouldnt get here
print $UNKNOWN->{exitcode}." There is a problem that needs looking into with this check\n";
exit $UNKNOWN->{exitcode};
