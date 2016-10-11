package Pandoc::Filter::Usage;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.24';

use Pod::Simple::Pandoc;
use Pandoc;

sub pod2usage {
    my %opt = ref $_[0] ? %{$_[0]} : @_;

    $opt{exitval} //= 0;

    if ($opt{to}) {
        my $doc = Pod::Simple::Pandoc->new->parse_file($0);
        my $json = $doc->to_json;
        pandoc->require('1.16');
        pandoc '-f' => 'json', '-t' => $opt{format},
            { in => \$json, out => undef, err => undef };
    } else {
        ## no critic
        my $module = -t STDOUT ? 'Pod::Text::Termcap' : 'Pod::Text';
        eval "require $module" or die "Can't locate $module in \@INC\n";
        $module->new( indent => 2, nourls => 1 )->parse_file($0);
    }

    exit $opt{exitval} if $opt{exitval} ne 'NOEXIT';
}

1;

=head1 NAME

Pandoc::Filter::Usage - print filter documentation from embedded Pod

=head1 DESCRIPTION

This module provides the function C<pod2usage> as replacement for C<pod2usage>
to get and print documentation of a filter script. The function is called
automatically by L<Pandoc::Filter/pandoc_filter>. If your filter does not use
this function, execute C<pod2usage> like this:

  my %opt;
  Getopt::Long::GetOptions(\%opt, 'help|?');
  Pandoc::Filter::Usage::pod2usage( to => $ARGV[0] ) if $opt{help};

=head1 FUNCTIONS

=head2 pod2usage [ %options | { %options } ]

Print filter documentation parsed with L<Pod::Simple::Pandoc> from its 
script and exit. 

=over

=item to

Output format (C<json>, C<markdown>, C<html>...) to print documentation with
pandoc. By default the documentation is printed with L<Pod::Text> instead.

=item exitval

The desired exit status to pass to the exit function or the string "NOEXIT" to
let the function return without calling exit.

=back

=head1 SEE ALSO

L<Pod::Usage>

=cut
