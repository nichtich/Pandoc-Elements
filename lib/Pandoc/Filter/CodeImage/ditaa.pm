package Pandoc::Filter::CodeImage::ditaa;
use strict;
use parent 'Pandoc::Filter::CodeImage';

sub config {
    return {
        from => 'ditaa',
        to   => 'png',
        run  => [ 'ditaa', '-o', '$infile$', '$outfile$' ]
    };
}

1;

=head1 NAME

Pandoc::Filter::CodeImage::ditaa - create images with ditaa

=head1 DESCRIPTION

This L<Pandoc::Filter::CodeImage> filter transforms code blocks with class
C<.ditaa> into images with ditaa.

=head1 LIMITATIONS

The current version always creates bitmap images. A later version might create
vector images with ditaa-eps for output formats such as PDF.

=head1 SEE ALSO

This is a rewrite of the standalone-script C<mdddia> originally published at
L<https://github.com/nichtich/ditaa-markdown>.

=cut
