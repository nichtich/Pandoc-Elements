#!/usr/bin/env perl
use strict;
use Pandoc::Filter;
use Pandoc::Filter::CodeImage::plantuml;

pandoc_filter CodeBlock => Pandoc::Filter::CodeImage::plantuml->new;

=head1 NAME

plantuml - process code blocks with C<.plantuml> into images with PlantUML

=head1 SEE ALSO

L<http://plantuml.com/>

=cut
