package Pandoc::Filter::Usage;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.22';

use Pod::Simple::Pandoc;
use IPC::Run3;

sub frompod {
    my %opt = ref $_[0] ? %{$_[0]} : @_;

    if (!@_) {
        require Getopt::Long;
        Getopt::Long::GetOptions(\%opt, 'help|?', 'to|write:s');
    }
    return unless $opt{help};

    $opt{exitval} //= 0;

    if ($opt{to}) {
        my $doc = Pod::Simple::Pandoc->new->parse_file($0);
        my $json = $doc->to_json;
        run3 [qw(pandoc -f json -t), $opt{to}], \$json, undef, undef;
    } else {
        ## no critic
        my $module = -t STDOUT ? 'Pod::Text::Termcap' : 'Pod::Text';
        eval "require $module" or die "Can't locate $module in \@INC\n";
        $module->new( indent => 2, nourls => 1 )->parse_file($0);
    }

    exit $opt{exitval};
}

1;

=head1 NAME

Pandoc::Filter::Usage - get filter documentation from Pod

=head1 SYNOPSIS

Called automatically in L<Pandoc::Filter/pandoc_filter>. If a filter does not
directly use this function, use like this:

  my %opt;
  Getopt::Long::GetOptions(\%opt, 'help|?', 'to|write:s');
  Pandoc::Filter::Usage::frompod(\%opt);

=head1 DESCRIPTION

This module provides the function C<frompod> as replacement for C<pod2usage> to
get and print documentation of a filter.

=head1 FUNCTIONS

=head2 frompod [ %options | { %options } ]

Prints filter documentation from its Pod and exits if option C<help> is true.
If no options are passed, options are read from C<@ARGV> with L<GetOpt::Long>
to check whether command line option C<--help>, C<-h>, or C<-?> was specified.

If option C<to> or C<write> is given, L<Pod::Simple::Pandoc> is used to parse
the Pod and Pandoc is used to create output in the selected format.
Documentation is printed with L<Pod::Text> otherwise.

=head1 SEE ALSO

L<Pod::Usage>

=cut
