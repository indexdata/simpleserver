#!/usr/bin/perl -w

#use Carp qw(cluck); $SIG{__WARN__} = sub { cluck @_ };

## This file is part of simpleserver
## Copyright (C) 2000-2017 Index Data.
## All rights reserved.
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
##     * Redistributions of source code must retain the above copyright
##       notice, this list of conditions and the following disclaimer.
##     * Redistributions in binary form must reproduce the above copyright
##       notice, this list of conditions and the following disclaimer in the
##       documentation and/or other materials provided with the distribution.
##     * Neither the name of Index Data nor the names of its contributors
##       may be used to endorse or promote products derived from this
##       software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
## EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
## WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
## DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
## DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
## (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
## LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
## ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
## (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
## THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use ExtUtils::testlib;
use Data::Dumper;
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

	print("IMP_ID = '", $args->{IMP_ID}, "'\n");
	print("IMP_NAME = '", $args->{IMP_NAME}, "'\n");
	print("IMP_VER = '", $args->{IMP_VER}, "'\n");
	print("ERR_CODE = '", $args->{ERR_CODE}, "'\n");
	print("ERR_STR = '", $args->{ERR_STR}, "'\n");
	print("PEER_NAME = '", $args->{PEER_NAME}, "'\n");
	print("PID = '", $args->{PID}, "'\n");

	if (defined($args->{USER})) {
	    printf("Received USER=%s\n", $args->{USER});
	}
	if (defined($args->{GROUP})) {
	    printf("Received GROUP=%s\n", $args->{GROUP});
	}
	if (defined($args->{PASS})) {
	    printf("Received PASS=%s\n", $args->{PASS});
	}

	$args->{IMP_NAME} = "DemoServer";
	$args->{IMP_ID} = "81";
	$args->{IMP_VER} = "3.14159";
	$args->{ERR_CODE} = 0;
	$args->{HANDLE} = $session;
}


sub my_sort_handler {
    my ($args) = @_;

    print "Sort handler called\n";
    print Dumper( $args );
}

sub my_scan_handler {
	my $args = shift;
	my $term = $args->{TERM};
	my $entries = [
				{	TERM		=>	'Number 1',
					DISPLAY_TERM    =>      'Number .1',
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
	$args->{EXTRA_RESPONSE_DATA} = '<scanextra>b</scanextra>';
	print "You scanned for term '$term'\n";
}


my $_fail_frequency = 0;
my $_counter = 0;

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
	my $rpn = $args->{RPN};
	my @database_list = @{ $args->{DATABASES} };
	my $query = $args->{QUERY};
	my $facets = my_facets_response($args->{INPUTFACETS});
	my $hits = 3;

	print "------------------------------------------------------------\n";
	print "Processing query : $query\n";
	printf("Database set     : %s\n", join(" ", @database_list));
	print "Setname          : $set_id\n";
	print " inputfacets:\n";
	print Dumper($facets);
        print " extra args:\n";
        print Dumper($args->{EXTRA_ARGS});
	print "------------------------------------------------------------\n";

	$args->{OUTPUTFACETS} = $facets;

	$args->{EXTRA_RESPONSE_DATA} = '<searchextra>b</searchextra>';
	$args->{HITS} = $hits;
	$session->{$set_id} = $data;
	$session->{__HITS} = $hits;
	if ($_fail_frequency != 0 && ++$_counter % $_fail_frequency == 0) {
	    print "Exiting to be nasty to client\n";
	    exit(1);
	}
}

sub my_facets_response {
	my $inputfacets = shift;
	if (!$inputfacets) {
		# no facets requested: generate default input facets
		$inputfacets = [
			{ attributes => [
				  { attributeType => 1,
				    attributeValue => 'author'
				  },
				  { attributeType => 2,
				    attributeValue => 0
				  },
				  { attributeType => 3,
				    attributeValue => 5
				  },
				  { attributeType => 4,
				    attributeValue => 1
				  }
			      ]
			},
			{ attributes => [
				  { attributeType => 1,
				    attributeValue => 'title'
				  },
				  { attributeType => 2,
				    attributeValue => 0
				  },
				  { attributeType => 3,
				    attributeValue => 5
				  },
				  { attributeType => 4,
				    attributeValue => 1
				  }
			      ]
			}
		    ];
	}
	# generate facets response. we use inputfacets as basis
	my $zfacetlist = [];
	bless $zfacetlist, 'Net::Z3950::FacetList';
	my $i = 0;
	foreach my $x (@$inputfacets) {
		my $facetname = "unknown";
		my $sortorder = 0;
		my $count = 5;
		my $offset = 1;
		foreach my $attr (@{$x->{'attributes'}}) {
			my $type = $attr->{'attributeType'};
			my $value = $attr->{'attributeValue'};
			print "attr " . $type . "=" . $value . "\n";
			if ($type == 1) { $facetname = $value; }
			if ($type == 2) { $sortorder = $value; }
			if ($type == 3) { $count = $value; }
			if ($type == 4) { $offset = $value; }
		}
		my $zfacetfield = {};
		bless $zfacetfield, 'Net::Z3950::FacetField';
		if ($count > 0) {
			$zfacetlist->[$i++] = $zfacetfield;
		}
		my $zattributes = [];
		bless $zattributes, 'Net::Z3950::RPN::Attributes';
		$zfacetfield->{'attributes'} = $zattributes;
		my $zattribute = {};
		bless $zattribute, 'Net::Z3950::RPN::Attribute';
		$zattribute->{'attributeType'} = 1;
		$zattribute->{'attributeValue'} = $facetname;
		$zattributes->[0] = $zattribute;
		my $zfacetterms = [];
		bless $zfacetterms, 'Net::Z3950::FacetTerms';
		$zfacetfield->{'terms'} = $zfacetterms;

		my $j = 0;
		while ($j < $count) {
			my $zfacetterm = {};
			bless $zfacetterm, 'Net::Z3950::FacetTerm';
			# just a fake term ..
			$zfacetterm->{'term'} = "t" . $j;
			# most frequent first (fake count)
			my $freq = $count - $j;
			$zfacetterm->{'count'} = $freq;
			$zfacetterms->[$j++] = $zfacetterm;
		}
	}
	return $zfacetlist;
}

sub my_fetch_handler {
	my $args = shift;
	my $session = $args->{HANDLE};
	my $set_id = $args->{SETNAME};
	my $data = $session->{$set_id};
	my $offset = $args->{OFFSET};
	my $comp = $args->{COMP};
	my $field;
	my $hits = $session->{__HITS};
	my $href = $data->[$offset - 1];

	$args->{REP_FORM} = Net::Z3950::OID::xml;
	if ($offset == $session->{__HITS}) {
		$args->{LAST} = 1;
	} elsif ($comp eq "OP") {
	    $args->{RECORD} = return_opacxml();
	} elsif ($comp eq "marcxml") {
	    $args->{RECORD} = return_marcxml();
	} else {
	    my $record = "<xml>";
	    foreach $field (keys %$href) {
		$record .= "<" . $field . ">" . $href->{$field} . "</" . $field . ">";
	    }
	    $record .= "</xml>";
	    $args->{RECORD} = $record;
	}
}

sub my_esrequest_handler {
	my $args = shift;
	print Dumper($args);
	if (defined($args->{XML_ILL})) {
		$args->{XML_ILL} = "<response>1234</response>\n";
	}
}

sub my_start_handler {
    my $args = shift;
    my $config = $args->{CONFIG};
}

# Return fake MARC record
sub return_marcxml {
	my $record = q@
<record xmlns="http://www.loc.gov/MARC21/slim">
  <leader>01212nam a2200157 i 4500</leader>
  <controlfield tag="001">9910367181303811</controlfield>
  <controlfield tag="005">20180618101041.0</controlfield>
  <controlfield tag="008">170620s        xx            000 0 eng d</controlfield>
  <datafield tag="035" ind1=" " ind2=" ">
    <subfield code="a">bw90000408-01tuli_inst</subfield>
  </datafield>
  <datafield tag="245" ind1="0" ind2="0">
    <subfield code="a">Host bibliographic record for boundwith item barcode 39074015913874</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">How fiscal (mis)-management may impede trade reform : lessons from an intertemporal, multi-sector general equilibrium model for Turkey / Xinshen Diao, Terry L. Roe and A. Erin&#xE7; Yeldan.</subfield>
    <subfield code="w">991011711849703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Educational achievement and sectoral transition in the Indonesian labor force / Anna Maria Siti Kawuryan.</subfield>
    <subfield code="w">991011711799703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Growth economics and development economics : what should development economists learn (if anything) from the new growth theory? / Vernon W. Ruttan.</subfield>
    <subfield code="w">991011711709703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">The effect of sequencing trade and water market reform on interest groups in irrigated agriculture : an intertemporal economy-wide analysis of the Moroccan case / Xinshen Diao and Terry Roe.</subfield>
    <subfield code="w">991011712049703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Monetary instability and economic growth / Willis Peterson.</subfield>
    <subfield code="w">991011711759703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="852" ind1="0" ind2=" ">
    <subfield code="b">KARDON</subfield>
    <subfield code="c">p_remote</subfield>
    <subfield code="h">HD1401</subfield>
    <subfield code="i">.B95x no.98-6</subfield>
  </datafield>
</record>
@;
	return $record;
}

# Return fake OPACXML record
sub return_opacxml {
	my $record = q@
<opacRecord>
  <bibliographicRecord>
<record xmlns="http://www.loc.gov/MARC21/slim">
  <leader>01212nam a2200157 i 4500</leader>
  <controlfield tag="001">9910367181303811</controlfield>
  <controlfield tag="005">20180618101041.0</controlfield>
  <controlfield tag="008">170620s        xx            000 0 eng d</controlfield>
  <datafield tag="035" ind1=" " ind2=" ">
    <subfield code="a">bw90000408-01tuli_inst</subfield>
  </datafield>
  <datafield tag="245" ind1="0" ind2="0">
    <subfield code="a">Host bibliographic record for boundwith item barcode 39074015913874</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">How fiscal (mis)-management may impede trade reform : lessons from an intertemporal, multi-sector general equilibrium model for Turkey / Xinshen Diao, Terry L. Roe and A. Erin&#xE7; Yeldan.</subfield>
    <subfield code="w">991011711849703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Educational achievement and sectoral transition in the Indonesian labor force / Anna Maria Siti Kawuryan.</subfield>
    <subfield code="w">991011711799703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Growth economics and development economics : what should development economists learn (if anything) from the new growth theory? / Vernon W. Ruttan.</subfield>
    <subfield code="w">991011711709703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">The effect of sequencing trade and water market reform on interest groups in irrigated agriculture : an intertemporal economy-wide analysis of the Moroccan case / Xinshen Diao and Terry Roe.</subfield>
    <subfield code="w">991011712049703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="774" ind1="1" ind2=" ">
    <subfield code="t">Monetary instability and economic growth / Willis Peterson.</subfield>
    <subfield code="w">991011711759703811</subfield>
    <subfield code="9">ExL</subfield>
  </datafield>
  <datafield tag="852" ind1="0" ind2=" ">
    <subfield code="b">KARDON</subfield>
    <subfield code="c">p_remote</subfield>
    <subfield code="h">HD1401</subfield>
    <subfield code="i">.B95x no.98-6</subfield>
  </datafield>
</record>
  </bibliographicRecord>
<holdings>
 <holding>
  <encodingLevel>3</encodingLevel>
  <localLocation>Remote Storage</localLocation>
  <shelvingLocation>Main Remote Stacks</shelvingLocation>
  <callNumber>HD1401 .B95x no.98-6</callNumber>
  <volumes>
   <volume>
    <enumeration>       </enumeration>
    <chronology>     </chronology>
   </volume>
  </volumes>
  <circulations>
   <circulation>
    <availableNow value="1"/>
    <availableThru>0</availableThru>
    <itemId>39074015913874</itemId>
    <renewable value="0"/>
    <onHold value="0"/>
   </circulation>
  </circulations>
 </holding>
</holdings>
</opacRecord>
@;
	print $record;
	return $record;
}


my $handler = new Net::Z3950::SimpleServer(
                START   =>      "main::my_start_handler",
		INIT	=>	"main::my_init_handler",
		SEARCH	=>	"main::my_search_handler",
		SCAN	=>	"main::my_scan_handler",
                SORT    =>      "main::my_sort_handler",
		FETCH	=>	"main::my_fetch_handler",
		ESREQUEST =>	"main::my_esrequest_handler"
);

if (@ARGV >= 2 && $ARGV[0] eq "-n") {
    $_fail_frequency = $ARGV[1];
    shift;
    shift;
}
$handler->launch_server("ztest.pl", @ARGV);
