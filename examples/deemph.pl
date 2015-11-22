#!/usr/bin/env perl
use strict;

=head1 DESCRIPTION

Pandoc filter that causes emphasized text to be displayed in ALL CAPS. 

=cut

use Pandoc::Filter;
use Pandoc::Elements qw(Str);

pandoc_filter Emph => sub {
    $_[0]->transform( Str => sub { Str(uc($_[0]->content)) });
#    $_[0];
};

=head1 SYNOPSIS

  pandoc --filter deemph.pl -o output.html < input.md

=head1 SEE ALSO

This is a port of
L<deemph.py|https://github.com/jgm/pandocfilters/blob/master/examples/deemph.py>
from Python to Perl with L<Pandoc::Elements> and L<Pandoc::Filter>.

=cut
