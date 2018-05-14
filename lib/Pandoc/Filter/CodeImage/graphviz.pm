package Pandoc::Filter::CodeImage::graphviz;
use strict;
use parent 'Pandoc::Filter::CodeImage';

sub config {
    return {
        from => 'dot',
        to   => sub { $_[0] eq 'latex' ? 'pdf' : 'png' },
        run  => [ 'dot', '-T$to$', '-o$outfile$', '$infile$' ],
    };
}

1;

=head1 NAME

Pandoc::Filter::CodeImage::graphviz - create images with GraphViz

=head1 DESCRIPTION

This L<Pandoc::Filter::CodeImage> filter transforms code blocks with class
C<graphviz> into graphviz-generated images. Attribute C<option=-K...> can be
used to select layout engine (C<dot> by default).

=head1 SEE ALSO

This is an extended port of
L<graphviz.py|https://github.com/jgm/pandocfilters/blob/master/examples/graphviz.py>
from Python to Perl with L<Pandoc::Elements> and L<Pandoc::Filter>.

=cut
