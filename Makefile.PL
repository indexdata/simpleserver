use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.8 2005-03-13 20:01:38 adam Exp $

my $yazconf = "yaz-config";
my $yazinc = `$yazconf --cflags threads`;
my $yazlibs = `$yazconf --libs threads`;
if (!$yazinc && !$yazlibs) {
   die qq[
ERROR: Unable to call script: yaz-config
If you're using a YAZ installation from the Debian package "yaz", you
will also need to install "libyaz-dev" in order to build the
SimpleServer module.
];
}

# For Windows use
# $yazinc = '-Ic:\yaz\include'
# $yazlibs = 'c:\yaz\lib\yaz.lib'

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$yazlibs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> $yazinc,     # e.g., '-I/usr/include/other' 
);
