package Pandoc::Elements;
use strict;
use warnings;
use 5.008_005;

our $VERSION = '0.02';

our %ELEMENTS = (
    # Constructors for block elements
    Plain => 1,
    Para => 1,
    CodeBlock => 2,
    RawBlock => 2,
    BlockQuote => 1,
    OrderedList => 2,
    BulletList => 1,
    DefinitionList => 1,
    Header => 3,
    HorizontalRule => 0,
    Table => 5,
    Div => 2,
    Null => 0,
    # Constructors for inline elements
    Str => 1,
    Emph => 1,
    Strong => 1,
    Strikeout => 1,
    Superscript => 1,
    Subscript => 1,
    SmallCaps => 1,
    Quoted => 2,
    Cite => 2,
    Code => 2,
    Space => 0,
    LineBreak => 0,
    Math => 2,
    RawInline => 2,
    Link => 2,
    Image => 2,
    Note => 1,
    Span => 2,
    # constructors for meta elements
    MetaBool => 1,
    MetaString => 1,
    MetaMap => 1,
    MetaInlines => 1,
    MetaList => 1,
    MetaBlocks => 1,
);

use Carp;
use Scalar::Util;
use parent 'Exporter';
our @EXPORT = (keys %ELEMENTS, qw(Document attributes));
our @EXPORT_OK = (@EXPORT, 'element');

while (my ($name, $numargs) = each %ELEMENTS) {
    no strict 'refs';
    *{__PACKAGE__."::$name"} = Scalar::Util::set_prototype( sub {
        croak "$name expects $numargs arguments, but given " . scalar @_
            if @_ != $numargs;
        return { t => $name, c => (@_ == 1 ? $_[0] : \@_) };
    }, '$' x $numargs );
}

sub element {
    my $name = shift;
    no strict 'refs';
    croak "unknown element $name" unless $ELEMENTS{$name};
    &$name(@_);
}

sub Document($$) {
   @_ == 2 or croak "Document expects 2 arguments, but given " . scalar @_;
   return [ { unMeta => $_[0] }, $_[1] ];
}

sub attributes($) {
    my ($attrs) = @_;
    return [ 
        defined $attrs->{id} ? $attrs->{id} : '',
        defined $attrs->{classes} ? $attrs->{classes} : [],
        [ 
            map { $_ => $attrs->{$_} } 
            grep { $_ ne 'id' and $_ ne 'classes' } 
            keys %$attrs 
        ]
    ];
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Elements - utility functions to create and process Pandoc documents

=begin markdown

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Elements.png)](https://travis-ci.org/nichtich/Pandoc-Elements)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Elements/badge.png)](https://coveralls.io/r/nichtich/Pandoc-Elements)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc-Elements.png)](http://cpants.cpanauthors.org/dist/Pandoc-Elements)

=end markdown


=head1 SYNOPSIS

The output of this script C<hello.pl>

    use Pandoc::Elements;
    use JSON;

    print encode_json Document { 
        title => MetaInlines [ Str "Greeting" ] 
      }, [
        Header( 1, attributes { id => 'top' }, [ Str 'Hello' ] ),
        Para [ Str 'Hello, world!' ],
      ];

can be converted for instance to HTML with via

    ./hello.pl | pandoc -f json -t html5 --standalone

an equivalent Pandoc Markdown document would be

    % Greeting
    # Hello {.top}
    Hello, world!

=head1 DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of L<Pandoc|http://johnmacfarlane.net/pandoc/> documents. The resulting
data structure can be processed by pandoc to be converted an many other
document formats, such as HTML, LaTeX, ODT, and ePUB. The module
L<Pandoc::Walker> contains functions for processing the AST in Perl.

A future versions of this module may upgrade the data structures to blessed
objects, so better encode JSON as following:

    JSON->new->utf8->allow_blessed->convert_blessed->encode($document);

=head1 FUNCTIONS

=head2 BLOCK ELEMENTS

BlockQuote, BulletList, CodeBlock, DefinitionList, Div, Header, HorizontalRule,
Null, OrderedList, Para, Plain, RawBlock, Table

=head2 INLINE ELEMENTS

Cite, Code, Emph, Image, LineBreak, Link, Math, Note, Quoted, RawInline,
SmallCaps, Space, Span, Str, Strikeout, Strong, Subscript, Superscript

=head2 METADATA ELEMENTS

MetaBlocks, MetaBool, MetaInlines, MetaList, MetaMap, MetaString

=head3 Document

Root element, consisting of metadata hash and document element array.

=head2 ADDITIONAL FUNCTIONS

=head3 attributes( { key => $value, ... } )

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

=head3 element( $name => $content )

Create a Pandoc document element. A future version of this module may return a
blessed object This function is only exported on request.

=head1 AUTHOR

Jakob Voß E<lt>jakob.voss@gbv.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

See L<Text.Pandoc.Definition|https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html>
for the original definition of Pandoc document data structure in Haskell.

See L<Pandoc::Walker> for a module to implement L<pandoc
filters|http://johnmacfarlane.net/pandoc/scripting.html>.

=cut
