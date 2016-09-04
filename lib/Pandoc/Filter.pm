package Pandoc::Filter;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.20';

use JSON;
use Carp;
use Scalar::Util 'reftype';
use List::Util;
use Pandoc::Walker;
use Pandoc::Elements qw(Image Str);

use parent 'Exporter';
our @EXPORT = qw(pandoc_filter pandoc_walk build_image stringify);

# FUNCTIONS

sub stringify {

    # warning added in version 0.18
    warn "Pandoc::Filter::stringify deprecated => Pandoc::Element::stringify\n";
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

sub build_image {
    my $e = shift;
    my $filename = shift // '';

    my $img = Image [$e->id, $e->classes, []], [], [$filename, ''];
    my $keyvals = $e->keyvals;

    my $caption = $keyvals->get('caption');
    if (defined $caption) {
        push @{$img->content}, Str($caption);
        $img->target->[1] = 'fig:';
        $keyvals->remove('caption');
    }
    $img->keyvals($keyvals);

    return $img;
}


# METHODS

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
    $_[0]->{action};
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
documentation|http://pandoc.org/scripting.html>, converts level 2+ headers to
regular paragraphs.

    use Pandoc::Filter;
    use Pandoc::Elements;

    pandoc_filter Header => sub {
        return unless $_->level >= 2;       # keep
        return Para [ Emph $_->content ];   # replace
    };

To apply this filter on a Markdown file:

    pandoc --filter flatten.pl -t markdown < input.md

See L<https://metacpan.org/pod/distribution/Pandoc-Elements/examples/> for more 
examples of filters.

=head1 DESCRIPTION

This module is a port of L<pandocfilters|https://github.com/jgm/pandocfilters>
from Python to modern Perl.  It provides methods and functions to aid writing
Perl scripts that process a L<Pandoc|http://pandoc.org/> abstract syntax tree
(AST) serialized as JSON. See L<Pandoc::Elements> for documentation of AST
elements.

The function interface (see L</FUNCTIONS>) directly reads AST and format from
STDIN and ARGV and prints the transformed AST to STDOUT. 

The object oriented interface (see L</METHODS>) requires to:

    my $filter = Pandoc::Filter->new( ... );  # create a filter object
    $filter->apply( $ast, $format );          # pass it an AST for processing

If you don't need the C<format> parameter, consider using the interface
provided by module L<Pandoc::Walker> instead. It can be used both:

    transform $ast, ...;        # as function
    $ast->transform( ... );     # or as method

=head1 ACTIONS

An action is a code reference that is executed on matching document elements of
an AST. The action is passed a reference to the current element, the output
format (the empty string by default), and the document metadata (an empty hash
by default).  The current element is also given in the special variable C<$_>
for convenience.

The action is expected to return an element, an empty array reference, or
C<undef> to modify, remove, or keep a traversed element in the AST. 

=head1 METHODS

=head2 new( @actions | %actions )

Create a new filter object with one or more actions (see L</ACTIONS>). If
actions are given as hash, key values are used to check which elements to apply
for, e.g. 

    Pandoc::Filter->new( 
        Header                 => sub { ... }, 
        'Suscript|Superscript' => sub { ... }
    )

=head2 apply( $ast [, $format [, $metadata ] ] )

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

    my $ast    = Pandoc::Elements::pandoc_json(<>);
    my $format = $ARGV[0];
    Pandoc::Filter->new(@actions)->apply($ast, $format);
    say $ast->to_json;

=head2 build_image( $element [, $filename ] )

Maps an element to an L<Image|Pandoc::Elements/Image> element with attributes
from the given element. The attribute C<caption>, if available, is transformed
into image caption. This utility function is useful for filters that transform
content to images. See graphviz, tikz, lilypond and similar filters in the
L<examples|https://metacpan.org/pod/distribution/Pandoc-Elements/examples/>.

=head1 SEE ALSO

Script L<pandocwalk>, installed with this module, facilitates execution of
C<pandoc_walk> to traverse a document from command line.

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
