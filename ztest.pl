#!/usr/bin/perl -w

##  $Id: ztest.pl,v 1.13 2004-05-28 20:27:16 sondberg Exp $
##  ------------------------------------------------------------------
##
##  Copyright (c) 2000-2004, Index Data.
##
##  Permission to use, copy, modify, distribute, and sell this software and
##  its documentation, in whole or in part, for any purpose, is hereby granted,
##  provided that:
##
##  1. This copyright and permission notice appear in all copies of the
##  software and its documentation. Notices of copyright or attribution
##  which appear at the beginning of any file must remain unchanged.
##
##  2. The name of Index Data or the individual authors may not be used to
##  endorse or promote products derived from this software without specific
##  prior written permission.
##
##  THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY OF ANY KIND,
##  EXPRESS, IMPLIED, OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY
##  WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
##  IN NO EVENT SHALL INDEX DATA BE LIABLE FOR ANY SPECIAL, INCIDENTAL,
##  INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND, OR ANY DAMAGES
##  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER OR
##  NOT ADVISED OF THE POSSIBILITY OF DAMAGE, AND ON ANY THEORY OF
##  LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
##  OF THIS SOFTWARE.
##

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
	$args->{IMP_ID} = "81";
	$args->{IMP_VER} = "3.14159";
	$args->{ERR_CODE} = 0;
	$args->{HANDLE} = $session;
	if (defined($args->{PASS}) && defined($args->{USER})) {
	    printf("Received USER/PASS=%s/%s\n", $args->{USER},$args->{PASS});
	}
	    
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
	$args->{STATUS} = Net::Z3950::SimpleServer::ScanPartial;
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
		INIT	=>	"main::my_init_handler",
		SEARCH	=>	"main::my_search_handler",
		SCAN	=>	"main::my_scan_handler",
		FETCH	=>	"main::my_fetch_handler" );

$handler->launch_server("ztest.pl", @ARGV);
