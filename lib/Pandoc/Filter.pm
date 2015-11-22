package Pandoc::Filter;
use 5.010;
use strict;
use warnings;

our $VERSION = '0.06';

use JSON;
use Carp;
use Scalar::Util 'reftype';
use List::Util;
use Pandoc::Walker;
use Pandoc::Elements ();

use parent 'Exporter';
our @EXPORT = qw(pandoc_filter stringify);

sub stringify {
    my ($ast) = @_;
    my @result;
    walk( $ast, sub {
        my ($name, $content) = ($_[0]->name, $_[0]->content);
        if ($name eq 'Str' or $name eq 'Code' or $name eq 'Math') {
            push @result, $content;
        } elsif ($name eq 'LineBreak' or $name eq 'Space') {
            push @result, " ";
        }
        return; 
    }, "", {} );
    return join '', @result;
}

sub pandoc_filter(@) { ## no critic
    my $filter = Pandoc::Filter->new(@_);
    my $ast = Pandoc::Elements::pandoc_json(<STDIN>);
    $filter->apply($ast);
    my $json = JSON->new->utf8->allow_blessed->convert_blessed->encode($ast);
    #my $json = $ast->to_json; # TODO
    say STDOUT $json;
}

# constructor and methods

sub new {
    my $class = shift;
    if ( @_ and !(ref $_[0] or @_ % 2) ) {
        my @actions;
        for( my $i=0; $i<@_; $i+=2 ) {
            my @names  = split /\|/, $_[$i];
            my $action = $_[$i+1];
            push @actions, sub {
                return unless List::Util::first { $_[0]->name eq $_ } @names;
                $action->(@_);
            };
        }
        bless \@actions, $class;
    } else {
        if ( grep { !reftype $_ or reftype $_ ne 'CODE' } @_ ) {
            croak $class.'->new expects a hash or list of CODE references';
        }
        bless \@_, $class;
    }
}

sub apply {
    my ($self, $ast, $format, $meta) = @_;
    $meta ||= eval { $ast->[0]->{unMeta} } || { };

    foreach my $action (@$self) {
        Pandoc::Walker::transform($ast, $action, $format || '', $meta);
    }
    $ast;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Filter - process Pandoc abstract syntax tree 

=head1 SYNOPSIS

The following filter C<flatten.pl>, adopted from L<pandoc scripting
documentation|http://johnmacfarlane.net/pandoc/scripting.html> converts level
2+ headers to regular paragraphs.

    use Pandoc::Filter;
    use Pandoc::Elements;

    pandoc_filter Header => sub {
        return unless $_[0]->level >= 2;
        return Para [ Emph $_[0]->content ];
    };

To apply this filter on a Markdown file:

    pandoc --filter flatten.pl -t markdown < input.md

See L<https://metacpan.org/pod/distribution/Pandoc-Elements/examples/> for more 
examples of filters.

=head1 DESCRIPTION

Pandoc::Filter is a port of
L<pandocfilters|https://github.com/jgm/pandocfilters> from Python to modern
Perl.  The module provide provides functions to aid writing Perl scripts that
process a L<Pandoc|http://johnmacfarlane.net/pandoc/> abstract syntax tree
(AST) serialized as JSON. See L<Pandoc::Elements> for documentation of AST
elements.

This module is based on L<Pandoc::Walker> and its function C<transform>. Please
consider using its function interface (C<transform>, C<query>, C<walk>) instead
of this module.

=head1 METHODS

=head2 new( @actions | %actions )

Create a new filter with one or more action functions, given as code
reference(s). Each function is expected to return an element, an empty array
reference, or C<undef> to modify, remove, or keep a traversed element in the
AST. If actions are given as hash, key values are used to check which elements
to apply for, e.g. 

    Pandoc::Filter->new( 
        Header                 => sub { ... }, 
        'Suscript|Superscript' => sub { ... }
    )

=head2 apply( $ast [, $format [ $metadata ] ] )

Apply all actions to a given abstract syntax tree (AST). The AST is modified in
place and also returned for convenience. Additional argument format and
metadata are also passed to the action function. Metadata is taken from the
Document by default (if the AST is a Document root).

=head1 FUNCTIONS

The following functions are exported by default.

=head2 pandoc_filter( @actions | %actions )

Read a single line of JSON from STDIN, apply actions and print the resulting
AST as single line of JSON. This function is roughly equivalent to

    my $ast = Pandoc::Elements::pandoc_json(<>);
    Pandoc::Filter->new(@actions)->apply($ast);
    say $ast->to_json;

=head2 stringify( $ast )

Walks the ast and returns concatenated string content, leaving out all
formatting.

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
