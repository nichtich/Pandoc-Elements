#!/usr/bin/env perl
use strict;

=head1 NAME

graphviz - process code blocks with C<.graphviz> into images

=head1 DESCRIPTION

Pandoc filter to process code blocks with class "graphviz" into
graphviz-generated images. Attribute "graphviz-layout" can be used to select
layout engine (dot by default).

=cut

use Pandoc::Filter;
use Pandoc::Elements;
use IPC::Run3;
use Digest::MD5 'md5_hex';

pandoc_filter 'CodeBlock.graphviz' => sub {
    my ($e, $f, $m) = @_;

    my $ext = $f eq 'latex' ? 'pdf' : 'png';
    
    my $dot = $e->content;

    my $dir = "."; # TODO: configure
    my $filename = "$dir/".md5_hex($e->content).".$ext";
    my $layout = $e->keyvals->get('graphviz-layout') || 'dot';
    $layout = 'dot' unless $layout =~ /^(dot|neato|twopi|circo|fdp)$/;

    my ($stderr, $stdout);
    run3 [$layout, "-T$ext", "-o$filename"],
			\$dot, \$stdout, \$stderr,
			{
				binmode_stdin  => ':utf8',
				binmode_stdout => ':raw',
				binmode_stderr => ':raw',
			};

    # TODO: include $dot on error in debug mode
    # TODO: skip error if requested
	die $stderr if $stderr;

    # TODO: refactor this helper function
    my $img = build_image($e, $filename);

    return Para [ $img ];
};

=head1 SYNOPSIS

  pandoc --filter graphviz.pl -o output.html < input.md

=head1 SEE ALSO

This is an extended port of
L<graphviz.py|https://github.com/jgm/pandocfilters/blob/master/examples/graphviz.py>
from Python to Perl with L<Pandoc::Elements> and L<Pandoc::Filter>.

=cut
