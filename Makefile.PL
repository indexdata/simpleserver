use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.6 2004-06-07 17:08:00 adam Exp $

my $libs = `yaz-config --libs threads` || die "ERROR: Unable to call script: yaz-config";

# For Windows use
# 'LIBS' => 'c:\yaz\lib\yaz.lib'
# 'INC' => 'c:\yaz\include'

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$libs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
