use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.7 2004-08-03 08:59:37 mike Exp $

my $libs = `yaz-config --libs threads` || die qq[
ERROR: Unable to call script: yaz-config
If you're using a YAZ installation from the Debian package "yaz", you
will also need to install "libyaz-dev" in order to build the
SimpleServer module.
];

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
