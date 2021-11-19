use ExtUtils::MakeMaker;

# Use: perl Makefile.PL OPTIMIZE="-O0 -g -Wdeclaration-after-statement"

my $yazver;
my $yazinc;
my $yazlibs;
system("pkg-config --exists yaz-server");
if ($? == 0) {
    $yazconf = "pkg-config";
    $yazver = `pkg-config --modversion yaz-server` or die;
    $yazinc = `pkg-config --cflags yaz-server` or die;
    $yazlibs = `pkg-config --libs yaz-server` or die;
} else {
    my $yazconf = "yaz-config";
    $yazver = `$yazconf --version`;
    $yazinc = `$yazconf --cflags servers`;
    $yazlibs = `$yazconf --libs server`;
    if (!$yazver || (!$yazinc && !$yazlibs)) {
       die qq[
ERROR: Unable to call script: yaz-config
If you are using a YAZ installation from the Debian package "yaz", you
will also need to install "libyaz-dev" in order to build the
SimpleServer module.
];
   }
}

chomp($yazver);
my ($major, $minor, $trivial) = split(/\./, $yazver);
my ($needMaj, $needMin, $needTriv) = (5, 27, 0);
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
