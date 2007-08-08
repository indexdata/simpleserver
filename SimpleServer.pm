##
##  Copyright (c) 2000-2006, Index Data.
##
##  Permission to use, copy, modify, distribute, and sell this software and
##  its documentation, in whole or in part, for any purpose, is hereby granted,
##  provided that:
##
##  1. This copyright and permission notice appear in all copies of the
##  software and its documentation. Notices of copyright or attribution
##  which appear at the beginning of any file must remain unchanged.
##
##  2. The name of Index Data or the individual authors may not be used to
##  endorse or promote products derived from this software without specific
##  prior written permission.
##
##  THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY OF ANY KIND,
##  EXPRESS, IMPLIED, OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY
##  WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
##  IN NO EVENT SHALL INDEX DATA BE LIABLE FOR ANY SPECIAL, INCIDENTAL,
##  INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND, OR ANY DAMAGES
##  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER OR
##  NOT ADVISED OF THE POSSIBILITY OF DAMAGE, AND ON ANY THEORY OF
##  LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
##  OF THIS SOFTWARE.
##
##

## $Id: SimpleServer.pm,v 1.32 2007-08-08 10:27:43 mike Exp $

package Net::Z3950::SimpleServer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp;

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter AutoLoader DynaLoader);
@EXPORT = qw( );
$VERSION = '1.06';

bootstrap Net::Z3950::SimpleServer $VERSION;

# Preloaded methods go here.

my $count = 0;

sub new {
	my $class = shift;
	my %args = @_;
	my $self = \%args;

	if ($count) {
		carp "SimpleServer.pm: WARNING: Multithreaded server unsupported";
	}
	$count = 1;

	croak "SimpleServer.pm: ERROR: Unspecified search handler" unless defined($self->{SEARCH});
	croak "SimpleServer.pm: ERROR: Unspecified fetch handler" unless defined($self->{FETCH});

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
	if (defined($self->{PRESENT})) {
		set_present_handler($self->{PRESENT});
	}
	if (defined($self->{SCAN})) {
		set_scan_handler($self->{SCAN});
	}
	if (defined($self->{SORT})) {
		set_sort_handler($self->{SORT});
	}
	if (defined($self->{EXPLAIN})) {
		set_explain_handler($self->{EXPLAIN});
	}

	start_server(@args);
}


# Register packages that we will use in translated RPNs
package Net::Z3950::APDU::Query;
package Net::Z3950::APDU::OID;
package Net::Z3950::RPN::And;
package Net::Z3950::RPN::Or;
package Net::Z3950::RPN::AndNot;
package Net::Z3950::RPN::Term;
package Net::Z3950::RPN::RSID;
package Net::Z3950::RPN::Attributes;
package Net::Z3950::RPN::Attribute;

# Must revert to original package for Autoloader's benefit
package Net::Z3950::SimpleServer;


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Net::Z3950::SimpleServer - Simple Perl API for building Z39.50 servers. 

=head1 SYNOPSIS

  use Net::Z3950::SimpleServer;

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

	my $record = fetch_a_record($args->{OFFSET});

	$args->{RECORD} = $record;
	if (number_of_hits() == $args->{OFFSET}) {	## Last record in set?
		$args->{LAST} = 1;
	} else {
		$args->{LAST} = 0;
	}
  }

  ## Register custom event handlers:
  my $z = new Net::Z3950::SimpleServer(GHANDLE = $someObject,
				       INIT   =>  \&my_init_handler,
				       CLOSE  =>  \&my_close_handler,
				       SEARCH =>  \&my_search_handler,
				       FETCH  =>  \&my_fetch_handler);

  ## Launch server:
  $z->launch_server("ztest.pl", @ARGV);

=head1 DESCRIPTION

The SimpleServer module is a tool for constructing Z39.50 "Information
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
  - Present request
  - Fetching of records
  - Scan request (browsing) 
  - Closing down connection

Note that only the Search and Fetch handler functions are required.
The module can supply default responses to the other on its own.

After the launching of the server, all control is given away from
the Perl script to the server. The server calls the registered
subroutines to field incoming requests from Z39.50 clients.

A reference to an anonymous hash is passed to each handler. Some of
the entries of these hashes are to be considered input and others
output parameters.

The Perl programmer specifies the event handlers for the server by
means of the SimpleServer object constructor

  my $z = new Net::Z3950::SimpleServer(
			INIT	=>	\&my_init_handler,
			CLOSE	=>	\&my_close_handler,
			SEARCH	=>	\&my_search_handler,
			PRESENT	=>	\&my_present_handler,
			SCAN	=>	\&my_scan_handler,
			FETCH	=>	\&my_fetch_handler,
  			EXPLAIN =>	\&my_explain_handler);

In addition, the arguments to the constructor may include GHANDLE, a
global handle which is made available to each invocation of every
callback function.  This is typically a reference to either a hash or
an object.

If you want your SimpleServer to start a thread (threaded mode) to
handle each incoming Z39.50 request instead of forking a process
(forking mode), you need to register the handlers by symbol rather
than by code reference. Thus, in threaded mode, you will need to
register your handlers this way:

  my $z = new Net::Z3950::SimpleServer(
  			INIT	=>	"my_package::my_init_handler",
			CLOSE	=>	"my_package::my_close_handler",
			....
			....          );

where my_package is the Perl package in which your handler is
located.

After the custom event handlers are declared, the server is launched
by means of the method

  $z->launch_server("MyServer.pl", @ARGV);

Notice, the first argument should be the name of your server
script (for logging purposes), while the rest of the arguments
are documented in the YAZ toolkit manual: The section on
application invocation: <http://www.indexdata.dk/yaz/yaz-7.php>

In particular, you need to use the -T switch to start your SimpleServer
in threaded mode.

=head2 Init handler

The init handler is called whenever a Z39.50 client is attempting
to logon to the server. The exchange of parameters between the
server and the handler is carried out via an anonymous hash reached
by a reference, i.e.

  $args = shift;

The argument hash passed to the init handler has the form

  $args = {
				    ## Response parameters:

	     IMP_ID    =>  "",      ## Z39.50 Implementation ID
	     IMP_NAME  =>  "",      ## Z39.50 Implementation name
	     IMP_VER   =>  "",      ## Z39.50 Implementation version
	     ERR_CODE  =>  0,       ## Error code, cnf. Z39.50 manual
	     ERR_STR   =>  "",      ## Error string (additional info.)
	     USER      =>  "xxx"    ## If Z39.50 authentication is used,
	     			    ## this member contains user name
	     PASS      =>  "yyy"    ## Under same conditions, this member
	     			    ## contains the password in clear text
	     GHANDLE   =>  $obj     ## Global handler specified at creation
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

The Implementation ID, name and version are only really used by Z39.50
client developers to see what kind of server they're dealing with.
Filling these in is optional.

The ERR_CODE should be left at 0 (the default value) if you wish to
accept the connection. Any other value is interpreted as a failure
and the client will be shown the door, with the code and the
associated additional information, ERR_STR returned.

=head2 Search handler

Similarly, the search handler is called with a reference to an anony-
mous hash. The structure is the following:

  $args = {
	  			    ## Request parameters:

	     GHANDLE   =>  $obj     ## Global handler specified at creation
	     HANDLE    =>  ref,     ## Your session reference.
	     SETNAME   =>  "id",    ## ID of the result set
	     REPL_SET  =>  0,       ## Replace set if already existing?
	     DATABASES =>  ["xxx"], ## Reference to a list of data-
				    ## bases to search
	     QUERY     =>  "query", ## The query expression
	     RPN       =>  $obj,    ## Reference to a Net::Z3950::APDU::Query

				    ## Response parameters:

	     ERR_CODE  =>  0,       ## Error code (0=Succesful search)
	     ERR_STR   =>  "",      ## Error string
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

A more convenient alternative to the QUERY member may be the RPN
member, which is a reference to a Net::Z3950::APDU::Query object
representing the RPN query tree.  The structure of that object is
supposed to be self-documenting, but here's a brief summary of what
you get:

=over 4

=item *

C<Net::Z3950::APDU::Query> is a hash with two fields:

Z<>

=over 4

=item C<attributeSet>

Optional.  If present, it is a reference to a
C<Net::Z3950::APDU::OID>.  This is a string of dot-separated integers
representing the OID of the query's top-level attribute set.

=item C<query>

Mandatory: a refererence to the RPN tree itself.

=back

=item *

Each node of the tree is an object of one of the following types:

Z<>

=over 4

=item C<Net::Z3950::RPN::And>

=item C<Net::Z3950::RPN::Or>

=item C<Net::Z3950::RPN::AndNot>

These three classes are all arrays of two elements, each of which is a
node of one of the above types.

=item C<Net::Z3950::RPN::Term>

See below for details.

=item C<Net::Z3950::RPN::RSID>

A reference to a result-set ID indicating a previous search.  The ID
of the result-set is in the C<id> element.

=back

(I guess I should make a superclass C<Net::Z3950::RPN::Node> and make
all of these subclasses of it.  Not done that yet, but will do one day.)

=back

=over 4

=item *

C<Net::Z3950::RPN::Term> is a hash with two fields:

Z<>

=over 4

=item C<term>

A string containing the search term itself.

=item C<attributes>

A reference to a C<Net::Z3950::RPN::Attributes> object.

=back

=item *

C<Net::Z3950::RPN::Attributes> is an array of references to
C<Net::Z3950::RPN::Attribute> objects.  (Note the plural/singular
distinction.)

=item *

C<Net::Z3950::RPN::Attribute> is a hash with three elements:

Z<>

=over 4

=item C<attributeSet>

Optional.  If present, it is dot-separated OID string, as above.

=item C<attributeType>

An integer indicating the type of the attribute - for example, under
the BIB-1 attribute set, type 1 indicates a ``use'' attribute, type 2
a ``relation'' attribute, etc.

=item C<attributeValue>

An integer indicating the value of the attribute - for example, under
BIB-1, if the attribute type is 1, then value 4 indictates a title
search and 7 indictates an ISBN search; but if the attribute type is
2, then value 4 indicates a ``greater than or equal'' search, and 102
indicates a relevance match.

=back

=back

Note that, at the moment, none of these classes have any methods at
all: the blessing into classes is largely just a documentation thing
so that, for example, if you do

	{ use Data::Dumper; print Dumper($args->{RPN}) }

you get something fairly human-readable.  But of course, the type
distinction between the three different kinds of boolean node is
important.

By adding your own methods to these classes (building what I call
``augmented classes''), you can easily build code that walks the tree
of the incoming RPN.  Take a look at C<samples/render-search.pl> for a
sample implementation of such an augmented classes technique.


=head2 Present handler

The presence of a present handler in a SimpleServer front-end is optional.
Each time a client wishes to retrieve records, the present service is
called. The present service allows the origin to request a certain number
of records retrieved from a given result set.
When the present handler is called, the front-end server should prepare a
result set for fetching. In practice, this means to get access to the
data from the backend database and store the data in a temporary fashion
for fast and efficient fetching. The present handler does *not* fetch
anything. This task is taken care of by the fetch handler, which will be
called the correct number of times by the YAZ library. More about this
below.
If no present handler is implemented in the front-end, the YAZ toolkit
will take care of a minimum of preparations itself. This default present
handler is sufficient in many situations, where only a small amount of
records are expected to be retrieved. If on the other hand, large result
sets are likely to occur, the implementation of a reasonable present
handler can gain performance significantly.

The informations exchanged between client and present handle are:

  $args = {
				    ## Client/server request:

	     GHANDLE   =>  $obj     ## Global handler specified at creation
	     HANDLE    =>  ref,     ## Reference to datastructure
	     SETNAME   =>  "id",    ## Result set ID
	     START     =>  xxx,     ## Start position
	     COMP      =>  "",	    ## Desired record composition
	     NUMBER    =>  yyy,	    ## Number of requested records


				    ## Respons parameters:

	     HITS      =>  zzz,	    ## Number of returned records
	     ERR_CODE  =>  0,	    ## Error code
	     ERR_STR   =>  ""	    ## Error message
          };


=head2 Fetch handler

The fetch handler is asked to retrieve a SINGLE record from a given
result set (the front-end server will automatically call the fetch
handler as many times as required).

The parameters exchanged between the server and the fetch handler are

  $args = {
				    ## Client/server request:

	     GHANDLE   =>  $obj     ## Global handler specified at creation
	     HANDLE    =>  ref	    ## Reference to data structure
	     SETNAME   =>  "id"     ## ID of the requested result set
	     OFFSET    =>  nnn      ## Record offset number
	     REQ_FORM  =>  "n.m.k.l"## Client requested format OID
	     COMP      =>  "xyz"    ## Formatting instructions
	     SCHEMA    =>  "abc"    ## Requested schema, if any

				    ## Handler response:

	     RECORD    =>  ""       ## Record string
	     BASENAME  =>  ""       ## Origin of returned record
	     LAST      =>  0        ## Last record in set?
	     ERR_CODE  =>  0        ## Error code
	     ERR_STR   =>  ""       ## Error string
	     SUR_FLAG  =>  0        ## Surrogate diagnostic flag
	     REP_FORM  =>  "n.m.k.l"## Provided format OID
	     SCHEMA    =>  "abc"    ## Provided schema, if any
	  };

The REP_FORM value has by default the REQ_FORM value but can be set to
something different if the handler desires. The BASENAME value should
contain the name of the database from where the returned record originates.
The ERR_CODE and ERR_STR works the same way they do in the search
handler. If there is an error condition, the SUR_FLAG is used to
indicate whether the error condition pertains to the record currently
being retrieved, or whether it pertains to the operation as a whole
(eg. the client has specified a result set which does not exist.)

If you need to return USMARC records, you might want to have a look at
the MARC module on CPAN, if you don't already have a way of generating
these.

NOTE: The record offset is 1-indexed - 1 is the offset of the first
record in the set.

=head2 Scan handler

A full featured Z39.50 server should support scan (or in some literature
browse). The client specifies a starting term of the scan, and the server
should return an ordered list of specified length consisting of terms
actually occurring in the data base. Each of these terms should be close
to or equal to the term originally specified. The quality of scan compared
to simple search is a guarantee of hits. It is simply like browsing through
an index of a book, you always find something! The parameters exchanged are

  $args = {
						## Client request

		GHANDLE		=> $obj		## Global handler specified at creation
		HANDLE		=> $ref		## Reference to data structure
		TERM		=> 'start',	## The start term
		NUMBER		=> xx,		## Number of requested terms
		POS		=> yy,		## Position of starting point
						## within returned list
		STEP		=> 0,		## Step size

						## Server response

		ERR_CODE	=> 0,		## Error code
		ERR_STR		=> '',		## Diagnostic message
		NUMBER		=> zz,		## Number of returned terms
		STATUS		=> $status,	## ScanSuccess/ScanFailure
		ENTRIES		=> $entries	## Referenced list of terms
	};

where the term list is returned by reference in the scalar $entries, which
should point at a data structure of this kind,

  my $entries = [
			{	TERM		=> 'energy',
				OCCURRENCE	=> 5		},

			{	TERM		=> 'energy density',
				OCCURRENCE	=> 6,		},

			{	TERM		=> 'energy flow',
				OCCURRENCE	=> 3		},

				...

				...
	];

The $status flag should be assigned one of two values:

  Net::Z3950::SimpleServer::ScanSuccess  On success (default)
  Net::Z3950::SimpleServer::ScanPartial  Less terms returned than requested

The STEP member contains the requested number of entries in the term-list
between two adjacent entries in the response.

=head2 Close handler

The argument hash recieved by the close handler has two elements only:

  $args = {
				    ## Server provides:

	     GHANDLE   =>  $obj     ## Global handler specified at creation
	     HANDLE    =>  ref      ## Reference to data structure
	  };

What ever data structure the HANDLE value points at goes out of scope
after this call. If you need to close down a connection to your server
or something similar, this is the place to do it.

=head2 Support for SRU and SRW

Since release 1.0, SimpleServer includes support for serving the SRU
and SRW protocols as well as Z39.50.  These ``web-friendly'' protocols
enable similar functionality to that of Z39.50, but by means of rich
URLs in the case of SRU, and a SOAP-based web-service in the case of
SRW.  These protocols are described at
http://www.loc.gov/sru

In order to serve these protocols from a SimpleServer-based
application, it is necessary to launch the application with a YAZ
Generic Frontend Server (GFS) configuration file, which can be
specified using the command-line argument C<-f> I<filename>.  A
minimal configuration file looks like this:

  <yazgfs>
    <server>
      <cql2rpn>pqf.properties</cql2rpn>
    </server>
  </yazgfs>

This file specifies only that C<pqf.properties> should be used to
translate the CQL queries of SRU and SRW into corresponding Z39.50
Type-1 queries.  For more information about YAZ GFS configuration,
including how to specify an Explain record, see the I<Virtual Hosts>
section of the YAZ manual at
http://indexdata.com/yaz/doc/server.vhosts.tkl

The mapping of CQL queries into Z39.50 Type-1 queries is specified by
a file that indicates which BIB-1 attributes should be generated for
each CQL index, relation, modifiers, etc.  A typical section of this
file looks like this:

  index.dc.title                        = 1=4
  index.dc.subject                      = 1=21
  index.dc.creator                      = 1=1003
  relation.<                            = 2=1
  relation.le                           = 2=2

This file specifies the BIB-1 access points (type=1) for the Dublin
Core indexes C<title>, C<subject> and C<creator>, and the BIB-1
relations (type=2) corresponding to the CQL relations C<E<lt>> and
C<E<lt>=>.  For more information about the format of this file, see
the I<CQL> section of the YAZ manual at
http://indexdata.com/yaz/doc/tools.tkl#tools.cql

The YAZ distribution include a sample CQL-to-PQF mapping configuration
file called C<pqf.properties>; this is sufficient for many
applications, and a good base to work from for most others.

If a SimpleServer-based application is run without this SRU-specific
configuration, it can still serve SRU; however, CQL queries will not
be translated, but passed straight through to the search-handler
function, as the C<CQL> member of the parameters hash.  It is then the
responsibility of the back-end application to parse and handle the CQL
query, which is most easily done using Ed Summers' fine C<CQL::Parser>
module, available from CPAN at
http://search.cpan.org/~esummers/CQL-Parser/

=head1 AUTHORS

Anders Sønderberg (sondberg@indexdata.dk),
Sebastian Hammer (quinn@indexdata.dk),
Mike Taylor (indexdata.com).

=head1 SEE ALSO

Any Perl module which is useful for accessing the database of your
choice.

=cut
