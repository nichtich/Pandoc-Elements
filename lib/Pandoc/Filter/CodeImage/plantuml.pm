package Pandoc::Filter::CodeImage::plantuml;
use v5.10;
use strict;
use parent 'Pandoc::Filter::CodeImage';

sub config {
    {
        from => 'puml',
        to   => sub { $_[0] eq 'latex' ? 'eps' : 'svg' },
        run  => [qw(plantuml -T$to$ -o . $infile$)],
        name => {
            state $counter = 0;
            $counter++;

            # NOTE: name provided in first line may contain any kinds of characters!
            return $1 if $_[0]->content =~ qr/^\@startuml[ \t]+(.+)$/m;
            return $_[0]->id if $_[0]->id =~ /^[a-z0-9_]+$/i;
            return "plantuml-$counter";

        }
    };
}

1;

=head1 NAME
 
Pandoc::Filter::CodeImage::plantuml - create images with PlantUML

=head1 DESCRIPTION

This L<Pandoc::Filter::CodeImage> filter transforms code blocks with class
C<.plantuml> into images with L<PlantUML|http://plantuml.com/>. Image files can
be specified at the first line of plantuml code or with the id attribute.
Otherwise files are numbered starting with C<plantuml-1.puml>.

=cut
