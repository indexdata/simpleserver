use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.5 2004-06-05 23:09:04 adam Exp $

my $libs = `../yaz/yaz-config --libs threads` || die "ERROR: Unable to call script: yaz-config";

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$libs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '-I../yaz/include',     # e.g., '-I/usr/include/other' 
);
