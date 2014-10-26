package Pandoc::Filter;
use strict;
use warnings;

our $VERSION = '0.03';

use JSON;
use Carp;
use Scalar::Util 'reftype';
use Pandoc::Walker;
use Pandoc::Elements ();

use parent 'Exporter';
our @EXPORT = qw(pandoc_filter stringify);

sub stringify {
    my ($ast) = @_;
    my @result;
    walk( $ast, sub {
        my ($name, $value) = ($_[0]->name, $_[0]->value);
        if ($name eq 'Str') {
            push @result, $value;
        } elsif ($name eq 'Code' or $name eq 'Math') {
            push @result, $value->[1];
        } elsif ($name eq 'LineBreak' or $name eq 'Space') {
            push @result, " ";
        }
        return; 
    }, "", {} );
    return join '', @result;
}

sub pandoc_filter(@) { ## no critic
    my $filter = Pandoc::Filter->new(@_);
    my $ast = Pandoc::Elements::from_json(<STDIN>);
    $filter->apply($ast);
    my $json = JSON->new->utf8->allow_blessed->convert_blessed->encode($ast);
    #my $json = $ast->to_json; # TODO
    print STDOUT $json;
    print STDOUT "\n";
}

# constructor and methods

sub new {
    my $class = shift;
    if ( grep { reftype $_ ne 'CODE' } @_ ) {
        croak $class.'->new expects a list of CODE references';
    }
    bless \@_, $class;
}

sub apply {
    my ($self, $ast, $format, $meta) = @_;
    $meta ||= eval { $ast->[0]->{unMeta} } || { };

    foreach my $action (@$self) {
        transform($ast, $action, $format || '', $meta);
    }
    $ast;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Filter - process Pandoc abstract syntax tree 

=head1 SYNOPSIS

The following filter, adopted from [pandoc scripting
documentation](http://johnmacfarlane.net/pandoc/scripting.html) converts level
2+ headers to regular paragraphs.

    use Pandoc::Filter;
    use Pandoc::Elements;

    pandoc_filter sub {
        return unless ($_[0]->name eq 'Header' and $_[0]->value->[0] >= 2);
        return Para [ Emph $_[0]->value->[2] ];
    };

[Signatures](http://perldoc.perl.org/perlsub.html#Signatures), as introduced in
Perl 5.20, can be used for better readability:

    use Pandoc::Filter;
    use experimental 'signatures';

    pandoc_filter sub ($elem, $format, $meta) {
        return unless ($elem->name eq 'Header' and $elem->value->[0] >= 2);
        return Para [ Emph $elem->value->[2] ];
    };

=head1 DESCRIPTION

Pandoc::Filter is a port of
L<pandocfilters|https://github.com/jgm/pandocfilters> from Python to modern
Perl.  The module provide provides functions to aid writing Perl scripts that
process a L<Pandoc|http://johnmacfarlane.net/pandoc/> abstract syntax tree
(AST) serialized as JSON. See also L<Pandoc::Elements> and L<Pandoc::Walker>
for modules that filters are based on.

=head1 METHODS

=head2 new( @action )

Create a new filter with one or more action functions, given as code
reference(s).

=head2 apply( $ast [, $format [ $metadata ] ] )

Apply all actions to a given abstract syntax tree. The syntax tree is modified
in place and also returned for convenience. Additional argument format and
metadata are also passed to the action function. Metadata is taken from
the Document by default (if the AST is a Document root).

=head1 FUNCTIONS

=head2 pandoc_filter( @action )

Read a single line of JSON from STDIN, apply actions and print the resulting
AST as single line of JSON. This function is roughly equivalent to

    my $ast = Pandoc::Elements::from_json(<>);
    Pandoc::Filter->new(@action)->apply($ast);
    say $ast->to_json;

=head2 stringify( $ast )

Walks the ast and returns concatenated string content, leaving out all
formatting.

=head1 SEE ALSO

L<Pandoc::Elements>, L<Pandoc::Walker>

=cut
