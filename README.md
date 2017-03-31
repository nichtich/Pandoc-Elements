# NAME

Pandoc::Elements - create and process Pandoc documents

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Elements.svg)](https://travis-ci.org/nichtich/Pandoc-Elements)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Elements/badge.svg)](https://coveralls.io/r/nichtich/Pandoc-Elements)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc-Elements.png)](http://cpants.cpanauthors.org/dist/Pandoc-Elements)
[![Code Climate Issue Count](https://codeclimate.com/github/nichtich/Pandoc-Elements/badges/issue_count.svg)](https://codeclimate.com/github/nichtich/Pandoc-Elements)

# SYNOPSIS

The output of this script `hello.pl`

    use Pandoc::Elements;
    use JSON;

    print Document(
        {
            title => MetaInlines [ Str "Greeting" ]
        },
        [
            Header( 1, attributes { id => 'top' }, [ Str 'Hello' ] ),
            Para [ Str 'Hello, world!' ],
        ],
        api_version => '1.17.0.4'
    )->to_json;

can be converted for instance to HTML via

    ./hello.pl | pandoc -f json -t html5 --standalone

an equivalent Pandoc Markdown document would be

    % Greeting
    # Gruß {.de}
    Hello, world!

# DESCRIPTION

Pandoc::Elements provides utility functions to parse, serialize, and modify
abstract syntax trees (AST) of [Pandoc](http://pandoc.org/) documents. Pandoc
can convert this data structure to many other document formats, such as HTML,
LaTeX, ODT, and ePUB.

See also module [Pandoc::Filter](https://metacpan.org/pod/Pandoc::Filter), command line script [pod2pandoc](https://metacpan.org/pod/pod2pandoc), and the
internal modules [Pandoc::Walker](https://metacpan.org/pod/Pandoc::Walker) and [Pod::Simple::Pandoc](https://metacpan.org/pod/Pod::Simple::Pandoc).

# PANDOC VERSIONS

The Pandoc document model is defined in file
[Text.Pandoc.Definition](https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html)
as part of Haskell package
[pandoc-types](https://hackage.haskell.org/package/pandoc-types).

Pandoc::Elements is compatible with pandoc-types 1.12.3 (released with pandoc
1.12.1) up to _at least_ pandoc-types-1.17.0.4 (first releases with pandoc
1.18). JSON output of all pandoc releases since 1.12.1 can be parsed with
function `pandoc_json`, the ["Document"](#document) constructor or method `parse` of
module [Pandoc](https://metacpan.org/pod/Pandoc). The AST is always upgraded to pandoc-types 1.17 and
downgraded to another api version on serialization with `to_json`.

To determine the api version required by a version of pandoc executable since
version 1.18 execute pandoc with the `--version` option and check which
version of the `pandoc-types` library pandoc was compiled with.

Beginning with version 1.18 pandoc will not decode a JSON AST representation
unless the major and minor version numbers (Document method `api_version`)
match those built into that version of pandoc. The following changes in pandoc
document model have been implemented:

- pandoc-types 1.17, released for pandoc 1.18, introduced the
[LineBlock](#lineblock) element and modified representation
of the root [Document](#document) element.
- pandoc-types 1.16, released with pandoc 1.16, introduced attributes to [Link](#link) and [Image](#image) elements
- pandoc-types 1.12.3, released with pandoc 1.12.1, modified the representation
of elements to objects with field `t` and `c`. This is also the internal
representation of documents used in this module.

# FUNCTIONS

The following functions and keywords are exported by default:

- Constructors for all Pandoc document element ([block elements](#block-elements)
such as `Para` and [inline elements](#inline-elements) such as `Emph`,
[metadata elements](#metadata-elements) and the [Document](#document-element)).
- [Type keywords](#type-keywords) such as `Decimal` and `LowerAlpha` to be used
as types in other document elements.
- The following helper functions `pandoc_json`, `pandoc_version`,
`attributes`, `metadata`, `citation`, and `element`.

## pandoc\_json $json

Parse a JSON string, as emitted by pandoc in JSON format. This is the reverse
to method `to_json` but it can read both old (before Pandoc 1.16) and new
format.

## attributes { key => $value, ... }

Maps a hash reference or instance of [Hash::MultiValue](https://metacpan.org/pod/Hash::MultiValue) into the internal
structure of Pandoc attributes. The special keys `id` (string), and `class`
(string or array reference with space-separated class names) are recognized.
See [attribute methods](#attribute-methods) for details.

## citation { ... }

A citation as part of document element [Cite](#cite) must be a hash reference
with fields `citationID` (string), `citationPrefix` (list of [inline
elements](#inline-elements)) `citationSuffix` (list of [inline
elements](#inline-elements)), `citationMode` (one of `NormalCitation`,
`AuthorInText`, `SuppressAuthor`), `citationNoteNum` (integer), and
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

## pandoc\_version( \[ $document \] )

Return a [Pandoc::Version](https://metacpan.org/pod/Pandoc::Version) object with expected version number of pandoc
executable to be used for serializing documents with [to\_json](#to_json).

If a [Document element](#document-element) is given as argument, the minimal
pandoc release version compatible with its api version is returned.

Without argument, package variable `$PANDOC_VERSION` is checked for a
preferred pandoc release. By default this variable is set from an environment
variable of same name. If no preferred pandoc release has been specified, the
function returns version 1.18 because this is the first pandoc release
compatible with most recent api version supported by this module.

See also method `version` of module [Pandoc](https://metacpan.org/pod/Pandoc) to get the current version of
pandoc executable on your system.

## element( $name => $content )

Create a Pandoc document element of arbitrary name. This function is only
exported on request.

# ELEMENTS AND METHODS

Document elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format `json`. This JSON structure is
subject to minor changes between [versions of pandoc](#pandoc_version).  All
elements are blessed objects that provide [common element methods](#common-methods) (all elements), [attribute methods](#attribute-methods) (elements with
attributes), and additional element-specific methods.

## COMMON METHODS

### to\_json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->canonical->convert_blessed->encode($element);

The serialization format can be adjusted to different [pandoc versions](#pandoc-versions) with module and environment variable `PANDOC_VERSION` or with
Document element properties `api_version` and `pandoc_version`.

When writing filters you can normally just rely on the api version value
obtained from pandoc, since pandoc expects to receive the same JSON format as
it emits.

### name

Return the name of the element, e.g. "Para" for a [paragraph element](#para).

### content

Return the element content. For most elements ([Para](#para), [Emph](#emph),
[Str](#str)...) the content is an array reference with child elements. Other
elements consist of multiple parts; for instance the [Link](#link) element has
attributes (`attr`, `id`, `class`, `classes`, `keyvals`) a link text
(`content`) and a link target (`target`) with `url` and `title`.

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

## ATTRIBUTE METHODS

Some elements have attributes which can be an identifier, ordered class names
and ordered key-value pairs. Elements with attributes provide the following
methods:

### attr

Get or set the attributes in Pandoc internal structure:

    [ $id, [ @classes ], [ [ key => $value ], ... ] ]

See helper function [attributes](#attributes-key-value) to create this
structure.

### keyvals

Get all attributes (id, class, and key-value pairs) as new [Hash::MultiValue](https://metacpan.org/pod/Hash::MultiValue)
instance, or replace _all_ key-value pairs plus id and/or class if these are
included as field names. All class fields are split by whitespaces.

    $e->keyvals                           # return new Hash::MultiValue
    $e->keyvals( $HashMultiValue )        # update by instance of Hash::MultiValue
    $e->keyvals( key => $value, ... )     # update by list of key-value pairs
    $e->keyvals( \%hash )                 # update by hash reference
    $e->keyvals( { } )                    # remove all key-value pairs
    $e->keyvals( id => '', class => '' )  # remove all key-value pairs, id, class

### id

Get or set the identifier. See also [Pandoc::Filter::HeaderIdentifiers](https://metacpan.org/pod/Pandoc::Filter::HeaderIdentifiers) for
utility functions to handle [Header](#header) identifiers.

### class

Get or set the list of classes, separated by whitespace.

### add\_attribute( $name => $value )

Append an attribute. The special attribute names `id` and `class` set or
append identifier or class, respectively.

## DOCUMENT ELEMENT

### Document

Root element, consisting of metadata hash (`meta`), document element array
(`content`=`blocks`) and optional `api_version`. The constructor accepts
either two arguments and an optional named parameter `api_version`:

    Document { %meta }, [ @blocks ], api_version => $version_string

or a hash with three fields for metadata, document content, and an optional
pandoc API version:

    {
        meta               => { %metadata },
        blocks             => [ @content ],
        pandoc-api-version => [ $major, $minor, $revision ]
    }

The latter form is used as pandoc JSON format since pandoc release 1.18. If no
api version is given, it will be set 1.17 which was also introduced with pandoc
release 1.18.

A third ("old") form is accepted for compatibility with pandoc JSON format
before release 1.18 and since release 1.12.1: an array with two elements for
metadata and document content respectively.

    [ { unMeta => { %meta } }, [ @blocks ] ]

The api version is set to 1.16 in this case, but older versions down to 1.12.3
used the same format.

Document elements provide the following special methods in addition to
[common element methods](#common-methods):

- **api\_version( \[ $api\_version \] )**

    Return the pandoc-types version (aka "pandoc-api-version") of this document as
    [Pandoc::Version](https://metacpan.org/pod/Pandoc::Version) object or sets it to a new value. This
    version determines how method [to\_json](#to_json) serializes the document.

    See ["PANDOC VERSIONS"](#pandoc-versions) for details.

- **pandoc\_version( \[ $pandoc\_version \] )**

    Return the minimum required version of pandoc executable compatible
    with the api\_version of this document. The following are equivalent:

        $doc->pandoc_version;
        pandoc_version( $doc );

    If used as setter, sets the api version of this document to be compatible with
    the given pandoc version.

- **content** or **blocks**

    Get or set the array of [block elements](#block-elements) of the
    document.

- **meta( \[ $metadata \] )**

    Get and/or set document [metadata elements](#metadata-elements).

- **metavalue( \[ $field \] )**

    Shortcut for `meta->value`.

- **to\_pandoc( \[ \[ $pandoc, \] @arguments \])**

    Process the document with [Pandoc](https://metacpan.org/pod/Pandoc) executable and return its output:

        $doc->to_pandoc( -o => 'doc.html' );
        my $markdown = $doc->to_pandoc( -t => 'markdown' );

    The first argument can optionally be an instance of [Pandoc](https://metacpan.org/pod/Pandoc) to use a specific
    executable.

- **to\_...( \[ @arguments \] )**

    Process the document into `markdown` (pandoc's extended Markdown), `latex`
    (LaTeX), `html` (HTML), `rst` (reStructuredText), or `plain` (plain text).
    The following are equivalent:

        $doc->to_markdown( @args );
        $doc->to_pandoc( @args, '-t' => 'markdown' );

- **outline( \[ $depth \] )**

    Returns an outline of the document structure based on [Header](#header)
    elements. The outline is a hierarchical hash reference with the following
    fields:

    - header

        [Header](#header) element (not included at the document root)

    - blocks

        List of [block elements](#block-elements) before the next [Header](#header)
        element (of given depth or less if a maximum depth was given)

    - sections

        List of subsections, each having the same outline structure.

## BLOCK ELEMENTS

### BlockQuote

Block quote, consisting of a list of [blocks](#block-elements) (`content`)

    BlockQuote [ @blocks ]

### BulletList

Unnumbered list of items (`content`=`items`), each a list of
[blocks](#block-elements)

    BulletList [ [ @blocks ] ]

### CodeBlock

Code block (literal string `content`) with attributes (`attr`, `id`,
`class`, `classes`, `keyvals`)

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
(`attr`, `id`, `class`, `classes`, `keyvals`).

    Div $attributes, [ @blocks ]

### Header

Header with `level` (integer), attributes (`attr`, `id`, `class`,
`classes`, `keyvals`), and text (`content`, a list of [inlines](#inline-elements)).

    Header $level, $attributes, [ @inlines ]

### HorizontalRule

Horizontal rule

    HorizontalRule

### LineBlock

List of lines (`content`), each a list of [inlines](#inline-elements).

    LineBlock [ @lines ]

This element was added in pandoc 1.18. Before it was represented [Para](#para)
elements with embedded [LineBreak](#linebreak) elements. This old serialization
form can be enabled by setting `$PANDOC_VERSION` package variable to a lower
version number.

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
(`content`). See helper function [citation](#citation) to construct
citations.

    Cite [ @citations ], [ @inlines ]

### Code

Inline code, a literal string (`content`) with attributes (`attr`, `id`,
`class`, `classes`, `keyvals`)

    Code attributes { %attr }, $content

### Emph

Emphasized text, a list of [inlines](#inline-elements) (`content`).

    Emph [ @inlines ]

### Image

Image with alt text (`content`, a list of [inlines](#inline-elements)) and
`target` (list of `url` and `title`) with attributes (`attr`, `id`,
`class`, `classes`, `keyvals`).

    Image attributes { %attr }, [ @inlines ], [ $url, $title ]

Serializing the attributes is disabled in api version less then 1.16.

### LineBreak

Hard line break

    LineBreak

### Link

Hyperlink with link text (`content`, a list of [inlines](#inline-elements))
and `target` (list of `url` and `title`) with attributes (`attr`, `id`,
`class`, `classes`, `keyvals`).

    Link attributes { %attr }, [ @inlines ], [ $url, $title ]

Serializing the attributes is disabled in api version less then 1.16.

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

### SoftBreak

Soft line break

    SoftBreak

This element was added in pandoc 1.16 as a matter of editing convenience to
preserve line breaks (as opposed to paragraph breaks) from input source to
output. If you are going to feed a document containing `SoftBreak` elements to
Pandoc < 1.16 you will have to set the package variable or environment
variable `PANDOC_VERSION` to 1.15 or below.

### Space

Inter-word space

    Space

### Span

Generic container of [inlines](#inline-elements) (`content`) with attributes
(`attr`, `id`, `class`, `classes`, `keyvals`).

    Span attributes { %attr }, [ @inlines ]

### Str

Plain text, a string (`content`).

    Str $content

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

See [Pandoc::Metadata](https://metacpan.org/pod/Pandoc::Metadata) for documentation.

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

Perl module [Pandoc](https://metacpan.org/pod/Pandoc) implements a wrapper around the pandoc executable.

Similar libraries in other programming languages are listed at [https://github.com/jgm/pandoc/wiki/Pandoc-wrappers-and-interfaces](https://github.com/jgm/pandoc/wiki/Pandoc-wrappers-and-interfaces).

# AUTHOR

Jakob Voß <jakob.voss@gbv.de>

# CONTRIBUTORS

Benct Philip Jonsson <bpjonsson@gmail.com>

# COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.
