package Pandoc::Elements;
use strict;
use warnings;
use 5.008_005;

our $VERSION = '0.04';

our %ELEMENTS = (
    Plain => [ Block => 'content' ],
    Para => [ Block => 'content' ],
    CodeBlock => [ Block => qw(attr content) ],
    RawBlock => [ Block => qw(format content) ],
    BlockQuote => [ Block => 'content' ],
    OrderedList => [ Block => qw(attr content) ],
    BulletList => [ Block => 'content' ],
    DefinitionList => [ Block => 'content' ],
    Header => [ Block => qw(level attr content) ],
    HorizontalRule => [ 'Block' ],
    Table => [ Block => qw(caption alignment widths headers rows) ],
    Div => [ Block => qw(attr content) ],
    Null => [ 'Block' ],

    Str => [ Inline => 'content' ],
    Emph => [ Inline => 'content' ],
    Strong => [ Inline => 'content' ],
    Strikeout => [ Inline => 'content' ],
    Superscript => [ Inline => 'content' ],
    Subscript => [ Inline => 'content' ],
    SmallCaps => [ Inline => 'content' ],
    Quoted => [ Inline => qw(type content) ],
    Cite => [ Inline => qw(citation content) ],
    Code => [ Inline => qw(attr content) ],
    Space => [ 'Inline' ],
    LineBreak => [ 'Inline' ],
    Math => [ Inline => qw(type content) ],
    RawInline => [ Inline => qw(format content) ],
    Link => [ Inline => qw(content target) ],
    Image => [ Inline => qw(content target) ],
    Note => [ Inline => 'content' ],
    Span => [ Inline => qw(attr content) ],
    
    MetaBool => [ Meta => 'content' ],
    MetaString => [ Meta => 'content' ],
    MetaMap => [ Meta => 'content' ],
    MetaInlines => [ Meta => 'content' ],
    MetaList => [ Meta => 'content' ],
    MetaBlocks => [ Meta => 'content' ],

);

# type constructors
foreach (qw(DefaultDelim Period OneParen TwoParens SingleQuote DoubleQuote
    DisplayMath InlineMath AuthorInText SuppressAuthor NormalCitation 
    AlignLeft AlignRight AlignCenter AlignDefault DefaultStyle Example 
    Decimal LowerRoman UpperRoman LowerAlpha UpperAlpha)) {
    $ELEMENTS{$_} = ['Inline']
}

use Carp;
use JSON qw(decode_json);
use Scalar::Util qw(reftype);
use Pandoc::Walker qw(walk);

use parent 'Exporter';
our @EXPORT = (keys %ELEMENTS, qw(Document attributes));
our @EXPORT_OK = (@EXPORT, 'element', 'from_json');

# create constructor functions
foreach my $name (keys %ELEMENTS) {
    no strict 'refs'; ## no critic

    my ($parent, @accessors) = @{$ELEMENTS{$name}};
    my $numargs = scalar @accessors;
    my $class = "Pandoc::Document::$name";

    eval "package $class; our \@ISA = qw(Pandoc::Document::$parent);";

    *{__PACKAGE__."::$name"} = Scalar::Util::set_prototype( sub {
        croak "$name expects $numargs arguments, but given " . scalar @_
            if @_ != $numargs;
        bless { t => $name, c => (@_ == 1 ? $_[0] : \@_) }, $class;
    }, '$' x $numargs );

    for (my $i=0; $i<@accessors; $i++) {
        *{$class."::".$accessors[$i]} = eval(
            @accessors == 1 
                ? "sub { \$_[0]->{c} }"
                : "sub { \$_[0]->{c}->[$i] }"
        );
    }
}

sub element {
    my $name = shift;
    no strict 'refs';
    croak "undefined element" unless defined $name;
    croak "unknown element $name" unless $ELEMENTS{$name};
    &$name(@_);
}

sub Document($$) {
   @_ == 2 or croak "Document expects 2 arguments, but given " . scalar @_;
   return bless [ { unMeta => $_[0] }, $_[1] ], 'Pandoc::Document';
}

# specific accessors

sub Pandoc::Document::Link::url { $_[0]->{c}->[1][0] }
sub Pandoc::Document::Link::title { $_[0]->{c}->[1][1] }
sub Pandoc::Document::Image::url { $_[0]->{c}->[1][0] }
sub Pandoc::Document::Image::title { $_[0]->{c}->[1][1] }

# additional functions

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

sub from_json {
    shift if $_[0] =~ /^Pandoc::/;

    my $ast = eval { decode_json($_[0]) };
    if ($@) {
        $@ =~ s/ at [^ ]+Elements\.pm line \d+//;
        chomp $@;
        croak $@;
    }
    return unless reftype $ast;

    if (reftype $ast eq 'ARRAY') {
        $ast = Document( $ast->[0]->{unMeta}, $ast->[1] );
    } elsif (reftype $ast eq 'HASH') {
        $ast = element( $ast->{t}, $ast->{c} );
    }

    walk $ast, sub {
        bless $_[0], 'Pandoc::Document::'.$_[0]->{t};
    };

    return $ast;
}

# document element packages

{
    package Pandoc::Document;
    use strict;
    our $VERSION = '0.04';
    our @ISA = ('Pandoc::Document::Element');
    sub TO_JSON { [ @{$_[0]} ] }
    sub name { 'Document' }
    sub meta { $_[0]->[0]->{unMeta} }
    sub content { $_[0]->[1] }
    sub is_document { 1 }
}

{
    package Pandoc::Document::Element;
    use strict;
    use warnings;
    our $VERSION = $Pandoc::Document::VERSION;
    use JSON ();
    use Scalar::Util qw(reftype);
    sub to_json { 
        JSON->new->utf8->convert_blessed->encode($_[0])
    }
    sub TO_JSON { return { %{$_[0]} } }    
    sub name        { $_[0]->{t} }
    sub value       { $_[0]->{c} }
    sub content     { $_[0]->{c} }
    sub is_document { 0 }
    sub is_block    { 0 }
    sub is_inline   { 0 }
    sub is_meta     { 0 }
}

{
    package Pandoc::Document::Block;
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA = ('Pandoc::Document::Element');
    sub is_block { 1 }
}

{
    package Pandoc::Document::Inline;
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA = ('Pandoc::Document::Element');
    sub is_inline { 1 }
}

{
    package Pandoc::Document::Meta;
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA = ('Pandoc::Document::Element');
    sub is_meta { 1 }
}


1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Elements - create and process Pandoc documents

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
        ])->to_json;

can be converted for instance to HTML with via

    ./hello.pl | pandoc -f json -t html5 --standalone

an equivalent Pandoc Markdown document would be

    % Greeting
    # Gruß {.de}
    Hello, world!

See module L<Pandoc::Filter> and L<Pandoc::Walker> for processing the abstract
syntax tree of pandoc documents in Perl.

=head1 DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of L<Pandoc|http://johnmacfarlane.net/pandoc/> documents. The resulting
data structure can be converted by L<Pandoc> to many other document formats,
such as HTML, LaTeX, ODT, and ePUB. 

=head2 FUNCTIONS

In addition to constructor functions for each document element, the following
functions are exported.

=head3 attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

=head3 element( $name => $content )

Create a Pandoc document element. This function is only exported on request.

=head1 ELEMENTS 

AST elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format C<json>. All elements are blessed
objects that provide the following element methods and additional accessor
methods specific to each element.

=head2 ELEMENT METHODS

=head3 json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->convert_blessed->encode($element);

=head3 name

Return the name of the element, e.g. "Para" for a L<paragraph element|/Para>.

=head3 value

Return the full element content as array reference. The structure of the value
depends on the element. For known elements better use one of the specific
accessor methods or the C<content> method.

=head3 content

Return the element content. For many elements (L<Para|/Para>, L<Emph|/Emph>,
L<Str|/Str>...) this is equal to the value, but if elements consist of multiple
parts, the content is a subset of the C<value>. For instance the L<Link|/Link>
element consists a link text (C<content>) and a link target (C<target>), the
latter consisting of C<url> and C<title>.

=head3 is_block

True if the element is a L<Block element|/BLOCK ELEMENTS>

=head3 is_inline

True if the element is an inline L<Inline element|/INLINE ELEMENTS>

=head3 is_meta

True if the element is a L<Metadata element|/METADATA ELEMENTS>

=head3 is_document

True if the element is a L<Document element|/DOCUMENT ELEMENT>

=head2 BLOCK ELEMENTS

=head3 BlockQuote

Block quote, consisting of a list of L<blocks|/BLOCK ELEMENTS> (C<content>)

=head3 BulletList

...

=head3 CodeBlock

...

=head3 DefinitionList

...

=head3 Div

Generic container of L<blocks|/BLOCK ELEMENTS> (C<content>) with attributes
(C<attrs>)

=head3 Header

...

=head3 HorizontalRule

Horizontal rule

=head3 Null

Nothing

=head3 OrderedList

...

=head3 Para

Paragraph, consisting of a list of L<Inline elements|/INLINE ELEMENTS>
(C<content>).

=head3 Plain

Plain text, not a paragraph, consisting of a list of L<Inline elements|/INLINE
ELEMENTS> (C<content>).

=head3 RawBlock

Raw block with C<format> and C<content> string.

=head3 Table

Table, with C<caption>, column C<alignments>, relative column C<widths> (0 =
default), column C<headers> (each a list of L<blocks|/BLOCK ELEMENTS>), and
C<rows> (each a list of lists of L<blocks|/BLOCK ELEMENTS>).

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

Root element, consisting of metadata hash (C<meta>) and document element array
(C<content>).

=head2 TYPES

The following elements are used as types only: 

C<DefaultDelim>, C<Period>, C<OneParen>, C<TwoParens>, C<SingleQuote>,
C<DoubleQuote>, C<DisplayMath>, C<InlineMath>, C<AuthorInText>,
C<SuppressAuthor>, C<NormalCitation>, C<AlignLeft>, C<AlignRight>,
C<AlignCenter>, C<AlignDefault>, C<DefaultStyle>, C<Example>, C<Decimal>,
C<LowerRoman>, C<UpperRoman>, C<LowerAlpha>, C<UpperAlpha>

=head1 SEE ALSO

L<Pandoc> implements a wrapper around the pandoc executable.

L<Text.Pandoc.Definition|https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html>
contains the original definition of Pandoc document data structure in Haskell.
This module version was last aligned with pandoc-types-1.12.4.1.

=head1 AUTHOR

Jakob Voß E<lt>jakob.voss@gbv.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
