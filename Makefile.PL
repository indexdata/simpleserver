use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.3 2004-05-28 20:27:16 sondberg Exp $

my $libs = `yaz-config --libs threads` || die "ERROR: Unable to call script: yaz-config";

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$libs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
