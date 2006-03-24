use ExtUtils::MakeMaker;

## $Id: Makefile.PL,v 1.9 2006-03-24 12:06:15 mike Exp $

my $yazconf = "yaz-config";
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

# Judging by the YAZ NEWS file, 2.1.10 was the first release to
# include SRW/U support in the GFS
chomp($yazver);
my ($major, $minor, $trivial) = split(/\./, $yazver);
#print "major=$major, minor=$minor, trivial=$trivial\n";
die "You have YAZ version $major.$minor.$trivial; you need 2.1.10 or better"
    if ($major < 2 || 
	$major == 2 && $minor < 1 ||
	$major == 2 && $minor == 1 && $trivial < 10);

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
