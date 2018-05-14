#!/usr/bin/env perl
use strict;

use Pandoc::Filter;
use Pandoc::Filter::CodeImage::ditaa;

pandoc_filter CodeBlock => Pandoc::Filter::CodeImage::ditaa->new;

__END__

=head1 NAME

ditaa - process code blocks with C<.ditaa> into images

=head1 SYNOPSIS

  pandoc --filter ditaa.pl -o output.html < input.md

=cut
