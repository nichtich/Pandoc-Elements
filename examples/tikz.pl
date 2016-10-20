#!/usr/bin/env perl
use strict;

use Pandoc::Filter;
use Pandoc::Filter::ImagesFromCode;

pandoc_filter 'CodeBlock.tikz' => Pandoc::Filter::ImagesFromCode->new(
    from    => 'tex',
    to      => sub { $_[0] eq 'latex' ? 'pdf' : 'png' },
    content => sub {
		my ($codeblock, $format, $meta) = @_;

		my $content = $codeblock->content;
		$content =~ s/^\s+//m;
		if ($content !~ /^\\begin{tikzpicture}/) {
			$content = "\\begin{tikzpicture}$content\\end{tikzpicture}";
		}

		my $convert;
		if ($format ne 'latex') { 
 			# TODO: add dpi and size
			$convert = '[convert]';
		}

		join "\n", "\\documentclass$convert\{standalone}", '\usepackage{tikz}',
			'\nofiles', 
			'\begin{document}', 
			$content,
			'\end{document}';
    },
	
	# TODO: what about error?
    run  => ['pdflatex', '-halt-on-error', '-shell-escape', '$infile$'], 
);

__END__

=head1 NAME

tikz - process latex tikzpicture environment into images

=head1 DESCRIPTION

Pandoc filter to process code blocks with tikz into images.  Assumes that
C<pdflatex> is in the path, and that the C<standalone> package with minimum
version 1.0 is available.  Also assumes that one ImageMagick's C<convert>,
C<imgconvert>, and Ghostscript's C<gs> is in the path.

=head1 SYNOPSIS

The code does not need to be enclosed in C<\begin{tikzpicture}> and 
C<\end{tikzpicture}>.

  ~~~tikz
  \node [draw] {Hello, World!};
  ~~~

Options can be passed like this

  ~~~tikz
  [font=\sffamily]
  \node [draw] {Hello, World!};
  ~~~

Or like this

  ~~~{.tikz options="font=\sffamily"}
  \node [draw] {Hello, World!};
  ~~~


=head1 LIMITATIONS

Each image is created as independent LaTeX document. Injection of additional
LaTeX code into this document, for instance add required packages is not
supported yet.

=head1 SEE ALSO

This is an improved port of
L<tikz.py|https://github.com/jgm/pandocfilters/blob/master/examples/tikz.py>
from Python to Perl with L<Pandoc::Elements> and L<Pandoc::Filter>.

=cut
