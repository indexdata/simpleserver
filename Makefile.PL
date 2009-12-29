use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.23 2009-12-29 10:24:12 adam Exp $

# Use: perl Makefile.PL OPTIMIZE="-O0 -g -Wdeclaration-after-statement"

my $yazconf = "yaz-config";
my $yazver = `$yazconf --version`;
my $yazinc = `$yazconf --cflags servers`;
my $yazlibs = `$yazconf --libs server`;
if (!$yazver || (!$yazinc && !$yazlibs)) {
   die qq[
ERROR: Unable to call script: yaz-config
If you are using a YAZ installation from the Debian package "yaz", you
will also need to install "libyaz-dev" in order to build the
SimpleServer module.
];
}

### Although this release of SimpleServer will work with version 3.0.2
#   of YAZ, you will not be able to take advantage of the new CCL
#   support in the YAZ GFS unless you have version 3.0.9 or better.

chomp($yazver);
my ($major, $minor, $trivial) = split(/\./, $yazver);
my ($needMaj, $needMin, $needTriv) = (3, 0, 2);
#print "major=$major, minor=$minor, trivial=$trivial\n";
die "You have YAZ version $major.$minor.$trivial; " .
    "you need $needMaj.$needMin.$needTriv or better."
    if ($major < $needMaj || 
	$major == $needMaj && $minor < $needMin ||
	$major == $needMaj && $minor == $needMin && $trivial < $needTriv);

# For Windows use
# $yazinc = '-Ic:\yaz\include'
# $yazlibs = 'c:\yaz\lib\yaz3.lib'

WriteMakefile(
    'NAME'	=> 'Net::Z3950::SimpleServer',
    'VERSION_FROM' => 'SimpleServer.pm', # finds $VERSION
    'LIBS'	=> [$yazlibs],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> $yazinc,     # e.g., '-I/usr/include/other' 
#    OPTIMIZE   => "-Wdeclaration-after-statement -g -O0",
);
