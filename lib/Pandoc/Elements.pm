package Pandoc::Elements;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.09';

our %ELEMENTS = (
    # BLOCK ELEMENTS
    Plain => [ Block => 'content' ],
    Para => [ Block => 'content' ],
    CodeBlock => [ Block => qw(attr content) ],
    RawBlock => [ Block => qw(format content) ],
    BlockQuote => [ Block => 'content' ],
    OrderedList => [ Block => qw(attr content/items) ],
    BulletList => [ Block => 'content/items' ],
    DefinitionList => [ Block => 'content/items:[DefinitionPair]' ],
    Header => [ Block => qw(level attr content) ],
    HorizontalRule => [ 'Block' ],
    Table => [ Block => qw(caption alignment widths headers rows) ],
    Div => [ Block => qw(attr content) ],
    Null => [ 'Block' ],
    # INLINE ELEMENTS
    Str => [ Inline => 'content' ],
    Emph => [ Inline => 'content' ],
    Strong => [ Inline => 'content' ],
    Strikeout => [ Inline => 'content' ],
    Superscript => [ Inline => 'content' ],
    Subscript => [ Inline => 'content' ],
    SmallCaps => [ Inline => 'content' ],
    Quoted => [ Inline => qw(type content) ],
    Cite => [ Inline => qw(citations content) ],
    Code => [ Inline => qw(attr content) ],
    Space => [ 'Inline' ],
    LineBreak => [ 'Inline' ],
    Math => [ Inline => qw(type content) ],
    RawInline => [ Inline => qw(format content) ],
    Link => [ Inline => qw(content target) ],
    Image => [ Inline => qw(content target) ],
    Note => [ Inline => 'content' ],
    Span => [ Inline => qw(attr content) ],
    # METADATA ELEMENTS
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
our @EXPORT = (keys %ELEMENTS, qw(Document attributes citation pandoc_json));
our @EXPORT_OK = (@EXPORT, 'element');

# create constructor functions
foreach my $name (keys %ELEMENTS) {
    no strict 'refs'; ## no critic

    my ($parent, @accessors) = @{$ELEMENTS{$name}};
    my $numargs = scalar @accessors;
    my $class = "Pandoc::Document::$name";
    my @parents = map { "Pandoc::Document::$_" } ($parent);
    $parent = join ' ', map { "Pandoc::Document::$_" } 
        $parent, 
        map { 'AttributesRole' } grep { $_ eq 'attr' } @accessors;

    eval "package $class; our \@ISA = qw($parent);";

    *{__PACKAGE__."::$name"} = Scalar::Util::set_prototype( sub {
        croak "$name expects $numargs arguments, but given " . scalar @_
            if @_ != $numargs;
        bless { t => $name, c => (@_ == 1 ? $_[0] : \@_) }, $class;
    }, '$' x $numargs );

    for (my $i=0; $i<@accessors; $i++) {
        my $code = @accessors == 1
                 ? "\$_[0]->{c}" : "\$_[0]->{c}->[$i]";
        # auto-bless on access via accessor (TODO: move to constructor?)
        if ($accessors[$i] =~ s/:\[(.+)\]$//) {
            $code = "[ map { bless \$_, 'Pandoc::Document::$1' } \@{$code} ]";
        }
        for (split '/', $accessors[$i]) {
            *{$class."::$_"} = eval "sub { $code }";
        }
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
sub Pandoc::Document::DefinitionPair::term { $_[0]->[0] }
sub Pandoc::Document::DefinitionPair::definitions { $_[0]->[1] }

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

sub citation($) {    
    my $a = shift;
    {
        citationId => $a->{id} // "missing",
        citationPrefix => $a->{prefix} // [], 
        citationSuffix => $a->{suffix} // [], 
        citationMode => $a->{mode} // 
            bless({ t => 'NormalCitation', c => [] },
                  'Pandoc::Document::NormalCitation'),
        citationNoteNum => $a->{num} // 0,
        citationHash => $a->{hash} // 1,
    }
}

sub pandoc_json {
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
    use Pandoc::Walker ();
    sub to_json { 
        JSON->new->utf8->convert_blessed->encode($_[0])
    }
    sub TO_JSON     { return { %{$_[0]} } }    
    sub name        { $_[0]->{t} }
    sub content     { $_[0]->{c} }
    sub is_document { 0 }
    sub is_block    { 0 }
    sub is_inline   { 0 }
    sub is_meta     { 0 }
    *walk      = *Pandoc::Walker::walk;
    *query     = *Pandoc::Walker::query;
    *transform = *Pandoc::Walker::transform;
}

{
    package Pandoc::Document::AttributesRole;
    sub id { $_[0]->attr->[0] }
    sub classes { $_[0]->attr->[1] }
    sub class { join ' ', @{$_[0]->classes} }
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

See also script L<pandoc-walk> installed with this module.

=head1 DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of L<Pandoc|http://johnmacfarlane.net/pandoc/> documents. The resulting
data structure can be converted by L<Pandoc> to many other document formats,
such as HTML, LaTeX, ODT, and ePUB. 

=head2 EXPORTED FUNCTIONS

=over

=item 

Constructors for all Pandoc document element (L<block elements|/BLOCK ELEMENTS>
such as C<Para> and L<inline elements|/INLINE ELEMENTS> such as C<Emph>,
L<metadata elements|/METADATA ELEMENTS> and the L<DOCUMENT ELEMENT/Document>).

=item 

L<Type keywords|/TYPE KEYWORDS> such as C<Decimal> and C<LowerAlpha> to be used
as types in other document elements.

=item

The helper following functions C<pandoc_json>, C<attributes>, C<citation>, and
C<element>.

=back

=head3 pandoc_json( $json )

Parse a JSON string, as emitted by pandoc in JSON format. This is the reverse
to method C<to_json>.

=head3 attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs. The special keys C<id> and C<classes> are recognized but
setting multi-value attributes or controlled order is not supported with this
function. You can always manually create an attributes structure:

    [ $id, [ @classes ], [ key => $value, ... ] ]

Elements with attributes (element accessor method C<attr>) also provide the
accessor method C<id>, C<classes>, and C<class>. See L<Hash::MultiValue> for
easy access to key-value-pairs.

=head3 citation { ... }

A citation as part of document element L<Cite|/Cite> must be a hash reference
with fields C<citationID> (string), C<citationPrefix> (list of L<inline
elements|/INLINE ELEMENTS>) C<citationSuffix> (list of L<inline
elements|/INLINE ELEMENTS>), C<citationMode> (one of C<NormalCitation>,
C>AuthorInText>, C<SuppressAuthor>), C<citationNoteNum> (integer), and
C<citationHash> (integer). The helper method C<citation> can be used to
construct such hash by filling in default values and using shorter field names
(C<id>, C<prefix>, C<suffix>, C<mode>, C<note>, and C<hash>. For instance

    citation { 
        id => 'foo', 
        prefix => [ Str "see" ], 
        suffix => [ Str "p.", Space, Str "42" ]
    }

    # in Pandoc Markdown

    [see @foo p. 42]

=head3 element( $name => $content )

Create a Pandoc document element of arbitrary name. This function is only
exported on request.

=head1 ELEMENTS 

Document elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format C<json>. All elements are blessed
objects that provide the following element methods and additional accessor
methods specific to each element.

=head2 ELEMENT METHODS

=head3 to_json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->convert_blessed->encode($element);

=head3 name

Return the name of the element, e.g. "Para" for a L<paragraph element|/Para>.

=head3 content

Return the element content. For most elements (L<Para|/Para>, L<Emph|/Emph>,
L<Str|/Str>...) the content is an array reference with child elements. Other
elements consist of multiple parts; for instance the L<Link|/Link> element has
a link text (C<content>) and a link target (C<target>) with C<url> and
C<title>.

=head3 is_block

True if the element is a L<Block element|/BLOCK ELEMENTS>

=head3 is_inline

True if the element is an inline L<Inline element|/INLINE ELEMENTS>

=head3 is_meta

True if the element is a L<Metadata element|/METADATA ELEMENTS>

=head3 is_document

True if the element is a L<Document element|/DOCUMENT ELEMENT>

=head3 walk

Walk the element tree with L<Pandoc::Walker>

=head3 query

Query the element to extract results with L<Pandoc::Walker>

=head3 transform

Transform the element tree with L<Pandoc::Walker>

=head2 BLOCK ELEMENTS

=head3 BlockQuote

Block quote, consisting of a list of L<blocks|/BLOCK ELEMENTS> (C<content>)

    BlockQuote [ @blocks ]

=head3 BulletList

Unnumbered list of items (C<content>=C<items>), each a list of
L<blocks|/BLOCK ELEMENTS>

    BlockQuote [ [ @blocks ] ]

=head3 CodeBlock

Code block (literal string C<content>) with attributes (C<attr>)

    CodeBlock $attributes, $content

=head3 DefinitionList

Definition list, consisting of a list of pairs (C<content>=C<items>),
each a term (C<term>, a list of L<inlines|/INLINE ELEMENTS>) and one
or more definitions (C<definitions>, a list of L<blocks|/BLOCK ELEMENTS>).

    DefinitionList [ @definitions ]

    # each item in @definitions being a pair of the form

        [ [ @inlines ], [ @blocks ] ]

=head3 Div

Generic container of L<blocks|/BLOCK ELEMENTS> (C<content>) with attributes
(C<attr>).

    Div $attributes, [ @blocks ]

=head3 Header

Header with C<level> (integer), attributes (C<attr>), and text (C<content>, a
list of L<inlines|/INLINE ELEMENTS>).

    Header $level, $attributes, [ @inlines ]

=head3 HorizontalRule

Horizontal rule

    HorizontalRule 

=head3 Null

Nothing

    Null

=head3 OrderedList

Numbered list of items (C<content>=C<items>), each a list of L<blocks|/BLOCK
ELEMENTS>), preceded by list attributes (start number, numbering style, and
delimiter).

    OrderedList [ $start, $style, $delim ], [ [ @blocks ] ]

Supported styles are C<DefaultStyle>, C<Example>, C<Decimal>, C<LowerRoman>,
C<UpperRoman>, C<LowerAlpha>, and C<UpperAlpha>.

Supported delimiters are C<DefaultDelim>, C<Period>, C<OneParen>, and
C<TwoParens>.

=head3 Para

Paragraph, consisting of a list of L<Inline elements|/INLINE ELEMENTS>
(C<content>).

    Para [ $elements ]

=head3 Plain

Plain text, not a paragraph, consisting of a list of L<Inline elements|/INLINE
ELEMENTS> (C<content>).

    Plain [ @inlines ]

=head3 RawBlock

Raw block with C<format> and C<content> string.

    RawBlock $format, $content

=head3 Table

Table, with C<caption>, column C<alignments>, relative column C<widths> (0 =
default), column C<headers> (each a list of L<blocks|/BLOCK ELEMENTS>), and
C<rows> (each a list of lists of L<blocks|/BLOCK ELEMENTS>).

    Table [ @inlines ], [ @alignments ], [ @width ], [ @headers ], [ @rows ]

Possible alignments are C<AlignLeft>, C<AlignRight>, C<AlignCenter>, and
C<AlignDefault>.

An example:

    Table [Str "Example"], [AlignLeft,AlignRight], [0.0,0.0],
     [[Plain [Str "name"]]
     ,[Plain [Str "number"]]],
     [[[Plain [Str "Alice"]]
      ,[Plain [Str "42"]]]
     ,[[Plain [Str "Bob"]]
      ,[Plain [Str "23"]]]];

=head2 INLINE ELEMENTS

=head3 Cite

Citation, a list of C<citations> and a list of L<inlines|/INLINE ELEMENTS>
(C<content>).  See helper function L<citation/citation> to construct citations.

    Cite [ @citations ], [ @inlines ]

=head3 Code

Inline code, a literal string (C<content>) with attributes (C<attr>)

    Code attributes { %attr }, $content

=head3 Emph

Emphasized text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).
 
    Emph [ @inlines ]

=head3 Image

Image with alt text (C<content>, a list of L<inlines|/INLINE ELEMENTS>) and
C<target> (list of C<url> and C<title>).

    Image [ @inlines ], [ $url, $title ]

=head3 LineBreak

Hard line break

    LineBreak

=head3 Link

Hyperlink with link text (C<content>, a list of L<inlines|/INLINE ELEMENTS>)
and C<target> (list of C<url> and C<title>).

    Link [ @inlines ], [ $url, $title ]

=head3 Math

TeX math, given as literal string (C<content>) with C<type> (one of
C<DisplayMath> and C<InlineMath>).

    Math $type, $content

=head3 Note

Footnote or Endnote, a list of L<blocks|/BLOCK ELEMENTS> (C<content>).

    Note [ @blocks ]

=head3 Quoted

Quoted text with quote C<type> (one of C<SingleQuote> and C<DoubleQuote>) and a
list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Quoted $type, [ @inlines ]

=head3 RawInline

Raw inline with C<format> (a string) and C<content> (a string).

    RawInline $format, $content

=head3 SmallCaps

Small caps text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    SmallCaps [ @inlines ]

=head3 Space

Inter-word space

    Space

=head3 Span

Generic container of L<inlines|/INLINE ELEMENTS> (C<content>) with attributes
(C<attr>).

    Span attributes { %attr }, [ @inlines ]

=head3 Str

Plain text, a string (C<content>).

    Str $text

=head3 Strikeout

Strikeout text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Strikeout [ @inlines ]

=head3 Strong

Strongly emphasized text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Strong [ @inlines ]

=head3 Subscript

Subscripted text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Supscript [ @inlines ]

=head3 Superscript

Superscripted text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Superscript [ @inlines ]

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

    Document $meta, [ @blocks ]

=head2 TYPE KEYWORDS

The following document elements are only as used as type keywords in other
document elements:

=over

=item

C<SingleQuote>, C<DoubleQuote>

=item

C<DisplayMath>, C<InlineMath>

=item

C<AuthorInText>, C<SuppressAuthor>, C<NormalCitation> 

=item

C<AlignLeft>, C<AlignRight>, C<AlignCenter>, C<AlignDefault> 

=item

C<DefaultStyle>, C<Example>, C<Decimal>, C<LowerRoman>, C<UpperRoman>,
C<LowerAlpha>, C<UpperAlpha>

=item

C<DefaultDelim>, C<Period>, C<OneParen>, C<TwoParens>

=back

=head1 SEE ALSO

L<Pandoc> implements a wrapper around the pandoc executable.

L<Text.Pandoc.Definition|https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html>
contains the original definition of Pandoc document data structure in Haskell.
This module version was last aligned with pandoc-types-1.12.4.

=head1 AUTHOR

Jakob Voß E<lt>jakob.voss@gbv.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
