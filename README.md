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
(AST) of [Pandoc](http://johnmacfarlane.net/pandoc/) documents. The resulting
data structure can be processed by pandoc to be converted an many other
document formats, such as HTML, LaTeX, ODT, and ePUB. 

See also module [Pandoc::Filter](https://metacpan.org/pod/Pandoc::Filter) and [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker) for processing the AST
in Perl.

## FUNCTIONS

In addition to constructor functions for each document element, the following
functions are exported.

### attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

### element( $name => $content )

Create a Pandoc document element. This function is only exported on request.

# ELEMENTS 

AST elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format `json`. All elements are blessed
objects that provide the following methods. Additional accessor methods for
particular elements are listed below at each element.

## ELEMENT METHODS

## json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->convert_blessed->encode($element);

## name

Return the name of the element, e.g. "Para"

## value

Return the full element content as array reference. You may better use one of
the specific accessor methods or the content method.

## content

Return the element content. For many elements (Para, Emph, Str...) this is
equal to the value, but if elements consist of multiple parts, the content is a
subset of the value. For instance the Link element consists a link text
(content) and a link target (target).

## is\_block

True if the element is a [Block element](#block-elements)

## is\_inline

True if the element is an inline [Inline element](#inline-elements)

## is\_meta

True if the element is a [Metadata element](#metadata-elements)

## is\_document

True if the element is a [Document element](#document-element)

## BLOCK ELEMENTS

### BlockQuote

Block quote, consisting of a list of [blocks](#block-elements) (`content`)

### BulletList

...

### CodeBlock

...

### DefinitionList

...

### Div

Generic container of [blocks](#block-elements) (`content`) with attributes
(`attrs`)

### Header

### HorizontalRule

Horizontal rule

### Null

Nothing

### OrderedList

...

### Para

Paragraph, consisting of a list of [Inline elements](#inline-elements)
(`content`).

### Plain

Plain text, not a paragraph, consisting of a list of [Inline elements](#inline-elements) (`content`).

### RawBlock

Raw block with `format` and `content` string.

### Table

Table, with `caption`, column `alignments`, relative column `widths` (0 =
default), column `headers` (each a list of [blocks](#block-elements)), and
`rows` (each a list of lists of [blocks](#block-elements)).

## INLINE ELEMENTS

### Cite

### Code

### Emph

### Image

### LineBreak

### Link

### Math

### Note

### Quoted

### RawInline

### SmallCaps

### Space

### Span

### Str

### Strikeout

### Strong

### Subscript

### Superscript

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

## TYPES

The following elements are used as types only: DefaultDelim Period OneParen
TwoParens SingleQuote DoubleQuote DisplayMath InlineMath AuthorInText
SuppressAuthor NormalCitation AlignLeft AlignRight AlignCenter AlignDefault
DefaultStyle Example Decimal LowerRoman UpperRoman LowerAlpha UpperAlpha

# SEE ALSO

[Pandoc](https://metacpan.org/pod/Pandoc) implements a wrapper around the pandoc executable.

[Text.Pandoc.Definition](https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html)
contains the original definition of Pandoc document data structure in Haskell.

# AUTHOR

Jakob Voß <jakob.voss@gbv.de>

# COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.
