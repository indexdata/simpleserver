package Net::Z3950::GRS1;

use strict;
use IO::Handle;
use Carp;


sub new {
	my $class = shift;
	my $self = {};

	$self->{ELEMENTS} = [];
	$self->{FH} = *STDOUT;		## Default output handle is STDOUT
	bless $self, $class;

	return $self;
}


sub GetElementList {
	my $self = shift;

	return $self->{ELEMENTS};
}


sub CreateTaggedElement {
	my ($self, $type, $value, $element_data) = @_;
	my $tagged = {};

	$tagged->{TYPE} = $type;
	$tagged->{VALUE} = $value;
	$tagged->{OCCURANCE} = undef;
	$tagged->{META} = undef;
	$tagged->{VARIANT} = undef;
	$tagged->{ELEMENTDATA} = $element_data;

	return $tagged;
}


sub GetTypeValue {
	my ($self, $TaggedElement) = @_;

	return ($TaggedElement->{TYPE}, $TaggedElement->{VALUE});
}


sub GetElementData {
	my ($self, $TaggedElement) = @_;

	return $TaggedElement->{ELEMENTDATA};
}


sub CheckTypes {
	my ($self, $which, $content) = @_;

	if ($which == &Net::Z3950::GRS1::ElementData::String) {
		if (ref($content) eq '') {
			return 1;
		} else {
			croak "Wrong content type, expected a scalar";
		}
	} elsif ($which == &Net::Z3950::GRS1::ElementData::Subtree) {
		if (ref($content) eq __PACKAGE__) {
			return 1;
		} else {
			croak "Wrong content type, expected a blessed reference";
		}
	} else {
		croak "Content type currently not supported";
	}
}


sub CreateElementData {
	my ($self, $which, $content) = @_;
	my $ElementData = {};

	$self->CheckTypes($which, $content);
	$ElementData->{WHICH} = $which;
	$ElementData->{CONTENT} = $content;

	return $ElementData;
}
	

sub AddElement {
	my ($self, $type, $value, $which, $content) = @_;
	my $Elements = $self->GetElementList;
	my $ElmData = $self->CreateElementData($which, $content);
	my $TaggedElm = $self->CreateTaggedElement($type, $value, $ElmData);

	push(@$Elements, $TaggedElm);
}


sub _Indent {
	my ($self, $level) = @_;
	my $space = "";

	foreach (1..$level - 1) {
		$space .= "    ";
	}

	return $space;
}


sub _RecordLine {
	my ($self, $level, $pool, @args) = @_;
	my $fh = $self->{FH};
	my $str = sprintf($self->_Indent($level) . shift(@args), @args);

	print $fh $str;
	if (defined($pool)) {
		$$pool .= $str;
	}
}


sub Render {
	my $self = shift;
	my %args = (
			FORMAT	=>	&Net::Z3950::GRS1::Render::Plain,
			FILE	=>	'/dev/null',	
			LEVEL	=>	0,
			HANDLE	=>	undef,
			POOL	=>	undef,
			@_ );
	my @Elements = @{$self->GetElementList};
	my $TaggedElement;
	my $fh = $args{HANDLE};
	my $level = ++$args{LEVEL};
	my $ref = $args{POOL};

	if (!defined($fh) && defined($args{FILE})) {
		open(FH, '> ' . $args{FILE}) or croak "Render: Unable to open file '$args{FILE}' for writing: $!";
		FH->autoflush(1);
		$fh = *FH;
	}
	$self->{FH} = defined($fh) ? $fh : $self->{FH};
	$args{HANDLE} = $fh;
	foreach $TaggedElement (@Elements) {
		my ($type, $value) = $self->GetTypeValue($TaggedElement);
		if ($self->GetElementData($TaggedElement)->{WHICH} == &Net::Z3950::GRS1::ElementData::String) {
			$self->_RecordLine($level, $ref, "(%s,%s) %s\n", $type, $value, $self->GetElementData($TaggedElement)->{CONTENT});
		} elsif ($self->GetElementData($TaggedElement)->{WHICH} == &Net::Z3950::GRS1::ElementData::Subtree) {
			$self->_RecordLine($level, $ref, "(%s,%s) {\n", $type, $value);
			$self->GetElementData($TaggedElement)->{CONTENT}->Render(%args);
			$self->_RecordLine($level, $ref, "}\n");
		}
	}
	if ($level == 1) {
		$self->_RecordLine($level, $ref, "(0,0)\n");
	}	
}		

	
package Net::Z3950::GRS1::ElementData;

## Define some constants according to the GRS-1 specification

sub Octets		{ 1 }
sub Numeric		{ 2 }
sub Date		{ 3 }
sub Ext			{ 4 }
sub String		{ 5 }
sub TrueOrFalse		{ 6 }
sub OID			{ 7 }
sub IntUnit		{ 8 }
sub ElementNotThere	{ 9 }
sub ElementEmpty	{ 10 }
sub NoDataRequested	{ 11 }
sub Diagnostic		{ 12 }
sub Subtree		{ 13 }


package Net::Z3950::GRS1::Render;

## Define various types of rendering formats

sub Plain		{ 1 }
sub XML			{ 2 }
sub Raw			{ 3 }


1;

__END__


=head1 NAME

Net::Z3950::Record::GRS1 - Perl package used to encode GRS-1 records.

=head1 SYNOPSIS

  use Net::Z3950::Record::GRS1;

  my $a_grs1_record = new Net::Z3950::Record::GRS1;
  my $another_grs1_record = new Net::Z3950::Record::GRS1;

  $a_grs1_record->AddElement($type, $value, $content);
  $a_grs1_record->render();

=head1 DESCRIPTION

Here goes the documentation. I guess, you'll have to wait for it!

=head1 AUTHOR

Anders Sønderberg Mortensen <sondberg@indexdata.dk>
Index Data ApS, Copenhagen, Denmark.
2001/03/09

=head1 SEE ALSO

Specification of the GRS-1 standard, for instance in the Z39.50 protocol specification.

=cut

#$Log: GRS1.pm,v $
#Revision 1.1  2001-03-13 14:17:15  sondberg
#Added support for GRS-1.
#

