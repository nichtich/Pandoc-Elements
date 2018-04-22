#!/usr/bin/env perl
use strict;
use 5.010001;
use Pandoc::Filter;
use Pandoc::Filter::ImagesFromCode;

pandoc_filter 'CodeBlock.plantuml' => Pandoc::Filter::ImagesFromCode->new(
    from => 'puml',
    to   => sub { $_[0] eq 'latex' ? 'eps' : 'svg' },
    name => sub {
		state $counter = 0;
		$counter++;
		return $_[0]->content =~ qr/^\@startuml[ \t]+(.+)$/m
            ? $1 : "plantuml-$counter";
    },
    run  => [ qw(plantuml -T$to$ -o . $infile$) ],
);

=head1 NAME

plantuml - process code blocks with C<.plantuml> into images with PlantUML

=head1 SEE ALSO

L<http://plantuml.com/>

=cut
