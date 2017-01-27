package App::pod2pandoc;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.30';

use Getopt::Long qw(:config pass_through);
use Pod::Usage;
use Pod::Simple::Pandoc;
use Pandoc;
use Pandoc::Elements;
use List::Util qw(all);

use parent 'Exporter';
our @EXPORT = qw(pod2pandoc);
our @EXPORT_OK = qw(pod2pandoc parse_arguments);


sub parse_arguments {
    my %opt;
    Getopt::Long::GetOptionsFromArray(
        \@_, \%opt,
        'help|h|?', 'data-sections', 'podurl=s',
        'ext=s', 'index=s', 'wiki', 'update', 'quiet'
    ) or exit 1;
    pod2usage(1) if delete $opt{help};

    my @input = @_ ? () : '-';

    my ($index) = grep { $_[$_] eq '--' } (0 .. @_-1);

    if (defined $index) {
        push @input, shift @_ for 0..$index-1;
        shift @_; # --
    } else {
        push(@input, shift @_) while @_ and $_[0] !~ /^-./;
    }

    return (\@input, \%opt, @_);
}

sub pod2pandoc {
    my $input = shift;
    my $opt   = ref $_[0] ? shift : {};
    my @args  = @_;

    # directories
    if (@$input > 0 and -d $input->[0]) {
        my $target = @$input > 1 ? pop @$input : $input->[0];

        foreach my $dir (@$input) {
            my $modules = Pod::Simple::Pandoc->new->parse_modules($dir);
            warn "no .pm or .pod files found in $dir\n"
                unless %$modules or $opt->{quiet};
            $modules->serialize( $target, $opt, @args );
        }
    }
    # files and/or module names
    else {
        my $parser = Pod::Simple::Pandoc->new(%$opt);
        my $doc = $parser->parse_and_merge(@$input ? @$input : '-');

        if (@args) {
            pandoc->require('1.12.1');
            $doc->pandoc_version( pandoc->version );
            $doc->to_pandoc(@args);
        } else {
            print $doc->to_json, "\n";
        }
    }
}

1;
__END__

=head1 NAME

App::pod2pandoc - implements pod2pandoc command line script

=head1 SYNOPSIS

  use App::pod2pandoc;

  # pod2pandoc command line script
  my ($input, $opt, @args) = parse_arguments(@ARGV); 
  pod2pandoc($input, $opt, @args);

  # parse a Perl/Pod file and print its JSON serialization
  pod2pandoc( ['example.pl'], {} );

  # parse a Perl/Pod file and convert to HTML with a template
  pod2pandoc( ['example.pl'], {}, '--template', 'template.html' );

  # process directory of Perl modules
  pod2pandoc( [ lib => 'doc'], { ext => 'html' }, '--standalone' );

=head1 DESCRIPTION

This module implements the command line script L<pod2pandoc>.

=head1 FUNCTIONS

=head2 pod2pandoc( \@input, [ \%options, ] \@arguments )

Processed input files with given options (C<data-sections>, C<podurl>, C<ext>,
C<wiki>, C<update>, and C<quiet>, see script L<pod2pandoc> for documentation) .
Additional arguments are passed to C<pandoc> executable via module L<Pandoc>.

Input can be either files and/or module names or directories to recursively
search for C<.pm> and C<.pod> files. If no input is specified, Pod is read from
STDIN. When processing directories, the last input directory is used as output
directory.

This function is exported by default.

=head2 parse_arguments( @argv )

Parses options and input arguments from given command line arguments. May
terminate the program with message, for instance with argument C<--help>.

=head1 SEE ALSO

This module is based on L<Pod::Simple::Pandoc>, L<Pod::Simple::Pandoc::Modules>
that use L<Pandoc::Element> und L<Pandoc>.

See L<Pod::Simple::HTMLBatch>, L<Pod::ProjectDocs>, L<Pod::POM::Web>, and
L<Pod::HtmlTree> for other modules for batch conversion of Perl documentation.

=cut
