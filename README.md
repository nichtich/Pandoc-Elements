# NAME

Pandoc::Elements - utility functions to create Pandoc documents

# SYNOPSIS

The output of this script `hello.pl`

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

# DESCRIPTION

Pandoc::Elements provides utility functions to create an abstract syntax trees
(AST) of [Pandoc](http://johnmacfarlane.net/pandoc/) documents. The resulting
data structure can be processed by pandoc to be converted an many other
document formats, such as HTML, LaTeX, ODT, and ePUB. 

A future versions of this module may upgrade the data structures to blessed
objects, so better encode JSON as following:

    JSON->new->utf8->allow_blessed->convert_blessed->encode($document);

# FUNCTIONS

# BLOCK ELEMENTS

BlockQuote, BulletList, CodeBlock, DefinitionList, Div, Header, HorizontalRule,
Null, OrderedList, Para, Plain, RawBlock, Table

## INLINE ELEMENTS

Cite, Code, Emph, Image, LineBreak, Link, Math, Note, Quoted, RawInline,
SmallCaps, Space, Span, Str, Strikeout, Strong, Subscript, Superscript

## METADATA ELEMENTS

MetaBlocks, MetaBool, MetaInlines, MetaList, MetaMap, MetaString

## Document

Root element, consisting of metadata hash and document element array.

## attributes

Maps a hash reference into an attributes list with id, classes, and ordered
key-value pairs.

# AUTHOR

Jakob Voß <jakob.voss@gbv.de>

# COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

See [Text.Pandoc.Definition](https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html)
for the original definition of Pandoc document data structure in Haskell.

See [Pandoc::Filter](https://metacpan.org/pod/Pandoc::Filter) for a module to implement [pandoc
filters](http://johnmacfarlane.net/pandoc/scripting.html).
