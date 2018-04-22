package Pandoc::Selector;
use strict;
use warnings;
use 5.010001;

use Pandoc::Elements;

sub new {
    my ($class, $selector) = @_;
    # TODO: compile selector
    bless { selector => $selector }, $class;
}

sub match {
    my ($self, $element) = @_;

    foreach my $selector ( split /\|/, $self->{selector} ) {
        return 1 if _match_simple($selector, $element);
    }

    return 0;
}

sub _match_simple {
    my ( $selector, $elem ) = @_;
    $selector =~ s/^\s+|\s+$//g;

    # name
    return 0
      if $selector =~ s/^([a-z]+)\s*//i and lc($1) ne lc( $elem->name );
    return 1 if $selector eq '';

    # type
    if ( $selector =~ s/^:(document|block|inline|meta)\s*// ) {
        my $method = "is_$1";
        return 0 unless $elem->$method;
        return 1 if $selector eq '';
    }

    # TODO: :method (e.g. :url)

    # TODO: [:level=1]

    # TODO [<number>]

    # TODO [@<attr>]

    # id and/or classes
    return 0 unless $elem->isa('Pandoc::Document::AttributesRole');
    return _match_attributes($selector, $elem);
}

our $IDENTIFIER = qr{\p{L}(\p{L}|[0-9_:.-])*};

# check #id and .class
sub _match_attributes {
    my ( $selector, $elem ) = @_;

    $selector =~ s/^\s+|\s+$//g; # trim

    while ( $selector ne '' ) {
        if ( $selector =~ s/^#($IDENTIFIER)\s*// ) {
            return 0 unless $elem->id eq $1;
        }
        elsif ( $selector =~ s/^\.($IDENTIFIER)\s*// ) {
            return 0 unless grep { $1 eq $_ } @{ $elem->attr->[1] };
        }
        else {
            return 0;
        }
    }

    return 1;
}

1;
__END__

=head1 NAME

Pandoc::Selector - Pandoc document selector language

=head1 SYNOPSIS

  my $selector = Pandoc::Selector->new('Code.perl|CodeBlock.perl');

  # check whether an element matches
  $selector->match($element);

  # use as element method
  $element->match('Code.perl|CodeBlock.perl')

=head1 DESCRIPTION

Pandoc::Selector provides a language to select elements of a Pandoc document.
It borrows ideas from L<CSS Selectors|https://www.w3.org/TR/selectors-3/>,
L<XPath|https://www.w3.org/TR/xpath/> and similar languages.

The language is being developed together with this implementation.

=head1 EXAMPLES

  Header#main
  Code.perl
  Code.perl.raw
  Subscript|Superscript
  :inline

=cut
