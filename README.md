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

# ELEMENT METHODS 

AST elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format `json`. All elements are blessed
objects in the `Pandoc::AST::` namespace, for instance `Pandoc::AST::Para`
for paragraph elements. 

## json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->convert_blessed->encode($element);

## is\_block

True if the element is a [Block element](#block-elements)

## is\_inline

True if the element is an inline [Inline element](#inline-elements)

## is\_meta

True if the element is a [Metadata element](#metadata-elements)

## is\_document

True if the element is a [Document element](#document-element)

# FUNCTIONS

## BLOCK ELEMENTS

### BlockQuote

### BulletList

### CodeBlock

### DefinitionList

### Div

### Header

### HorizontalRule

### Null

### OrderedList

### Para

### Plain

### RawBlock

### Table

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

Root element, consisting of metadata hash and document element array.

## ADDITIONAL FUNCTIONS

### attributes { key => $value, ... }

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

### element( $name => $content )

Create a Pandoc document element. This function is only exported on request.

# AUTHOR

Jakob Voß <jakob.voss@gbv.de>

# COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

See [Text.Pandoc.Definition](https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html)
for the original definition of Pandoc document data structure in Haskell.
