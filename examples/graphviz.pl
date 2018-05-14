#!/usr/bin/env perl
use strict;

use Pandoc::Filter;
use Pandoc::Filter::CodeImage::graphviz;

pandoc_filter CodeBlock => Pandoc::Filter::CodeImage::graphviz->new;

=head1 NAME

graphviz - process code blocks with C<.graphviz> into images

=head1 DESCRIPTION

Pandoc filter to process code blocks with class C<graphviz> into
graphviz-generated images. Attribute C<option=-K...> can be used to select
layout engine (C<dot> by default).

=head1 SYNOPSIS

  pandoc --filter graphviz.pl -o output.html < input.md

=cut
