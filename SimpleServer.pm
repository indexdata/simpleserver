package Net::Z3950::SimpleServer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp;

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter AutoLoader DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '0.02';

bootstrap Net::Z3950::SimpleServer $VERSION;

# Preloaded methods go here.

my $count = 0;

sub new {
	my $class = shift;
	my $args = shift || croak "SimpleServer::new: Usage new(argument hash)";
	my $self = {};

	if ($count) {
		carp "SimpleServer.pm: WARNING: Multithreaded server unsupported";
	}
	$count = 1;

	$self->{INIT} = $args->{INIT};
	$self->{SEARCH} = $args->{SEARCH} || croak "SimpleServer.pm: ERROR: Unspecified search handler";
	$self->{FETCH} = $args->{FETCH} || croak "SimpleServer.pm: ERROR: Unspecified fetch handler";
	$self->{CLOSE} = $args->{CLOSE};

	bless $self, $class;
	return $self;
}


sub launch_server {
	my $self = shift;
	my @args = @_;

	if (defined($self->{INIT})) {
		set_init_handler($self->{INIT});
	}
	set_search_handler($self->{SEARCH});
	set_fetch_handler($self->{FETCH});
	if (defined($self->{CLOSE})) {
		set_close_handler($self->{CLOSE});
	}

	start_server(@args);
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Zfront - Simple Perl API for building Z39.50 servers. 

=head1 SYNOPSIS

  use Zfront;

  sub my_search_handler {
	my $args = shift;

	my $set_id = $args->{SETNAME};
	my @database_list = @{ $args->{DATABASES} };
	my $query = $args->{QUERY};

	## Perform the query on the specified set of databases
	## and return the number of hits:

	$args->{HITS} = $hits;
  }

  sub my_fetch_handler {        # Get a record for the user
	my $args = shift;

	my $set_id = $args->{SETNAME};

	my $record = fetch_a_record($args->{OFFSET);

	$args->{RECORD} = $record;
	$args->{LEN} = length($record);
	if (number_of_hits() == $args->{OFFSET}) {	## Last record in set?
		$args->{LAST} = 1;
	} else {
		$args->{LAST} = 0;
	}
  }


  ## Register custom event handlers:

  Zfront::set_search_handler(\&my_search_handler);
  Zfront::set_fetch_handler(\&my_fetch_handler);

  ## Launch server:

  Zfront::start_server("mytestserver", @ARGV);

=head1 DESCRIPTION

The Zfront module is a tool for constructing Z39.50 "Information
Retrieval" servers in Perl. The module is easy to use, but it
does help to have an understanding of the Z39.50 query
structure and the construction of structured retrieval records.

Z39.50 is a network protocol for searching remote databases and
retrieving the results in the form of structured "records". It is widely
used in libraries around the world, as well as in the US Federal Government.
In addition, it is generally useful whenever you wish to integrate a number
of different database systems around a shared, asbtract data model.

The model of the module is simple: It implements a "generic" Z39.50
server, which invokes callback functions supplied by you to search
for content in your database. You can use any tools available in
Perl to supply the content, including modules like DBI and
WWW::Search.

The server will take care of managing the network connections for
you, and it will spawn a new process (or thread, in some
environments) whenever a new connection is received.

The programmer can specify subroutines to take care of the following type
of events:

  - Initialize request
  - Search request
  - Fetching of records
  - Closing down connection

Note that only the Search and Fetch handler functions are required.
The module can supply default responses to the other on its own.

After the launching of the server, all control is given away from
the Perl script to the server. The server calls the registered
subroutines to field incoming requests from Z39.50 clients.

A reference to an anonymous hash is passed to each handle. Some of
the entries of these hashes are to be considered input and others
output parameters.

The Perl programmer specifies the event handles for the server by
means of the subroutines

  Zfront::set_init_handler(\&my_init_handler);
  Zfront::set_search_handler(\&my_search_handler);
  Zfront::set_fetch_handler(\&my_fetch_handler);
  Zfront::set_close_handler(\&my_close_handler);

After each handle is declared, the server is launched by means of
the subroutine

  Zfront::start_server($script_name, @ARGV);

Notice, the first argument should be the name of your server
script (for logging purposes), while the rest of the arguments
are documented in the YAZ toolkit manual: The section on
application invocation: <http://www.indexdata.dk/yaz/yaz-7.php>

=head2 Init handler

The init handler is called whenever a Z39.50 client is attempting
to logon to the server. The exchange of parameters between the
server and the handler is carried out via an anonymous hash reached
by a reference, i.e.

  $args = shift;

The argument hash passed to the init handler has the form

  $args = {
				    ## Response parameters:

	     IMP_NAME  =>  ""       ## Z39.50 Implementation name
	     IMP_VER   =>  ""       ## Z39.50 Implementation version
	     ERR_CODE  =>  0        ## Error code, cnf. Z39.50 manual
	     HANDLE    =>  undef    ## Handler of Perl data structure
	  };

The HANDLE member can be used to store any scalar value which will then
be provided as input to all subsequent calls (ie. for searching, record
retrieval, etc.). A common use of the handle is to store a reference to
a hash which may then be used to store session-specific parameters.
If you have any session-specific information (such as a list of
result sets or a handle to a back-end search engine of some sort),
it is always best to store them in a private session structure -
rather than leaving them in global variables in your script.

The Implementation name and version are only really used by Z39.50
client developers to see what kind of server they're dealing with.
Filling these in is optional.

The ERR_CODE should be left at 0 (the default value) if you wish to
accept the connection. Any other value is interpreted as a failure
and the client will be shown the door.

=head2 Search handler

Similarly, the search handler is called with a reference to an anony-
mous hash. The structure is the following:

  $args = {
	  			    ## Request parameters:

	     HANDLE    =>  ref      ## Your session reference.
	     SETNAME   =>  "id"     ## ID of the result set
	     REPL_SET  =>  0        ## Replace set if already existing?
	     DATABASES =>  ["xxx"]  ## Reference to a list of data-
				    ## bases to search
	     QUERY     =>  "query"  ## The query expression

				    ## Response parameters:

	     ERR_CODE  =>  0        ## Error code (0=Succesful search)
	     ERR_STR   =>  ""       ## Error string
	     HITS      =>  0        ## Number of matches
	  };

Note that a search which finds 0 hits is considered successful in
Z39.50 terms - you should only set the ERR_CODE to a non-zero value
if there was a problem processing the request. The Z39.50 standard
provides a comprehensive list of standard diagnostic codes, and you
should use these whenever possible.

The QUERY is a tree-structure of terms combined by operators, the
terms being qualified by lists of attributes. The query is presented
to the search function in the Prefix Query Format (PQF) which is
used in many applications based on the YAZ toolkit. The full grammar
is described in the YAZ manual.

The following are all examples of valid queries in the PQF. 

	dylan

	"bob dylan"

	@or "dylan" "zimmerman"

	@set Result-1

	@or @and bob dylan @set Result-1

	@and @attr 1=1 "bob dylan" @attr 1=4 "slow train coming"

	@attrset @attr 4=1 @attr 1=4 "self portrait"

You will need to write a recursive function or something similar to
parse incoming query expressions, and this is usually where a lot of
the work in writing a database-backend happens. Fortunately, you don't
need to support anymore functionality than you want to. For instance,
it is perfectly legal to not accept boolean operators, but you SHOULD
try to return good error codes if you run into something you can't or
won't support.

=head2 Fetch handler

The fetch handler is asked to retrieve a SINGLE record from a given
result set (the front-end server will automatically call the fetch
handler as many times as required).

The parameters exchanged between the server and the fetch handler are

  $args = {
				    ## Client/server request:

	     HANDLE    =>  ref	    ## Reference to data structure
	     SETNAME   =>  "id"     ## ID of the requested result set
	     OFFSET    =>  nnn      ## Record offset number
	     REQ_FORM  =>  "USMARC" ## Client requested record format

				    ## Handler response:

	     RECORD    =>  ""       ## Record string
	     LEN       =>  0        ## Length of record string
	     BASENAME  =>  ""       ## Origin of returned record
	     LAST      =>  0        ## Last record in set?
	     ERR_CODE  =>  0        ## Error code
	     ERR_STR   =>  ""       ## Error string
	     SUR_FLAG  =>  0        ## Surrogate diagnostic flag
	     REP_FORM  =>  "USMARC" ## Provided record format
	  };

The REP_FORM value has by default the REQ_FORM value but can be set to
something different if the handler desires. The BASENAME value should
contain the name of the database from where the returned record originates.
The ERR_CODE and ERR_STR works the same way they do in the search
handler. If there is an error condition, the SUR_FLAG is used to
indicate whether the error condition pertains to the record currently
being retrieved, or whether it pertains to the operation as a whole
(eg. the client has specified a result set which does not exist.)

Record formats are currently carried as strings (eg. USMARC, TEXT_XML,
SUTRS), but this will probably change to proper OID strings in the
future (not to worry, though, the module will supply constant values
for the common OIDs). If you need to return USMARC records, you might
want to have a look at the MARC module on CPAN, if you don't already
have a way of generating these.

NOTE: The record offset is 1-indexed - 1 is the offset of the first
record in the set.

=head2 Close handler

The argument hash recieved by the close handler has one element only:

  $args = {
				    ## Server provides:
	     HANDLE    =>  ref      ## Reference to data structure
	  };

What ever data structure the HANDLE value points at goes out of scope
after this call. If you need to close down a connection to your server
or something similar, this is the place to do it.

=head1 AUTHORS

Anders Sønderberg (sondberg@indexdata.dk) and Sebastian Hammer
(quinn@indexdata.dk).

=head1 SEE ALSO

perl(1).

Any Perl module which is useful for accessing the database of your
choice.

=cut


