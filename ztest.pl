#!/usr/bin/perl -w
use ExtUtils::testlib;
use Net::Z3950::SimpleServer;
use Net::Z3950::OID;


sub udskriv_hash {

	my $href = shift;
	my $key;
	my $item;

	foreach $key (keys %{ $href }) {
		print "$key = ";
		if ($key eq "DATABASES") {
			foreach $item ( @{ $href->{DATABASES} }) {
				print "$item  ";
			}
			print "\n";
		} elsif ($key eq "HANDLE") {
			foreach $item ( keys %{ $href->{HANDLE} }) {
				print "        $item  => ";
				print ${ $href->{HANDLE}}{$item};
				print "\n";
			}
		} else {
			print $href->{$key};
			print "\n";
		}
	}
}



sub my_init_handler {

	my $href = shift;
	my $hash = {};

	$hash->{Anders} = "Sønderberg Mortensen";
	$hash->{Birgit} = "Stenhøj Andersen";
	$href->{IMP_NAME} = "MyServer";
	$href->{IMP_VER} = "3.14159";
	$href->{ERR_CODE} = 0;
	$href->{HANDLE} = $hash;
	print "\n";
	print "---------------------------------------------------------------\n";
	print "Connection established\n";
	print "\n";
	udskriv_hash($href);
	print "---------------------------------------------------------------\n";
}

sub my_search_handler { 

	my $href = shift;
	my $key;
	my $hash = $href->{HANDLE};
#	my $hash = {};

	$href->{HITS} = 1;
	$href->{ERR_STR} = "A";
	$hash->{Search} = "Search Handler er besøgt";
#	$href->{HANDLE} = $hash;
	print "\n";
	print "---------------------------------------------------------------\n";
	print "Search handler\n";
	print "\n";
	udskriv_hash($href);
	print "---------------------------------------------------------------\n";
}


sub my_present_handler {
	my $href = shift;

	$href->{ERR_CODE} = 0;

	$href->{ERR_STR} = "";
	print "\n";
	print "--------------------------------------------------------------\n";
	print "Present handler\n";
	print "\n";
	udskriv_hash($href);
	print "--------------------------------------------------------------\n";
	return;
}

sub my_close_handler {
	my $href = shift;

	print "\n";
	print "-------------------------------------------------------------\n";
	print "Connection closed\n";
	print "\n";
	udskriv_hash($href);
	print "-------------------------------------------------------------\n";

}


sub my_fetch_handler {
	my $href = shift;
	my $hash = $href->{HANDLE};

	$hash->{Fetch} = "Fetch handler er besøgt";
	##$href->{RECORD} = "<head>Overskrift</head> <text>Her kommer teksten</text>";
	$href->{RECORD} = "<xml><head>Overskrift</head><body>Der var engang en mand</body></xml>";
	$href->{LEN} = 69;
	$href->{NUMBER} = 1;
	$href->{BASENAME} = "MS-Gud";
	$href->{LAST} = 1;
	## $href->{HANDLE} = \%hash;
	print "\n";
	print "------------------------------------------------------------\n";
	print "Fetch handler\n";
	print "\n";
	udskriv_hash($href);
	if ($href->{REQ_FORM} eq Net::Z3950::OID::unimarc) {
		print "Formatet UNIMARC\n";
	} else {
		print "Formatet er IKKE unimarc\n";
	}
	print "------------------------------------------------------------\n";
	
}



my $handler = Net::Z3950::SimpleServer->new({ INIT	=>	\&my_init_handler,
				CLOSE	=>	\&my_close_handler,
				SEARCH	=>	\&my_search_handler,
			    FETCH	=>	\&my_fetch_handler
			  });

$handler->launch_server("ztest.pl", @ARGV);

