#!/usr/bin/perl
# vim:ts=4
#
# Steve Shipway
# View and modify the recurring downtime schedules for Nagios
# These are activated by the downtime_job.pl script in Nagios' crontabs

# TO DO: Add authentication to this, so you can only schedule for your own
#        hosts and hostgroups!
#
# Version 1.3: added verification of host and service names, allow wildcards
# Version 1.4: More validity checks
#         1.6: no real changes
#         2.0: nagios 2.x support
#         3.0: nagios 3.x support

use strict;
use CGI;

my($NAGIOS) = "/u02/nagios";
my($CFGFILE) = "$NAGIOS/etc/schedule.cfg"; # My config file!
my($CMDCGI) = "/nagios/cgi-bin/cmd.cgi";

# If you have Nagios 1.x define this
my($STATUSLOG) = "$NAGIOS/log/status.log";# if defined, check validity
# If you have Nagios 2.x or 3.x, define this
my($OBJECTS) = "$NAGIOS/log/objects.cache";# if defined, use nagios2 cache

my($USER);
my($DEBUG) = 0;
my($rv);
my( @schedules ) = ();
my($q,$cmd,$seq,$type);
my(%hostsvc,%hgroup);
##############################################################################
sub readstatuslog { # This is for Nagios 1.x
	%hostsvc = ();
	return if(! -r $STATUSLOG);
	open SL, "<$STATUSLOG" or return;
	while( <SL> ) {
		if( /^\[\d+\]\s+SERVICE;([^;]+);([^;]+);/ ) {
			$hostsvc{$1}{$2} = 1;
		}
	}
	close SL;
}
sub readobjects {
	my($ohost,$osvc,$ohg) = ("","","");
	%hostsvc = (); %hgroup = ();
	return if(! -r $OBJECTS);
	open OBJ, "<$OBJECTS" or return;
	while( <OBJ> ) {
		if( /^define service / ) {
			$osvc = 1; next;
		} elsif( /^define hostgroup / ) {
			$ohg = 1; next;
		} elsif( /^}/ ) {
			$ohost = $osvc = $ohg = "";
		} elsif( $osvc ) {
			if( /host_name\s+(.*\S)/ ) {
				$ohost = $1; 
			} elsif( /service_description\s+(.*\S)/ ) {
				$hostsvc{$ohost}{$1} = 1;
				$ohost = $osvc = "";
			}
		} elsif( $ohg ) {
			if( /hostgroup_name\s+(.*\S)/ ) {
				$hgroup{$1} = 1; $ohg="";
			}
		}
	}
	close OBJ;
}

sub byhname {
	my($na,$nb);
	$na = $a->{host_name};
	$na = $a->{hostgroup_name} if(!$na);
	$nb = $b->{host_name};
	$nb = $b->{hostgroup_name} if(!$nb);
	return ( $na cmp $nb );
}
##############################################################################

sub header {
	my($now) = scalar localtime();
	print $q->start_html(-title=>"Recurring Downtime Schedule",
		-style=>{-src=>"/nagios/stylesheets/extinfo.css"});
	print  <<_END_
<TABLE border=0 width=100%><TR>
<td align=left valign=top width=33%>
<TABLE CLASS='infoBox' BORDER=1 CELLSPACING=0 CELLPADDING=0>
<TR><TD CLASS='infoBox'>
<DIV CLASS='infoBoxTitle'>All Scheduled Recurring Downtime</DIV>
Last Updated: $now<BR>
Nagios&reg; - <A HREF='http://www.nagios.org' TARGET='_new' CLASS='homepageURL'>www.nagios.org</A><BR>
Logged in as <i>$USER</i><BR>
</TD></TR></TABLE></td>
<td align=center valign=center width=33%>
</td><td align=right valign=bottom width=33%>
</td></tr></table><BR>
_END_
;
	print "<P><DIV CLASS='downtimeNav'>[ &nbsp;<A HREF='#HOSTGROUPDOWNTIME' CLASS='downtimeNav'>Hostgroup Downtime</A>&nbsp;| &nbsp;<A HREF='#HOSTDOWNTIME' CLASS='downtimeNav'>Host Downtime</A>&nbsp;| &nbsp;<A HREF='#SERVICEDOWNTIME' CLASS='downtimeNav'>Service Downtime</A>&nbsp;]</DIV></P>\n";
}
sub aeheader {
	my($now) = scalar localtime();
	print $q->start_html(-title=>"Recurring Downtime Schedule",
		-style=>{-src=>"/nagios/stylesheets/cmd.css"});
	print  <<_END_
<TABLE border=0 width=100%><TR>
<td align=left valign=top width=33%>
<TABLE CLASS='infoBox' BORDER=1 CELLSPACING=0 CELLPADDING=0>
<TR><TD CLASS='infoBox'>
<DIV CLASS='infoBoxTitle'>Downtime Schedule Editor</DIV>
Last Updated: $now<BR>
Nagios&reg; - <A HREF='http://www.nagios.org' TARGET='_new' CLASS='homepageURL'>www.nagios.org</A><BR>
Logged in as <i>$USER</i><BR>
</TD></TR></TABLE></td>
<td align=center valign=center width=33%>
</td><td align=right valign=bottom width=33%>
</td></tr></table><BR>
_END_
;
	print "<P><DIV ALIGN=CENTER CLASS='cmdType'>You are ";
	if($q->param('cmd') eq 'add') { print "requesting to create" ; }
	else { print "modifying"; }
	print " a recurring schedule</DIV></P>\n";
}
sub footer {
	print $q->end_html."\n";
}

##############################################################################

sub readconfig {
	my(%newsched);
	my($line,$k,$v);
	my($seq) = 1;
	open CFG, "<$CFGFILE" or return "Error: $CFGFILE: $!";
	while( $line=<CFG> ) {
		chomp $line;
		$line =~ s/#.*$//;
		next if(!$line);
		if( $line =~ /^\s*define\s+schedule\s+{/i ) { %newsched = ( seq=>$seq ); next; }
		if( $line =~ /^\s*}/ ) { push @schedules, { %newsched }; $seq++; next; }
		if( $line =~ /^\s*(\S+)\s*(\S.*)$/ ) { 
			($k,$v) = ($1,$2); $v =~ s/\s+$//; 
			$newsched{$k} = $v; 
		}
	}
	close CFG;
#	print "<P>We have ".($#schedules+1)." schedules</P>\n";
	return 0;
}
############################################################################
sub listschedules {
	my($filter,$label,$heading) = @_;
	my($l) = "Even"; my($n) = 0; my($cnt) = 0;
	my($class);

	print "<A NAME=$label></A><DIV CLASS='downtimeTitle'>$heading</DIV><div CLASS='comment'><img src='/nagios/images/downtime.gif' border=0>&nbsp;<a href='".$q->url()."?type=$filter&cmd=add'>Add new downtime schedule</a></div><P>";

	print "<DIV ALIGN=CENTER><TABLE BORDER=0 CLASS='downtime'>\n";

	print "<TR CLASS='downtime'>";
	print "<TH CLASS='downtime'>Hostgroup Name</TH>" if($filter eq "hostgroup");
	print "<TH CLASS='downtime'>Host Name</TH>" if($filter ne "hostgroup");
	print "<TH CLASS='downtime'>Service</TH>" if($filter eq "service");

	print "<TH CLASS='downtime'>Author</TH><TH CLASS='downtime'>Comment</TH><TH CLASS='downtime'>Time</TH><TH CLASS='downtime'>Duration</TH>\n";
	print "<TH CLASS='downtime'>Dates of month</TH><TH CLASS='downtime'>Days of week</TH>\n";
	print "<TH CLASS='downtime'>Actions</TH></TR>";

	if( -f $OBJECTS) { readobjects; } else { readstatuslog; }

	foreach my $sref ( sort byhname @schedules ) {
		next if( lc ($sref->{schedule_type}) ne lc($filter) );
		$n = $sref->{seq};

		$class = "downtime$l";
		if( %hostsvc and $sref->{host_name} and $sref->{host_name}!~/\*/) {
			if( ! defined $hostsvc{$sref->{host_name}} ) {
				$class="serviceCRITICAL";
			} elsif( $sref->{service_description} 
				and $sref->{service_description}!~/\*/ ) {
				if( ! defined $hostsvc{$sref->{host_name}}{$sref->{service_description}} ) {
					$class="serviceCRITICAL";
				}
			}
		}
		# this only works for Nagios2
		if( %hgroup and $sref->{hostgroup_name} ) {
			if( ! defined $hgroup{$sref->{hostgroup_name}} ) {
				$class="serviceCRITICAL";
			}
		}

		print "<tr CLASS='$class'>";
		print "<td CLASS='$class'><A HREF='extinfo.cgi?type=5&hostgroup=".$sref->{hostgroup_name}."'>".$sref->{hostgroup_name}."</A></td>\n" if($filter eq 'hostgroup');
		if($filter ne 'hostgroup') {
			if( defined $hostsvc{$sref->{host_name}} ) {
				print "<td CLASS='$class'><A HREF='extinfo.cgi?type=1&host=".$sref->{host_name}."'>".$sref->{host_name}."</A></td>\n" ;
			} else {
				print "<td CLASS='$class'>".$sref->{host_name}."</td>\n" ;
			}
		}
		if( $filter eq 'service' ) {
			if( $sref->{service_description} =~ /\*/ 
				or !defined $hostsvc{$sref->{host_name}}
				or !defined $hostsvc{$sref->{host_name}}{$sref->{service_description}}
				) {
				print "<td CLASS='$class'>".$sref->{service_description}."</td>\n";
			} else {
				print "<td CLASS='$class'><A HREF='extinfo.cgi?type=2&host=".$sref->{host_name}."&service=".$sref->{service_description}."'>".$sref->{service_description}."</A></td>\n";
			}
		}

		print "<td CLASS='$class'>".$sref->{user}."</td><td CLASS='$class'>".$sref->{comment}."</td><td CLASS='$class'>".$sref->{'time'}."</td><td CLASS='$class'>".$sref->{duration}."min</td>\n";
		print "<td CLASS='$class'>".$sref->{days_of_month}."</td><td CLASS='$class'>".$sref->{days_of_week}."</td>\n";

		print "<td>";
		print "<a href='".$q->url()."?cmd=edit&seq=".($n-1)."'><img src='/nagios/images/comment.gif' border=0 ALT='Edit This Schedule Entry'>";
		print "<a href='".$q->url()."?cmd=del&seq=".($n-1)."'><img src='/nagios/images/delete.gif' border=0 ALT='Delete/Cancel This Schedule Entry'>";
		print "</td></tr>\n";

		if( $l eq "Even" ) { $l = "Odd"; } else { $l = "Even"; }
		$cnt += 1;
	}
	if(!$cnt) {	
		print "<TR CLASS='$class'><TD CLASS='$class' COLSPAN=".(($filter eq 'service')?9:8).">There are no recurring $filter downtime schedules</TD></TR>\n";
	}

	print "</TABLE><P><BR></P>\n";

}

############################################################################
sub dolist {
print $q->header(-expires=>"now");
header;
$rv=readconfig;
if($rv) { print "<h1>Error</h1><B>$rv</B>\n"; }
listschedules("hostgroup","HOSTGROUPDOWNTIME","Recurring Hostgroup Downtime");
listschedules("host","HOSTDOWNTIME","Recurring Host Downtime");
listschedules("service","SERVICEDOWNTIME","Recurring Service Downtime");
print "<center><P>Items listed in red are schedules for unrecognised hostgroup, host or service names.  Wildcards are not checked for matches.</P></center>\n";
		
footer;
}
# This prompts the user
sub editpage($$$) {
	my($type,$seq,$next) = @_;
	my($sptr);

#	readstatuslog;
#	if( -f $OBJECTS) { readobjects; } else { readstatuslog; }

	if( $seq >= 0 ) { $sptr = $schedules[$seq]; } else { $sptr = 0; }

	print <<_END_
<p> <div align='center'> <table border=0 width=90%>
	<tr> <td align=center valign=top>
<DIV ALIGN=CENTER CLASS='optBoxTitle'>Schedule Options</DIV>
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=1 CLASS='optBox'>
<TR><TD CLASS='optBoxItem'>
<TABLE CELLSPACING=0 CELLPADDING=0 CLASS='optBox'>
<tr><td CLASS='optBoxItem'>
_END_
;
	print "<form method='post' action='".$q->url()."'></td><td><INPUT TYPE='HIDDEN' NAME='cmd' VALUE='$next'><INPUT TYPE='HIDDEN' NAME='type' VALUE='$type'>\n";
	print "<INPUT TYPE='HIDDEN' NAME='seq' VALUE='$seq'>\n" if($seq>=0);
	
	print "</td></tr>\n";

	if($type eq 'hostgroup') {
		print "<tr><td CLASS='optBoxRequiredItem'>Hostgroup Name:</td><td><b><INPUT TYPE='TEXT' NAME='hostgroup' VALUE='".($sptr?$sptr->{hostgroup_name}:'')."'></b></td></tr>\n";
	} else {
		print "<tr><td CLASS='optBoxRequiredItem'>Host Name:</td><td><b>";
#		if( %hostsvc ) {
#			print $q->popup_menu(-name=>'host',-values=>[(keys %hostsvc)],-default=>($sptr?$sptr->{host_name}:''));
#		} else {
			print "<INPUT TYPE='TEXT' NAME='host' VALUE='".($sptr?$sptr->{host_name}:'')."'>";
#		}
		print "</b></td></tr>\n";
		print "<tr><td CLASS='optBoxRequiredItem'>Service Name:</td><td><b><INPUT TYPE='TEXT' NAME='service' VALUE='".($sptr?$sptr->{service_description}:'')."'></b></td></tr>\n" if($type eq 'service');
	}

	print "<tr><td CLASS='optBoxRequiredItem'>Author (Your Name):</td><td><b><INPUT TYPE='TEXT' NAME='user' VALUE='".($sptr?$sptr->{user}:$USER)."'></b></td></tr>\n";

	print "<tr><td CLASS='optBoxRequiredItem'>Comment:</td><td><b><INPUT TYPE='TEXT' NAME='comment' VALUE='".($sptr?$sptr->{comment}:'Recurring schedule')."' SIZE=40></b></td></tr>\n";

	print "<tr><td CLASS='optBoxRequiredItem'>Time:</td><td><b><INPUT TYPE='TEXT' NAME='time' VALUE='".($sptr?$sptr->{'time'}:'01:00')."'></b> (hh:mm)</td></tr>\n";

	print "<tr><td CLASS='optBoxRequiredItem'>Duration:</td><td><INPUT TYPE='TEXT' NAME='duration' VALUE='".($sptr?$sptr->{duration}:'120')."' SIZE=8 > Minutes </td></tr>\n";

	print "<tr><td CLASS='optBoxItem'>Days of week:</td><td><b><INPUT TYPE='TEXT' NAME='day' VALUE='".($sptr?$sptr->{days_of_week}:'')."'></b> Mon, Tue, Wed, ...</td></tr>\n";

	print "<tr><td CLASS='optBoxItem'>Dates of month:</td><td><b><INPUT TYPE='TEXT' NAME='date' VALUE='".($sptr?$sptr->{days_of_month}:'')."'></b> 1, 2, 3 ...</td></tr>\n";

	print "<tr><td CLASS='optBoxItem' COLSPAN=2></td></tr> <tr><td CLASS='optBoxItem'></td><td CLASS='optBoxItem'><INPUT TYPE='submit' NAME='btnSubmit' VALUE='Commit'> <INPUT TYPE='reset' VALUE='Reset'></FORM></td></tr>\n";
	print "</table> </td> </tr> </table> </td>\n";

	print <<_END_
<td align=center valign=top width=50%>
<DIV ALIGN=CENTER CLASS='descriptionTitle'>Command Description</DIV>
<TABLE BORDER=1 CELLSPACING=0 CELLPADDING=0 CLASS='commandDescription'>
<TR><TD CLASS='commandDescription'>
This command is used to scedule a recurring downtime schedule.  A new Nagios
schedule will be added one day before it activates, according to the parameters
specified.  The start time should be HH:MM in 24-hour clock.  Duration should be
in minutes.  The days of week are a comma separated list of one or more of Mon,
Tue, Wed etc.  If left blank, it means all days.  The days of month are a comma
separated list of numbers.  If left blank, it means all days.<P>
If you specify days of week <i>and</i> days of the month, then <i>both</i>
must match for the downtime to be scheduled.<P>
Service names can use the wildcard '*' to mean 0 or more characters.
</TD></TR> </TABLE> </td> </tr> </table> </div> </p>
_END_
;
	print"<P><DIV CLASS='infoMessage'>Please enter all required information before committing the command.<br>Required fields are marked in red.<br>Failure to supply all required values will result in an error.</DIV></P>";

}

sub doedit($) {
	my($seq) = $_[0];
	my($rv,$type);

	print $q->header(-expires=>"now");
	aeheader;
	$rv=readconfig;
	if($rv) { 
		print "<h1>Error</h1><B>$rv</B>\n"; 
	} elsif($seq>$#schedules or $seq<0) {
		print "<h1>Error</h1><B>Bad sequence</B>\n"; 
	} else {
		$type = $schedules[$seq]{schedule_type};
		editpage($type,$seq,"edit2");
	}
	footer;
}
sub doadd($) {
	my($type) = $_[0];

	print $q->header(-expires=>"now");
	aeheader;
	editpage($type,-1,"add2");
	footer;
}
# These three actually do it
sub dodel($) {
	my($seq) = $_[0];
	my($n) = 0;
	my($tmp) = "/tmp/sched.$$.$seq";

	open TMP, ">$tmp" or return;
	open CFG, "<$CFGFILE" or return;
	while( <CFG> ) {
		if( /^\s*#/ ) { print TMP; next; } # All comments come over
		print TMP if( $n != $seq ); # Dont print it if we're in the nth
		if( /^\s*}/ ) { $n+=1; }    # end of definition, so next
	}
	close CFG;
	close TMP;
	open TMP, "<$tmp" or return;
	open CFG, ">$CFGFILE" or return;
	while( <TMP> ) { print CFG; }
	close CFG; close TMP; unlink $tmp;
}
sub doadd2 {
	my($type,$host,$hostgroup,$service,$user,$comment);
	my($time,$day,$date,$duration);
	my($p);

#	readstatuslog;
	if( -f $OBJECTS) { readobjects; } else { readstatuslog; }

	$host = $hostgroup = $service;
	$type = $q->param('type'); #return if(!$type);
	if($type ne 'hostgroup') { $host = $q->param('host'); return if(!$host); }
	if($type eq 'hostgroup') { $hostgroup = $q->param('hostgroup'); return if(!$hostgroup); }
	if($type eq 'service') { $service = $q->param('service'); return if(!$service); }
	# check validity: fix spaces and case errors automatically
	if($host) {
		$host =~ s/\s+$//;
		$host =~ s/^\s+//;
		if(!defined $hostsvc{$host}) {
			$p = $host; $p =~ s/\s+/\\s+/g;
			foreach ( keys %hostsvc ) {
				if( /$p/i ) { $host = $_; last; }
			}
		}
		if(!defined $hostsvc{$host}) {
			$host .= "[NOT FOUND]";
		}
		if(defined $hostsvc{$host} and $service and $service !~ /\*/ ) {
			$service =~ s/\s+$//;
			$service =~ s/^\s+//;
			if(!defined $hostsvc{$host}{$service}) {
				$p = $service; $p =~ s/\s+/\\s+/g;
				foreach ( keys %{$hostsvc{$host}} ) {
					if( /$p/i ) { $service = $_; last; }
				}
			}
			if(!defined $hostsvc{$host}{$service}) {
				$service .= "[NOT FOUND]";
			}
		}
	}
	if($hostgroup) {
		$hostgroup =~ s/\s+$//;
		$hostgroup =~ s/^\s+//;
		# cant check these yet
	}
	# now do it
	$user = $q->param('user'); $user = $USER if(!$user);
	$comment = $q->param('comment'); $comment = "From $user"  if(!$comment);
	$time = $q->param('time'); #return if($time !~ /^\d\d?:\d\d/ );
	$duration = $q->param('duration'); #return if(!$duration);
	$day = $q->param('day'); $date = $q->param('date'); 
	open CFG,">>$CFGFILE" or do { print "Write: $!"; return; };
	print CFG "define schedule {\n";
	print CFG "	schedule_type	$type\n";
	print CFG "	hostgroup_name		$hostgroup\n" if($type eq 'hostgroup');
	print CFG "	host_name		$host\n" if($type ne 'hostgroup');
	print CFG "	service_description		$service\n" if($type eq 'service');
	print CFG "	user			$user\n";
	print CFG "	comment		$comment\n";
	print CFG "	time  		$time\n";
	print CFG "	duration		$duration\n";
	print CFG "	days_of_week		$day\n" if($day);
	print CFG "	days_of_month		$date\n" if($date);
	print CFG "}\n";
	close CFG;
}
sub doedit2($) {
	my($seq) = $_[0];
	doadd2;
	dodel($seq);	
}
############################################################################

$q = new CGI;
$USER = $q->user_name;

$cmd = $q->param('cmd');
$cmd = '' if(!$cmd);

if($cmd eq 'del') {
	$seq = $q->param('seq'); $seq = -1 if(!defined $seq);
	if($seq>=0) { dodel($seq); } 
	dolist;
} elsif( $cmd eq 'edit' ) {
	$seq = $q->param('seq'); $seq = -1 if(!defined $seq);
	if($seq>=0) { doedit($seq); } else { dolist; }
} elsif( $cmd eq 'edit2' ) {
	$seq = $q->param('seq'); $seq = -1 if(!defined $seq);
	if($seq>=0) { doedit2($seq); } 
	dolist;
} elsif( $cmd eq 'add' ) {
	$type = $q->param('type'); 
	if($type) { doadd($type); } else { dolist; }
} elsif( $cmd eq 'add2' ) {	
	doadd2; dolist;
} else {
	dolist;
}
exit(0);
