use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.14 2007-04-17 07:56:29 adam Exp $

my $yazconf = "../yaz/yaz-config";
my $yazver = `$yazconf --version`;
my $yazinc = `$yazconf --cflags threads`;
my $yazlibs = `$yazconf --libs threads`;
if (!$yazver || (!$yazinc && !$yazlibs)) {
   die qq[
ERROR: Unable to call script: yaz-config
If you're using a YAZ installation from the Debian package "yaz", you
will also need to install "libyaz-dev" in order to build the
SimpleServer module.
];
}

chomp($yazver);
my ($major, $minor, $trivial) = split(/\./, $yazver);
# YAZ 2.1.14 is the first to propagate SRW/U addinfo correctly
my ($needMaj, $needMin, $needTriv) = (2, 1, 99);
#print "major=$major, minor=$minor, trivial=$trivial\n";
die "You have YAZ version $major.$minor.$trivial; " .
    "you need $needMaj.$needMin.$needTriv or better."
    if ($major < $needMaj || 
	$major == $needMaj && $minor < $needMin ||
	$major == $needMaj && $minor == $needMin && $trivial < $needTriv);

# For Windows use
# $yazinc = '-Ic:\yaz\include'
# $yazlibs = 'c:\yaz\lib\yaz.lib'

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$yazlibs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> $yazinc,     # e.g., '-I/usr/include/other' 
#    OPTIMIZE   => "-Wdeclaration-after-statement -g -O0",
);
