package Pod::Simple::Pandoc::Modules;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.30';

use File::Path qw(make_path);
use File::Find;
use File::Spec;
use File::Basename qw(dirname);
use Pandoc::Elements;
use Carp qw(croak);

sub module_link {
    my ($module, $opt) = @_;
    if ($opt->{wiki}) {
        my $target = $module;
        $target =~ s{::}{-}g;
        return Link attributes {}, [ Str $module ], [ $target, 'wikilink' ];
    } else {
        my $name = shift;
        my $file = $name;
        $file =~ s{::}{/}g;
        $file .= '.' . ($opt->{ext} // 'html');
        return Link attributes {}, [ Str $name ], [ $file, $name ];
    }
}


sub index {
    my ($modules, %opt) = @_;

    my $meta = {}; # TODO

    Document $meta, [
        map { Para [ module_link($_, \%opt) ] } sort keys %$modules 
    ];
}

sub serialize {
    my ($modules, $dir, $opt, @args) = _parse_arguments(@_);

    # adjust links
    # TODO: create copy instead of transforming, so
    # this can be called multiple times!
    foreach my $doc (values %$modules) {
        $doc->transform( Link => sub {
            # TODO: use configured prefix instead of hard-coded URL base
            my ($module, $hash) = $_->url =~ qr{^https://metacpan\.org/pod/([^#]+)(#.*)?$};
            return unless ($module and $modules->{$module});

            # TODO: check whether hash link target exists 
            my $link = module_link($module, $opt);
            if (defined $hash) {
                $link->url( $link->url . $hash );
            }
            return $link;
        } );
    }

    # serialize
    foreach my $doc (values %$modules) {
        my $file = $doc->metavalue('file');
        my $module = $doc->metavalue('title');

        my $name = $module;
        if ($opt->{wiki}) {
            $name =~ s{::}{-}g;
        } else {
            $name =~ s{::}{/}g;
        }
        $name .= '.' . ($opt->{ext} // 'html');
        my $target = File::Spec->catfile($dir, $name);

        # TODO: respect option update
        make_path(dirname($target));
        $doc->to_pandoc( -o => $target, @args );
        say "$file => $target" unless $opt->{quiet};
    }

    # create index file
    if ($opt->{index}) {
        my $index = $modules->index(%$opt);
        my $target = File::Spec->catfile($dir, $opt->{index} . '.' . $opt->{ext});
        $index->to_pandoc(@args, -o => $target);
        say $target unless $opt->{quiet}; 
    }
}

sub _parse_arguments {
    my $modules = shift;

    my $dir =  ref $_[0] ? undef : shift;
    my %opt = ref $_[0] ? %{shift()} : ();
    
    $dir //= $opt{dir} // croak "output directory must be specified!";
    $opt{index} = 'index' unless exists $opt{index};

    $opt{ext} //= 'html';
    $opt{ext} =~ s/^\.//;
    croak "ext must not be .pm or .pod" if $opt{ext} =~ /^(pod|pm)$/;

    ($modules, $dir, \%opt, @_);
}


1;
__END__

=head1 NAME

Pod::Simple::Pandoc::Modules - set of parsed documentation of Perl modules

=head1 SYNOPSIS

  use Pod::Simple::Pandoc;

  my $modules = Pod::Simple::Pandoc->new->parse_modules('lib');
  $modules->serialize( { target => 'doc' }, '--template' => '...' ] ); # TODO

=head1 DESCRIPTION

Module to serialize Pod from a set of parsed Perl or Pod files. Can be
configured via templates, document rewriting etc. and used with many output
formats (html, markdown, and rst to be embedded in static site generators such
as Jekyll).

=head1 EXAMPLES

Create GitHub Wiki pages:

    $modules->serialize(
        { dir => 'wiki', ext => 'md', index => 'Home', wiki => 1 },
        ...
    );

=head1 METHODS

=head2 serialize ( [ $dir ] [, \%options ] [, @args ] )

Serialize a set of modules into a given directory.

This method is experimental and may change!

=over

=item dir

Output directory.

=item ext

Output file extension. Set to the value of C<format> by default.

=item index

Index filename (with or without extension). Set to C<index> by default. Use a
false value to disable index generation.

=item wiki

Don't create subdirectories and use wiki links for references between files.
instead.

=item update

Generate target files even if source files have not been updated.

=item quiet

Don't emit warnings and status information.

=back

=head2 index ( %options )

Create and return an index document as L<Pandoc::Document>.

=head1 SEE ALSO

L<pod2pandoc>, L<App::pod2pandoc>, L<Pod::Simple::Pandoc>

=cut
