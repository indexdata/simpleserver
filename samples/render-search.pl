#!/usr/bin/perl -w

use Net::Z3950::SimpleServer;
use strict;

my $handler = Net::Z3950::SimpleServer->new(SEARCH => \&search_handler,
					    FETCH => \&fetch_handler);
$handler->launch_server("render-search.pl", @ARGV);

sub search_handler {
    my($args) = @_;
    print "got search: ", $args->{RPN}->{query}->render(), "\n";
}

sub fetch_handler {} # no-op


package Net::Z3950::RPN::Term;
sub render {
    my $self = shift;
    return '"' . $self->{term} . '"';
}

package Net::Z3950::RPN::And;
sub render {
    my $self = shift;
    return '(' . $self->[0]->render() . ' AND ' .
                 $self->[1]->render() . ')';
}

package Net::Z3950::RPN::Or;
sub render {
    my $self = shift;
    return '(' . $self->[0]->render() . ' OR ' .
                 $self->[1]->render() . ')';
}

package Net::Z3950::RPN::AndNot;
sub render {
    my $self = shift;
    return '(' . $self->[0]->render() . ' ANDNOT ' .
                 $self->[1]->render() . ')';
}
