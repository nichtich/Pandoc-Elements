package Pandoc::Walker;
use strict;
use warnings;

our $VERSION = '0.11';

use Scalar::Util qw(reftype blessed);

use parent 'Exporter';
our @EXPORT = qw(walk query transform);

sub _walker {
    return @_ if @_ == 2 and ref $_[1] eq 'CODE';

    my $ast = shift;
    my @actions;

    if (!ref $_[0]) {
        @actions = ( shift, shift );
    } elsif (ref $_[0] eq 'CODE') {
        my ($action, @args) = @_;
        return ($ast, sub { $_=$_[0]; $action->($_[0], @args) });
    } elsif (reftype $_[0] eq 'HASH') {
        @actions = %{ shift @_ };
    } 

    my @args = @_;

    my %names;
    for (my $i=0; $i<@actions; $i+=2) {
        foreach( split /\|/, $actions[$i] ) {
            $names{$_} = $actions[$i+1];
        }
    }

    # compile callback
    my $callback = sub {
        my $element = shift;
        my $action = $names{ $element->name } or return;
        $action->($element, @args);
    };

    return ($ast, $callback);
}

sub transform {
    my ($ast, $action) = _walker(@_);

    my $reftype = reftype($ast) || ''; 

    if ($reftype eq 'ARRAY') {
        for (my $i=0; $i<@$ast; ) {
            my $item = $ast->[$i];
            if ((reftype $item || '') eq 'HASH' and $item->{t}) {
                my $res = $action->($item);
                # replace current item with result element(s)
                if (defined $res) {
                    my @elements = #map { transform($_, $action, @_) } 
                        (reftype $res || '') eq 'ARRAY' ? @$res : $res;
                    splice @$ast, $i, 1, @elements;
                    $i += scalar @elements;
                    next;
                }
            }
            transform($item, $action);
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
    my ($ast, $query) = _walker(@_);
    transform( $ast, sub { $_=$_[0]; $query->(@_); return } );
}

sub query(@) { ## no critic
    my ($ast, $query) = _walker(@_);

    my $list = [];
    transform( $ast, sub { $_=$_[0]; push @$list, $query->(@_); return } );
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

    # extract all links and image URLs
    my $links = query $ast, 'Link|Image' => sub { $_->url };

    # print all links and image URLs
    walk $ast, 'Link|Image' => sub { say $_->url };

    # remove all links
    transform $ast, sub {
        return ($_->name eq 'Link' ? [] : ());
    };

    # replace all links by their link text angle brackets
    use Pandoc::Elements 'Str';
    transform $ast, Link => sub {
        return (Str "<", $_->content->[0], Str ">");
    };

=head1 DESCRIPTION

This module provides to helper functions to traverse the abstract syntax tree
(AST) of a pandoc document (see L<Pandoc::Elements> for documentation of AST
elements).

Document elements are passed to action functions by reference, so I<don't
shoot yourself in the foot> by trying to directly modify the element.
Traversing a single element is not reliable neither, so put the element in an
array reference if needed.  For instance to replace links in headers only by
their link text content:

    transform $ast, Header => sub {
        transform [ $_[0] ], Link => sub { # make an array
            return $_[0]->content;         # is an array
        };
    };

See also L<Pandoc::Filter> for an object oriented interface to transformations.

=head1 FUNCTIONS

=head2 walk( $ast, [ $names => ] $action [, @arguments ] )

=head2 walk( $ast, \%actions [, @arguments ] )

Walks an abstract syntax tree and calls an action on every element or every
element of given name(s). Additional arguments are also passed to the action.

See also function C<pandoc_walk> exported by L<Pandoc::Filter>.

=head2 query( $ast, [ $names => ] $query [, @arguments ] )

=head2 query( $ast, \%queries [, @arguments ] )

Walks an abstract syntax tree and applies one or multiple query functions to
extract results.  The query function is expected to return a list. The combined
query result is returned as array reference. For instance the C<string> method
of L<Pandoc::Elements> is implemented as following:

    join '', @{ 
        query( $ast, { 
            'Str|Code|Math'   => sub { $_->content },
            'LineBreak|Space' => sub { ' ' } 
        } );

=head2 transform( $ast [ $names => ] $action [, @arguments ] )

=head2 transform( $ast, \%actions [, @arguments ] )

Walks an abstract syntax tree and applies an action on every element, or every
element of given name(s), to either keep it (if the action returns C<undef>),
remove it (if it returns an empty array reference), or replace it with one or
more elements (returned by array reference or as single value).

See also function C<pandoc_filter> exported by L<Pandoc::Filter>.

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=head1 SEE ALSO

Haskell module L<Text.Pandoc.Walk|http://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Walk.html> for the original.

=cut
