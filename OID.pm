package Net::Z3950::OID;

my $prefix = "1.2.840.10003.5.";

sub unimarc	{ $prefix . '1' }
sub intermarc	{ $prefix . '2' }
sub ccf		{ $prefix . '3' }
sub usmarc	{ $prefix . '10' }
sub ukmarc	{ $prefix . '11' }
sub normarc	{ $prefix . '12' }
sub librismarc	{ $prefix . '13' }
sub danmarc	{ $prefix . '14' }
sub finmarc	{ $prefix . '15' }
sub mab		{ $prefix . '16' }
sub canmarc	{ $prefix . '17' }
sub sbn		{ $prefix . '18' }
sub picamarc	{ $prefix . '19' }
sub ausmarc	{ $prefix . '20' }
sub ibermarc	{ $prefix . '21' }
sub carmarc	{ $prefix . '22' }
sub malmarc	{ $prefix . '23' }
sub jpmarc	{ $prefix . '24' }
sub swemarc	{ $prefix . '25' }
sub siglemarc	{ $prefix . '26' }
sub isdsmarc	{ $prefix . '27' }
sub rusmarc	{ $prefix . '28' }
sub explain	{ $prefix . '100' }
sub sutrs	{ $prefix . '101' }
sub opac	{ $prefix . '102' }
sub summary	{ $prefix . '103' }
sub grs0	{ $prefix . '104' }
sub grs1	{ $prefix . '105' }
sub extended	{ $prefix . '106' }
sub fragment	{ $prefix . '107' }
sub pdf		{ $prefix . '109.1' }
sub postscript	{ $prefix . '109.2' }
sub html	{ $prefix . '109.3' }
sub tiff	{ $prefix . '109.4' }
sub gif		{ $prefix . '109.5' }
sub jpeg	{ $prefix . '109.6' }
sub png		{ $prefix . '109.7' }
sub mpeg	{ $prefix . '109.8' }
sub sgml	{ $prefix . '109.9' }
sub tiffb	{ $prefix . '110.1' }
sub wav		{ $prefix . '110.2' }
sub sqlrs	{ $prefix . '111' }
sub soif	{ $prefix . '1000.81.2' }
sub textxml	{ $prefix . '109.10' }
sub xml		{ $prefix . '109.10' }
sub appxml	{ $prefix . '109.11' }


## $Log: OID.pm,v $
## Revision 1.2  2001-03-13 14:54:13  sondberg
## Started CVS logging
##
