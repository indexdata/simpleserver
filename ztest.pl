#!/usr/bin/perl -w

use ExtUtils::testlib;
use Net::Z3950::SimpleServer;
use Net::Z3950::OID;
use strict;


sub dump_hash {
	my $href = shift;
	my $key;

	foreach $key (keys %$href) {
		printf("%10s	=>	%s\n", $key, $href->{$key});
	}
}


sub my_init_handler {
	my $args = shift;
	my $session = {};

	$args->{IMP_NAME} = "DemoServer";
	$args->{IMP_VER} = "3.14159";
	$args->{ERR_CODE} = 0;
	$args->{HANDLE} = $session;
}

sub my_scan_handler {
	my $args = shift;
	my $term = $args->{TERM};
	my $entries = [
				{	TERM		=>	'Number 1',
					OCCURRENCE	=>	10 },
				{	TERM		=>	'Number 2',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 3',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 4',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 5',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 6',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 7',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 8',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 9',
					OCCURRENCE	=>	8 },
				{	TERM		=>	'Number 10',
					OCCURRENCE	=>	4 },
			];


	$args->{NUMBER} = 10;
	$args->{ENTRIES} = $entries;
	print "Welcome to scan....\n";
	print "You scanned for term '$term'\n";
}


sub my_search_handler { 
	my $args = shift;
	my $data = [{
			name		=>	"Peter Dornan",
			title		=>	"Spokesman",
			collaboration	=>	"ATLAS"
	    	    }, {
			name		=>	"Jorn Dines Hansen",
			title		=>	"Professor",
			collaboration	=>	"HERA-B"
	    	    }, {
			name		=>	"Alain Blondel",
			title		=>	"Head of coll.",
			collaboration	=>	"ALEPH"
	   	    }];

	my $session = $args->{HANDLE};
	my $set_id = $args->{SETNAME};
	my @database_list = @{ $args->{DATABASES} };
	my $query = $args->{QUERY};
	my $hits = 3;

	print "------------------------------------------------------------\n";
	print "Processing query : $query\n";
	printf("Database set     : %s\n", join(" ", @database_list));
	print "Setname          : $set_id\n";
	print "------------------------------------------------------------\n";

	$args->{HITS} = $hits;
	$session->{$set_id} = $data;
	$session->{__HITS} = $hits;
}


sub my_fetch_handler {
	my $args = shift;
	my $session = $args->{HANDLE};
	my $set_id = $args->{SETNAME};
	my $data = $session->{$set_id};
	my $offset = $args->{OFFSET};
	my $record = "<xml>";
	my $field;
	my $hits = $session->{__HITS};
	my $href = $data->[$offset - 1];

	$args->{REP_FORM} = Net::Z3950::OID::xml;
	foreach $field (keys %$href) {
		$record .= "<" . $field . ">" . $href->{$field} . "</" . $field . ">";
	}

	$record .= "</xml>";
	$args->{RECORD} = $record;
	if ($offset == $session->{__HITS}) {
		$args->{LAST} = 1;
	}
}


my $handler = new Net::Z3950::SimpleServer( 
		INIT	=>	\&my_init_handler,
		SEARCH	=>	\&my_search_handler,
		SCAN	=>	\&my_scan_handler,
		FETCH	=>	\&my_fetch_handler );

$handler->launch_server("ztest.pl", @ARGV);


## $Log: ztest.pl,v $
## Revision 1.8  2001-08-24 14:00:20  sondberg
## Added support for scan.
##
## Revision 1.7  2001/03/13 14:20:21  sondberg
## Added CVS logging
##

