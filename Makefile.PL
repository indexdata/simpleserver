use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.4 2004-06-05 07:55:05 adam Exp $

my $libs = `yaz-config --libs` || die "ERROR: Unable to call script: yaz-config";

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$libs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
