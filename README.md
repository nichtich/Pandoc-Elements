# NAME

Pandoc::Elements - create and process Pandoc documents

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Elements.png)](https://travis-ci.org/nichtich/Pandoc-Elements)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Elements/badge.png)](https://coveralls.io/r/nichtich/Pandoc-Elements)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc-Elements.png)](http://cpants.cpanauthors.org/dist/Pandoc-Elements)

# SYNOPSIS

The output of this script `hello.pl`

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

# DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of [Pandoc](http://pandoc.org/) documents. Pandoc can convert the
resulting data structure to many other document formats, such as HTML, LaTeX,
ODT, and ePUB. 

Please make sure to use at least Pandoc 1.12 when processing documents

See also module [Pandoc::Filter](https://metacpan.org/pod/Pandoc::Filter), command line scripts [pandocwalk](https://metacpan.org/pod/pandocwalk) and
[pod2pando](https://metacpan.org/pod/pod2pando), and the internal modules [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker) and
[Pandoc::Filter::Lazy](https://metacpan.org/pod/Pandoc::Filter::Lazy).

## EXPORTED FUNCTIONS

The following functions and keywords are exported by default:

- Constructors for all Pandoc document element ([block elements](#block-elements)
such as `Para` and [inline elements](#inline-elements) such as `Emph`,
[metadata elements](#metadata-elements) and the ["Document" in DOCUMENT ELEMENT](https://metacpan.org/pod/DOCUMENT&#x20;ELEMENT#Document)).
- [Type keywords](#type-keywords) such as `Decimal` and `LowerAlpha` to be used
as types in other document elements.
- The helper following functions `pandoc_json`, `attributes`, `citation`, and
`element`.

### pandoc\_json $json

Parse a JSON string, as emitted by pandoc in JSON format. This is the reverse
to method `to_json`.

### attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs. The special keys `id` and `classes` are recognized but
setting multi-value attributes or controlled order is not supported with this
function. You can always manually create an attributes structure:

    [ $id, [ @classes ], [ key => $value, ... ] ]

Elements with attributes (element accessor method `attr`) also provide the
accessor method `id`, `classes`, and `class`. See [Hash::MultiValue](https://metacpan.org/pod/Hash::MultiValue) for
easy access to key-value-pairs.

### citation { ... }

A citation as part of document element [Cite](#cite) must be a hash reference
with fields `citationID` (string), `citationPrefix` (list of [inline
elements](#inline-elements)) `citationSuffix` (list of [inline
elements](#inline-elements)), `citationMode` (one of `NormalCitation`,
C>AuthorInText>, `SuppressAuthor`), `citationNoteNum` (integer), and
`citationHash` (integer). The helper method `citation` can be used to
construct such hash by filling in default values and using shorter field names
(`id`, `prefix`, `suffix`, `mode`, `note`, and `hash`):

    citation { 
        id => 'foo', 
        prefix => [ Str "see" ], 
        suffix => [ Str "p.", Space, Str "42" ]
    }

    # in Pandoc Markdown

    [see @foo p. 42]

### element( $name => $content )

Create a Pandoc document element of arbitrary name. This function is only
exported on request.

# ELEMENTS 

Document elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format `json`. All elements are blessed
objects that provide the following element methods and additional accessor
methods specific to each element.

## ELEMENT METHODS

### to\_json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->convert_blessed->encode($element);

### name

Return the name of the element, e.g. "Para" for a [paragraph element](#para).

### content

Return the element content. For most elements ([Para](#para), [Emph](#emph),
[Str](#str)...) the content is an array reference with child elements. Other
elements consist of multiple parts; for instance the [Link](#link) element has
a link text (`content`) and a link target (`target`) with `url` and
`title`.

### is\_block

True if the element is a [Block element](#block-elements)

### is\_inline

True if the element is an inline [Inline element](#inline-elements)

### is\_meta

True if the element is a [Metadata element](#metadata-elements)

### is\_document

True if the element is a [Document element](#document-element)

### walk(...)

Walk the element tree with [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker)

### query(...)

Query the element to extract results with [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker)

### transform(...)

Transform the element tree with [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker)

### string

Returns a concatenated string of element content, leaving out all formatting.

## BLOCK ELEMENTS

### BlockQuote

Block quote, consisting of a list of [blocks](#block-elements) (`content`)

    BlockQuote [ @blocks ]

### BulletList

Unnumbered list of items (`content`=`items`), each a list of
[blocks](#block-elements)

    BulletList [ [ @blocks ] ]

### CodeBlock

Code block (literal string `content`) with attributes (`attr`)

    CodeBlock $attributes, $content

### DefinitionList

Definition list, consisting of a list of pairs (`content`=`items`),
each a term (`term`, a list of [inlines](#inline-elements)) and one
or more definitions (`definitions`, a list of [blocks](#block-elements)).

    DefinitionList [ @definitions ]

    # each item in @definitions being a pair of the form

        [ [ @inlines ], [ @blocks ] ]

### Div

Generic container of [blocks](#block-elements) (`content`) with attributes
(`attr`).

    Div $attributes, [ @blocks ]

### Header

Header with `level` (integer), attributes (`attr`), and text (`content`, a
list of [inlines](#inline-elements)).

    Header $level, $attributes, [ @inlines ]

### HorizontalRule

Horizontal rule

    HorizontalRule 

### Null

Nothing

    Null

### OrderedList

Numbered list of items (`content`=`items`), each a list of [blocks](#block-elements)), preceded by list attributes (start number, numbering style, and
delimiter).

    OrderedList [ $start, $style, $delim ], [ [ @blocks ] ]

Supported styles are `DefaultStyle`, `Example`, `Decimal`, `LowerRoman`,
`UpperRoman`, `LowerAlpha`, and `UpperAlpha`.

Supported delimiters are `DefaultDelim`, `Period`, `OneParen`, and
`TwoParens`.

### Para

Paragraph, consisting of a list of [Inline elements](#inline-elements)
(`content`).

    Para [ $elements ]

### Plain

Plain text, not a paragraph, consisting of a list of [Inline elements](#inline-elements) (`content`).

    Plain [ @inlines ]

### RawBlock

Raw block with `format` and `content` string.

    RawBlock $format, $content

### Table

Table, with `caption`, column `alignments`, relative column `widths` (0 =
default), column `headers` (each a list of [blocks](#block-elements)), and
`rows` (each a list of lists of [blocks](#block-elements)).

    Table [ @inlines ], [ @alignments ], [ @width ], [ @headers ], [ @rows ]

Possible alignments are `AlignLeft`, `AlignRight`, `AlignCenter`, and
`AlignDefault`.

An example:

    Table [Str "Example"], [AlignLeft,AlignRight], [0.0,0.0],
     [[Plain [Str "name"]]
     ,[Plain [Str "number"]]],
     [[[Plain [Str "Alice"]]
      ,[Plain [Str "42"]]]
     ,[[Plain [Str "Bob"]]
      ,[Plain [Str "23"]]]];

## INLINE ELEMENTS

### Cite

Citation, a list of `citations` and a list of [inlines](#inline-elements)
(`content`).  See helper function ["citation" in citation](https://metacpan.org/pod/citation#citation) to construct citations.

    Cite [ @citations ], [ @inlines ]

### Code

Inline code, a literal string (`content`) with attributes (`attr`)

    Code attributes { %attr }, $content

### Emph

Emphasized text, a list of [inlines](#inline-elements) (`content`).

    Emph [ @inlines ]

### Image

Image with alt text (`content`, a list of [inlines](#inline-elements)) and
`target` (list of `url` and `title`).

    Image [ @inlines ], [ $url, $title ]

### LineBreak

Hard line break

    LineBreak

### Link

Hyperlink with link text (`content`, a list of [inlines](#inline-elements))
and `target` (list of `url` and `title`).

    Link [ @inlines ], [ $url, $title ]

### Math

TeX math, given as literal string (`content`) with `type` (one of
`DisplayMath` and `InlineMath`).

    Math $type, $content

### Note

Footnote or Endnote, a list of [blocks](#block-elements) (`content`).

    Note [ @blocks ]

### Quoted

Quoted text with quote `type` (one of `SingleQuote` and `DoubleQuote`) and a
list of [inlines](#inline-elements) (`content`).

    Quoted $type, [ @inlines ]

### RawInline

Raw inline with `format` (a string) and `content` (a string).

    RawInline $format, $content

### SmallCaps

Small caps text, a list of [inlines](#inline-elements) (`content`).

    SmallCaps [ @inlines ]

### Space

Inter-word space

    Space

### Span

Generic container of [inlines](#inline-elements) (`content`) with attributes
(`attr`).

    Span attributes { %attr }, [ @inlines ]

### Str

Plain text, a string (`content`).

    Str $text

### Strikeout

Strikeout text, a list of [inlines](#inline-elements) (`content`).

    Strikeout [ @inlines ]

### Strong

Strongly emphasized text, a list of [inlines](#inline-elements) (`content`).

    Strong [ @inlines ]

### Subscript

Subscripted text, a list of [inlines](#inline-elements) (`content`).

    Supscript [ @inlines ]

### Superscript

Superscripted text, a list of [inlines](#inline-elements) (`content`).

    Superscript [ @inlines ]

## METADATA ELEMENTS

### MetaBlocks

### MetaBool

### MetaInlines

### MetaList

### MetaMap

### MetaString

## DOCUMENT ELEMENT

### Document

Root element, consisting of metadata hash (`meta`) and document element array
(`content`).

    Document $meta, [ @blocks ]

## TYPE KEYWORDS

The following document elements are only as used as type keywords in other
document elements:

- `SingleQuote`, `DoubleQuote`
- `DisplayMath`, `InlineMath`
- `AuthorInText`, `SuppressAuthor`, `NormalCitation` 
- `AlignLeft`, `AlignRight`, `AlignCenter`, `AlignDefault` 
- `DefaultStyle`, `Example`, `Decimal`, `LowerRoman`, `UpperRoman`,
`LowerAlpha`, `UpperAlpha`
- `DefaultDelim`, `Period`, `OneParen`, `TwoParens`

# SEE ALSO

[Pandoc](https://metacpan.org/pod/Pandoc) implements a wrapper around the pandoc executable.

[Text.Pandoc.Definition](https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html)
contains the original definition of Pandoc document data structure in Haskell.
This module version was last aligned with pandoc-types-1.12.4.

# AUTHOR

Jakob Voß <jakob.voss@gbv.de>

# COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.
