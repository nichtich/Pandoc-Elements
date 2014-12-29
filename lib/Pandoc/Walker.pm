package Pandoc::Walker;
use strict;
use warnings;

our $VERSION = '0.05';

use Scalar::Util qw(reftype blessed);
use parent 'Exporter';
our @EXPORT = qw(walk query transform);

sub transform {
    my $ast    = shift;
    my $action = shift;

    my $reftype = reftype($ast) || ''; 

    if ($reftype eq 'ARRAY') {
        my $i = 0;
        foreach my $item (@$ast) {
            if ((reftype $item || '') eq 'HASH' and $item->{t}) {
                my $res = $action->($item, @_);
                # replace current item with result element(s)
                if (defined $res) {
                    my @elements = map { transform($_, $action, @_) } 
                        (reftype $res || '') eq 'ARRAY' ? @$res : $res;
                    splice @$ast, $i, 1, @elements;
                    $i += scalar @elements;
                    next;
                }
            }
            transform($item, $action, @_);
            $i++;
        }
    } elsif ($reftype eq 'HASH') {
        # TODO: directly transform an element. 
        # if (blessed $ast and $ast->isa('Pandoc::Elements::Element')) {
        # } else {
            foreach (keys %$ast) {
                transform($ast->{$_}, $action, @_);
            }
        # }
    }

    $ast;
}

sub walk(@) { ## no critic
    my ($ast, $query, @arguments) = @_;

    transform( $ast, sub { $query->(@_); return }, @arguments );
}

sub query(@) { ## no critic
    my ($ast, $query, @arguments) = @_;

    my $list = [];
    transform( $ast, sub { push @$list, $query->(@_); return; }, @arguments );
    return $list;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Walker - utility functions to traverse Pandoc documents

=head1 SYNOPSIS

    use Pandoc::Walker;
    use Pandoc::Elements qw(pandoc_json);

    my $ast = pandoc_json(<>);

    # extract all links
    my $links = query $ast, sub {
        my $e = shift;
        return unless ($e->name eq 'Link' or $e->name eq 'Image');
        return $e->url;
    };

    # print all links
    walk $ast, sub {
        my $e = shift;
        return unless ($e->name eq 'Link' or $e->name eq 'Image');
        print $e->url;
    };

    # remove of all links
    transform $ast, sub {
        return ($_[0]->name eq 'Link' ? [] : ());
    };

    # replace all links by their link text angle brackets
    use Pandoc::Elements 'Str';
    transform $ast, sub {
        my $elem = $_[0];
        return unless $elem->name eq 'Link';
        return (Str "<", $elem->content->[0], Str ">");
    };

=head1 DESCRIPTION

This module provides to helper functions to traverse the abstract syntax tree
(AST) of a pandoc document (see L<Pandoc::Elements> for documentation of AST
elements).

Document elements are passed to action functions by reference, so I<don't shoot
yourself in the foot> by trying to directly modify the element. Traversing a single
element is not reliable neither, so put the element in an array reference if needed.
For instance to replace links in headers only by their link text content:

    transform $ast, sub {
        my $header = shift;
        return unless $header->name eq 'Header';
        transform [$header], sub { # make an array
            my $link = shift;
            return unless $link->name eq 'Link';
            return $e->content;    # is an array
        };
    };

See also L<Pandoc::Filter> for an object oriented interface to transformations.

=head1 FUNCTIONS

=head2 walk( $ast, $action [, @arguments ] )

Walks an abstract syntax tree and calls an action on every element. Additional
arguments are also passed to the action.

=head2 query( $ast, $query [, @arguments ] )

Walks an abstract syntax tree and applies a query function to extract results.
The query function is expected to return a list. The combined query result is
returned as array reference.

=head2 transform( $ast, $action [, @arguments ] )

Walks an abstract syntax tree and applies an action on every element to either
keep it (if the action returns C<undef>), remove it (if it returns an empty
array reference), or replace it with one or more elements (returned by array
reference or as single value).

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=head1 SEE ALSO

Haskell module L<Text.Pandoc.Walk|http://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Walk.html> for the original.

=cut
