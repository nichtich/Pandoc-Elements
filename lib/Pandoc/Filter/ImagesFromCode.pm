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

my $check_pandoc_obj = sub {
    blessed $_[0] and $_[0]->isa( 'Pandoc' )
      or croak "option 'pandoc' must be undefined or an instance of class Pandoc";
};

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

    $check_pandoc_obj->($opts{pandoc} //= pandoc);

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
    # XXX: NB This regex is negatively defined, i.e. note the `[^`!
    # It matches the complement of the listed props and chars!
    state $md_metachars_re = qr/[^\P{PosixPunct}\p{Term}()+%#]/;
    # check for trivially well-formed pandoc format string
    state $pandoc_format_re = qr/^(?![\d_])\w+(?:[-+]\w+)*$/;
    # defined and false pandoc-format == don't invoke pandoc!
    state $defined_and_false = sub {
        defined( $_[0] ) and (!$_[0] or $_[0] =~ /^false$/i);
    };
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
    if ( defined( my $text = $keyvals->get( 'caption' ) ) ) {
        my $format = $keyvals->get( 'pandoc-format' )    #
          // $opts{pandoc_format}                               #
          // 'markdown';                                        #
        # defined and false pandoc-format == don't invoke pandoc!
        my $no_conv = $defined_and_false->($format)
            or $defined_and_false->($opts{pandoc_format});           #
        if ( $no_conv or !$opts{pandoc} or $text !~ $md_metachars_re ) {
            push @{ $img->content }, Str( $text );
        } elsif ( $fig or $format and $opts{pandoc} ) {
            $check_pandoc_obj->( $opts{pandoc} );
            if ( $format =~ /^[-+]/ ) {       # if only extensions
                    # maybe p-f attr is only exts but p_f option is format
                my $_format
                  = ( $opts{pandoc_format} and $opts{pandoc_format} !~ /^[-+]/ )
                  ? $opts{pandoc_format}
                  : 'markdown';
                $format = $_format . $format;
                $format =~ $pandoc_format_re
                    or croak "doesn't look like a pandoc --reader format: $format";
            }
            my $contents = $opts{pandoc}->parse( $format => $text )
              ->query( 'Para|Plain' => sub { $_->content } );
            my @inlines = map {; @$_ } @$contents;
            if ( @inlines ) {
                push @{ $img->content }, @inlines;
                $fig //= 1;
            }
        }
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
    my %defaults = map {; $_ => $self->{$_} } qw( pandoc pandoc_format );
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

=item fig

If set to a true value the image will be output as a figure
as per the Pandoc manual's description of the 
L<< C<implicit_figures> extension|http://pandoc.org/MANUAL.html#extension-implicit_figures >>.

This means that the Image element will be wrapped in a Para element rather
than a Plain element and the image title will have a C<fig:> prefix (which
the Pandoc writer will remove), so that the image is formatted as a figure
by Pandoc writers which support this.

In addition to customary Perl false values the string C<false> (case
insensitive) is considered to be a false value. All other non-empty
non-zero values are considered true.

If the C<fig> attribute is non-false the value of the C<caption> attribute
contains any characters which are used in in Pandoc Markdown markup the
value of the C<caption> attribute will be converted with L<Pandoc> and
inserted as the caption of the image. You can use the C<pandoc-format>
attribute to force conversion with L<Pandoc> to be either performed or
skipped, or performed from a format other than C<markdown> and/or with
non-default extensions.

=item pandoc-format

If this attribute is defined and is not a Perl false value or the string
C<false> (case insensitive) the value of the C<caption> attribute will be
converted with L<Pandoc> and inserted as the caption of the image
regardless of whether it contains any characters which are used in in
Pandoc Markdown markup or not.

Such a non-false value must be either a string suitable to be passed to the
Pandoc C<--reader>/C<--from>/C<-r>/C<-f> option, i.e. a valid Pandoc
input format with or without trailing extensions in
C<+EXTENSION>/C<-EXTENSION> format. If the value of this attribute starts
with a C<+> or C<-> character it is assumed to consist of extensions
only and will be appended to the value of the C<pandoc_format> option
passed to the constructor, or if that is not set to C<markdown> as the
default format.

If the value of this attribute is defined and B<is> a Perl false value or
the string C<false> (case insensitive) the value of the C<caption>
attribute will B<not> be converted with L<Pandoc> regardless of its
content. 

If this attribute is I<undefined> the conversion of the caption text
will be decided based on the value of the C<fig> attribute and
the presence of Pandoc Markdown markup characters as described
above under the C<fig> attribute.

The precence of this attribute implies a true value for the C<fig>
attribute.

Don't use the C<pandoc-format> attribute with a true value unless you
actually need the caption to contain formatted text. Each formatted caption
is expensive as the filter needs to call out to the C<pandoc> executable
once for each such caption. Cf. C<pandoc> under
L<CONFIGURATION|/"CONFIGURATION"> below.

Since you probably will enclose the C<caption> attribute value in double
quotes use the HTML C<&quot;> entity for embedded double quotes in
formatted captions. Pandoc will do the right thing!

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

An instance of the L<Pandoc> class to use to convert any figure C<caption>
attributes as described under L<Attributes|/"Attributes"> above.

You shouldn't provide any C<--from> or C<--to> options (or their aliases)
as these will be overridden on each invocation. Use C<pandoc_format> or the
corresponding L<attribute|/"Attributes"> to set the input format.

If this parameter is omitted or undefined the defaults as described in
the L<Pandoc> module will be used.

=item pandoc_format

The pandoc reader to use when converting figure C<caption>
L<attributes|/"Attributes">. along with any extensions which you want to
apply, as described under the C<pandoc-format> L<attribute/"Attributes">
above, which can be used override this option on a per-image basis.

Defaults to C<markdown>.

If the value of this option is B<defined> but is a Perl false value or
the string C<false> (case insensitive) conversion of C<caption> attributes
with L<Pandoc> will be globally disabled. This is useful if you want to
skip calling out to C<pandoc> when producing draft document versions, since
unlike the images themselves caption texts converted with L<Pandoc> can not
be cached.

=back

=cut
