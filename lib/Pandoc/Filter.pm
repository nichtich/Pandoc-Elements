package Pandoc::Filter;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.17';

use JSON;
use Carp;
use Scalar::Util 'reftype';
use List::Util;
use Pandoc::Walker;
use Pandoc::Elements ();

use parent 'Exporter';
our @EXPORT = qw(pandoc_filter pandoc_walk stringify);

sub stringify {
    $_[0]->string;
}

sub pandoc_walk(@) {    ## no critic
    my $filter = Pandoc::Filter->new(@_);
    my $ast    = Pandoc::Elements::pandoc_json(<STDIN>);
    binmode STDOUT, ':encoding(UTF-8)';
    $filter->apply( $ast, @ARGV ? $ARGV[0] : '' );
}

sub pandoc_filter(@) {    ## no critic
    my $ast = pandoc_walk(@_);    # implies binmode STDOUT UTF-8
    my $json = JSON->new->allow_blessed->convert_blessed->encode($ast);

    #my $json = $ast->to_json;  # does not want binmode STDOUT UTF-8
    say STDOUT $json;
}

# constructor and methods

sub new {
    my $class = shift;
    bless {
        action => Pandoc::Walker::action(@_),
        error  => '',
    }, $class;
}

sub error {
    $_[0]->{error};
}

sub action {
    return $_[0]->{action};

    my $actions = $_[0]->{actions};

    sub {
        my ( $element, $format, $meta ) = @_;
        foreach my $action (@$actions) {
            local $_ = $element;
            $action->( $element, $format, $meta );
        }
      }
}

# TODO: refactor with method action
sub apply {
    my ( $self, $ast, $format, $meta ) = @_;
    $format ||= '';
    $meta ||= eval { $ast->[0]->{unMeta} } || {};

    if ( $self->{action} ) {
        Pandoc::Walker::transform( $ast, $self->{action}, $format, $meta );
    }

    #    foreach my $action (@{$self->{actions}}) {
    #        Pandoc::Walker::transform( $ast, $action, $format, $meta );
    #    }
    $ast;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Filter - process Pandoc abstract syntax tree 

=head1 SYNOPSIS

The following filter C<flatten.pl>, adopted from L<pandoc scripting
documentation|http://pandoc.org/scripting.html> converts level 2+ headers to
regular paragraphs.

    use Pandoc::Filter;
    use Pandoc::Elements;

    pandoc_filter Header => sub {
        return unless $_->level >= 2;
        return Para [ Emph $_->content ];
    };

To apply this filter on a Markdown file:

    pandoc --filter flatten.pl -t markdown < input.md

See L<https://metacpan.org/pod/distribution/Pandoc-Elements/examples/> for more 
examples of filters.

=head1 DESCRIPTION

Pandoc::Filter is a port of
L<pandocfilters|https://github.com/jgm/pandocfilters> from Python to modern
Perl.  The module provide provides functions to aid writing Perl scripts that
process a L<Pandoc|http://pandoc.org/> abstract syntax tree (AST) serialized as
JSON. See L<Pandoc::Elements> for documentation of AST elements.

This module is based on L<Pandoc::Walker> and its function C<transform>. Please
consider using its function interface (C<transform>, C<query>, C<walk>) instead
of this module.

=head1 METHODS

=head2 new( @actions | %actions )

Create a new filter with one or more action functions, given as code
reference(s). Each function is expected to return an element, an empty array
reference, or C<undef> to modify, remove, or keep a traversed element in the
AST. The current element is passed to an action function both as first argument
and in the special variable C<$_>. Output format (if specified) and document
metadata are passed as second and third argument.

If actions are given as hash, key values are used to check which elements to
apply for, e.g. 

    Pandoc::Filter->new( 
        Header                 => sub { ... }, 
        'Suscript|Superscript' => sub { ... }
    )

=head2 apply( $ast [, $format [ $metadata ] ] )

Apply all actions to a given abstract syntax tree (AST). The AST is modified in
place and also returned for convenience. Additional argument format and
metadata are also passed to the action function. Metadata is taken from the
Document by default (if the AST is a Document root).

=head2 action

Return a code reference to call all actions.

=head2 size

Return the number of actions in this filter.

=head1 FUNCTIONS

The following functions are exported by default.

=head2 pandoc_walk( @actions | %actions )

Read a single line of JSON from STDIN and walk down the AST.  Implicitly sets
binmode UTF-8 for STDOUT.

=head2 pandoc_filter( @actions | %actions )

Read a single line of JSON from STDIN, apply actions and print the resulting
AST as single line of JSON. This function is roughly equivalent to

    my $ast = Pandoc::Elements::pandoc_json(<>);
    Pandoc::Filter->new(@actions)->apply($ast, @ARGV ? $ARGV[0] : ());
    say $ast->to_json;

=head2 stringify( $ast )

Walks the ast and returns concatenated string content, leaving out all
formatting. This function is also accessible as method of L<Pandoc::Element>
since version 0.12, so I<it will be removed as exportable function> in a later
version.

=head1 SEE ALSO

Script L<pandocwalk> installed with this module facilitates execution of
C<pandoc_walk> to traverse a document.

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
