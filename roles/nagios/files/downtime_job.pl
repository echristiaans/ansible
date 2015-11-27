#!/usr/bin/perl
# vim:ts=4
#
# this should be run regularly from your crontabs, to schedule any outages
# for the forthcoming 24 hours.

# Daily: 
#        crontabs:  01 07 * * * downtime_job.pl > /dev/null 2>&1
# Hourly:
#        crontabs:  01  * * * * downtime_job.pl > /dev/null 2>&1

# WARNING! Only minor verification is made on the config file.  If you give 
#         incorrect hostnames, service descriptions, or hostgrouname then it
#         will not be noticed until Nagios tries to parse the command!

# See companion file for example of structure of schedule.cfg file.
#
# Version 1.1 : fixed for nagios 1.2
# Version 1.2 : trim trailing spaces from parameters, allow smaller increments
# Version 1.3 : allow wildcards in service name, check for already sched
#         1.5 : optimisation
#         1.6 : fix lookahead correctly, big rewrite
#         2.0 : Nagios 2 support
#         2.1 : Fix split regexp to allow spaces as well as commas
#         3.0 : Nagios 3 support
#         3.1 : Month days error
#         3.2 : Month day errors, leap year corrections

use strict;
use Time::Local;

my($NAGDIR) = "/u02/nagios" ;  # Nagios root directory
my($NAGVER) = 3;               # 1 2 or 3
my($SVCALSO) = 0; # schedule outages for services on hosts as well as hosts?

my($OBJECTS,$RETENTIONDAT,$STATUSDAT,$DOWNDAT,$STATUSLOG,$HGCFG,$DOWNLOG)
	= ('','','','','','','');

# Always define these
my($CFGFILE) =   "$NAGDIR/etc/schedule.cfg";  # my configuration file
my($CMDFILE) =   "$NAGDIR/log/rw/nagios.cmd"; # Nagios CMD file
# Define this for Nagios 2 or 3
$OBJECTS = "$NAGDIR/log/objects.cache"        # Nagios 2/3 objects file
	if( $NAGVER>1 );
# Define this for Nagios 3
$STATUSDAT = "$NAGDIR/log/status.dat"         # Nagios status file
	if( $NAGVER > 2 );
$RETENTIONDAT = "$NAGDIR/log/retention.dat"   # Nagios retained status file
	if( $NAGVER > 2 );
# Define this for Nagios 2
$DOWNDAT =   "$NAGDIR/log/downtime.dat"       # Nagios 2 existing downtime
	if( $NAGVER >= 2 and $NAGVER < 3 );
# Or these for Nagios 1
if( $NAGVER < 2 ) {
	$STATUSLOG = "$NAGDIR/log/status.log";    # Nagios status log file
	$HGCFG =     "$NAGDIR/etc/hostgroups.cfg";# hostgroup definitions
	$DOWNLOG =   "$NAGDIR/log/downtime.log";  # existing sched downtime
}

my($FREQUENCY) = 1440*7; # how many minutes to look ahead.  Should be at least
                         # 1440 (one day) and <= 1 week.  Only the next outage
                         # is scheduled, not all of them.
my($MINDUR) = 5; # shortest outage allowed in minutes
my($DEBUG) = 0; # set to 1 to produce helpful debugging information
my($rv);

# Nothing more to change after this point!
############################################################################
my(%hostgroups) = ();
my(%hostsvc);
sub readstatuslog {
    %hostsvc = ();
    return if(! -r $STATUSLOG);
	print "Reading $STATUSLOG..." if($DEBUG);
    open SL, "<$STATUSLOG" or return;
    while( <SL> ) {
        if( /^\[\d+\]\s+SERVICE;([^;]+);([^;]+);/ ) {
            $hostsvc{$1}{$2} = 1;
        }
    }
    close SL;
	print "Done.\n" if($DEBUG);
}
sub readobjects {
	my($ohost,$osvc,$ohg) = ("","","");
	if(! -r $OBJECTS) { readstatuslog; return; }
	print "Reading $OBJECTS..." if($DEBUG);
    %hostsvc = (); %hostgroups = ();
	open OBJ, "<$OBJECTS" or return;
	while( <OBJ> ) {
		if( /^\s*define service / ) {
			$osvc = 1; next;
		} elsif( /^\s*define hostgroup / ) {
			$ohg = 1; next;
		} elsif( /^\s*}/ ) {
			$ohost = $osvc = $ohg = "";
		} elsif( $osvc ) {
			if( /^\s*host_name\s+(.*\S)/ ) {
				$ohost = $1; 
			} elsif( /^\s*service_description\s+(.*\S)/ ) {
				$hostsvc{$ohost}{$1} = 1;
				$ohost = $osvc = "";
			}
		} elsif( $ohg ) {
			if( /^\s*hostgroup_name\s+(.*\S)/ ) {
				$ohg=$1;
			} elsif( /^\s*members\s+(.*\S)/ ) {
				$hostgroups{$ohg} = [ split /[,\s]+/,$1 ];
#				print "HG $ohg = ".(join ":",@{$hostgroups{$ohg}})."\n" if($DEBUG);
				$ohg = "";
			}
		}
	}
	close OBJ;
	print "Done.\n" if($DEBUG);
}

my(%downtime);
sub readdowntime {
    return if(! -r $DOWNLOG);
	print "Reading $DOWNLOG..." if($DEBUG);
    open DL, "<$DOWNLOG" or return;
    while( <DL> ) {
        if( /^\[\d+\]\s+SERVICE_DOWNTIME;\d+;([^;]+);([^;]+);(\d+);/ ) {
            $downtime{"$1:$2:$3"} = 1;
        } elsif( /^\[\d+\]\s+HOST_DOWNTIME;\d+;([^;]+);(\d+);/ ) {
            $downtime{"$1:$2"} = 1;
        } elsif( /^\[\d+\]\s+HOSTGROUP_DOWNTIME;\d+;([^;]+);(\d+);/ ) {
            $downtime{"HG!$1:$2"} = 1;
        }
    }
    close DL;
	print "Done.\n" if($DEBUG);
}
sub readdowntime2 {
	my($hd,$sd,$start,$a);
	my($f) = $DOWNDAT;
	$f = $STATUSDAT if(!$f or ! -r $f);
	$f = $RETENTIONDAT if(!$f or ! -r $f);
	if(!$f or ! -r $f) { readdowntime; return; }
	print "Reading $f ..." if($DEBUG);
	$a = 0;
	open DD, "<$f" or return;
	while ( <DD> ) {	
		if( /^\s*hostdowntime/ ) {
			$a = 1; $hd = ""; $start = 0;
		} elsif( /^\s*servicedowntime/ ) {
			$a = 2; $hd = $sd = ""; $start = 0;
		} elsif( $a and /^\s*}/ ) {
			if($a == 1) {
				$downtime{"$hd:$start"} = 1;
				print "Adding $hd:$start\n" if($DEBUG);
			} elsif($a == 2) {
				$downtime{"$hd:$sd:$start"} = 1;
				print "Adding $hd:$sd:$start\n" if($DEBUG);
			}
			$a = 0;
		} elsif( $a ) {
			if( /^\s*host_name\s*=\s*(.*\S)/ ) { $hd = $1; }
			elsif( /^\s*service_description\s*=\s*(.*\S)/ ) { $sd = $1; }
			elsif( /^\s*start_time\s*=\s*(\d+)/ ) { $start = $1; }
		}
	}
	close DD;
	print "Done.\n" if($DEBUG);
}

############################################################################
sub sendcmd($) {
	my($msg) = $_[0];
	my($t) = time;
	print "Sending command '$msg'\n" if($DEBUG);
#	if(!$DEBUG) {
		open CMD,">$CMDFILE" or return "Error: $!";
		print CMD "[$t] $msg\n";
		close CMD;
#	}
	print "$msg\n";
	return 0;
}
sub schedule_host($$$$$) {
	my($h,$s,$d,$u,$c) = @_;
	my($rv);
	$u = "Automatic" if(!$u);
	$c = "AUTO: $c" if($c);
	$c = "AUTO: Automatically scheduled for host" if(!$c);
	return "Invalid host $h!" if(!$h or !defined $hostsvc{$h});
	return "Invalid time $s!" if(!$s);
	return "Invalid duration $d!" if(!$DEBUG and ($d < $MINDUR));
	print "Scheduling host $h\n" if($DEBUG);
	if( !defined $downtime{"$h:$s"} ) {
		if($NAGVER>=2) {
			$rv = sendcmd "SCHEDULE_HOST_DOWNTIME;$h;$s;".($s+($d*60)).";1;0;".($d*60).";$u;$c";
		} else {
			$rv = sendcmd "SCHEDULE_HOST_DOWNTIME;$h;$s;".($s+($d*60)).";1;0;$u;$c";
		}
	
		if($SVCALSO) {
			if($NAGVER>=2) {
				$rv = sendcmd "SCHEDULE_HOST_SVC_DOWNTIME;$h;$s;"
					.($s+($d*60)).";1;0;".($d*60).";$u;$c" if(!$rv);
			} else {
				$rv = sendcmd "SCHEDULE_HOST_SVC_DOWNTIME;$h;$s;"
					.($s+($d*60)).";1;0;$u;$c" if(!$rv);
			}
		}
	} else { print "Already scheduled\n"; return 0; }
	return $rv;
}
sub schedule_service($$$$$$) {
	my($h,$svc,$s,$d,$u,$c) = @_;
	my($rv);
	$u = "Automatic" if(!$u);
	$c = "AUTO: $c" if($c);
	$c = "AUTO: Automatically scheduled for service" if(!$c);
	return "Invalid host $h!" if(!$h or !defined $hostsvc{$h});
	return "Invalid service!" if(!$svc);
	return "Invalid time $s!" if(!$s);
	return "Invalid duration $d!" if(!$DEBUG and ($d < $MINDUR));
	print "Scheduling service $h:$svc\n" if($DEBUG);
	$rv = 0;
	if( $svc =~ /\*/ ) { # wildcarded?
		$svc =~ s/\*/.*/g; # change to regexp
		foreach ( keys %{$hostsvc{$h}} ) {
			if( /^$svc$/ ) {
				if(!defined $downtime{"$h:$_:$s"}) {
				if($NAGVER>=2) {
				$rv = sendcmd "SCHEDULE_SVC_DOWNTIME;$h;$_;$s;".($s+($d*60)).";1;0;".($d*60).";$u;$c";
				} else {
				$rv = sendcmd "SCHEDULE_SVC_DOWNTIME;$h;$_;$s;".($s+($d*60)).";1;0;$u;$c";
				}
				} else { print "Already scheduled!\n"; }
			}
			last if($rv);
		}
	} else {
		return "Invalid service $s on host $h!" if(!defined $hostsvc{$h}{$svc});
		if(!defined $downtime{"$h:$svc:$s"}) {
			if($NAGVER>=2) {
				$rv = sendcmd "SCHEDULE_SVC_DOWNTIME;$h;$svc;$s;".($s+($d*60)).";1;0;".($d*60).";$u;$c";
			} else {
				$rv = sendcmd "SCHEDULE_SVC_DOWNTIME;$h;$svc;$s;".($s+($d*60)).";1;0;$u;$c";
			}
		} else { print "Already scheduled!\n"; }
	}
	return $rv;
}
sub schedule_hostgroup($$$$$) {
	my($hg,$s,$d,$u,$c) = @_;
	my($rv,$h);
	$u = "Automatic" if(!$u);
	$c = "AUTO: $c" if($c);
	$c = "AUTO: Automatically scheduled for hostgroup" if(!$c);
	return "Invalid hostgroup $hg!" if(!$hg);
	return "Invalid time $s!" if(!$s);
	return "Invalid duration $d!" if(!$DEBUG and ($d < $MINDUR));
	print "Scheduling hostgroup $hg\n" if($DEBUG);
	$rv = 0;
	if( $NAGVER >= 2 ) {
		print "Checking hostgroup representative ".$hostgroups{$hg}[0].":$s\n" if($DEBUG);
		if(!defined $downtime{$hostgroups{$hg}[0].":$s"}) {
		$rv = sendcmd "SCHEDULE_HOSTGROUP_HOST_DOWNTIME;$hg;$s;".($s+($d*60))
			.";1;0;0;$u;$c\n";
		if($SVCALSO) {
			$rv = sendcmd "SCHEDULE_HOSTGROUP_SERVICE_DOWNTIME;$hg;$s;"
				.($s+($d*60)).";1;0;0;$u;$c\n" if(!$rv);
		}
		} else { print "Already scheduled!\n"; }
	} else {
		return "Hostgroup $hg not recognised!" if(!defined $hostgroups{$hg}) ;
		foreach $h ( @{$hostgroups{$hg}} ) {
			if( !defined $downtime{"$h:$s"} ) {
				$rv = sendcmd "SCHEDULE_HOST_DOWNTIME;$h;$s;"
					.($s+($d*60)).";1;0;$u;$c";
				if($SVCALSO) {
					$rv = sendcmd "SCHEDULE_HOST_SVC_DOWNTIME;$h;$s;"
						.($s+($d*60)).";1;0;$u;$c" if(!$rv);
				}
			} else { print "Already scheduled!\n"; }
			last if($rv);
		}
	}
	return $rv;
}
############################################################################
sub readhgcfg {
	my($name,@members);
	return if( $NAGVER >= 2 ); # not needed: it came from the objects
	%hostgroups = ();
	print "Reading $HGCFG..." if($DEBUG);
	open HG, "<$HGCFG";
	while ( <HG> ) {
		if( /^\s*define / ) { $name = ""; next; }
		if( /^\s*hostgroup_name\s+(\S+)/ ) { $name = $1; next; }
		if( $name and /^\s*members\s+(.*)$/ ) {
			@members = split /[,\s]+/,$1;
			$hostgroups{$name} = [ @members ];
			$name = "";
		}
	}
	close HG;
	print "Done.\n" if($DEBUG);
}

############################################################################
my( @schedules ) = ();

sub readcfg {
	my(%newsched);
	my($line,$k,$v);
	open CFG, "<$CFGFILE" or return "Error: $CFGFILE: $!";
	while( $line=<CFG> ) {
		chomp $line;
		$line =~ s/#.*$//;
		next if(!$line);
		if( $line =~ /^\s*define\s+schedule\s+{/i ) { %newsched = (); next; }
		if( $line =~ /^\s*}/ ) { 
			push @schedules, { %newsched }
				if(%newsched);; 
			next; 
		}
		if( $line =~ /^\s*(\S+)\s*(\S.*)/ ) { 
			($k,$v)=($1,$2);
			$v =~ s/\s*$//; # trim trailing spaces
			$newsched{$k} = $v; 
		}
	}
	close CFG;
	return 0;
}
sub numerically { $a<=>$b; }
my %dow = ( mon=>1, tue=>2, wed=>3, thu=>4, fri=>5, sat=>6, sun=>0 );
sub parse_days($) {
	my(@rv);

	foreach my $dn ( split /[,\s]+/,$_[0] ) {
		$dn = lc( substr($dn,0,3) );
		push @rv,$dow{$dn} if(defined $dow{$dn});
		push @rv,($1+0) if($dn=~/(\d+)/);
	}
	return ( sort numerically @rv );
}
sub parse_dates($) {
	my(@rv);
	foreach ( split /[,\s]+/,$_[0] ) { push @rv,($_+0); }
	return ( sort numerically @rv );
}

sub checkscheds {
	my($sref);
	my($T) = time();
	my($dow,$h,$min,$d,$m,$y,$next,$nh,$nmin,$nd,$nm,$ny,$rv);
	my(@lt,@nlt,@lst,$f,$t);

	# Identify 'now'.
	@lt = localtime($T);
	($dow,$h,$min,$d,$m,$y) = ($lt[6],$lt[2],$lt[1],$lt[3],$lt[4],$lt[5]);

	# Loop through all known schedules, find their next due time
	foreach  $sref ( @schedules ) {
		if($DEBUG) {
			if(defined $sref->{comment}) {
				print $sref->{comment} .": ";
			} else {
				print "Next schedule: ";
			}
			print " ".$sref->{host_name} if(defined $sref->{host_name});
			print " ".$sref->{service_description} if(defined $sref->{service_description});
			print "\n";
		}
		$t = $sref->{'time'};
		next if($t !~ /^(\d\d?):(\d\d)/);
		# start with scheduled time, today (may be in the past)
		($nh,$nmin)=($1,$2);
		($nd,$nm,$ny)=($d,$m,$y);
		print "Current candidate: $nh:$nmin on $nd/".($nm+1)."/".($ny+1900)."\n" if($DEBUG);
		# if in the past, advance one day
		if(($h>$nh) or ($h==$nh and $min>$nmin) ) {
			$nd+=1;
			if(($nd>29)and($nm==1)and(int($ny/4)==($ny/4)))
				{$nm+=1;$nd-=29;} #  Leap yrs?
			if(($nd>28)and($nm==1)) {$nm+=1;$nd-=28;}
            if(($nd>30)and($nm==8 or $nm==3 or $nm==5 or $nm==10))
                    {$nm+=1;$nd-=30;}
			if($nd>31) {$nm+=1;$nd-=31;} 
			if($nm>11) {$ny+=1;$nm-=12;}
		}
		# now see if we have a filter on dates.  If so, advance until we
		# get a valid date
		if( $sref->{days_of_month} ) {
			@lst = parse_dates($sref->{days_of_month});	# already sorted
			if($#lst>=0) { # any set?
				$f = 0;
				# take the smallest >= our planned time
				foreach ( @lst ) { if( $_ >= $nd ) { $nd=$_; $f = 1; last; } }
				# must be in next month, then
				if(!$f) { $nd = $lst[0]; $nm+=1; if($nm>11){$nm-=12;$ny+=1;} }
			}
		}
		# identify day of week we are looking at
		eval {
			$next = timelocal( 0,$nmin,$nh,$nd,$nm,$ny );
		};
		if($@) { print "$@\n"; next; }
		@nlt = localtime($next); # to get day of week
		print "Current candidate: $nh:$nmin on $nd/".($nm+1)."/".($ny+1900)."\n" if($DEBUG);
		# is there a day-of-week filter?
		if( $sref->{days_of_week} ) {
			@lst = parse_days($sref->{days_of_week});	
			if($#lst>=0) {
				print "Checking days of week: days (".(join ",",@lst).") are valid\n" if($DEBUG);
				$f = 0;
				# loop through all possible days
				foreach ( @lst ) { 
					if( $_ >= $nlt[6] ) { 
						print "Scheduling for day $_ (today is $dow, looking at scheds for ".$nlt[6]." and later)\n" if($DEBUG); 
						$nd+=($_-$nlt[6]); $f = 1; last; 
					} 
				}
				if(!$f) { $nd +=(7-$dow+$lst[0]); 
					print "Advancing a week to day ".$lst[0]."\n" if($DEBUG); }
				# if we advanced the day, then make sure the month is right
				if(($nd>29)and($nm==1)and(int($ny/4)==($ny/4)))
					{$nm+=1;$nd-=29;} #  Leap yrs?
				if(($nd>28)and($nm==1)) {$nm+=1;$nd-=28;}
				if(($nd>30)and($nm==8 or $nm==3 or $nm==5 or $nm==10))
					 {$nm+=1;$nd-=30;} 
				if($nd>31) {$nm+=1;$nd-=31;} 
				if($nm>11){$nm-=12;$ny+=1; } 
			}
		}

		# convert the planned event to a time_t
		eval {
		$next = timelocal( 0,$nmin,$nh,$nd,$nm,$ny );
		};
		if($@) { print "$@\n"; next; }
		print "Current candidate: $nh:$nmin on $nd/".($nm+1)."/".($ny+1900)."\n" if($DEBUG);
		# now we know when its next due to run!

		if( $next < $T ) { print "ERROR!  Going back in time?\n"; next; }
		if( ($next-$T) <= ($FREQUENCY*60) ) {
			# Schedule it!
			$rv = "";
			if( $sref->{schedule_type} =~ /hostgroup|hg/i ) {
$rv = schedule_hostgroup($sref->{hostgroup_name} ,$next,$sref->{duration},$sref->{user},$sref->{comment});
			} elsif( $sref->{schedule_type} =~ /host/i ) {
$rv = schedule_host($sref->{host_name} ,$next,$sref->{duration},$sref->{user},$sref->{comment});
			} elsif( $sref->{schedule_type} =~ /service|svc/i ) {
$rv = schedule_service($sref->{host_name},$sref->{service_description} ,$next,$sref->{duration},$sref->{user},$sref->{comment});
			} else {
				$rv =  "Unknown schedule type : ".$sref->{schedule_type};	
			}
			if($rv) {
				print "ERROR: $rv\n";
			}
		} else {
			print "Not yet time for this one (wait ".(($next-$T)/3600)."hr)\n" if($DEBUG);
		}
	}
}

############################################################################

$DEBUG = 1 if($ARGV[0] =~ /-d/);

print "Reading in configuration\n";
$rv = readcfg;
if($rv) {
	print "ERROR: $rv\n";
	exit 1;
}
print "Reading in status log to get list of services\n";
if( $OBJECTS and -f $OBJECTS ) { readobjects; } 
	else { readstatuslog; readhgcfg; }
print "Reading in list of already scheduled downtime\n";
readdowntime2; 
print "Checking for downtime due in next $FREQUENCY minutes\n";
checkscheds;

exit 0;
