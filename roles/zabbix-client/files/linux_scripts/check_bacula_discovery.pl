#!/bin/env perl
# check_bacula.pl
# Author -  Michael van den Berg
# Copyright - Sentia B.V. 2016


use DBI;
use Getopt::Long;
use DateTime;
use Time::Piece;
use Math::Round;
use JSON;

# Help message etc
(my $script_name = $0) =~ s/.\///;

my $bacula_server = "localhost";
my $db = "bacula";

# Command line options
GetOptions (	"H|host=s"  	=> \$bacula_server,
	  					"u|username=s" 	=> \my $username,
							"p|password=s"	=> \my $password,
	    				"help|?" 		=> \my $help);

my $help_info = <<END;
\n$script_name - v1.0

Zabbix Discovery check

This check will do a MySQL/MariaDB lookup and query the bacula pools for and returns a JSON with
the pools.

Usage:
-H|host		The host where the bacula SQL database resides
-u|username	Username that can query the bacula database (Only SELECT rights are required)
-p|password	Password

Example: $script_name -H bacuala.server.com -u nagios -p mysecret

END

# Nagios exit codes
my $OK		= { "status" => "OK:", "exitcode" => 0 };
my $WARNING 	= { "status" => "WARNING:", "exitcode" => 1 };
my $CRITICAL	= { "status" => "CRITICAL:", "exitcode" => 2 };
my $UNKNOWN	= { "status" => "UNKNOWN:", "exitcode" => 3 };

my $nagiosResult = $UNKNOWN;	# Default

# If the needed command line arguments or help was called, exit with UNKNOWN.
if((!defined $bacula_server) || (!defined $username) || (!defined $password) || (defined $help)){
	print $help_info;
	exit $UNKNOWN->{status};
}

#$sqlquery = "SELECT Pool.Name from Pool where Pool.Name != 'Default' AND Pool.Name != 'Scratch' AND Pool.Name != 'File'";
$sqlquery = "SELECT Pool.Name from Pool";

$dbh = DBI->connect("DBI:mysql:$db;host=$bacula_server", $username, $password) || die "CRITICAL: Could not connect to database: $DBI::errstr";

$sth = $dbh->prepare($sqlquery);
$sth->execute();

my @pools = ();

while ($result = $sth->fetchrow_hashref){
	$name = "$result->{Name}";
	push(@pools, {'{#POOL}'=>$name});
}

my $json = encode_json({data => \@pools});
print "$json";
