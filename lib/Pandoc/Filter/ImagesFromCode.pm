package Pandoc::Filter::ImagesFromCode;
use strict;
use warnings;
use utf8;
use Encode;
use 5.010;

our $VERSION = '0.36';

use Carp qw(croak);
use Digest::MD5 'md5_hex';
use IPC::Run3;
use File::Spec::Functions;
use File::stat;
use Pandoc::Elements;
use Pandoc;
use Scalar::Util qw(blessed reftype);
use parent 'Pandoc::Filter', 'Exporter';

our @EXPORT_OK = qw(read_file write_file);

sub new {
    my ($class, %opts) = @_;

    $opts{from} //= 'code';
    $opts{dir} //= '.';
    $opts{dir} =~ s!/$!!;
    $opts{name} //= sub {
        $_[0]->id =~ /^[a-z0-9_]+$/i ? $_[0]->id
            : md5_hex( encode( 'utf8', $_[0]->content ) );
    };

    die "missing option: to\n" unless $opts{to};

    if ('ARRAY' ne reftype $opts{run} or !@{$opts{run}}) {
        die "missing or empty option: run\n";
    }

    _verify_pandoc(\%opts);

    bless \%opts, $class;
}

sub to {
    my $to     = $_[0]->{to};
    my $format = $_[1];
    if (ref $to) {
        return $to->($format);
    } elsif ($to) {
        return $to;
    } else {
        return 'png';
    }
}

sub action {
    my $self = shift;

    sub {
        my ($e, $format, $m) = @_;

        return if $e->name ne 'CodeBlock';

        my $code = $e->content;
        my $dir  = $self->{dir};

        my %args = (
            name => $self->{name}->($e),
            from => $self->{from},
            to   => $self->to($format),
        );
        $args{infile}  = catfile($self->{dir}, "$args{name}.$args{from}");
        $args{outfile} = catfile($self->{dir}, "$args{name}.$args{to}");

        # TODO: document or remove this experimental code. If keep, expand args
        my $kv = $e->keyvals;
        my @options = $kv->get_all('option');
        push @options, map { split /\s+/, $_ } $kv->get_all('options');

        # TODO: print args in debug mode?

        # skip transformation if nothing has changed
        my $in  = stat($args{infile});
        my $out = stat($args{outfile});
        if (!$self->{force} and $in and $out and $in->mtime <= $out->mtime) {
            if ($code eq read_file($args{infile}, ':utf8')) {
                # no need to rebuild the same outfile
                return $self->_build_image($e, $args{outfile});
            }
        }

        write_file($args{infile}, $code, ':utf8');

        my ($stderr, $stdout);
        my @command = map {
                  my $s = $_;
                  #if ($args{substr $s, 1, -1})
                  $s =~ s|\$([^\$]+)\$| $args{$1} // $1 |eg;
                  $s
                } @{$self->{run}};
        push @command, @options;

        run3 \@command, \undef, \$stdout, \$stderr,
            {
                binmode_stdin  => ':utf8',
                binmode_stdout => ':raw',
                binmode_stderr => ':raw',
            };

        if ($self->{capture}) {
            write_file($args{outfile}, $stdout, ':raw');
        }

        # TODO: include $code or $stderr on error in debug mode
        # TODO: skip error if requested
        die $stderr if $stderr;

        return $self->_build_image($e, $args{outfile});
    }
}

# build_image( $element [, $filename ] )
#
# Maps an element to an L<Image|Pandoc::Elements/Image> element with attributes
# from the given element. The attribute C<caption>, if available, is transformed
# into image caption. This utility function is useful for filters that transform
# content to images. See graphviz, tikz, lilypond and similar filters in the
# L<examples|https://metacpan.org/pod/distribution/Pandoc-Elements/examples/>.

sub build_image {
    my $e = shift;
    my %opts = (@_%2) ? (filename => @_) : @_;
    my $filename = $opts{filename} // '';

    my $keyvals = $e->keyvals;
    my $title = $keyvals->get('title') // '';
    my $img = Image attributes { id => $e->id, class => $e->class },
        [], [$filename, $title];

    my $fig = $title =~ /^fig:/ || do {
        my $fig_attr = $keyvals->get('fig') // "";
        $fig_attr && ($fig_attr !~ /^false$/i);
    };
    # Support passing fig-caption with markdown/markup
    if ( defined( my $text = $keyvals->get('fig-caption') ) ) {
        _verify_pandoc( \%opts, $keyvals );
        my $contents
          = $opts{pandoc}->parse( "$opts{reader}$opts{reader_ext}" => $text )
          ->query( 'Para|Plain' => sub { $_->content } );
        if ( my @inlines = map {; @$_ } @$contents ) {
            push @{$img->content}, @inlines;
            $fig //= 1;
        }
    }
    # XXX: distinguish between alt-text and caption ?
    # elsif ( defined( my $alt = $keyvals->get('alt') ) ) {
    #     push @{$img->content}, Str($alt);
    #     $fig //= 0;
    # }
    elsif ( defined( my $caption = $keyvals->get('caption') ) ) {
        push @{$img->content}, Str($caption);
        # XXX: distinguish between alt-text and caption ?
        # $fig //= 1;
    }
    if ( $fig ) {
        $img->title('fig:' . $title) unless $title =~ /^fig:/;
        return Para [ $img ]; # Must be Para for fig: to work!
    }

    return Plain [ $img ];
}

# OO wrapper around function build_image
# in order to set default opts from object
sub _build_image {
    my $self = shift;
    my $e = shift;
    my %opts = (@_%2) ? (filename => @_) : @_;
    my %defaults = map {; $_ => $self->{$_} } qw( pandoc reader_ext reader );
    return build_image($e, %defaults, %opts);
}

sub write_file {
    my ($file, $content, $encoding) = @_;

    open my $fh, ">$encoding", $file
        or die "failed to create file $file: $!\n";
    print $fh $content;
    close $fh;
}

sub read_file {
    my ($file, $encoding) = @_;

    open my $fh, "<$encoding", $file
        or die "failed to open file: $file: $!\n";

    my $content = do { local $/; <$fh> };
    close $fh or die "failed to close file: $file: $!\n";

    return $content;
}

sub _verify_pandoc {
    my($opts, $keyvals) = @_;
    for my $pandoc ( $opts->{pandoc} ) {
        if ( !defined($pandoc) ) {
            $pandoc = pandoc;
        } elsif ( !blessed($pandoc) ) {
            'ARRAY' eq ref $pandoc or $pandoc = [$pandoc];
            my $error = do {
                local $@;
                eval { $pandoc = Pandoc->new(@$pandoc); };
                $@;
            };
            if ( $error ) {
                croak "couldn't instantiate Pandoc.pm: $error";
            }
        } else {
            $pandoc->isa('Pandoc')
                or croak "expected option 'pandoc' to be Pandoc.pm parameters or instance";
        }
    }
    if ( defined $keyvals ) {
        for my $key ( qw[ reader_ext reader_exts reader ] ) {
            $opts->{$key} //= "";
            (my $attr = $key) =~ tr/_/-/;
            $opts->{$key} = $keyvals->get($attr) // $opts->{$key};
        }
    }
    ($opts->{reader_ext} //= "") .= ($opts->{reader_exts} // "");
    $opts->{reader_ext} =~ /\A(?:[-+]\w+)*\z/
        or croak "expected option 'reader_ext' to be string with zero or more +EXTENSION and/or -EXTENSION";
    ($opts->{reader} //= 'markdown' ) =~ /\A(?!\d|_)\w+(?:[-+]\w+)*\z/
        or croak "expected option 'reader' to be pandoc input format";
    return $opts;
}

1;

__END__

=head1 NAME

Pandoc::Filter::ImagesFromCode - transform code blocks into images

=head1 DESCRIPTION

This L<Pandoc::Filter> transforms L<CodeBlock|Pandoc::Elements/CodeBlock>
elements into L<Image|Pandoc::Elements/Image> elements. Content of transformed
code section and resulting image files are written to files.

=head2 Attributes

The following attributes can be set on a CodeBlock to modify the output.

=over

=item title

Mapped to the image title attribute.

=item caption

Mapped to the image caption/alt-text as a single unformatted string.

Ignored if C<fig-caption> is also present.

=for UNIMPLEMENTED:
Ignored if C<alt> is also present.

=begin UNIMPLEMENTED:

=item alt

Mapped to the image caption/alt-text as a single unformatted string.

Ignored if C<fig-caption> is also present.

=end UNIMPLEMENTED:

=item fig

If set to a true value the image will be output as a figure
as per the Pandoc manual's description of the 
L<< C<implicit_figures> extension|http://pandoc.org/MANUAL.html#extension-implicit_figures >>.

This means that the Image element will be wrapped in a Para element rather than
a Plain element and the image title will have a C<fig:> prefix (which the Pandoc
writer will remove), so that the image is formatted as a figure by Pandoc writers
which support this.

In addition to customary Perl false values a value C<false> (case insensitive) is
considered to be false.  All other non-empty non-zero values are considered true.

=item fig-caption

If present and non-empty the value of this attribute will be converted with
L<Pandoc> and inserted as the caption of the image.

Implies a true value for C<fig>.

Use the C<caption> attribute unless you actually need the caption to contain 
formatted text; C<fig-caption> is expensive as it needs to shell out to the C<pandoc>
executable.  Cf. C<pandoc> under L<CONFIGURATION|/"CONFIGURATION"> below.

Since you probably will enclose this attribute value in double quotes use
the HTML C<&quot;> entity for embedded double quotes.
Pandoc will do the right thing!

=item reader

=item reader-ext

These attributes are only relevant if the C<fig-caption> attribute is also
present and non-empty!

See C<pandoc>, C<reader> and C<reader_ext> under L<CONFIGURATION|/"CONFIGURATION"> below.

If C<reader> and/or C<reader-ext> are given as attributes they override the 
corresponding constructor parameters.  Note the difference between
e.g. C<reader="markdown+smart"> and C<reader-ext="+smart">:
the value of C<reader-ext> will be appended to the value of C<reader>, or to 
the value for C<reader> passed to the constructor if the C<reader> I<attribute>
is missing.

=back

=head1 CONFIGURATION

=over

=item from

File extension of input files extracted from code blocks. Defaults to C<code>.

=item to

File extension of created image files. Can be a fixed string or a code reference that
gets the document output format (for instance C<latex> or C<html>) as argument to
produce different image formats depending on output format.

=item name

Code reference that maps the L<CodeBlock|Pandoc::Elements/CodeBlock> element to
a filename (without directory and extension). By default the element's C<id> is
used if it contains characters no other than C<a-zA-Z0-9_->. Otherwise the name
is the MD5 hash of the element's content.

=item dir

Directory where to place input and output files, relative to the current
directory. This directory (default C<.>) is prepended to all image references
in the target document.

=item run

Command to transform input files to output files. Variable references C<$...$>
can be used to refer to current values of C<from>, C<to>, C<name>, C<dir>,
C<infile> and C<outfile>. Example:

  run => ['ditaa', '-o', '$infile$', '$outfile$'],

=item capture

Capture output of command and write it to C<outfile>. Disabled by default.

=item force

Apply transformation also if input and output file already exists unchanged.
Disabled by default.

=item pandoc

A string containing the path to or name of the C<pandoc> executable to use
to convert any C<fig-caption> attributes as described under
L<Attributes|/"Attributes"> above.

If this is an array reference instead of a string the contents of the array
will be passed as arguments to the constructor of the
L<Pandoc|Pandoc/"METHODS"> module.

You can also pass an instance of the L<Pandoc> class.

You shouldn't provide any C<--from> or C<--to> options (or their aliases)
as these will be overridden on each invocation. Use C<reader> or
C<reader_ext> or their corresponding L<attributes|/"Attributes">
to set the input format.

If this parameter is omitted or undefined the defaults as described in
the L<Pandoc> module will be used.

=item reader

The pandoc reader to use when converting C<fig-caption> L<attributes|/"Attributes">.
Defaults to C<markdown>. Can be overridden on a per-image basis through the 
C<reader> L<attribute/"Attributes">.

=item reader_ext

A string containing zero or more C<+PANDOC_EXTENSION> and/or
C<-PANDOC_EXTENSION> substrings. Will be appended to the C<reader>
parameter or to any C<reader> L<attribute|/"Attributes"> which overrides
it, unless itself overridden by a C<reader-ext> attribute which will be
used instead of it if present.

=back

=cut
