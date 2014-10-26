package Pandoc::Elements;
use strict;
use warnings;
use 5.008_005;

our $VERSION = '0.02';

our %ELEMENTS = (
    Plain => [ Block => 1 ],
    Para => [ Block => 1 ],
    CodeBlock => [ Block => 2 ],
    RawBlock => [ Block => 2 ],
    BlockQuote => [ Block => 1 ],
    OrderedList => [ Block => 2 ],
    BulletList => [ Block => 1 ],
    DefinitionList => [ Block => 1 ],
    Header => [ Block => 3 ],
    HorizontalRule => [ Block => 0 ],
    Table => [ Block => 5 ],
    Div => [ Block => 2 ],
    Null => [ Block => 0 ],

    Str => [ Inline => 1 ],
    Emph => [ Inline => 1 ],
    Strong => [ Inline => 1 ],
    Strikeout => [ Inline => 1 ],
    Superscript => [ Inline => 1 ],
    Subscript => [ Inline => 1 ],
    SmallCaps => [ Inline => 1 ],
    Quoted => [ Inline => 2 ],
    Cite => [ Inline => 2 ],
    Code => [ Inline => 2 ],
    Space => [ Inline => 0 ],
    LineBreak => [ Inline => 0 ],
    Math => [ Inline => 2 ],
    RawInline => [ Inline => 2 ],
    Link => [ Inline => 2 ],
    Image => [ Inline => 2 ],
    Note => [ Inline => 1 ],
    Span => [ Inline => 2 ],
    
    MetaBool => [ Meta => 1 ],
    MetaString => [ Meta => 1 ],
    MetaMap => [ Meta => 1 ],
    MetaInlines => [ Meta => 1 ],
    MetaList => [ Meta => 1 ],
    MetaBlocks => [ Meta => 1 ],
);

use Carp;
use Scalar::Util;
use parent 'Exporter';
our @EXPORT = (keys %ELEMENTS, qw(Document attributes));
our @EXPORT_OK = (@EXPORT, 'element');

foreach my $name (qw(Inline Block Meta Document)) {
    no strict 'refs';
    eval "package Pandoc::AST::$name; our \@ISA=qw(Pandoc::AST::Element)";
}

foreach my $name (keys %ELEMENTS) {
    no strict 'refs';

    my $parent  = $ELEMENTS{$name}->[0];
    my $numargs = $ELEMENTS{$name}->[1];
    my $class = "Pandoc::AST::$name";

    eval "package $class; our \@ISA = qw(Pandoc::AST::$parent);";

    *{__PACKAGE__."::$name"} = Scalar::Util::set_prototype( sub {
        croak "$name expects $numargs arguments, but given " . scalar @_
            if @_ != $numargs;
        bless { t => $name, c => (@_ == 1 ? $_[0] : \@_) }, $class;
    }, '$' x $numargs );
}

sub element {
    my $name = shift;
    no strict 'refs';
    croak "unknown element $name" unless $ELEMENTS{$name};
    &$name(@_);
}

{
    package Pandoc::AST::Element;
    use JSON;
    use Scalar::Util qw(reftype);
    sub json { JSON->new->utf8->convert_blessed->encode($_[0]) }
    sub TO_JSON {
        return unless reftype $_[0];
        if (reftype $_[0] eq 'ARRAY') {
            return  [ @{$_[0]} ] ;
        } elsif (reftype $_[0] eq 'HASH') {
            return  { %{$_[0]} } ;
        }
        return;
    }    
    sub is_document { $_[0]->isa('Pandoc::AST::Document') }
    sub is_block    { $_[0]->isa('Pandoc::AST::Block') }
    sub is_inline   { $_[0]->isa('Pandoc::AST::Inline') }
    sub is_meta     { $_[0]->isa('Pandoc::AST::Meta') }
}

sub Document($$) {
   @_ == 2 or croak "Document expects 2 arguments, but given " . scalar @_;
   return bless [ { unMeta => $_[0] }, $_[1] ], 'Pandoc::AST::Document';
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

    print Document({ 
        title => MetaInlines [ Str "Greeting" ] 
      }, [
        Header( 1, attributes { id => 'top' }, [ Str 'Hello' ] ),
        Para [ Str 'Hello, world!' ],
      ])->json;

can be converted for instance to HTML with via

    ./hello.pl | pandoc -f json -t html5 --standalone

an equivalent Pandoc Markdown document would be

    % Greeting
    # Gruß {.de}
    Hello, world!

=head1 DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of L<Pandoc|http://johnmacfarlane.net/pandoc/> documents. The resulting
data structure can be processed by pandoc to be converted an many other
document formats, such as HTML, LaTeX, ODT, and ePUB. The module
L<Pandoc::Walker> contains functions for processing the AST in Perl.

=head1 ELEMENT METHODS 

AST elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format C<json>. All elements are blessed
objects in the C<Pandoc::AST::> namespace, for instance C<Pandoc::AST::Para>
for paragraph elements. 

=head2 json

Return the element as JSON encoded string. The following are equivalent:

    $element->json;
    JSON->new->utf8->convert_blessed->encode($element);

=head2 is_block

True if the element is a L<Block element|/BLOCK ELEMENTS>

=head2 is_inline

True if the element is an inline L<Inline element|/INLINE ELEMENTS>

=head2 is_meta

True if the element is a L<Metadata element|/METADATA ELEMENTS>

=head2 is_document

True if the element is a L<Document element|/DOCUMENT ELEMENT>

=head1 FUNCTIONS

=head2 BLOCK ELEMENTS

=head3 BlockQuote

=head3 BulletList

=head3 CodeBlock

=head3 DefinitionList

=head3 Div

=head3 Header

=head3 HorizontalRule

=head3 Null

=head3 OrderedList

=head3 Para

=head3 Plain

=head3 RawBlock

=head3 Table

=head2 INLINE ELEMENTS

=head3 Cite

=head3 Code

=head3 Emph

=head3 Image

=head3 LineBreak

=head3 Link

=head3 Math

=head3 Note

=head3 Quoted

=head3 RawInline

=head3 SmallCaps

=head3 Space

=head3 Span

=head3 Str

=head3 Strikeout

=head3 Strong

=head3 Subscript

=head3 Superscript

=head2 METADATA ELEMENTS

=head3 MetaBlocks

=head3 MetaBool

=head3 MetaInlines

=head3 MetaList

=head3 MetaMap

=head3 MetaString

=head2 DOCUMENT ELEMENT

=head3 Document

Root element, consisting of metadata hash and document element array.

=head2 ADDITIONAL FUNCTIONS

=head3 attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

=head3 element( $name => $content )

Create a Pandoc document element. This function is only exported on request.

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
