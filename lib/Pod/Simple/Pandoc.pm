package Pod::Simple::Pandoc;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.25';

use Pod::Simple::SimpleTree;
use Pandoc::Elements;
use Pandoc::Filter::HeaderIdentifiers;
use Pod::Simple::Pandoc::Modules;
use Pandoc;
use File::Find ();
use File::Spec;
use IPC::Run3;
use Carp;
use utf8;

sub new {
    my ($class, %opt) = @_;

    my @targets = qw(html HTML tex latex TeX LaTeX);
    if ($opt{'data-sections'}) {
        Pandoc->require('1.12');
        push @targets, pandoc->input_formats;
    }
    $opt{targets} = \@targets;

    $opt{podurl} //= 'https://metacpan.org/pod/';

    bless \%opt, $class;
}

sub _parser {
    my $self = shift;

    my $parser = Pod::Simple::SimpleTree->new;
    $parser->nix_X_codes(1);         # ignore X<...> codes
    $parser->nbsp_for_S(1);          # map S<...> to U+00A0 (non-breaking space)
    $parser->merge_text(1);          # emit text nodes combined
    $parser->no_errata_section(1);   # omit errata section
    $parser->complain_stderr(1);     # TODO: configure
    $parser->accept_targets(@{$self->{targets}});

    # remove shortest leading whitespace string from verbatim sections
    $parser->strip_verbatim_indent(
        sub {
            my $indent = length $_[0][1];
            for ( @{ $_[0] } ) {
                $_ =~ /^(\s*)/;
                $indent = length($1) if length($1) < $indent;
            }
            ' ' x $indent;
        }
    );

    return $parser;
}

sub parse_file {
    my ( $self, $file ) = @_;

    {
        # Pod::Simple::parse_file does not detect this
        no warnings;
        croak "Can't use directory as a source for parse_file" if -d $file;
    }

    my $doc = $self->parse_tree( $self->_parser->parse_file($file)->root );

    if (!ref $file and $file ne '-') {
        $doc->meta->{file} = MetaString($file);
    }

    $doc;
}

sub parse_string {
    my ( $self, $string ) = @_;
    $self->parse_tree( $self->_parser->parse_string_document($string)->root );
}

sub parse_tree {
    my $doc = Pandoc::Filter::HeaderIdentifiers->new->apply( _pod_element(@_) );

    my $sections = $doc->outline(1)->{sections};
    if (my ($name) = grep { $_->{header}->string eq 'NAME' } @$sections) {
        # TODO: support formatting
        my $text = $name->{blocks}->[0]->string;
        my ($title, $subtitle) = $text =~ m{^\s*([^ ]+)\s*[:-]*\s*(.+)};
        $doc->meta->{title} = MetaString($title) if $title;
        $doc->meta->{subtitle} = MetaString($subtitle) if $subtitle;
    }

    $doc;
}

sub parse_and_merge {
    my ($self, @input) = @_;

    my $doc;

    foreach my $file (@input) {

        # map module names to files
        if ($file ne '-' and !-e $file) {
            run3 ['perldoc','-lm',$file], undef, \$file;
            exit $? if $?;
        }
        my $cur = $self->parse_file($file);
        if ($doc) {
            push @{ $doc->content }, @{ $cur->content };
        }
        else {
            $doc = $cur;
        }
    }

    return unless $doc;

    $doc->meta->{file} = MetaList [ map { MetaString $_ } @input ];

    return $doc;
}


sub parse_dir {
    my ($parser, $directory) = @_;
    my $files = {};

    File::Find::find({
        no_chdir => 1,
        wanted => sub {
            my $file = $_;
            return if $file !~ /\.(pm|pod)$/;
            my $doc = $parser->parse_file($file);
            my $base = File::Spec->abs2rel($directory, $file);
            $base =~ s/\.\.$//;
            $doc->meta->{base} = MetaString $base;
            $files->{$file} = $doc;
        } }, $directory);

    $files;
}

sub parse_modules {
    my $parser = shift;
    my %opt = @_ % 2 ? (source => @_) : @_;
    return unless defined $opt{source} and -d $opt{source};

    my $modules = {};
    foreach my $doc ( values %{$parser->parse_dir($opt{source})} ) {
        my $file = $doc->metavalue('file');
        my $module = File::Spec->abs2rel($file, $opt{source});
        $module =~ s{\.(pm|pod)$}{}g;
        $module =~ s{/}{::}g;
        if (($doc->metavalue('title') // $module) eq $module) {
            if ($modules->{$module}) {
                # TODO: compare file and prefer .pod over .pm if both given
                warn "$file skipped for ".$modules->{$module}->metavalue('file')
                    unless $opt{quiet};
                next;
            }
            $modules->{$module} = $doc;
        } else {
            warn "$file NAME does not match module\n" unless $opt{quiet};
        }
    }

    bless $modules, 'Pod::Simple::Pandoc::Modules';
}


my %POD_ELEMENT_TYPES = (
    Document => sub {
        Document {}, [ _pod_content(@_) ];
    },
    Para => sub {
        Para [ _pod_content(@_) ];
    },
    I => sub {
        Emph [ _pod_content(@_) ];
    },
    B => sub {
        Strong [ _pod_content(@_) ];
    },
    L => \&_pod_link,
    C => sub {
        Code attributes {}, _pod_flatten(@_);
    },
    F => sub {
        Code attributes { classes => ['filename'] }, _pod_flatten(@_);
    },
    head1 => sub {
        Header 1, attributes {}, [ _pod_content(@_) ];
    },
    head2 => sub {
        Header 2, attributes {}, [ _pod_content(@_) ];
    },
    head3 => sub {
        Header 3, attributes {}, [ _pod_content(@_) ];
    },
    head4 => sub {
        Header 4, attributes {}, [ _pod_content(@_) ];
    },
    Verbatim => sub {
        CodeBlock attributes {}, _pod_flatten(@_);
    },
    'over-bullet' => sub {
        BulletList [ _pod_list(@_) ];
    },
    'over-number' => sub {
        OrderedList [ 1, DefaultStyle, DefaultDelim ], [ _pod_list(@_) ];
    },
    'over-text' => sub {
        DefinitionList [ _pod_list(@_) ];
    },
    'over-block' => sub {
        BlockQuote [ _pod_content(@_) ];
    },
    'for' => \&_pod_data,
);

# option --smart
sub _str {
    my $s = shift;
    $s =~ s/\.\.\./…/g;
    Str $s;
}

# map a single element or text to a list of Pandoc elements
sub _pod_element {
    my ($self, $element) = @_;

    if ( ref $element ) {
        my $type = $POD_ELEMENT_TYPES{ $element->[0] } or return;
        $type->($self, $element);
    }
    else {
        my $n = 0;
        map { $n++ ? ( Space, _str($_)) : _str($_) } split( /\s+/, $element, -1 );
    }
}

# map the content of a Pod element to a list of Pandoc elements
sub _pod_content {
    my ($self, $element) = @_;
    my $length = scalar @$element;
    map { _pod_element($self, $_) } @$element[ 2 .. ( $length - 1 ) ];
}

# stringify the content of an element
sub _pod_flatten {
    my $string = '';
    my $walk;
    $walk = sub {
        my ($element) = @_;
        my $n = scalar @$element;
        for ( @$element[ 2 .. $n - 1 ] ) {
            if ( ref $_ ) {
                $walk->($_);
            }
            else {
                $string .= $_;
            }
        }
    };
    $walk->($_[1]);

    return $string;
}

# map link
sub _pod_link {
    my ($self, $link) = @_;
    my $type    = $link->[1]{type};
    my $to      = $link->[1]{to};
    my $section = $link->[1]{section};
    my $url     = '';

    if ( $type eq 'url' ) {
        $url = "$to";
    }
    elsif ( $type eq 'man' ) {
        if ( $to =~ /^([^(]+)(?:[(](\d+)[)])?$/ ) {

            # TODO: configure MAN_URL, e.g.
            # http://man7.org/linux/man-pages/man{section}/{name}.{section}.html
            $url = "http://linux.die.net/man/$2/$1";

            # TODO: add section to URL if given
        }
    }
    elsif ( $type eq 'pod' ) {
        if ($to) {
            $url = $self->{podurl}.$to;
        }
        if ($section) {
            $section = header_identifier("$section") unless $to; # internal link
            $url .= "#" . $section;
        }
    }

    return Link attributes { }, [ _pod_content($self, $link) ], [ $url, '' ];
}

# map data section
sub _pod_data {
    my ($self, $element) = @_;
    my $target = lc( $element->[1]{target} );

    my $length = scalar @$element;
    my $content = join "\n\n", map { $_->[2] }
      grep { $_->[0] eq 'Data' } @$element[ 2 .. $length - 1 ];

    if ( $target eq 'html' ) {
        $content = "<div>$content</div>" if $content !~ /^<.+>$/s;
        RawBlock 'html', $content . "\n";
    }
    elsif ( $target =~ /^(la)?tex$/ ) {

        # TODO: more intelligent check & grouping, especiall at the end
        $content = "\\begingroup $content \\endgroup" if $content !~ /^[\\{]/;
        RawBlock 'tex', "$content\n";
    }
    elsif (grep { $target eq $_ } @{$self->{targets}}) {
        my $doc = pandoc->parse( $target => $content, '--smart' );
        @{ $doc->content };
    }
}

# map a list (any kind)
sub _pod_list {
    my ($self, $element) = @_;
    my $length = scalar @$element;

    my $deflist = $element->[2][0] eq 'item-text';
    my @list;
    my $item = [];

    my $push_item = sub {
        return unless @$item;
        if ($deflist) {
            my $term = shift @$item;
            push @list, [ $term->content, [$item] ];
        }
        else {
            push @list, $item;
        }
    };

    foreach my $e ( @$element[ 2 .. $length - 1 ] ) {
        my $type = $e->[0];
        if ( $type =~ /^item-(number|bullet|text)$/ ) {
            $push_item->();
            $item = [ Plain [ _pod_content($self, $e) ] ];
        }
        else {
            if ( @$item == 1 and $item->[0]->name eq 'Plain' ) {

                # first block element in item should better be Paragraph
                $item->[0] = Para $item->[0]->content;
            }
            push @$item, _pod_element($self, $e);
        }
    }
    $push_item->();

    # BulletList/OrderedList: [ @blocks ], ...
    # DefinitionList: [ [ @inlines ], [ @blocks ] ], ...
    return @list;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pod::Simple::Pandoc - convert Pod to Pandoc document model

=head1 SYNOPSIS

  use Pod::Simple::Pandoc;

  my $parser = Pod::Simple::Pandoc->new;
  my $doc    = $parser->parse_file( $filename );

  # result is a Pandoc::Document object
  my $json = $doc->to_json;
  my $markdown = $doc->to_pandoc( -t => 'markdown' );
  $doc->to_pandoc(qw( -o doc.html --standalone ));

=head1 DESCRIPTION

This module converts POD format documentation (L<perlpod>) to the document
model used by L<Pandoc|http://pandoc.org/>. The result object can be accessed
with methods of L<Pandoc::Elements> and emitted as JSON for further processing
to other document formats (HTML, Markdown, LaTeX, PDF, EPUB, docx, ODT,
man...).

The command line script L<pod2pandoc> makes use of this module, for instance to
directly convert to PDF:

  pod2pandoc input.pod -o output.pdf

=head1 OPTIONS

=over

=item data-sections

Parse L<data sections|/Data sections> of pandoc input formats with L<Pandoc>
and merge them into the document (disabled by default).

=item podurl

Base URL to link Perl module names to. Set to L<https://metacpan.org/pod/> by
default.

=back

=head1 METHODS

=head2 parse_file( $filename | *INPUT )

Reads Pod from file or filehandle and convert it to a L<Pandoc::Document>. The
filename is put into document metadata field C<file> and the module name. The
NAME section, if given, is additionally split into metadata fields C<title> and
C<subtitle>.

=head2 parse_and_merge( @files_or_modules )

Reads Pod from files or modules given by name and merges them into one 
L<Pandoc::Document>.

=head2 parse_string( $string )

Reads Pod from string and convert it to a L<Pandoc::Document>. Also sets
metadata fields C<title> and C<subtitle>.

=head2 parse_dir( $directory )

Recursively looks for C<.pm> and C<.pod> files in a given directory and parses
them. Returns a hash reference with filenames mapped to L<Pandoc::Document>
objects. Each document is enriched with metadata fields C<base> (relative path
from each file to the base directory) in addition to C<file>, C<title>, and
C<subtitle>.

=head2 parse_modules( [ $directory ], %options )

Same as method C<parse_dir> but returns a L<Pod::Simple::Pandoc::Modules>
instance that maps module names to L<Pandoc::Document> instances. The source
directory can also be specified with option C<source>. Option C<quiet> disables
warnings for skipped files. See module L<Pod::Simple::Pandoc::Modules> for
further usage.

=head1 MAPPING

Pod elements are mapped to Pandoc elements as following:

=head2 Formatting codes

L<Formatting codes|perlpod/Formatting Codes> for I<italic text>
(C<IE<lt>...E<gt>>), B<bold text> (C<BE<lt>...E<gt>>), and C<code>
(C<CE<lt>...E<gt>>) are mapped to Emphasized text (C<Emph>), strongly
emphasized text (C<Strong>), and inline code (C<Code>). Formatting code for
F<filenames> (C<FE<lt>...E<gt>>) are mapped to inline code with class
C<filename> (C<`...`{.filename}> in Pandoc Markdown).  Formatting codes inside
code and filenames (e.g. C<code with B<bold>> or F<L<http://example.org/>> as
filename) are stripped to unformatted code.  Character escapes
(C<EE<lt>...E<gt>>) and C<SE<lt>...E<gt>> are directly mapped to Unicode
characters. The special formatting code C<XE<lt>...E<gt>> is ignored.

=head2 Links

Some examples of links of different kinds:

L<http://example.org/>

L<pod2pandoc>

L<pod2pandoc/"OPTIONS">

L<perl(1)>

L<crontab(5)/"ENVIRONMENT">

L<hell itself!|crontab(5)>

Link text can contain formatting codes:

L<the C<pod2pandoc> script|pod2pandoc>

Internal links are not supported yet:

L</"MAPPING">

L<mapping from PoD to Pandoc|/"MAPPING">

=head2 Titles I<may contain formatting C<codes>>!

=head2 Lists

=over

=item 1

Numbered lists are

=item 2

converted to C<NumberedList> and

=over

=item *

Bulleted lists are

=item *

converted to

C<BulletList>

=back

=back

=over

=item Definition

=item Lists

=item are

I<also> supported.

=back

=head2 =over/=back

=over

An C<=over>...C<=back> region containing no C<=item> is mapped to C<BlockQuote>.

=back

=head2 Verbatim sections

  verbatim sections are mapped
    to code blocks

=head2 Data sections

Data sections with target C<html> or C<latex> are passed as C<RawBlock>.
C<HTML>, C<LaTeX>, C<TeX>, and C<tex> are recognized as alias.

With option C<parse-data-sections> additional targets supported by pandoc as
input format (C<markdown>, C<markdown_github>, C<rst>...) are parsed with
L<Pandoc> and merged into the result document.

=begin markdown

### Examples

=end markdown

=begin html

<p>
  HTML is passed through

  as <i>you can see here</i>.
</p>

=end html

=for html HTML is automatically enclosed in
  <code>&ltdiv>...&lt/div></code> if needed.

=for latex \LaTeX\ is passed through as you can see here.

=begin tex

\LaTeX\ sections should start and end so Pandoc can recognize them.

=end tex

=head1 SEE ALSO

This module is based on L<Pod::Simple> (L<Pod::Simple::SimpleTree>). It makes
obsolete several specialized C<Pod::Simple::...> modules such as
L<Pod::Simple::HTML>, L<Pod::Simple::XHTML>, L<Pod::Simple::LaTeX>,
L<Pod::Simple::RTF> L<Pod::Simple::Text>, L<Pod::Simple::Wiki>, L<Pod::WordML>,
L<Pod::Perldoc::ToToc> etc.

=cut
